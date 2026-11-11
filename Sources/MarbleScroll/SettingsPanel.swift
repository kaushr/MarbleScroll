import AppKit
#if SWIFT_PACKAGE
import MarbleCore
#endif

final class SettingsPanel: NSWindowController {
    private var fields: [String: NSTextField] = [:]
    private let acceleration = NSButton(checkboxWithTitle: "Acceleration", target: nil, action: nil)
    private let reverse = NSButton(checkboxWithTitle: "Reverse direction", target: nil, action: nil)
    var onSave: ((Settings) -> Void)?
    private var settings = Settings()
    init(settings: Settings) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "MarbleScroll Settings"; window.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading
        stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20)])
        for (key, title) in [("button", "CG button number (2–31)"), ("speed", "Speed (0.1–10)"),
            ("horizontal", "Horizontal sensitivity (0–5)"), ("vertical", "Vertical sensitivity (0–5)"),
            ("double", "Double-click seconds (blank = system)"), ("hold", "Hold seconds (0.05–1)"),
            ("movement", "Movement threshold (0–30)")] {
            let field = NSTextField(string: ""); field.widthAnchor.constraint(equalToConstant: 80).isActive = true
            fields[key] = field
            let row = NSStackView(views: [NSTextField(labelWithString: title), field]); row.distribution = .equalSpacing
            row.widthAnchor.constraint(equalToConstant: 390).isActive = true; stack.addArrangedSubview(row)
        }
        stack.addArrangedSubview(reverse); stack.addArrangedSubview(acceleration)
        let save = NSButton(title: "Save and Disable Scrolling", target: self, action: #selector(save))
        stack.addArrangedSubview(save)
        update(settings); window.center()
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
