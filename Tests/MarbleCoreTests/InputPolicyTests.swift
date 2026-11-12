import Foundation
import Testing
@testable import MarbleCore

@Test func permissionSnapshotQueriesOnceDuringEventBurst() {
    var calls = 0
    let access = PermissionSnapshot { calls += 1; return true }
    for i in 0..<200 { #expect(access.value(at: Double(i) / 1000)) }
    #expect(calls == 1)
    #expect(access.value(at: 0.25)); #expect(calls == 2)
}
@Test func permissionRevocationDetectedAtBoundedExpiry() {
    var allowed = true
    let access = PermissionSnapshot { allowed }
    #expect(access.value(at: 0)); allowed = false
    #expect(access.value(at: 0.249))
    #expect(!access.value(at: 0.25)); #expect(!access.cached)
}
@Test func explicitCheckBypassesPermissionCache() {
    var allowed = true
    let access = PermissionSnapshot { allowed }
    #expect(access.value(at: 1)); allowed = false
    #expect(!access.value(at: 1.001, force: true))
}
@Test func backwardsClockRevalidatesAndInvalidClockFailsOpen() {
    var calls = 0
    let access = PermissionSnapshot { calls += 1; return true }
    #expect(access.value(at: 5)); #expect(access.value(at: 4)); #expect(calls == 2)
    #expect(!access.value(at: .nan)); #expect(!access.cached); #expect(calls == 2)
}

private final class TapHarness {
    var armed = true
    var allowed = true
    var disarms = 0
    var faults: [Bool] = []
    var buttons: [Int] = []
    var inputs: [Input] = []
    var emissions: [ScrollPixels] = []
    lazy var router: MouseTapRouter = {
        let router = MouseTapRouter(armed: { self.armed }, disarm: { self.armed = false; self.disarms += 1 }, permission: { self.allowed })
        router.onFault = { self.faults.append($0) }
        router.onButton = { self.buttons.append($0) }
        router.onRoute = { input, output in
            self.inputs.append(input)
            return output(ScrollPixels(horizontal: 1, vertical: 2))
        }
        return router
    }()
    func receive(_ event: TapEvent, probe: Bool = false, marker: Int64 = 0) -> Bool {
        router.receive(event, marker: marker, probe: probe, at: 10) { self.emissions.append($0); return true }
    }
}
@Test func unarmedCallbackPassesWithoutOutput() {
    let h = TapHarness(); h.armed = false
    #expect(!h.receive(.input(.down(3)))); #expect(h.inputs.isEmpty); #expect(h.emissions.isEmpty)
}
@Test func syntheticNativeEventNeverReentersSession() {
    let h = TapHarness()
    #expect(!h.receive(.input(.move(Delta(1, 2))), marker: MouseTapRouter.syntheticMarker))
    #expect(h.inputs.isEmpty); #expect(h.emissions.isEmpty)
}
@Test func timeoutDisarmsBeforeNotifyingAndAlwaysPasses() {
    let h = TapHarness()
    h.router.onFault = { timeout in #expect(timeout); #expect(!h.armed); h.faults.append(timeout) }
    #expect(!h.receive(.disabled(timeout: true)))
    #expect(h.disarms == 1); #expect(h.faults == [true]); #expect(h.inputs.isEmpty)
}
@Test func userDisabledTapRequestsNoTimeoutRecovery() {
    let h = TapHarness()
    #expect(!h.receive(.disabled(timeout: false))); #expect(h.faults == [false]); #expect(!h.armed)
}
@Test func probePermissionRevocationDisarmsAndPasses() {
    let h = TapHarness(); h.allowed = false
    #expect(!h.receive(.input(.down(3)), probe: true))
    #expect(h.buttons.isEmpty); #expect(h.faults == [false]); #expect(!h.armed)
}
@Test func scrollingPermissionRevocationNeverRoutesInput() {
    let h = TapHarness(); h.allowed = false
    #expect(!h.receive(.input(.move(Delta(1, 2)))))
    #expect(h.inputs.isEmpty); #expect(h.emissions.isEmpty); #expect(!h.armed)
}
@Test func probeReportsOneSecondaryButtonAndPassesThrough() {
    let h = TapHarness()
    #expect(!h.receive(.input(.down(3)), probe: true))
    #expect(!h.receive(.input(.down(4)), probe: true))
    #expect(h.buttons == [3]); #expect(h.disarms == 1); #expect(h.inputs.isEmpty)
}
@Test func probeIgnoresMovementReleasesAndPrimaryButtons() {
    let h = TapHarness()
    for event: TapEvent in [.input(.move(Delta(1, 2))), .input(.up(3)), .input(.down(0)), .input(.down(1)), .unhandled] {
        #expect(!h.receive(event, probe: true))
    }
    #expect(h.buttons.isEmpty); #expect(h.armed)
}
@Test func unhandledEventPassesWithoutRouting() {
    let h = TapHarness()
    #expect(!h.receive(.unhandled)); #expect(h.inputs.isEmpty)
}
@Test func absentRouteFailsOpen() {
    let h = TapHarness(); h.router.onRoute = nil
    #expect(!h.receive(.input(.down(3)))); #expect(h.emissions.isEmpty)
}
@Test func nativeRouteUsesMonotonicTimeAndPhysicalInput() {
    let h = TapHarness()
    #expect(h.receive(.input(.move(Delta(1, 2)))))
    #expect(h.inputs.count == 1); #expect(h.inputs.first?.time == 10)
    #expect(h.inputs.first?.synthetic == false); #expect(h.emissions.count == 1)
}
@Test func emergencyDuringRoutePreventsOutputAndSuppression() {
    let h = TapHarness()
    h.router.onRoute = { _, output in
        h.armed = false
        #expect(!output(ScrollPixels(horizontal: 1, vertical: 2)))
        return true
    }
    #expect(!h.receive(.input(.down(3)))); #expect(h.emissions.isEmpty)
}
@Test func outputConstructionFailurePassesOriginalThroughAdapterAndSession() throws {
    final class Backend: InputBackend { func start() throws {} ; func stop() {} ; func recover() throws {} }
    let h = TapHarness(); var settings = Settings(); settings.button = 3
    let session = Session(settings: settings, backend: Backend(), permission: { true }, device: { true })
    try session.start(liveAuthorized: true, globalConsent: true)
    h.router.onRoute = { session.route($0, output: $1) }
    #expect(h.receive(.input(.down(3))))
    let consumed = h.router.receive(.input(.move(Delta(5, 6))), marker: 0, probe: false, at: 10.01) { _ in false }
    #expect(!consumed); #expect(!session.enabled); #expect(session.stopReason == .tapFailure)
}
@Test func openingMenuDuringTrackingPreservesProbe() {
    var detection = ButtonDetection(); detection.enable(); let started = detection.start()
    #expect(started); #expect(!detection.shouldDisarmOnMenuOpen(scrollingEnabled: false))
    detection.finish(); #expect(detection.shouldDisarmOnMenuOpen(scrollingEnabled: false))
    #expect(!detection.shouldDisarmOnMenuOpen(scrollingEnabled: true))
}
@Test func cancelledAndReplacedRecoveriesCannotRestartTap() {
    var generation = RecoveryGeneration()
    let old = generation.replace(); #expect(generation.accepts(old))
    let replacement = generation.replace()
    #expect(!generation.accepts(old)); #expect(generation.accepts(replacement))
    _ = generation.replace(); #expect(!generation.accepts(replacement))
}
@Test func everyStartFailureHasActionableLocalizedDescription() {
    for error in StartError.allCases {
        #expect(error.localizedDescription == error.errorDescription)
        #expect(!error.localizedDescription.contains("error 3"))
        #expect(error.localizedDescription.count > 30)
    }
}
@Test func newDefaultAllowsTwoHundredMillisecondClickWithoutHoldLatency() {
    var settings = Settings(); settings.button = 3
    #expect(settings.holdDuration == 0.3)
    var interaction = Interaction(settings: settings)
    _ = interaction.handle(Input(.down(3), at: 0))
    _ = interaction.handle(Input(.up(3), at: 0.2))
    _ = interaction.handle(Input(.down(3), at: 0.4))
    #expect(interaction.state == .lockedScroll)
    interaction.reset()
    _ = interaction.handle(Input(.down(3), at: 1))
    #expect(interaction.handle(Input(.move(Delta(3, 0)), at: 1.001)) == .scroll(Delta(3, 0)))
}
