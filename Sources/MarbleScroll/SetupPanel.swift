import AppKit

/// Visible setup/status controls; observing a button still needs an explicit user action.
final class SetupPanel: NSWindowController {
    private let status = NSTextField(wrappingLabelWithString: "")
    private let prerequisites = NSTextField(wrappingLabelWithString: "")
    private let enable = NSButton(title: "Enable Scrolling…", target: nil, action: nil)
    var onDetect: (() -> Void)?
    var onToggle: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDisable: (() -> Void)?
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 330),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MarbleScroll Setup & Status"; window.isReleasedWhenClosed = false
        super.init(window: window)
        let heading = NSTextField(labelWithString: "Set up your small trackball button")
        heading.font = .boldSystemFont(ofSize: 18)
        let instructions = NSTextField(wrappingLabelWithString:
            "1. Click Detect Small Button, then press the physical small button once.\n2. Confirm Use Button when its number appears.\n3. Click Enable Scrolling and accept global mode.\nHold + roll to scroll; double-click to lock; click once to unlock.")
        let detect = NSButton(title: "Detect Small Button…", target: self, action: #selector(detect))
        enable.target = self; enable.action = #selector(toggle)
        let settings = NSButton(title: "Settings…", target: self, action: #selector(configure))
        let disable = NSButton(title: "Emergency Disable", target: self, action: #selector(emergency))
        let controls = NSStackView(views: [detect, enable])
        let secondary = NSStackView(views: [settings, disable])
        let stack = NSStackView(views: [heading, instructions, prerequisites, status, controls, secondary])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            instructions.widthAnchor.constraint(equalToConstant: 470),
            prerequisites.widthAnchor.constraint(equalToConstant: 470),
            status.widthAnchor.constraint(equalToConstant: 470)
        ])
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Not a storyboard controller") }
    func update(enabled: Bool, state: String, button: Int?, device: Bool, permission: Bool, liveAllowed: Bool, probing: Bool) {
        let mapping = button.map { "CG button \($0) (physical mapping saved)" } ?? "Not configured — click Detect Small Button"
        prerequisites.stringValue = "Trackball: \(device ? "connected" : "not detected") · Accessibility: \(permission ? "allowed" : "missing")\nButton: \(mapping)"
        status.stringValue = probing ? "Listening: press one small trackball button now (10 seconds)." :
            "\(state). Scrolling \(enabled ? "enabled" : "disabled").\(liveAllowed ? "" : " Live input is gated for this launch.")"
        enable.title = enabled ? "Disable Scrolling" : "Enable Scrolling…"
        enable.isEnabled = enabled || (button != nil && !probing)
    }
    @objc private func detect() { onDetect?() }
    @objc private func toggle() { onToggle?() }
    @objc private func configure() { onSettings?() }
    @objc private func emergency() { onDisable?() }
}
