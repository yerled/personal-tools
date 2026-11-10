import XCTest
@testable import PersonalToolsCore

final class EyedropperSessionTests: XCTestCase {
    func testDoubleCommandBeginsAndASecondOneCancels() {
        var session = EyedropperController()
        XCTAssertEqual(session.handle(.doubleCommand), .begin)
        XCTAssertEqual(session.phase, .inspecting)
        XCTAssertEqual(session.handle(.doubleCommand), .cancel)
        XCTAssertEqual(session.phase, .idle)
    }

    func testClickCopiesUppercaseHexAndReturnsToIdle() {
        var session = EyedropperController()
        _ = session.handle(.doubleCommand)
        let action = session.handle(.click(RGBAPixel(r: 0x1A, g: 0x2B, b: 0x3C)))
        XCTAssertEqual(action, .copy("#1A2B3C"))
        XCTAssertEqual(session.phase, .idle)
    }

    func testClickAndEscapeDoNothingWhileIdle() {
        var session = EyedropperController()
        XCTAssertEqual(session.handle(.click(RGBAPixel(r: 1, g: 2, b: 3))), .none)
        XCTAssertEqual(session.handle(.escape), .none)
        XCTAssertEqual(session.phase, .idle)
    }

    func testEscapeCancelsAnOpenLoupe() {
        var session = EyedropperController()
        _ = session.handle(.doubleCommand)
        XCTAssertEqual(session.handle(.escape), .cancel)
        XCTAssertEqual(session.phase, .idle)
    }

    func testDisabledSessionIgnoresTheGestureAndDropsAnOpenLoupe() {
        var session = EyedropperController()
        XCTAssertEqual(session.handle(.setEnabled(false)), .none)
        XCTAssertEqual(session.handle(.doubleCommand), .none)
        _ = session.handle(.setEnabled(true))
        _ = session.handle(.doubleCommand)
        XCTAssertEqual(session.handle(.setEnabled(false)), .cancel)
        XCTAssertFalse(session.isEnabled)
        XCTAssertEqual(session.phase, .idle)
    }

    func testSamplingTimerExistsOnlyWhileTheLoupeIsVisible() {
        XCTAssertNil(SamplingClock.timerInterval(loupeVisible: false))
        let interval = SamplingClock.timerInterval(loupeVisible: true)
        XCTAssertEqual(interval ?? 0, 1.0 / 30.0, accuracy: 0.0001)
    }
}
