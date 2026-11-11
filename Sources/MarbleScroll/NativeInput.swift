import AppKit
import ApplicationServices
import IOKit
#if SWIFT_PACKAGE
import MarbleCore
#endif

enum NativeInputError: LocalizedError {
    case permission, tapDenied, sourceFailed
    var errorDescription: String? {
        switch self {
        case .permission: return "Accessibility permission is absent. MarbleScroll made no permission request."
        case .tapDenied: return "macOS refused the mouse tap. Scrolling remains disabled. Do not run as root or weaken security settings."
        case .sourceFailed: return "Could not create the event source. Normal input remains enabled."
        }
    }
}

final class NativeInput: InputBackend {
    static let marker: Int64 = 0x4D4152424C455343
    let gate = SafetyLatch<CFMachPort> { port in
        CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port)
    }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var probe = false
    var onRoute: ((Input, (ScrollPixels) -> Bool) -> Bool)?
    var onFault: ((Bool) -> Void)?
    var onButton: ((Int) -> Void)?

    static let scrollingTypes: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                               .otherMouseDragged, .otherMouseDown, .otherMouseUp]
    static func mask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(0) { $0 | (CGEventMask(1) << $1.rawValue) }
    }
    func start() throws { try install(probe: false) }
    func recover() throws { try start() }
    func startProbe() throws { try install(probe: true) }
    func stop() {
        gate.disarm()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil; probe = false
    }
    private func install(probe: Bool) throws {
        stop()
        guard AXIsProcessTrusted() else { throw NativeInputError.permission }
        self.probe = probe
        let types: [CGEventType] = probe ? [.otherMouseDown] : Self.scrollingTypes
        // No silent session/warp fallback. Failure is safe and visible.
        guard let port = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
            options: probe ? .listenOnly : .defaultTap, eventsOfInterest: Self.mask(for: types),
            callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<NativeInput>.fromOpaque(context).takeUnretainedValue()
                return owner.receive(proxy, type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            self.probe = false; throw NativeInputError.tapDenied
        }
        guard let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port)
            self.probe = false; throw NativeInputError.sourceFailed
        }
        tap = port; source = runSource
        guard gate.arm(port) else {
            CFMachPortInvalidate(port); self.tap = nil; self.source = nil
            throw NativeInputError.tapDenied
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }
    private func receive(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let original = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            gate.disarm(); onFault?(type == .tapDisabledByTimeout); return original
        }
        guard gate.isArmed else { return original }
        guard !probe || AXIsProcessTrusted() else {
            gate.disarm(); onFault?(false); return original
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return original }
        if probe {
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            onButton?(button); return original
        }
        let kind: InputKind
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            kind = .move(Delta(event.getDoubleValueField(.mouseEventDeltaX), event.getDoubleValueField(.mouseEventDeltaY)))
        case .otherMouseDown: kind = .down(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .otherMouseUp: kind = .up(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        default: return original
        }
        let consumed = onRoute?(Input(kind, at: ProcessInfo.processInfo.systemUptime), { pixels in
            guard self.gate.isArmed else { return false }
            guard let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                       wheel1: pixels.vertical, wheel2: pixels.horizontal, wheel3: 0) else {
                return false
            }
            guard self.gate.isArmed else { return false }
            scroll.setIntegerValueField(.eventSourceUserData, value: Self.marker)
            scroll.location = event.location
            scroll.flags = event.flags
            // The wheel type is absent from our mask. No synthetic clicks or pointer warps.
            scroll.tapPostEvent(proxy)
            return true
        }) ?? false
        guard gate.isArmed else { return original }
        return consumed ? nil : original
    }
}

/// USB registry metadata only: no IOHIDManagerOpen, input reports or device seizure.
final class TrackballPresence {
    static let vendor = 0x046D, product = 0xC408
    private var port: IONotificationPortRef?
    private var added: io_iterator_t = 0
    private var removed: io_iterator_t = 0
    private var devices = Set<UInt64>()
    private(set) var error: String?
    var connected: Bool { !devices.isEmpty }
    var onChange: (() -> Void)?
    func start() {
        stop()
        guard let p = IONotificationPortCreate(kIOMainPortDefault) else { error = "USB notifications unavailable"; return }
        port = p
        if let source = IONotificationPortGetRunLoopSource(p)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        func matching() -> CFDictionary {
            let dictionary = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
            dictionary["idVendor"] = Self.vendor; dictionary["idProduct"] = Self.product
            return dictionary
        }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let a = IOServiceAddMatchingNotification(p, kIOFirstMatchNotification, matching(), { context, iterator in
            guard let context else { return }
            Unmanaged<TrackballPresence>.fromOpaque(context).takeUnretainedValue().drain(iterator, adding: true)
        }, ctx, &added)
        let r = IOServiceAddMatchingNotification(p, kIOTerminatedNotification, matching(), { context, iterator in
            guard let context else { return }
            Unmanaged<TrackballPresence>.fromOpaque(context).takeUnretainedValue().drain(iterator, adding: false)
        }, ctx, &removed)
        guard a == KERN_SUCCESS, r == KERN_SUCCESS else { stop(); error = "USB notifications failed (\(a), \(r))"; return }
        error = nil
        drain(added, adding: true); drain(removed, adding: false)
    }
    private func drain(_ iterator: io_iterator_t, adding: Bool) {
        let before = devices
        while case let service = IOIteratorNext(iterator), service != 0 {
            var id: UInt64 = 0
            if IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS {
                if adding { devices.insert(id) } else { devices.remove(id) }
            }
            IOObjectRelease(service)
        }
        if before != devices { onChange?() }
    }
    func stop() {
        if added != 0 { IOObjectRelease(added); added = 0 }
        if removed != 0 { IOObjectRelease(removed); removed = 0 }
        if let port {
            if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            IONotificationPortDestroy(port)
        }
        port = nil; devices.removeAll()
    }
    deinit { stop() }
}
