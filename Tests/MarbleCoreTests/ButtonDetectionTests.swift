import Testing
@testable import MarbleCore

@Test func detectionStartsDisabledAndCannotTrack() {
    var d = ButtonDetection(); #expect(d.state == .disabled)
    let started = d.start(); #expect(!started)
}
@Test func enablingDetectionDoesNotStartTracking() {
    var d = ButtonDetection(); d.enable(); #expect(d.state == .ready)
}
@Test func separateStartActionIsRequired() {
    var d = ButtonDetection(); d.enable(); let started = d.start()
    #expect(started); #expect(d.state == .tracking)
}
@Test func repeatedStartCannotCreateSecondTrackingSession() {
    var d = ButtonDetection(); d.enable(); let first = d.start(); let second = d.start()
    #expect(first); #expect(!second)
}
@Test func trackingFinishOrTimeoutReturnsToReady() {
    var d = ButtonDetection(); d.enable(); _ = d.start(); d.finish()
    #expect(d.state == .ready); let restarted = d.start(); #expect(restarted)
}
@Test func cancellationRevokesDetectionReadiness() {
    var d = ButtonDetection(); d.enable(); _ = d.start(); d.reset()
    #expect(d.state == .disabled); let started = d.start(); #expect(!started)
}
@Test func staleFinishDoesNotReenableDetection() {
    var d = ButtonDetection(); d.enable(); _ = d.start(); d.reset(); d.finish()
    #expect(d.state == .disabled); let started = d.start(); #expect(!started)
}
@Test func repeatedEnableDoesNotChangeTracking() {
    var d = ButtonDetection(); d.enable(); _ = d.start(); d.enable(); #expect(d.state == .tracking)
}
