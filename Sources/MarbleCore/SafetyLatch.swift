import Foundation

/// Synchronizes emergency inhibition independently of the input run loop.
/// The token may be a real process-owned tap or a test double.
public final class SafetyLatch<Token> {
    private let lock = NSLock()
    private var token: Token?
    private var inhibited = true
    private let invalidate: (Token) -> Void
    public init(invalidate: @escaping (Token) -> Void) { self.invalidate = invalidate }
    public var isArmed: Bool { lock.lock(); defer { lock.unlock() }; return token != nil }
    public func allowExplicitStart() { lock.lock(); inhibited = false; lock.unlock() }
    public func arm(_ token: Token) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !inhibited, self.token == nil else { return false }
        self.token = token; return true
    }
    public func disarm() {
        lock.lock(); let old = token; token = nil; lock.unlock()
        if let old { invalidate(old) }
    }
    public func emergencyStop() {
        lock.lock(); inhibited = true; let old = token; token = nil; lock.unlock()
        if let old { invalidate(old) }
    }
}
