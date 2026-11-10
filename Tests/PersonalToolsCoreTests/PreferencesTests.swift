import XCTest
@testable import PersonalToolsCore

final class PreferencesTests: XCTestCase {
    func testMissingKeysUseFactoryDefaults() {
        let loaded = PreferenceStore().load()
        XCTAssertEqual(loaded, ToolPreferences.factory)
        XCTAssertTrue(loaded.scrollFlipEnabled)
        XCTAssertFalse(loaded.reverseHorizontalScroll)
        XCTAssertTrue(loaded.eyedropperEnabled)
    }

    func testExplicitFalseIsNotTreatedAsMissing() {
        let store = PreferenceStore(values: [ToolPreferences.scrollFlipEnabledKey: false])
        let loaded = store.load()
        XCTAssertFalse(loaded.scrollFlipEnabled)
        XCTAssertTrue(loaded.eyedropperEnabled)
        XCTAssertFalse(loaded.reverseHorizontalScroll)
    }

    func testTogglesAreIndependent() {
        var store = PreferenceStore()
        var preferences = store.load()
        preferences.eyedropperEnabled = false
        store.save(preferences)
        preferences = store.load()
        preferences.reverseHorizontalScroll = true
        store.save(preferences)

        let loaded = store.load()
        XCTAssertTrue(loaded.scrollFlipEnabled)
        XCTAssertTrue(loaded.reverseHorizontalScroll)
        XCTAssertFalse(loaded.eyedropperEnabled)
        XCTAssertEqual(Set(store.values.keys), Set(ToolPreferences.logicalKeys))
    }

    func testRoundTripPreservesEverySwitch() {
        var store = PreferenceStore()
        let preferences = ToolPreferences(
            scrollFlipEnabled: false,
            reverseHorizontalScroll: true,
            eyedropperEnabled: false
        )
        store.save(preferences)
        XCTAssertEqual(store.load(), preferences)
    }
}
