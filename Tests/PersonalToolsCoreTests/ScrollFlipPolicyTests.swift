import XCTest
@testable import PersonalToolsCore

final class ScrollFlipPolicyTests: XCTestCase {
    private let wheel = ScrollEventTraits(isContinuous: false, scrollPhase: 0, momentumPhase: 0)
    private let trackpad = ScrollEventTraits(isContinuous: true, scrollPhase: 2, momentumPhase: 0)

    func testDisabledFeaturePassesADiscreteWheelThrough() {
        XCTAssertEqual(
            ScrollFlipPolicy.decide(traits: wheel, enabled: false, reverseHorizontal: true),
            .passThrough
        )
    }

    func testTrackpadStaysUntouchedWhileTheFeatureIsOn() {
        XCTAssertEqual(
            ScrollFlipPolicy.decide(traits: trackpad, enabled: true, reverseHorizontal: true),
            .passThrough
        )
    }

    func testDiscreteWheelInvertsVerticalAndOptionallyHorizontal() {
        XCTAssertEqual(
            ScrollFlipPolicy.decide(traits: wheel, enabled: true, reverseHorizontal: false),
            .invert(horizontal: false)
        )
        XCTAssertEqual(
            ScrollFlipPolicy.decide(traits: wheel, enabled: true, reverseHorizontal: true),
            .invert(horizontal: true)
        )
    }
}
