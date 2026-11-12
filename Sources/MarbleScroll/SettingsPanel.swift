import AppKit
#if SWIFT_PACKAGE
import MarbleCore
#endif

final class SettingsPanel: NSWindowController, NSWindowDelegate {
    private var fields: [String: NSTextField] = [:]
    private let acceleration = NSButton(checkboxWithTitle: "Acceleration", target: nil, action: nil)
    private let reverse = NSButton(checkboxWithTitle: "Reverse direction", target: nil, action: nil)
    private let detectionEnabled = NSButton(checkboxWithTitle: "Enable Button Detection", target: nil, action: nil)
    private let startTracking = NSButton(title: "Start Tracking (10 seconds)", target: nil, action: nil)
    private let stopTracking = NSButton(title: "Stop Tracking", target: nil, action: nil)
    private let detectionStatus = NSTextField(wrappingLabelWithString: "")
    private let detectedStatus = NSTextField(wrappingLabelWithString: "")
    private let useButton = NSButton(title: "Use Detected Button", target: nil, action: nil)
    private var candidate: Int?
    var onSave: ((Settings) -> Void)?
    var onDetectionEnabled: ((Bool) -> Void)?
    var onStartTracking: (() -> Void)?
    var onStopTracking: (() -> Void)?
    var onClose: (() -> Void)?
    private var settings = Settings()
    init(settings: Settings) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 700),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "MarbleScroll — Configure Button & Scrolling"; window.isReleasedWhenClosed = false
        window.delegate = self
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading
        stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20)])
        let title = NSTextField(labelWithString: "Configure your small trackball button")
        title.font = .boldSystemFont(ofSize: 16); stack.addArrangedSubview(title)
        let help = NSTextField(wrappingLabelWithString:
            "First enable detection, then click Start Tracking when ready. Press the small physical button once; you don’t need to know its number. Detection observes secondary buttons globally and passes clicks through, so the button’s usual action may still occur. Avoid double-clicking during detection.")
        help.widthAnchor.constraint(equalToConstant: 480).isActive = true
        stack.addArrangedSubview(help)
        detectionEnabled.target = self; detectionEnabled.action = #selector(changeDetection)
        startTracking.target = self; startTracking.action = #selector(start)
        stopTracking.target = self; stopTracking.action = #selector(stop)
        useButton.target = self; useButton.action = #selector(useDetected)
        stack.addArrangedSubview(detectionEnabled)
        stack.addArrangedSubview(NSStackView(views: [startTracking, stopTracking]))
        for label in [detectionStatus, detectedStatus] {
            label.widthAnchor.constraint(equalToConstant: 480).isActive = true
            stack.addArrangedSubview(label)
        }
        stack.addArrangedSubview(useButton)
        for (key, title) in [("button", "Selected CG button (2–31)"), ("speed", "Speed (0.1–10)"),
            ("horizontal", "Horizontal sensitivity (0–5)"), ("vertical", "Vertical sensitivity (0–5)"),
            ("double", "Double-click seconds (blank = system)"), ("hold", "Hold seconds (0.05–1)"),
            ("movement", "Movement threshold (0–30)")] {
            let field = NSTextField(string: ""); field.widthAnchor.constraint(equalToConstant: 80).isActive = true
            fields[key] = field
            let row = NSStackView(views: [NSTextField(labelWithString: title), field]); row.distribution = .equalSpacing
            row.widthAnchor.constraint(equalToConstant: 480).isActive = true; stack.addArrangedSubview(row)
        }
        stack.addArrangedSubview(reverse); stack.addArrangedSubview(acceleration)
        let save = NSButton(title: "Save and Disable Scrolling", target: self, action: #selector(save))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"; cancel.keyEquivalentModifierMask = []
        stack.addArrangedSubview(NSStackView(views: [save, cancel]))
        update(settings); updateDetection(.disabled, status: "Detection is off. Enable it first; tracking will not start automatically.")
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Not a storyboard controller") }
    func update(_ s: Settings) {
        settings = s
        fields["button"]?.stringValue = s.button.map(String.init) ?? ""
        fields["speed"]?.stringValue = String(s.speed)
        fields["horizontal"]?.stringValue = String(s.horizontal)
        fields["vertical"]?.stringValue = String(s.vertical)
        fields["double"]?.stringValue = s.doubleClickInterval.map { String($0) } ?? ""
        fields["hold"]?.stringValue = String(s.holdDuration)
        fields["movement"]?.stringValue = String(s.movementThreshold)
        reverse.state = s.reverse ? .on : .off; acceleration.state = s.acceleration ? .on : .off
        candidate = nil; useButton.isEnabled = false
        detectedStatus.stringValue = s.button.map { "Saved button: CG \($0)." } ?? "No button selected yet."
    }
    func updateDetection(_ state: ButtonDetection.State, status: String) {
        detectionEnabled.state = state == .disabled ? .off : .on
        startTracking.isEnabled = state == .ready
        stopTracking.isEnabled = state == .tracking
        detectionStatus.stringValue = status
    }
    func showDetectedButton(_ button: Int) {
        candidate = button; useButton.isEnabled = true
        detectedStatus.stringValue = "Detected CG button \(button) (one-based \(button + 1)). Choose Use Detected Button if this was the small button you pressed."
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
    @objc private func changeDetection() { onDetectionEnabled?(detectionEnabled.state == .on) }
    @objc private func start() { onStartTracking?() }
    @objc private func stop() { onStopTracking?() }
    @objc private func cancel() { close() }
    @objc private func useDetected() {
        guard let candidate else { return }
        fields["button"]?.stringValue = String(candidate)
        detectedStatus.stringValue = "Selected CG button \(candidate). Click Save below to apply this mapping."
        self.candidate = nil; useButton.isEnabled = false
    }
    @objc private func save() {
        func number(_ key: String) -> Double? { Double(fields[key]?.stringValue ?? "") }
        var s = settings
        let rawButton = fields["button"]?.stringValue ?? ""
        let b = Int(rawButton)
        let rawDouble = fields["double"]?.stringValue ?? ""
        guard (rawButton.isEmpty || b.map({ (2...31).contains($0) }) == true),
              let speed = number("speed"), let horizontal = number("horizontal"), let vertical = number("vertical"),
              let hold = number("hold"), let movement = number("movement"),
              [speed, horizontal, vertical, hold, movement].allSatisfy(\.isFinite),
              rawDouble.isEmpty || number("double").map({ $0.isFinite }) == true else {
            let a = NSAlert(); a.messageText = "Enter finite numbers and a secondary button from 2 through 31."
            a.runModal(); return
        }
        s.button = b; s.speed = speed; s.horizontal = horizontal; s.vertical = vertical
        s.holdDuration = hold; s.movementThreshold = movement; s.doubleClickInterval = number("double")
        s.reverse = reverse.state == .on; s.acceleration = acceleration.state == .on
        s = s.validated(); update(s); onSave?(s); close()
    }
}
