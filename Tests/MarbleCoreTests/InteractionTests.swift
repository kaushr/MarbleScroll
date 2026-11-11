import Testing
@testable import MarbleCore

private func machine(hold: Double = 0.18, threshold: Double = 2, interval: Double? = nil) -> Interaction {
    var s = Settings(); s.button = 3; s.holdDuration = hold; s.movementThreshold = threshold; s.doubleClickInterval = interval
    return Interaction(settings: s, systemDoubleClickInterval: 0.5)
}
private func click(_ m: inout Interaction, _ t: Double) {
    _ = m.handle(Input(.down(3), at: t)); _ = m.handle(Input(.up(3), at: t + 0.02))
}
private func lock(_ m: inout Interaction) {
    click(&m, 0); _ = m.handle(Input(.down(3), at: 0.1)); _ = m.handle(Input(.up(3), at: 0.12))
}

@Test func normalPointerMovementPasses() {
    var m = machine()
    #expect(m.handle(Input(.move(Delta(8, -4)), at: 0)) == .pass)
    #expect(m.state == .normal)
}
@Test func configuredPressReservesButton() {
    var m = machine()
    #expect(m.handle(Input(.down(3), at: 0)) == .suppress)
    #expect(m.state == .buttonPressed); #expect(m.deadline == 0.18)
}
@Test func holdDeadlineActivatesTemporary() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0))
    _ = m.handle(Input(.tick, at: 0.18))
    #expect(m.state == .temporaryScroll)
    #expect(m.handle(Input(.move(Delta(1, 0)), at: 0.19)) == .scroll(Delta(1, 0)))
}
@Test func moveStartsScrollingWithoutHoldDelay() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0))
    #expect(m.handle(Input(.move(Delta(0, 4)), at: 0.001)) == .scroll(Delta(0, 4)))
    #expect(m.state == .temporaryScroll)
}
@Test func subthresholdMotionIsBuffered() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0))
    #expect(m.handle(Input(.move(Delta(0.5, 0)), at: 0.01)) == .suppress)
    #expect(m.handle(Input(.move(Delta(1.5, 0)), at: 0.02)) == .scroll(Delta(2, 0)))
}
@Test func holdDeadlineKeepsBufferedMotion() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0))
    _ = m.handle(Input(.move(Delta(0.5, 0)), at: 0.01)); _ = m.handle(Input(.tick, at: 0.2))
    #expect(m.handle(Input(.move(Delta(1, 0)), at: 0.21)) == .scroll(Delta(1.5, 0)))
}
@Test func releasingTemporaryRestoresPointerImmediately() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0)); _ = m.handle(Input(.move(Delta(2, 0)), at: 0.01))
    #expect(m.handle(Input(.up(3), at: 0.02)) == .suppress)
    #expect(m.state == .normal)
    #expect(m.handle(Input(.move(Delta(5, 5)), at: 0.021)) == .pass)
}
@Test func shortSingleClickNeverLocks() {
    var m = machine(); click(&m, 0)
    #expect(m.state == .waitingForSecondClick)
    _ = m.handle(Input(.tick, at: 0.51)); #expect(m.state == .normal)
}
@Test func doubleClickLocksOnSecondDown() {
    var m = machine(); click(&m, 0)
    #expect(m.handle(Input(.down(3), at: 0.1)) == .suppress)
    #expect(m.state == .lockedScroll)
}
@Test func secondReleaseRetainsLock() {
    var m = machine(); lock(&m)
    #expect(m.state == .lockedScroll); #expect(!m.isDown)
    #expect(m.handle(Input(.move(Delta(3, -5)), at: 0.2)) == .scroll(Delta(3, -5)))
}
@Test func singleDownUnlocksImmediately() {
    var m = machine(); lock(&m)
    _ = m.handle(Input(.down(3), at: 0.2)); #expect(m.state == .normal)
    #expect(m.handle(Input(.move(Delta(3, 0)), at: 0.201)) == .pass)
    #expect(m.handle(Input(.up(3), at: 0.21)) == .suppress)
    #expect(m.state == .normal)
}
@Test func duplicateDownDoesNotToggleLockOff() {
    var m = machine(); click(&m, 0)
    _ = m.handle(Input(.down(3), at: 0.1)); _ = m.handle(Input(.down(3), at: 0.11))
    #expect(m.state == .lockedScroll)
}
@Test func duplicateUnlockDownDoesNotReenterTemporary() {
    var m = machine(); lock(&m)
    _ = m.handle(Input(.down(3), at: 0.2)); _ = m.handle(Input(.down(3), at: 0.21))
    #expect(m.state == .normal)
}
@Test func repeatedRapidClicksRemainDeterministic() {
    var m = machine()
    for i in 0..<300 {
        click(&m, Double(i) * 0.03)
        let expected: ScrollState = [ScrollState.waitingForSecondClick, .lockedScroll, .normal][i % 3]
        #expect(m.state == expected)
    }
}
@Test func doubleClickBoundaryIsInclusive() {
    var m = machine(); click(&m, 0)
    _ = m.handle(Input(.down(3), at: 0.5)); #expect(m.state == .lockedScroll)
}
@Test func afterDoubleClickBoundaryStartsNewPress() {
    var m = machine(); click(&m, 0)
    _ = m.handle(Input(.down(3), at: 0.500001)); #expect(m.state == .buttonPressed)
}
@Test func customDoubleClickTimingIsUsed() {
    var m = machine(interval: 0.25); click(&m, 0)
    _ = m.handle(Input(.down(3), at: 0.26)); #expect(m.state == .buttonPressed)
}
@Test func timingIsMeasuredDownToDown() {
    var m = machine(hold: 0.4); _ = m.handle(Input(.down(3), at: 0))
    _ = m.handle(Input(.up(3), at: 0.3)); _ = m.handle(Input(.down(3), at: 0.6))
    #expect(m.state == .buttonPressed)
}
@Test func exactHoldBoundaryIsTemporaryNotClick() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0)); _ = m.handle(Input(.up(3), at: 0.18))
    #expect(m.state == .normal)
}
@Test func temporaryNeverBecomesFirstClickOfLock() {
    var m = machine(); _ = m.handle(Input(.down(3), at: 0))
    _ = m.handle(Input(.move(Delta(8, 0)), at: 0.01)); _ = m.handle(Input(.up(3), at: 0.02))
    _ = m.handle(Input(.down(3), at: 0.1)); #expect(m.state == .buttonPressed)
}
@Test func movementBetweenClicksPassesAndCancelsRecognition() {
    var m = machine(); click(&m, 0)
    #expect(m.handle(Input(.move(Delta(3, 0)), at: 0.03)) == .pass)
    _ = m.handle(Input(.down(3), at: 0.1)); #expect(m.state == .buttonPressed)
}
@Test func smallInterclickJitterAllowsLock() {
    var m = machine(); click(&m, 0)
    #expect(m.handle(Input(.move(Delta(0.5, 0)), at: 0.03)) == .pass)
    _ = m.handle(Input(.down(3), at: 0.1)); #expect(m.state == .lockedScroll)
}
@Test func unrelatedButtonsAlwaysPass() {
    var m = machine(); lock(&m)
    for (index, b) in [0, 1, 2, 4, 31].enumerated() {
        let time = 0.3 + Double(index) * 0.02
        #expect(m.handle(Input(.down(b), at: time)) == .pass)
        #expect(m.handle(Input(.up(b), at: time + 0.01)) == .pass)
    }
    #expect(m.state == .lockedScroll)
}
@Test func unmatchedReleasePasses() {
    var m = machine(); #expect(m.handle(Input(.up(3), at: 0)) == .pass)
}
@Test func syntheticInputCannotChangeStateOrRecurse() {
    var m = machine(); lock(&m)
    #expect(m.handle(Input(.down(3), at: 0.3, synthetic: true)) == .pass)
    #expect(m.handle(Input(.move(Delta(8, 8)), at: 100, synthetic: true)) == .pass)
    #expect(m.state == .lockedScroll)
    #expect(m.handle(Input(.move(Delta(1, 0)), at: 0.4)) == .scroll(Delta(1, 0)))
}
@Test func backwardsTimeFailsOpenAndResets() {
    var m = machine(); lock(&m)
    #expect(m.handle(Input(.move(Delta(1, 1)), at: 0.01)) == .pass)
    #expect(m.state == .normal)
}
@Test func nonfiniteMotionFailsOpen() {
    var m = machine(); lock(&m)
    #expect(m.handle(Input(.move(Delta(.infinity, 0)), at: 0.3)) == .pass)
    #expect(m.state == .normal)
}
@Test func settingsChangeCancelsLock() {
    var m = machine(); lock(&m); m.configure(Settings()); #expect(m.state == .normal)
}
@Test func zeroThresholdActivatesOnFirstMovement() {
    var m = machine(threshold: 0); _ = m.handle(Input(.down(3), at: 0))
    #expect(m.handle(Input(.move(Delta(0.01, 0)), at: 0.001)) == .scroll(Delta(0.01, 0)))
}
