import XCTest
@testable import PersonalToolsCore

final class EventTapSpecTests: XCTestCase {
    func testScrollMaskIsOnlyTheWheel() {
        let mask = InputTapSpec.scrollFlipMask()
        XCTAssertTrue(mask.contains(CGEventTypeCode.scrollWheel))
        XCTAssertFalse(mask.contains(CGEventTypeCode.keyDown))
        XCTAssertFalse(mask.contains(CGEventTypeCode.flagsChanged))
        XCTAssertFalse(mask.contains(CGEventTypeCode.leftMouseDown))
        XCTAssertFalse(mask.contains(CGEventTypeCode.mouseMoved))
    }

    func testEyedropperMaskDoesNotIncludeScrollOrModifierChanges() {
        let mask = InputTapSpec.eyedropperMask()
        XCTAssertTrue(mask.contains(CGEventTypeCode.leftMouseDown))
        XCTAssertTrue(mask.contains(CGEventTypeCode.keyDown))
        XCTAssertFalse(mask.contains(CGEventTypeCode.scrollWheel))
        XCTAssertFalse(mask.contains(CGEventTypeCode.flagsChanged))
        XCTAssertFalse(mask.contains(CGEventTypeCode.keyUp))
        XCTAssertFalse(mask.contains(CGEventTypeCode.mouseMoved))
        XCTAssertFalse(mask.contains(CGEventTypeCode.rightMouseDown))
        XCTAssertFalse(mask.contains(CGEventTypeCode.leftMouseUp))
        XCTAssertFalse(mask.contains(CGEventTypeCode.otherMouseDown))
    }

    func testOnlyTheSelectingClickAndEscapeAreSwallowed() {
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.leftMouseDown, keyCode: nil, loupeVisible: true),
            .swallow
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.keyDown, keyCode: InputTapSpec.escapeKeyCode, loupeVisible: true),
            .swallow
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.keyDown, keyCode: 8, loupeVisible: true),
            .pass
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.keyDown, keyCode: 48, loupeVisible: true),
            .pass
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.scrollWheel, keyCode: nil, loupeVisible: true),
            .pass
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.flagsChanged, keyCode: nil, loupeVisible: true),
            .pass
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.leftMouseDown, keyCode: nil, loupeVisible: false),
            .pass
        )
        XCTAssertEqual(
            InputTapSpec.eyedropperIntercept(type: CGEventTypeCode.keyDown, keyCode: 53, loupeVisible: false),
            .pass
        )
    }

    func testPickerTapLeaseDoesNotStackOrStopTwice() {
        var lease = ExclusiveTapLease()
        lease.start()
        lease.start()
        XCTAssertEqual(lease.startCount, 1)
        XCTAssertTrue(lease.isRunning)
        lease.stop()
        lease.stop()
        XCTAssertEqual(lease.stopCount, 1)
        XCTAssertFalse(lease.isRunning)
        lease.start()
        XCTAssertEqual(lease.startCount, 2)
        lease.stop()
        XCTAssertEqual(lease.stopCount, 2)
    }
}
