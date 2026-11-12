import Testing
@testable import MarbleCore

private final class MockBackend: InputBackend {
    enum Failure: Error { case unavailable }
    var starts = 0, stops = 0, recoveries = 0
    var failStart = false, failRecovery = false, active = false
    func start() throws {
        starts += 1
        // Model a partial native initialization to check cleanup in catch.
        active = true
        if failStart { throw Failure.unavailable }
    }
    func stop() { stops += 1; active = false }
    func recover() throws {
        recoveries += 1; active = true
        if failRecovery { throw Failure.unavailable }
    }
}
private final class Environment {
    var permission = true, device = true
    let backend = MockBackend()
    var session: Session!
    init() {
        var settings = Settings(); settings.button = 3
        session = Session(settings: settings, backend: backend, permission: { [unowned self] in self.permission }, device: { [unowned self] in self.device })
    }
    func start() throws { try session.start(liveAuthorized: true, globalConsent: true) }
    func lock() {
        _ = session.handle(Input(.down(3), at: 0)); _ = session.handle(Input(.up(3), at: 0.02))
        _ = session.handle(Input(.down(3), at: 0.1)); _ = session.handle(Input(.up(3), at: 0.12))
    }
}

@Test func startupNeverEnablesAutomatically() {
    let e = Environment(); #expect(!e.session.enabled); #expect(e.backend.starts == 0)
    #expect(e.session.handle(Input(.down(3), at: 0)) == .pass)
}
@Test func liveLaunchGatePreventsBackendCalls() {
    let e = Environment()
    #expect(throws: StartError.liveNotAuthorized) { try e.session.start(liveAuthorized: false, globalConsent: true) }
    #expect(e.backend.starts == 0)
}
@Test func globalConsentRequired() {
    let e = Environment()
    #expect(throws: StartError.globalConsentRequired) { try e.session.start(liveAuthorized: true, globalConsent: false) }
    #expect(e.backend.starts == 0)
}
@Test func missingButtonPreventsTap() {
    let e = Environment(); e.session.configure(Settings())
    #expect(throws: StartError.buttonNotConfigured) { try e.start() }; #expect(!e.backend.active)
}
@Test func missingDevicePreventsTap() {
    let e = Environment(); e.device = false
    #expect(throws: StartError.deviceMissing) { try e.start() }; #expect(e.backend.starts == 0)
}
@Test func missingPermissionPreventsTap() {
    let e = Environment(); e.permission = false
    #expect(throws: StartError.permissionMissing) { try e.start() }; #expect(e.backend.starts == 0)
}
@Test func partialTapInitializationFailureIsCleanedUp() {
    let e = Environment(); e.backend.failStart = true
    #expect(throws: MockBackend.Failure.unavailable) { try e.start() }
    #expect(!e.backend.active); #expect(!e.session.enabled); #expect(e.session.stopReason == .tapFailure)
}
@Test func permissionRevocationDuringLockPassesCurrentMovement() throws {
    let e = Environment(); try e.start(); e.lock(); e.permission = false
    #expect(e.session.handle(Input(.move(Delta(10, 10)), at: 0.2)) == .pass)
    #expect(!e.backend.active); #expect(e.session.interaction.state == .normal)
    #expect(e.session.stopReason == .permissionRevoked)
}
@Test func permissionNotificationRevocationDisables() throws {
    let e = Environment(); try e.start(); e.permission = false; e.session.permissionChanged()
    #expect(!e.session.enabled); #expect(!e.backend.active)
}
@Test func permissionRestoredDoesNotAutoEnable() throws {
    let e = Environment(); try e.start(); e.permission = false; e.session.permissionChanged()
    e.permission = true; e.session.permissionChanged(); #expect(!e.session.enabled)
}
@Test func deviceDisconnectCancelsTemporaryMode() throws {
    let e = Environment(); try e.start(); _ = e.session.handle(Input(.down(3), at: 0))
    _ = e.session.handle(Input(.move(Delta(5, 0)), at: 0.01))
    e.device = false; e.session.deviceChanged()
    #expect(!e.backend.active); #expect(e.session.interaction.state == .normal)
}
@Test func disconnectWithoutNotificationPassesCurrentEvent() throws {
    let e = Environment(); try e.start(); e.lock(); e.device = false
    #expect(e.session.handle(Input(.move(Delta(5, 0)), at: 0.2)) == .pass)
    #expect(e.session.stopReason == .deviceDisconnected)
}
@Test func deviceReconnectDoesNotAutoEnable() throws {
    let e = Environment(); try e.start(); e.device = false; e.session.deviceChanged()
    e.device = true; e.session.deviceChanged(); #expect(!e.session.enabled)
}
@Test func timeoutRecoversOnceWithoutRestoringLock() throws {
    let e = Environment(); try e.start(); e.lock(); e.session.tapFailed(timeout: true)
    #expect(e.session.enabled); #expect(e.backend.recoveries == 1)
    #expect(e.session.interaction.state == .normal)
    #expect(e.session.handle(Input(.move(Delta(5, 0)), at: 0.3)) == .pass)
    e.session.tapFailed(timeout: true)
    #expect(!e.session.enabled); #expect(!e.backend.active); #expect(e.backend.recoveries == 1)
}
@Test func recoveryCreationFailureStaysDisabled() throws {
    let e = Environment(); try e.start(); e.backend.failRecovery = true; e.session.tapFailed(timeout: true)
    #expect(!e.backend.active); #expect(!e.session.enabled)
}
@Test func userDisabledTapNeverAutomaticallyRecovers() throws {
    let e = Environment(); try e.start(); e.session.tapFailed(timeout: false)
    #expect(e.backend.recoveries == 0); #expect(!e.session.enabled)
}
@Test func timeoutAfterManualDisableDoesNotRearm() throws {
    let e = Environment(); try e.start(); e.session.stop(.emergency); e.session.tapFailed(timeout: true)
    #expect(e.backend.recoveries == 0); #expect(!e.session.enabled)
}
@Test func noRecoveryWhenPermissionLost() throws {
    let e = Environment(); try e.start(); e.permission = false; e.session.tapFailed(timeout: true)
    #expect(!e.backend.active); #expect(e.backend.recoveries == 0)
}
@Test func noRecoveryWhenDeviceAbsent() throws {
    let e = Environment(); try e.start(); e.device = false; e.session.tapFailed(timeout: true)
    #expect(!e.backend.active); #expect(e.backend.recoveries == 0)
}
@Test(arguments: [StopReason.disabled, .permissionRevoked, .deviceDisconnected, .sleep, .sessionInactive, .tapFailure, .emergency, .terminating])
func everyStopReasonFailsOpenAndResets(reason: StopReason) throws {
    let e = Environment(); try e.start(); e.lock(); e.session.stop(reason)
    #expect(!e.backend.active); #expect(!e.session.enabled)
    #expect(e.session.interaction.state == .normal)
    #expect(e.session.handle(Input(.move(Delta(10, 20)), at: 1)) == .pass)
    #expect(e.session.handle(Input(.up(3), at: 1.1)) == .pass)
}
@Test func restartedApplicationDoesNotInheritLockOrEnable() throws {
    let old = Environment(); try old.start(); old.lock(); old.session.stop(.terminating)
    let next = Environment(); #expect(!next.session.enabled); #expect(next.backend.starts == 0)
    #expect(next.session.interaction.state == .normal)
}
@Test func newExplicitEnableResetsTimeoutBudget() throws {
    let e = Environment(); try e.start(); e.session.tapFailed(timeout: true); e.session.tapFailed(timeout: true)
    try e.start(); e.session.tapFailed(timeout: true)
    #expect(e.backend.recoveries == 2); #expect(e.session.enabled)
}
@Test func configurationChangeDisarmsBackend() throws {
    let e = Environment(); try e.start(); e.lock(); e.session.configure(Settings())
    #expect(!e.backend.active); #expect(!e.session.enabled); #expect(e.session.interaction.deadline == nil)
}

