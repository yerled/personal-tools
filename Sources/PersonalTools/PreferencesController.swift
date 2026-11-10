import Foundation
import PersonalToolsCore

/// UserDefaults adapter. Missing keys keep the factory value; stored `false` stays off.
final class PreferencesController {
    private let defaults: UserDefaults
    private(set) var preferences: ToolPreferences
    var onChange: ((ToolPreferences) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Self.load(from: defaults)
    }

    func update(_ body: (inout ToolPreferences) -> Void) {
        body(&preferences)
        save()
        onChange?(preferences)
    }

    private func save() {
        for key in ToolPreferences.logicalKeys {
            defaults.set(storedValue(for: key), forKey: Self.defaultsKey(key))
        }
    }

    private func storedValue(for key: String) -> Bool {
        switch key {
        case ToolPreferences.scrollFlipEnabledKey:
            return preferences.scrollFlipEnabled
        case ToolPreferences.reverseHorizontalScrollKey:
            return preferences.reverseHorizontalScroll
        case ToolPreferences.eyedropperEnabledKey:
            return preferences.eyedropperEnabled
        default:
            return false
        }
    }

    private static func load(from defaults: UserDefaults) -> ToolPreferences {
        var values: [String: Bool] = [:]
        for key in ToolPreferences.logicalKeys {
            let stored = defaultsKey(key)
            if defaults.object(forKey: stored) != nil {
                values[key] = defaults.bool(forKey: stored)
            }
        }
        return PreferenceStore(values: values).load()
    }

    private static func defaultsKey(_ logical: String) -> String {
        "personalTools." + logical
    }
}
