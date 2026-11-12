// Read-only test helper. Does not create a tap, inspect event content or request permissions.
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let target = Int32(CommandLine.arguments[1]), target > 0 else {
    fputs("Usage: tap-status PID\n", stderr); exit(2)
}
var count: UInt32 = 0
let query = CGGetEventTapList(0, nil, &count)
guard query == .success else { fputs("Tap metadata unavailable: \(query.rawValue)\n", stderr); exit(1) }
var taps = Array(repeating: CGEventTapInformation(), count: Int(count))
let result = taps.withUnsafeMutableBufferPointer { CGGetEventTapList(count, $0.baseAddress, &count) }
guard result == .success else { fputs("Tap metadata unavailable: \(result.rawValue)\n", stderr); exit(1) }
let selected = taps.prefix(Int(count)).filter { $0.tappingProcess == target }
let rows: [[String: Any]] = selected.map {
    ["pid": Int($0.tappingProcess), "id": Int($0.eventTapID),
     "tapPoint": Int($0.tapPoint.rawValue), "listenOnly": $0.options == .listenOnly,
     "enabled": $0.enabled, "eventMask": String($0.eventsOfInterest, radix: 16),
     "averageCallbackMicroseconds": $0.avgUsecLatency, "maxCallbackMicroseconds": $0.maxUsecLatency]
}
let data = try JSONSerialization.data(withJSONObject: ["pid": Int(target), "taps": rows], options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