@Test func failedOutputAllocationPassesPhysicalMovementAndDisarms() throws {
    let e = Environment(); try e.start(); e.lock()
    var attempted = false
    let consumed = e.session.route(Input(.move(Delta(4, 2)), at: 0.2)) { pixels in
        attempted = true; #expect(!pixels.isZero); return false
    }
    #expect(attempted); #expect(!consumed); #expect(!e.backend.active)
    #expect(e.session.interaction.state == .normal); #expect(e.session.stopReason == .tapFailure)
}
@Test func successfulOutputConsumesOnlyOriginalMovement() throws {
    let e = Environment(); try e.start(); e.lock()
    var emitted: [ScrollPixels] = []
    #expect(e.session.route(Input(.move(Delta(4, 2)), at: 0.2)) { emitted.append($0); return true })
    #expect(emitted == [ScrollPixels(horizontal: -8, vertical: -4)])
    #expect(!e.session.route(Input(.move(Delta(4, 2)), at: 0.3, synthetic: true)) { _ in
        Issue.record("Synthetic event must not be emitted"); return true
    })
}
@Test func zeroOutputPreservesPointerFreezeWithoutPosting() throws {
    let e = Environment(); try e.start(); e.lock()
    #expect(e.session.route(Input(.move(Delta(0, 0)), at: 0.2)) { _ in
        Issue.record("Zero delta must not post"); return true
    })
}

@Test func reversingWhileEnabledKeepsTapAndLockActive() throws {
    let e = Environment(); try e.start(); e.lock()
    let stops = e.backend.stops
    e.session.setReverse(true)
    #expect(e.session.enabled); #expect(e.backend.active); #expect(e.backend.stops == stops)
    #expect(e.session.interaction.state == .lockedScroll)
    var output: ScrollPixels?
    let consumed = e.session.route(Input(.move(Delta(4, 2)), at: 0.2)) { output = $0; return true }
    #expect(consumed); #expect(output == ScrollPixels(horizontal: 8, vertical: 4))
}
@Test func reverseDirectionChangeClearsPriorFractionalResidual() throws {
    let e = Environment(); var s = Settings(); s.button = 3; s.speed = 0.5
    e.session.configure(s); try e.start(); e.lock()
    _ = e.session.route(Input(.move(Delta(1, 0)), at: 0.2)) { _ in true }
    e.session.setReverse(true)
    var emitted = 0
    _ = e.session.route(Input(.move(Delta(1, 0)), at: 0.3)) { _ in emitted += 1; return true }
    #expect(emitted == 0)
    var horizontal: Int32 = 0
    _ = e.session.route(Input(.move(Delta(1, 0)), at: 0.4)) { horizontal = $0.horizontal; return true }
    #expect(horizontal == 1)
}
