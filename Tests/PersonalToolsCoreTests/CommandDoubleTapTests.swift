import XCTest
@testable import PersonalToolsCore

final class CommandDoubleTapTests: XCTestCase {
    private let config = CommandDoubleTapConfiguration(maxPressDuration: 0.30, maxGap: 0.45)

    private func detector() -> CommandDoubleTapDetector {
        CommandDoubleTapDetector(configuration: config)
    }

    private func flags(_ modifiers: ModifierFlags, at time: TimeInterval) -> PointerDeviceEvent {
        .flagsChanged(modifiers, time: time)
    }

    private func key(_ code: UInt16, modifiers: ModifierFlags, at time: TimeInterval) -> PointerDeviceEvent {
        .keyDown(keyCode: code, modifiers: modifiers, time: time)
    }

    private func decisions(
        _ events: [PointerDeviceEvent],
        detector: CommandDoubleTapDetector? = nil
    ) -> [CommandGestureDecision] {
        var local = detector ?? self.detector()
        return events.map { local.receive($0) }
    }

    func testTwoShortPressReleaseCyclesRecognizeOnTheSecondRelease() {
        let result = decisions([
            flags(.command, at: 0.00),
            flags([], at: 0.08),
            flags(.command, at: 0.20),
            flags([], at: 0.28)
        ])
        XCTAssertEqual(result, [.none, .none, .none, .recognized])
    }

    func testSingleTapDoesNotRecognize() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.1)
        ])
        XCTAssertEqual(result, [.none, .none])
    }

    func testHoldingCommandDoesNotArmATap() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.31),
            flags(.command, at: 0.40),
            flags([], at: 0.48)
        ])
        XCTAssertEqual(result, [.none, .none, .none, .none])
    }

    func testPressExactlyAtTheLimitStillCounts() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.30),
            flags(.command, at: 0.75),
            flags([], at: 1.05)
        ])
        XCTAssertEqual(result.last, .recognized)
    }

    func testGapExactlyAtTheLimitStillCounts() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.10),
            flags(.command, at: 0.55),
            flags([], at: 0.65)
        ])
        XCTAssertEqual(result.last, .recognized)
    }

    func testSlowSecondPressStartsANewFirstTap() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.10),
            flags(.command, at: 0.56),
            flags([], at: 0.66)
        ])
        XCTAssertEqual(result, [.none, .none, .none, .none])
    }

    func testCommandCAfterFlagsDoesNotRecognize() {
        let result = decisions([
            flags(.command, at: 0),
            key(8, modifiers: .command, at: 0.04),
            flags([], at: 0.09)
        ])
        XCTAssertEqual(result, [.none, .none, .none])
    }

    func testCommandCBeforeFlagsDoesNotRecognize() {
        let result = decisions([
            key(8, modifiers: .command, at: 0),
            flags(.command, at: 0.01),
            flags([], at: 0.08)
        ])
        XCTAssertEqual(result, [.none, .none, .none])
    }

    func testCommandTabDoesNotRecognize() {
        let result = decisions([
            flags(.command, at: 1),
            key(48, modifiers: .command, at: 1.02),
            flags([], at: 1.20)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testCommandShiftChordDoesNotRecognize() {
        let result = decisions([
            flags(.shift, at: 0),
            flags([.command, .shift], at: 0.05),
            flags(.shift, at: 0.12),
            flags([], at: 0.14)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testAddingShiftWhileCommandIsHeldCancelsTheTap() {
        let result = decisions([
            flags(.command, at: 0),
            flags([.command, .shift], at: 0.05),
            flags([], at: 0.10),
            flags(.command, at: 0.20),
            flags([], at: 0.28)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testOptionControlAndFunctionContaminate() {
        for extra in [ModifierFlags.option, .control, .function] {
            let result = decisions([
                flags([.command, extra], at: 0),
                flags([], at: 0.08),
                flags(.command, at: 0.16),
                flags([], at: 0.24)
            ])
            XCTAssertFalse(result.contains(.recognized), "\(extra)")
        }
    }

    func testAKeyBetweenTapsBreaksTheGesture() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.08),
            key(0, modifiers: [], at: 0.12),
            flags(.command, at: 0.18),
            flags([], at: 0.26)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testScrollBetweenTapsDoesNotCancelOrSwallowTheGesture() {
        let result = decisions([
            flags(.command, at: 0),
            flags([], at: 0.08),
            .other(time: 0.12),
            flags(.command, at: 0.20),
            flags([], at: 0.28)
        ])
        XCTAssertEqual(result, [.none, .none, .none, .none, .recognized])
    }

    func testMouseMovementDuringAShortHoldDoesNotCancel() {
        let result = decisions([
            flags(.command, at: 0),
            .other(time: 0.04),
            flags([], at: 0.08),
            flags(.command, at: 0.16),
            .other(time: 0.18),
            flags([], at: 0.22)
        ])
        XCTAssertEqual(result.last, .recognized)
    }

    func testTripleTapRecognizesOnceThenArmsTheThird() {
        let result = decisions([
            flags(.command, at: 0.00),
            flags([], at: 0.08),
            flags(.command, at: 0.16),
            flags([], at: 0.24),
            flags(.command, at: 0.32),
            flags([], at: 0.40)
        ])
        XCTAssertEqual(result, [.none, .none, .none, .recognized, .none, .none])
    }

    func testASecondDoubleTapCanRecognizeAgain() {
        var local = detector()
        let first: [PointerDeviceEvent] = [
            flags(.command, at: 0),
            flags([], at: 0.08),
            flags(.command, at: 0.16),
            flags([], at: 0.24)
        ]
        XCTAssertEqual(first.map { local.receive($0) }.last, .recognized)
        let second: [PointerDeviceEvent] = [
            flags(.command, at: 1.00),
            flags([], at: 1.08),
            flags(.command, at: 1.16),
            flags([], at: 1.24)
        ]
        XCTAssertEqual(second.map { local.receive($0) }.last, .recognized)
    }

    func testRepeatedFlagsWhileHeldAreNotExtraTaps() {
        let result = decisions([
            flags(.command, at: 0),
            flags(.command, at: 0.05),
            flags(.command, at: 0.50),
            flags([], at: 0.60)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testBackwardsTimestampDoesNotRecognize() {
        let result = decisions([
            flags(.command, at: 1.0),
            flags([], at: 0.2),
            flags(.command, at: 0.3),
            flags([], at: 0.4)
        ])
        XCTAssertFalse(result.contains(.recognized))
    }

    func testCommandShortcutMappingIgnoresUnrelatedBits() {
        let raw = CocoaModifierRawValue.command | (1 << 16) // Command plus Caps Lock
        XCTAssertEqual(CocoaModifierRawValue.flags(from: raw), .command)
        let chord = CocoaModifierRawValue.command | CocoaModifierRawValue.shift
        XCTAssertEqual(CocoaModifierRawValue.flags(from: chord), [.command, .shift])
    }
}
