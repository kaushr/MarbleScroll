import Foundation

/// Synchronizes emergency inhibition independently of the input run loop.
/// The token may be a real process-owned tap or a test double.
// The lock protects token/inhibition; a detached token is invalidated exactly once.
// Invalidation must support the caller's queue (Core Graphics port invalidation does).
// No mutable token is exposed. This is the sole manually audited Sendable bridge.
public final class SafetyLatch<Token>: @unchecked Sendable {
    private let lock = NSLock()
    private var token: Token?
    private var inhibited = true
    private let invalidate: @Sendable (Token) -> Void
    public init(invalidate: @escaping @Sendable (Token) -> Void) { self.invalidate = invalidate }
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
