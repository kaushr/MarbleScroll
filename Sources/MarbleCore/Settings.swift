import Foundation

public struct Settings: Codable, Equatable {
    // CG button numbers are zero-based. No unverified hardware default.
    public var button: Int? = nil
    public var speed: Double = 2
    public var horizontal: Double = 1
    public var vertical: Double = 1
    public var reverse = false
    public var acceleration = false
    // nil uses NSEvent.doubleClickInterval, supplied by the platform adapter.
    public var doubleClickInterval: Double? = nil
    public var holdDuration: Double = 0.18
    public var movementThreshold: Double = 2
    public init() {}

    public func validated() -> Settings {
        var s = self
        if let b = s.button, !(2...31).contains(b) { s.button = nil }
        s.speed = Self.bound(s.speed, 0.1...10, fallback: 2)
        s.horizontal = Self.bound(s.horizontal, 0...5, fallback: 1)
        s.vertical = Self.bound(s.vertical, 0...5, fallback: 1)
        s.holdDuration = Self.bound(s.holdDuration, 0.05...1, fallback: 0.18)
        s.movementThreshold = Self.bound(s.movementThreshold, 0...30, fallback: 2)
        if let d = s.doubleClickInterval {
            s.doubleClickInterval = Self.bound(d, 0.15...1.5, fallback: 0.5)
        }
        return s
    }
    public static func bound(_ x: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        x.isFinite ? min(range.upperBound, max(range.lowerBound, x)) : fallback
    }
}

public struct Delta: Equatable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public static let zero = Delta(0, 0)
}

public struct ScrollPixels: Equatable {
    public var horizontal: Int32
    public var vertical: Int32
    public init(horizontal: Int32, vertical: Int32) {
        self.horizontal = horizontal; self.vertical = vertical
    }
    public var isZero: Bool { horizontal == 0 && vertical == 0 }
}

public struct ScrollConverter {
    private var remainder = Delta.zero
    public init() {}
    public mutating func reset() { remainder = .zero }
    public mutating func convert(_ delta: Delta, settings: Settings) -> ScrollPixels? {
        guard delta.x.isFinite, delta.y.isFinite else { reset(); return nil }
        let s = settings.validated()
        let x = max(-4096, min(4096, delta.x)), y = max(-4096, min(4096, delta.y))
        let gain = s.acceleration ? min(4, 1 + hypot(x, y) / 100) : 1
        // Default: rolling ball downward scrolls content upward; Reverse flips both axes.
        let sign: Double = s.reverse ? 1 : -1
        let hx = max(-32767, min(32767, x * s.speed * s.horizontal * gain * sign + remainder.x))
        let vy = max(-32767, min(32767, y * s.speed * s.vertical * gain * sign + remainder.y))
        let h = Int32(hx.rounded(.towardZero)), v = Int32(vy.rounded(.towardZero))
        remainder = Delta(hx - Double(h), vy - Double(v))
        return ScrollPixels(horizontal: h, vertical: v)
    }
}
