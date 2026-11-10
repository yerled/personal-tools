import XCTest
@testable import PersonalToolsCore

final class ColorSampleTests: XCTestCase {
    func testHexIsUppercaseAndIgnoresAlpha() {
        XCTAssertEqual(ColorFormatting.hex(RGBAPixel(r: 0, g: 0, b: 0)), "#000000")
        XCTAssertEqual(ColorFormatting.hex(RGBAPixel(r: 255, g: 255, b: 255, a: 10)), "#FFFFFF")
        XCTAssertEqual(ColorFormatting.hex(RGBAPixel(r: 0x0A, g: 0xB1, b: 0xC2)), "#0AB1C2")
    }

    func testLuminanceTreatsWhiteAsLightAndBlackAsDark() {
        XCTAssertTrue(ColorFormatting.isLight(RGBAPixel(r: 255, g: 255, b: 255)))
        XCTAssertFalse(ColorFormatting.isLight(RGBAPixel(r: 0, g: 0, b: 0)))
    }

    func testBitmapReadsBGRAWithRowPadding() {
        var bytes = [UInt8](repeating: 0, count: 16)
        // Row stride is 8. Pixel (1, 0) is green in BGRA. Pixel (0, 1) is red.
        bytes[4] = 0
        bytes[5] = 255
        bytes[6] = 0
        bytes[7] = 255
        bytes[8] = 0
        bytes[9] = 0
        bytes[10] = 255
        bytes[11] = 255
        let buffer = BitmapBuffer(
            width: 2, height: 2, bytesPerRow: 8,
            order: .bgra, premultipliedAlpha: false, bytes: bytes
        )
        XCTAssertEqual(buffer.pixel(x: 1, y: 0), RGBAPixel(r: 0, g: 255, b: 0))
        XCTAssertEqual(buffer.pixel(x: 0, y: 1), RGBAPixel(r: 255, g: 0, b: 0))
        XCTAssertNil(buffer.pixel(x: 2, y: 0))
    }

    func testPremultipliedChannelIsExpanded() {
        let buffer = BitmapBuffer(
            width: 1, height: 1, bytesPerRow: 4,
            order: .rgba, premultipliedAlpha: true,
            bytes: [128, 0, 0, 128]
        )
        XCTAssertEqual(buffer.pixel(x: 0, y: 0)?.r, 255)
        XCTAssertEqual(buffer.pixel(x: 0, y: 0)?.a, 128)
    }
}
