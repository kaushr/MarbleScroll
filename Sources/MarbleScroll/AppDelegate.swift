import AppKit
import ApplicationServices
import ServiceManagement
import Darwin
#if SWIFT_PACKAGE
import MarbleCore
#endif

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let configuration = Configuration()
    private let driver = NativeInput()
    private let presence = TrackballPresence()
    private var settings = Settings()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem(title: "Scrolling Enabled", action: #selector(toggle), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "Normal — Disabled", action: nil, keyEquivalent: "")
    private let deviceItem = NSMenuItem(title: "Trackball: checking", action: nil, keyEquivalent: "")
    private let reverseItem = NSMenuItem(title: "Reverse Direction", action: #selector(reverse), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(login), keyEquivalent: "")
    private var panel: SettingsPanel?
    private var setupPanel: SetupPanel?
    private var recognitionTimer: Timer?
    private var recognitionDeadline: Double?
    private var probeTimer: Timer?
    private var recoveryWork: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private let liveAllowed = CommandLine.arguments.contains("--allow-live-input")
    private var refreshPending = false
    private lazy var session = Session(settings: settings, systemDoubleClickInterval: NSEvent.doubleClickInterval,
        backend: driver, permission: { AXIsProcessTrusted() }, device: { [weak self] in self?.presence.connected == true })

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = configuration.load()
        // Construct the session in disabled state. No tap or permission prompt on launch.
        _ = session
        driver.onRoute = { [weak self] input, output in
            guard let self else { return false }
            let before = self.session.interaction.state
            let consumed = self.session.route(input, output: output)
            self.scheduleRecognition()
            if before != self.session.interaction.state || !self.session.enabled { self.queueRefresh() }
            return consumed
        }
        driver.onFault = { [weak self] timeout in self?.queueFault(timeout: timeout) }
        driver.onButton = { [weak self] in self?.detected($0) }
        presence.onChange = { [weak self] in
            guard let self else { return }
            self.session.deviceChanged()
            if !self.presence.connected { self.disable(.deviceDisconnected) }
            self.refresh()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        for item in [stateItem, deviceItem, .separator(),
                     NSMenuItem(title: "Setup & Status…", action: #selector(showSetup), keyEquivalent: ""), enabledItem,
                     NSMenuItem(title: "Scroll Speed…", action: #selector(configure), keyEquivalent: ""),
                     reverseItem, NSMenuItem(title: "Configure Button…", action: #selector(configure), keyEquivalent: ""),
                     NSMenuItem(title: "Detect Button (10 seconds)…", action: #selector(detectButton), keyEquivalent: ""),
                     loginItem, .separator(),
                     NSMenuItem(title: "Emergency Disable", action: #selector(emergency), keyEquivalent: ""),
                     NSMenuItem(title: "About MarbleScroll", action: #selector(about), keyEquivalent: ""),
                     NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")] {
            item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        presence.start()
        let center = NSWorkspace.shared.notificationCenter
        for (name, reason) in [(NSWorkspace.willSleepNotification, StopReason.sleep),
                               (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive),
                               (NSWorkspace.didWakeNotification, .sleep)] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.disable(reason) })
        }
        setupEmergencySignals()
        refresh()
        if settings.button == nil || CommandLine.arguments.contains("--show-setup") { showSetup() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup(); return true
    }
    @objc private func showSetup() {
        if setupPanel == nil {
            let panel = SetupPanel()
            panel.onDetect = { [weak self] in self?.detectButton() }
            panel.onToggle = { [weak self] in self?.toggle() }
            panel.onSettings = { [weak self] in self?.configure() }
            panel.onDisable = { [weak self] in self?.emergency() }
            setupPanel = panel
        }
        refresh(); setupPanel?.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) { disable(.terminating); presence.stop() }
    func menuWillOpen(_ menu: NSMenu) {
        session.permissionChanged()
        if !session.enabled { driver.gate.emergencyStop() }
        refresh()
    }
    private func setupEmergencySignals() {
        let queue = DispatchQueue(label: "MarbleScroll.emergency", qos: .userInitiated)
        let gate = driver.gate
        for number in [SIGUSR1, SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
            source.setEventHandler { [weak self] in
                gate.emergencyStop()
                if number != SIGUSR1 { Darwin._exit(0) }
                DispatchQueue.main.async { self?.disable(.emergency) }
            }
            source.resume(); signals.append(source)
        }
    }
    private func scheduleRecognition() {
        let deadline = session.enabled ? session.interaction.deadline : nil
        guard deadline != recognitionDeadline else { return }
        recognitionTimer?.invalidate(); recognitionTimer = nil; recognitionDeadline = deadline
        guard let deadline else { return }
        let timer = Timer(timeInterval: max(0.001, deadline - ProcessInfo.processInfo.systemUptime), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.recognitionDeadline = nil
            _ = self.session.handle(Input(.tick, at: ProcessInfo.processInfo.systemUptime))
            self.scheduleRecognition(); self.refresh()
        }
        recognitionTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func queueFault(timeout: Bool) {
        // Already disarmed in native callback; no interception while this one-shot is pending.
        recoveryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recoveryWork = nil
            if !AXIsProcessTrusted() { self.disable(.permissionRevoked) }
            else {
                self.session.tapFailed(timeout: timeout)
                if !self.session.enabled { self.disable(.tapFailure) }
                self.scheduleRecognition(); self.refresh()
            }
        }
        recoveryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (timeout ? 0.25 : 0), execute: work)
    }
    private func disable(_ reason: StopReason) {
        driver.gate.emergencyStop()
        recoveryWork?.cancel(); recoveryWork = nil
        recognitionTimer?.invalidate(); recognitionTimer = nil; recognitionDeadline = nil
        probeTimer?.invalidate(); probeTimer = nil
        session.stop(reason)
        refresh()
    }
    private func queueRefresh() {
        guard !refreshPending else { return }; refreshPending = true
        DispatchQueue.main.async { [weak self] in self?.refreshPending = false; self?.refresh() }
    }
    private func refresh() {
        guard statusItem != nil else { return }
        let state: String
        switch session.interaction.state {
        case .temporaryScroll: state = "Temporary scrolling"
        case .lockedScroll: state = "Locked scrolling"
        default: state = "Normal"
        }
        stateItem.title = "\(state) — \(session.enabled ? "Enabled" : "Disabled")"
        deviceItem.title = presence.error ?? (presence.connected ? "Trackball: 046D:C408 connected (global mode)" : "Trackball: disconnected")
        enabledItem.state = session.enabled ? .on : .off
        reverseItem.state = settings.reverse ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let icon = session.enabled ? (state == "Locked scrolling" ? "lock.circle.fill" : "arrow.up.and.down.circle.fill") : "circle.dotted"
        statusItem.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: "MarbleScroll: \(state)")
        statusItem.button?.toolTip = "MarbleScroll: \(stateItem.title). \(session.stopReason?.rawValue ?? "")"
        setupPanel?.update(enabled: session.enabled, state: state, button: settings.button,
                           device: presence.connected, permission: AXIsProcessTrusted(),
                           liveAllowed: liveAllowed, probing: probeTimer != nil)
    }
    private func message(_ title: String, _ body: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = body
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    private func consent(_ title: String, _ body: String) -> Bool {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = body
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Enable This Session")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }
    private func mayUseLiveInput() -> Bool {
        guard liveAllowed else {
            message("Live input is gated", "This launch cannot create an event tap. After separate approval, launch with --allow-live-input. No permission was requested.")
            return false
        }
        guard presence.connected else { message("Trackball unavailable", "Connect a Logitech 046D:C408 before enabling."); return false }
        guard AXIsProcessTrusted() else {
            message("Accessibility permission is absent", "This OS grant is broader than mouse access. Obtain approval and add MarbleScroll manually in Privacy & Security → Accessibility. No permission request was made. Do not grant Full Disk Access or run as administrator.")
            return false
        }
        return true
    }
    @objc private func toggle() {
        if session.enabled { disable(.disabled); return }
        guard mayUseLiveInput() else { return }
        guard settings.button != nil else { message("Configure a button first", "Use Detect Button or enter a verified secondary CG button number."); return }
        guard consent("Enable global mouse filtering?", "Trackball presence is checked, but mouse events cannot be reliably attributed to a USB device. Other mice and trackpads can drive scrolling. No keyboard events are observed. Emergency disable: kill -USR1 \(ProcessInfo.processInfo.processIdentifier).") else { return }
        disable(.disabled)
        driver.gate.allowExplicitStart()
        do { try session.start(liveAuthorized: liveAllowed, globalConsent: true) }
        catch { disable(.tapFailure); message("Scrolling remains disabled", error.localizedDescription) }
        refresh()
    }
    @objc private func configure() {
        disable(.disabled)
        if panel == nil {
            panel = SettingsPanel(settings: settings)
            panel?.onSave = { [weak self] value in
                guard let self else { return }
                self.settings = value; self.configuration.save(value); self.session.configure(value); self.refresh()
            }
        }
        panel?.update(settings); panel?.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func reverse() {
        disable(.disabled); settings.reverse.toggle(); configuration.save(settings); session.configure(settings); refresh()
    }
    @objc private func detectButton() {
        disable(.disabled)
        guard mayUseLiveInput(), consent("Observe a secondary button?", "For up to 10 seconds, observe the next secondary mouse-button down globally. It will pass through unchanged. Press the physical small trackball button; other mice cannot be distinguished. No keyboard monitoring or raw HID access.") else { return }
        driver.gate.allowExplicitStart()
        do { try driver.startProbe() }
        catch { disable(.tapFailure); message("Button detection unavailable", error.localizedDescription); return }
        let timer = Timer(timeInterval: 10, repeats: false) { [weak self] _ in self?.disable(.disabled) }
        probeTimer = timer; RunLoop.main.add(timer, forMode: .common)
        refresh()
    }
    private func detected(_ button: Int) {
        // No modal UI or preference write inside event callback.
        driver.gate.disarm()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.disable(.disabled)
            guard (2...31).contains(button) else { return }
            let a = NSAlert(); a.messageText = "Observed CG button \(button) (one-based \(button + 1))"
            a.informativeText = "If this was the small trackball button you pressed, select Use Button. Detection is global and does not prove the originating device."
            a.addButton(withTitle: "Cancel"); a.addButton(withTitle: "Use Button")
            if a.runModal() == .alertSecondButtonReturn {
                self.settings.button = button; self.configuration.save(self.settings); self.session.configure(self.settings)
            }
            self.refresh()
        }
    }
    @objc private func login() {
        disable(.disabled)
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else if consent("Launch MarbleScroll at login?", "Register the current app with macOS Login Items. Scrolling will still be disabled at every launch.") { try SMAppService.mainApp.register() }
        } catch { message("Login startup unchanged or pending", error.localizedDescription) }
        refresh()
    }
    @objc private func emergency() { disable(.emergency) }
    @objc private func quit() { disable(.terminating); NSApp.terminate(nil) }
    @objc private func about() {
        disable(.disabled)
        message("MarbleScroll 0.1.0", "MIT License · © 2026 Kaushik Ruparel\nBehavioral inspiration: DragScroll by Emre Yolcu. Independently written Swift; no DragScroll input/recovery code copied.\nGlobal fallback, no networking or keyboard tap. Physical acceptance testing pending.")
    }
}
