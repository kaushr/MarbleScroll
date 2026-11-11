import Foundation

public enum ScrollState: String { case normal, buttonPressed, temporaryScroll, waitingForSecondClick, lockedScroll }
public enum InputKind { case move(Delta), down(Int), up(Int), tick }
public struct Input {
    public var kind: InputKind
    public var time: Double
    public var synthetic: Bool
    public init(_ kind: InputKind, at time: Double, synthetic: Bool = false) {
        self.kind = kind; self.time = time; self.synthetic = synthetic
    }
}
public enum Decision: Equatable { case pass, suppress, scroll(Delta) }

/// Pure deterministic state machine. No platform input, timers, permissions or persistence.
public struct Interaction {
    public private(set) var state: ScrollState = .normal
    public private(set) var isDown = false
    public private(set) var settings: Settings
    private let systemDoubleClickInterval: Double
    private var pressedAt = 0.0
    private var firstDown = 0.0
    private var travel = 0.0
    private var pending = Delta.zero
    private var lastTime: Double?

    public init(settings: Settings = Settings(), systemDoubleClickInterval: Double = 0.5) {
        self.settings = settings.validated()
        self.systemDoubleClickInterval = Settings.bound(systemDoubleClickInterval, 0.15...1.5, fallback: 0.5)
    }
    private var doubleInterval: Double { settings.doubleClickInterval ?? systemDoubleClickInterval }
    public var deadline: Double? {
        if state == .buttonPressed { return pressedAt + settings.holdDuration }
        if state == .waitingForSecondClick { return firstDown + doubleInterval + 0.000001 }
        return nil
    }
    public mutating func reset() {
        state = .normal; isDown = false; pending = .zero; travel = 0; lastTime = nil
    }
    public mutating func configure(_ settings: Settings) { reset(); self.settings = settings.validated() }

    public mutating func handle(_ input: Input) -> Decision {
        // Synthetic events cannot change click recognition, time or state.
        guard !input.synthetic else { return .pass }
        guard input.time.isFinite, lastTime.map({ input.time >= $0 }) ?? true else {
            reset(); return .pass
        }
        lastTime = input.time
        if state == .buttonPressed && input.time - pressedAt >= settings.holdDuration { state = .temporaryScroll }
        if state == .waitingForSecondClick && input.time - firstDown > doubleInterval { state = .normal }
        switch input.kind {
        case .tick: return .pass
        case .down(let b):
            guard b == settings.button else { return .pass }
            guard !isDown else { return .suppress } // Duplicate downs cannot toggle twice.
            isDown = true
            if state == .lockedScroll { state = .normal; return .suppress }
            if state == .waitingForSecondClick {
                state = .lockedScroll; pending = .zero; return .suppress
            }
            state = .buttonPressed; pressedAt = input.time; firstDown = input.time
            travel = 0; pending = .zero
            return .suppress
        case .up(let b):
            guard b == settings.button, isDown else { return .pass }
            isDown = false
            if state == .buttonPressed { state = .waitingForSecondClick; travel = 0 }
            else if state == .temporaryScroll { state = .normal }
            // Releasing the lock-activation click must retain locked mode.
            pending = .zero
            return .suppress
        case .move(let d):
            guard d.x.isFinite, d.y.isFinite else { reset(); return .pass }
            switch state {
            case .buttonPressed:
                // Buffer tiny jitter; crossing the threshold scrolls the entire buffer.
                travel += hypot(d.x, d.y); pending.x += d.x; pending.y += d.y
                if travel >= settings.movementThreshold {
                    state = .temporaryScroll
                    let output = pending; pending = .zero; return .scroll(output)
                }
                return .suppress
            case .temporaryScroll:
                let output = Delta(d.x + pending.x, d.y + pending.y)
                pending = .zero; return .scroll(output)
            case .lockedScroll: return .scroll(d)
            case .waitingForSecondClick:
                travel += hypot(d.x, d.y)
                if travel >= settings.movementThreshold { state = .normal }
                // With button released, pointer movement passes through and can cancel lock recognition.
                return .pass
            case .normal: return .pass
            }
        }
    }
}
