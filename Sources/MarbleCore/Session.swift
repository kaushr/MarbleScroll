import Foundation

public protocol InputBackend: AnyObject {
    func start() throws
    func stop()
    /// Called only for a timeout; must not preserve any interaction state.
    func recover() throws
}
public enum StopReason: String { case disabled, permissionRevoked, deviceDisconnected, sleep, sessionInactive, tapFailure, emergency, terminating }
public enum StartError: Error, Equatable { case liveNotAuthorized, globalConsentRequired, buttonNotConfigured, deviceMissing, permissionMissing }

/// Main-run-loop owner. Tests inject a fake backend and fake permission/device state.
public final class Session {
    public private(set) var enabled = false
    public private(set) var stopReason: StopReason? = .disabled
    public private(set) var interaction: Interaction
    public private(set) var recoveryUsed = false
    private var converter = ScrollConverter()
    private let backend: InputBackend
    private let permission: () -> Bool
    private let device: () -> Bool
    public init(settings: Settings, systemDoubleClickInterval: Double = 0.5, backend: InputBackend,
                permission: @escaping () -> Bool, device: @escaping () -> Bool) {
        interaction = Interaction(settings: settings, systemDoubleClickInterval: systemDoubleClickInterval)
        self.backend = backend; self.permission = permission; self.device = device
    }
    public func start(liveAuthorized: Bool, globalConsent: Bool) throws {
        stop(.disabled)
        guard liveAuthorized else { throw StartError.liveNotAuthorized }
        guard globalConsent else { throw StartError.globalConsentRequired }
        guard interaction.settings.button != nil else { throw StartError.buttonNotConfigured }
        guard device() else { throw StartError.deviceMissing }
        guard permission() else { throw StartError.permissionMissing }
        do { try backend.start(); enabled = true; stopReason = nil; recoveryUsed = false }
        catch { stop(.tapFailure); throw error }
    }
    public func stop(_ reason: StopReason) {
        enabled = false; interaction.reset(); converter.reset(); stopReason = reason
        backend.stop()
    }
    public func configure(_ settings: Settings) { stop(.disabled); interaction.configure(settings) }
    public func setReverse(_ reverse: Bool) { interaction.setReverse(reverse); converter.reset() }
    public func permissionChanged() { if !permission() { stop(.permissionRevoked) } }
    public func deviceChanged() { if !device() { stop(.deviceDisconnected) } }
    public func tapFailed(timeout: Bool) {
        let wasEnabled = enabled
        stop(.tapFailure)
        guard timeout, wasEnabled, !recoveryUsed, permission(), device() else { return }
        recoveryUsed = true
        do { try backend.recover(); enabled = true; stopReason = nil }
        catch { stop(.tapFailure) }
    }
    public func handle(_ input: Input) -> Decision {
        guard enabled else { return .pass }
        guard permission() else { stop(.permissionRevoked); return .pass }
        guard device() else { stop(.deviceDisconnected); return .pass }
        let old = interaction.state
        let result = interaction.handle(input)
        if old != interaction.state && interaction.state == .normal { converter.reset() }
        return result
    }
    /// true consumes the physical event; false passes it unchanged.
    /// Output is injected so a construction-failure result is tested without native input.
    public func route(_ input: Input, output: (ScrollPixels) -> Bool) -> Bool {
        switch handle(input) {
        case .pass: return false
        case .suppress: return true
        case .scroll(let delta):
            guard let pixels = converter.convert(delta, settings: interaction.settings) else {
                stop(.tapFailure); return false
            }
            if pixels.isZero { return true }
            guard output(pixels) else { stop(.tapFailure); return false }
            return true
        }
    }
}
