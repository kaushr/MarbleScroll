import Foundation
import Testing
@testable import MarbleCore

@Test func verticalScrollDirection() {
    var c = ScrollConverter(); let p = c.convert(Delta(0, 4), settings: Settings())
    #expect(p == ScrollPixels(horizontal: 0, vertical: -8))
}
@Test func horizontalScrollDirection() {
    var c = ScrollConverter(); #expect(c.convert(Delta(4, 0), settings: Settings()) == ScrollPixels(horizontal: -8, vertical: 0))
}
@Test func directionReversalAffectsBothAxes() {
    var c = ScrollConverter(); var s = Settings(); s.reverse = true
    #expect(c.convert(Delta(3, -4), settings: s) == ScrollPixels(horizontal: 6, vertical: -8))
}
@Test func axesHaveIndependentSensitivity() {
    var c = ScrollConverter(); var s = Settings(); s.horizontal = 0.5; s.vertical = 2
    #expect(c.convert(Delta(4, 3), settings: s) == ScrollPixels(horizontal: -4, vertical: -12))
}
@Test func zeroSensitivityDisablesOneAxis() {
    var c = ScrollConverter(); var s = Settings(); s.horizontal = 0
    #expect(c.convert(Delta(9, 3), settings: s) == ScrollPixels(horizontal: 0, vertical: -6))
}
@Test func fractionalMotionAccumulates() {
    var c = ScrollConverter(); var s = Settings(); s.speed = 0.25
    #expect(c.convert(Delta(1, 0), settings: s)?.horizontal == 0)
    #expect(c.convert(Delta(1, 0), settings: s)?.horizontal == 0)
    #expect(c.convert(Delta(1, 0), settings: s)?.horizontal == 0)
    #expect(c.convert(Delta(1, 0), settings: s)?.horizontal == -1)
}
@Test func resetClearsFractionalResidual() {
    var c = ScrollConverter(); var s = Settings(); s.speed = 0.5
    _ = c.convert(Delta(1, 0), settings: s); c.reset()
    #expect(c.convert(Delta(1, 0), settings: s)?.horizontal == 0)
}
@Test func extremeDeltasAreBounded() {
    var c = ScrollConverter(); var s = Settings(); s.speed = 10; s.horizontal = 5; s.vertical = 5; s.acceleration = true
    #expect(c.convert(Delta(Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude), settings: s)
            == ScrollPixels(horizontal: -32767, vertical: 32767))
}
@Test func nonfiniteDeltasAreRejected() {
    var c = ScrollConverter(); #expect(c.convert(Delta(.nan, 0), settings: Settings()) == nil)
    #expect(c.convert(Delta(0, -.infinity), settings: Settings()) == nil)
}
@Test func accelerationIsOptionalAndBounded() {
    var c = ScrollConverter(); var s = Settings(); s.speed = 1
    #expect(c.convert(Delta(100, 0), settings: s)?.horizontal == -100)
    s.acceleration = true; #expect(c.convert(Delta(100, 0), settings: s)?.horizontal == -200)
}
@Test func invalidSettingsUseSafeValues() {
    var s = Settings(); s.button = 0; s.speed = .nan; s.horizontal = -.infinity
    s.vertical = 999; s.holdDuration = -1; s.doubleClickInterval = .nan; s.movementThreshold = .infinity
    let v = s.validated()
    #expect(v.button == nil); #expect(v.speed == 2); #expect(v.horizontal == 1); #expect(v.vertical == 5)
    #expect(v.holdDuration == 0.05); #expect(v.doubleClickInterval == 0.5); #expect(v.movementThreshold == 2)
}
@Test func configurationRoundTripPersistsOnlySettings() throws {
    var s = Settings(); s.button = 4; s.reverse = true
    let data = try JSONEncoder().encode(s)
    #expect(try JSONDecoder().decode(Settings.self, from: data) == s)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["enabled"] == nil); #expect(object["locked"] == nil); #expect(object["globalConsent"] == nil)
}
@Test func malformedSettingsJSONThrows() {
    #expect(throws: (any Error).self) { try JSONDecoder().decode(Settings.self, from: Data("{\"speed\":\"wrong\"}".utf8)) }
}
@Test func longMixedSequenceMaintainsStateInvariants() {
    var s = Settings(); s.button = 3
    var m = Interaction(settings: s)
    var seed: UInt64 = 0x12345678
    var time = 0.0
    for _ in 0..<20_000 {
        seed = seed &* 6364136223846793005 &+ 1; time += 0.001
        let kind: InputKind
        switch seed % 5 {
        case 0: kind = .down(3)
        case 1: kind = .up(3)
        case 2: kind = .move(Delta(3, 1))
        case 3: kind = .tick
        default: m.reset(); kind = .move(Delta(1, 1))
        }
        _ = m.handle(Input(kind, at: time))
        if m.state == .temporaryScroll || m.state == .buttonPressed { #expect(m.isDown) }
        if m.state == .waitingForSecondClick { #expect(!m.isDown) }
    }
}
