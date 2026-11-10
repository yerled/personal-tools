import Foundation

/// Independent feature switches. Missing keys use the factory value, so a
/// first launch reverses the wheel and arms the eyedropper. An explicit
/// `false` stays off.
public struct ToolPreferences: Equatable, Codable, Sendable {
    public var scrollFlipEnabled: Bool
    public var reverseHorizontalScroll: Bool
    public var eyedropperEnabled: Bool

    public static let scrollFlipEnabledKey = "scrollFlipEnabled"
    public static let reverseHorizontalScrollKey = "reverseHorizontalScroll"
    public static let eyedropperEnabledKey = "eyedropperEnabled"

    public static let factory = ToolPreferences(
        scrollFlipEnabled: true,
        reverseHorizontalScroll: false,
        eyedropperEnabled: true
    )

    public init(scrollFlipEnabled: Bool, reverseHorizontalScroll: Bool, eyedropperEnabled: Bool) {
        self.scrollFlipEnabled = scrollFlipEnabled
        self.reverseHorizontalScroll = reverseHorizontalScroll
        self.eyedropperEnabled = eyedropperEnabled
    }

    public static var logicalKeys: [String] {
        [scrollFlipEnabledKey, reverseHorizontalScrollKey, eyedropperEnabledKey]
    }
}

public struct PreferenceStore: Equatable, Sendable {
    public private(set) var values: [String: Bool]

    public init(values: [String: Bool] = [:]) {
        self.values = values
    }

    public func load() -> ToolPreferences {
        ToolPreferences(
            scrollFlipEnabled: values[ToolPreferences.scrollFlipEnabledKey] ?? ToolPreferences.factory.scrollFlipEnabled,
            reverseHorizontalScroll: values[ToolPreferences.reverseHorizontalScrollKey] ?? ToolPreferences.factory.reverseHorizontalScroll,
            eyedropperEnabled: values[ToolPreferences.eyedropperEnabledKey] ?? ToolPreferences.factory.eyedropperEnabled
        )
    }

    public mutating func save(_ preferences: ToolPreferences) {
        values[ToolPreferences.scrollFlipEnabledKey] = preferences.scrollFlipEnabled
        values[ToolPreferences.reverseHorizontalScrollKey] = preferences.reverseHorizontalScroll
        values[ToolPreferences.eyedropperEnabledKey] = preferences.eyedropperEnabled
    }
}
