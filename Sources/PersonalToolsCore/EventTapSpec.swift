import Foundation

/// `CGEventType` raw values from CGEventTypes.h. PersonalToolsMacTests compares
/// them with the SDK enums on the macOS runner.
public enum CGEventTypeCode {
    public static let leftMouseDown: UInt32 = 1
    public static let leftMouseUp: UInt32 = 2
    public static let rightMouseDown: UInt32 = 3
    public static let mouseMoved: UInt32 = 5
    public static let keyDown: UInt32 = 10
    public static let keyUp: UInt32 = 11
    public static let flagsChanged: UInt32 = 12
    public static let scrollWheel: UInt32 = 22
    public static let otherMouseDown: UInt32 = 25
}

public struct EventTypeMask: Equatable, Sendable {
    public var rawValue: UInt64

    public init(types: [UInt32]) {
        var value: UInt64 = 0
        for type in types where type < 64 {
            value |= 1 << type
        }
        rawValue = value
    }

    public func contains(_ type: UInt32) -> Bool {
        guard type < 64 else { return false }
        return rawValue & (1 << type) != 0
    }
}

public enum InputTapSpec {
    /// ANSI Escape. The picker swallows this key only while the loupe is visible.
    public static let escapeKeyCode: UInt16 = 53

    /// Scroll tap: wheel events only. Keys and pointer movement are not in the mask.
    public static func scrollFlipMask() -> EventTypeMask {
        EventTypeMask(types: [CGEventTypeCode.scrollWheel])
    }

    /// Picker tap, installed only while the loupe is visible.
    /// Scroll, flagsChanged, key-up, and other mouse buttons stay out of the mask
    /// so normal shortcuts and scrolling are not delivered to this tap.
    public static func eyedropperMask() -> EventTypeMask {
        EventTypeMask(types: [CGEventTypeCode.leftMouseDown, CGEventTypeCode.keyDown])
    }

    public enum Intercept: Equatable, Sendable {
        case pass
        case swallow
    }

    public static func eyedropperIntercept(
        type: UInt32,
        keyCode: UInt16?,
        loupeVisible: Bool
    ) -> Intercept {
        guard loupeVisible else { return .pass }
        if type == CGEventTypeCode.leftMouseDown {
            return .swallow
        }
        if type == CGEventTypeCode.keyDown, keyCode == escapeKeyCode {
            return .swallow
        }
        return .pass
    }
}

/// Counts picker-tap start/stop so a second loupe cannot stack another tap,
/// and hiding the loupe removes the tap. The mach port itself is macOS-only.
public struct ExclusiveTapLease: Equatable, Sendable {
    public private(set) var isRunning = false
    public private(set) var startCount = 0
    public private(set) var stopCount = 0

    public init() {}

    public mutating func start() {
        guard !isRunning else { return }
        isRunning = true
        startCount += 1
    }

    public mutating func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCount += 1
    }
}
