import AppKit
import CoreGraphics
import XCTest
import PersonalToolsCapture
@testable import PersonalToolsCore

final class MacSDKTests: XCTestCase {
    func testEventTypeCodesMatchTheSDK() {
        XCTAssertEqual(CGEventType.leftMouseDown.rawValue, CGEventTypeCode.leftMouseDown)
        XCTAssertEqual(CGEventType.leftMouseUp.rawValue, CGEventTypeCode.leftMouseUp)
        XCTAssertEqual(CGEventType.rightMouseDown.rawValue, CGEventTypeCode.rightMouseDown)
        XCTAssertEqual(CGEventType.mouseMoved.rawValue, CGEventTypeCode.mouseMoved)
        XCTAssertEqual(CGEventType.keyDown.rawValue, CGEventTypeCode.keyDown)
        XCTAssertEqual(CGEventType.keyUp.rawValue, CGEventTypeCode.keyUp)
        XCTAssertEqual(CGEventType.flagsChanged.rawValue, CGEventTypeCode.flagsChanged)
        XCTAssertEqual(CGEventType.scrollWheel.rawValue, CGEventTypeCode.scrollWheel)
        XCTAssertEqual(CGEventType.otherMouseDown.rawValue, CGEventTypeCode.otherMouseDown)
    }

    func testModifierBitsMatchTheSDK() {
        XCTAssertEqual(NSEvent.ModifierFlags.command.rawValue, CocoaModifierRawValue.command)
        XCTAssertEqual(NSEvent.ModifierFlags.shift.rawValue, CocoaModifierRawValue.shift)
        XCTAssertEqual(NSEvent.ModifierFlags.option.rawValue, CocoaModifierRawValue.option)
        XCTAssertEqual(NSEvent.ModifierFlags.control.rawValue, CocoaModifierRawValue.control)
        XCTAssertEqual(NSEvent.ModifierFlags.function.rawValue, CocoaModifierRawValue.function)
    }

    func testImageReaderKeepsTheTopRowAtTheTop() {
        let width = 2
        let height = 2
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: info
        ) else {
            XCTFail("Could not create a bitmap context")
            return
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        // User space is y-up, so y = 1 is the top row of a 2-pixel image.
        context.fill(CGRect(x: 0, y: 1, width: 2, height: 1))
        guard let image = context.makeImage(), let buffer = CGImageReader.bitmap(from: image) else {
            XCTFail("Could not read the image back")
            return
        }
        let top = buffer.pixel(x: 0, y: 0)
        let bottom = buffer.pixel(x: 0, y: 1)
        XCTAssertEqual(top?.b, 255)
        XCTAssertEqual(top?.r, 0)
        XCTAssertEqual(bottom?.r, 255)
        XCTAssertEqual(bottom?.b, 0)
    }
}
