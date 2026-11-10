import Foundation

/// Modifiers that matter for the Command double-tap gesture.
///
/// Caps Lock is ignored. Shift, Option, Control, and Function mark a chord,
/// so Command-C, Command-Tab, and Command-Shift never count as a bare tap.
public struct ModifierFlags: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift = ModifierFlags(rawValue: 1 << 1)
    public static let option = ModifierFlags(rawValue: 1 << 2)
    public static let control = ModifierFlags(rawValue: 1 << 3)
    public static let function = ModifierFlags(rawValue: 1 << 4)

    public static let contaminating: ModifierFlags = [.shift, .option, .control, .function]
}

/// Device-independent `NSEvent.ModifierFlags` bits. The macOS test target
/// checks these against the SDK so a wrong shift fails CI.
public enum CocoaModifierRawValue {
    public static let shift: UInt = 1 << 17
    public static let control: UInt = 1 << 18
    public static let option: UInt = 1 << 19
    public static let command: UInt = 1 << 20
    public static let function: UInt = 1 << 23

    public static func flags(from raw: UInt) -> ModifierFlags {
        var flags = ModifierFlags()
        if raw & command != 0 { flags.insert(.command) }
        if raw & shift != 0 { flags.insert(.shift) }
        if raw & control != 0 { flags.insert(.control) }
        if raw & option != 0 { flags.insert(.option) }
        if raw & function != 0 { flags.insert(.function) }
        return flags
    }
}

public enum PointerDeviceEvent: Equatable, Sendable {
    /// Command and other modifiers changed. This is how a bare Command tap arrives.
    case flagsChanged(ModifierFlags, time: TimeInterval)
    /// A non-modifier key went down. `keyCode` is the hardware code (Escape is 53).
    case keyDown(keyCode: UInt16, modifiers: ModifierFlags, time: TimeInterval)
    /// Scroll, mouse move, and anything else. These must not arm or cancel the gesture,
    /// and the app does not swallow them.
    case other(time: TimeInterval)
}

public enum CommandGestureDecision: Equatable, Sendable {
    case none
    case recognized
}

public struct CommandDoubleTapConfiguration: Equatable, Sendable {
    /// Press-to-release longer than this is a hold, not a tap.
    public var maxPressDuration: TimeInterval
    /// Release-to-next-press longer than this starts a new first tap.
    public var maxGap: TimeInterval

    public init(maxPressDuration: TimeInterval = 0.30, maxGap: TimeInterval = 0.45) {
        self.maxPressDuration = maxPressDuration
        self.maxGap = maxGap
    }
}

/// Recognizes two bare Command press/release cycles.
///
/// The gesture fires on the second release, never on the press. A key down
/// while Command is held (Command-C, Command-Tab, Command-Shift) cancels the
/// cycle, including when that key event arrives before `flagsChanged`.
/// Holding Command past `maxPressDuration` does not arm a tap.
///
/// Call this on the main thread only. It keeps no timer: the gap is checked
/// when the next event arrives, so an idle menu-bar app does not poll.
public struct CommandDoubleTapDetector {
    public let configuration: CommandDoubleTapConfiguration

    private enum Phase {
        case idle
        case holding(pressedAt: TimeInterval)
        case armed(releasedAt: TimeInterval)
        case secondHolding(pressedAt: TimeInterval)
    }

    private var phase: Phase = .idle
    private var commandIsDown = false
    private var blockUntilCommandUp = false

    public init(configuration: CommandDoubleTapConfiguration = CommandDoubleTapConfiguration()) {
        self.configuration = configuration
    }

    public mutating func reset() {
        phase = .idle
        commandIsDown = false
        blockUntilCommandUp = false
    }

    public mutating func receive(_ event: PointerDeviceEvent) -> CommandGestureDecision {
        switch event {
        case .other:
            return .none
        case let .keyDown(_, modifiers, _):
            return noteKeyDown(modifiers: modifiers)
        case let .flagsChanged(flags, time):
            return noteFlags(flags, time: time)
        }
    }

    private mutating func noteKeyDown(modifiers: ModifierFlags) -> CommandGestureDecision {
        let commandInvolved = commandIsDown || modifiers.contains(.command)
        if commandInvolved {
            blockUntilCommandUp = true
            phase = .idle
            return .none
        }
        // A normal key between two Command taps breaks the double-tap.
        if case .armed = phase {
            phase = .idle
        }
        return .none
    }

    private mutating func noteFlags(_ flags: ModifierFlags, time: TimeInterval) -> CommandGestureDecision {
        let commandNow = flags.contains(.command)
        if !flags.isDisjoint(with: .contaminating) {
            phase = .idle
            blockUntilCommandUp = commandNow
            commandIsDown = commandNow
            return .none
        }

        if commandNow == commandIsDown {
            if !commandNow, case let .armed(releasedAt) = phase, time - releasedAt > configuration.maxGap {
                phase = .idle
            }
            return .none
        }

        if commandNow {
            commandIsDown = true
            if blockUntilCommandUp {
                phase = .idle
                return .none
            }
            switch phase {
            case let .armed(releasedAt):
                let gap = time - releasedAt
                if withinLimit(gap, configuration.maxGap) {
                    phase = .secondHolding(pressedAt: time)
                } else {
                    phase = .holding(pressedAt: time)
                }
            default:
                phase = .holding(pressedAt: time)
            }
            return .none
        }

        commandIsDown = false
        let blocked = blockUntilCommandUp
        blockUntilCommandUp = false
        if blocked {
            phase = .idle
            return .none
        }

        switch phase {
        case let .holding(pressedAt):
            let duration = time - pressedAt
            if withinLimit(duration, configuration.maxPressDuration) {
                phase = .armed(releasedAt: time)
            } else {
                phase = .idle
            }
            return .none
        case let .secondHolding(pressedAt):
            let duration = time - pressedAt
            phase = .idle
            if withinLimit(duration, configuration.maxPressDuration) {
                return .recognized
            }
            return .none
        default:
            phase = .idle
            return .none
        }
    }

    /// Human taps are not exact binary fractions. One microsecond keeps a
    /// press that lands on the configured limit from being rejected.
    private func withinLimit(_ value: TimeInterval, _ limit: TimeInterval) -> Bool {
        value >= -0.000001 && value <= limit + 0.000001
    }
}
