import Foundation

/// Main-run-loop permission snapshot. No timer, idle polling or permission requests.
/// Active input revalidates at most once per 250 ms. Explicit actions force a check.
public final class PermissionSnapshot {
    public private(set) var cached = false
    private var checkedAt: Double?
    private let query: () -> Bool
    private let maxAge: Double
    public init(maxAge: Double = 0.25, query: @escaping () -> Bool) {
        self.maxAge = maxAge.isFinite ? max(0, maxAge) : 0
        self.query = query
    }
    public func value(at time: Double, force: Bool = false) -> Bool {
        guard time.isFinite else { cached = false; checkedAt = nil; return false }
        if force || checkedAt == nil || time < checkedAt! || time - checkedAt! >= maxAge {
            cached = query(); checkedAt = time
        }
        return cached
    }
}

public enum TapEvent {
    case input(InputKind)
    case unhandled
    case disabled(timeout: Bool)
}

/// Production callback policy shared by the native adapter and mock tests.
/// Core Graphics allocation/posting stays in the adapter's output closure.
public final class MouseTapRouter {
    public static let syntheticMarker: Int64 = 0x4D4152424C455343
    public var onRoute: ((Input, (ScrollPixels) -> Bool) -> Bool)?
    public var onFault: ((Bool) -> Void)?
    public var onButton: ((Int) -> Void)?
    private let armed: () -> Bool
    private let disarm: () -> Void
    private let permission: () -> Bool
    public init(armed: @escaping () -> Bool, disarm: @escaping () -> Void, permission: @escaping () -> Bool) {
        self.armed = armed; self.disarm = disarm; self.permission = permission
    }
    /// true drops the physical event; false returns it unchanged.
    public func receive(_ event: TapEvent, marker: Int64, probe: Bool, at time: Double,
                        output: (ScrollPixels) -> Bool) -> Bool {
        if case .disabled(let timeout) = event {
            disarm(); onFault?(timeout); return false
        }
        guard armed(), marker != Self.syntheticMarker else { return false }
        guard permission() else { disarm(); onFault?(false); return false }
        guard case .input(let kind) = event else { return false }
        if probe {
            if case .down(let button) = kind, (2...31).contains(button) {
                // Only one result even if the UI queue has not caught up yet.
                disarm(); onButton?(button)
            }
            return false
        }
        let consumed = onRoute?(Input(kind, at: time), { pixels in
            guard self.armed() else { return false }
            return output(pixels)
        }) ?? false
        return armed() && consumed
    }
}

/// A cancelled/replaced delayed recovery cannot restart interception later.
public struct RecoveryGeneration {
    private var current: UInt64 = 0
    public init() {}
    public mutating func replace() -> UInt64 { current &+= 1; return current }
    public func accepts(_ ticket: UInt64) -> Bool { ticket == current }
}
