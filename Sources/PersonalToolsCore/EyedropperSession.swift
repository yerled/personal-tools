import Foundation

public enum EyedropperPhase: Equatable, Sendable {
    case idle
    case inspecting
}

public enum EyedropperAction: Equatable, Sendable {
    case none
    case begin
    case cancel
    case copy(String)
}

public enum EyedropperEvent: Equatable, Sendable {
    case doubleCommand
    case click(RGBAPixel)
    case escape
    case setEnabled(Bool)
}

/// Picker session. A double Command tap begins it, a second one cancels,
/// a click copies HEX, and Escape cancels. Disabled sessions ignore the gesture.
public struct EyedropperController: Equatable, Sendable {
    public private(set) var phase: EyedropperPhase
    public private(set) var isEnabled: Bool

    public init(isEnabled: Bool = true) {
        phase = .idle
        self.isEnabled = isEnabled
    }

    public mutating func handle(_ event: EyedropperEvent) -> EyedropperAction {
        switch event {
        case let .setEnabled(enabled):
            isEnabled = enabled
            if !enabled, phase == .inspecting {
                phase = .idle
                return .cancel
            }
            return .none
        case .doubleCommand:
            guard isEnabled else { return .none }
            if phase == .inspecting {
                phase = .idle
                return .cancel
            }
            phase = .inspecting
            return .begin
        case let .click(pixel):
            guard phase == .inspecting else { return .none }
            phase = .idle
            return .copy(ColorFormatting.hex(pixel))
        case .escape:
            guard phase == .inspecting else { return .none }
            phase = .idle
            return .cancel
        }
    }
}

/// Sampling cost while the loupe is on screen.
///
/// Idle means no timer. The menu-bar process must not keep a capture loop
/// running after Escape, a click, or quit. 30 samples per second is only for
/// the short time the loupe is visible, and unchanged pixels skip the capture.
public enum SamplingClock {
    public static let samplesPerSecondWhileVisible = 30

    public static func timerInterval(loupeVisible: Bool) -> TimeInterval? {
        guard loupeVisible else { return nil }
        return 1.0 / Double(samplesPerSecondWhileVisible)
    }
}
