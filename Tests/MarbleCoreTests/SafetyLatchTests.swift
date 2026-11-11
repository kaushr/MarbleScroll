import Foundation
import Testing
@testable import MarbleCore

@Test func latchStartsInhibited() {
    let gate = SafetyLatch<Int> { _ in }
    #expect(!gate.arm(1)); #expect(!gate.isArmed)
}
@Test func disarmInvalidatesExactlyOnce() {
    var invalidated: [Int] = []
    let gate = SafetyLatch<Int> { invalidated.append($0) }
    gate.allowExplicitStart(); #expect(gate.arm(1)); gate.disarm(); gate.disarm()
    #expect(invalidated == [1]); #expect(!gate.isArmed)
}
@Test func emergencyInhibitsTimeoutRearmUntilExplicitAction() {
    var invalidated: [Int] = []
    let gate = SafetyLatch<Int> { invalidated.append($0) }
    gate.allowExplicitStart(); #expect(gate.arm(1)); gate.emergencyStop()
    #expect(!gate.arm(2)); #expect(invalidated == [1])
    gate.allowExplicitStart(); #expect(gate.arm(3)); gate.emergencyStop()
    #expect(invalidated == [1, 3])
}
@Test func duplicateArmDoesNotLoseOwnedResource() {
    var invalidated: [Int] = []
    let gate = SafetyLatch<Int> { invalidated.append($0) }
    gate.allowExplicitStart(); #expect(gate.arm(1)); #expect(!gate.arm(2)); gate.disarm()
    #expect(invalidated == [1])
}
@Test func concurrentEmergencyAndRearmEndsInhibited() {
    let gate = SafetyLatch<Int> { _ in }
    gate.allowExplicitStart()
    DispatchQueue.concurrentPerform(iterations: 1000) { i in
        if i % 2 == 0 { _ = gate.arm(i) } else { gate.emergencyStop() }
    }
    gate.emergencyStop()
    #expect(!gate.isArmed); #expect(!gate.arm(1001))
}
