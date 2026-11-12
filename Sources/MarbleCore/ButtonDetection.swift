/// Ephemeral two-step consent/readiness gate. Enabling never starts observation.
public struct ButtonDetection {
    public enum State: Equatable { case disabled, ready, tracking }
    public private(set) var state: State = .disabled
    public init() {}
    public mutating func enable() {
        if state == .disabled { state = .ready }
    }
    /// Only the separate Start Tracking action may consume readiness.
    public mutating func start() -> Bool {
        guard state == .ready else { return false }
        state = .tracking; return true
    }
    public mutating func finish() {
        if state == .tracking { state = .ready }
    }
    public mutating func reset() { state = .disabled }
}
