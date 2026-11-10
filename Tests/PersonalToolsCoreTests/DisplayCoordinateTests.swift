import XCTest
@testable import PersonalToolsCore

final class DisplayCoordinateTests: XCTestCase {
    // Built-in Retina, plus a 1x display to the right, bottoms aligned.
    // Primary Cocoa frame origin is (0, 0), so its top is y = 982.
    private let builtIn = LogicalDisplay(
        id: 1,
        cocoaFrame: UnitRect(x: 0, y: 0, width: 1512, height: 982),
        pixelWidth: 3024,
        pixelHeight: 1964
    )
    private let external = LogicalDisplay(
        id: 2,
        cocoaFrame: UnitRect(x: 1512, y: 0, width: 1920, height: 1080),
        pixelWidth: 1920,
        pixelHeight: 1080
    )

    private var displays: [LogicalDisplay] { [builtIn, external] }

    private var quartzDisplays: [QuartzDisplay] {
        let primary = DisplayCoordinate.primaryHeight(of: displays)!
        return displays.map { display in
            let origin = display.quartzOrigin(primaryHeight: primary)
            return QuartzDisplay(
                id: display.id,
                frame: QuartzFrame(
                    originX: origin.x,
                    originY: origin.y,
                    width: display.cocoaFrame.width,
                    height: display.cocoaFrame.height
                ),
                pixelWidth: display.pixelWidth,
                pixelHeight: display.pixelHeight
            )
        }
    }

    func testPrimaryHeightIsTheDisplayAtTheCocoaOrigin() {
        XCTAssertEqual(DisplayCoordinate.primaryHeight(of: displays), 982)
    }

    func testRetinaPointMapsToDevicePixelsFromTheTopLeft() {
        let pixel = DisplayCoordinate.pixel(atCocoa: UnitPoint(x: 10, y: 972), displays: displays)
        XCTAssertEqual(pixel, DisplayPixel(displayID: 1, x: 20, y: 20))
    }

    func testPixelBoundaryUsesTheUpperPixel() {
        // 0.5 points down from the top is the first row of the second pixel at 2x.
        let pixel = DisplayCoordinate.pixel(atCocoa: UnitPoint(x: 0, y: 981.5), displays: displays)
        XCTAssertEqual(pixel, DisplayPixel(displayID: 1, x: 0, y: 1))
    }

    func testBottomEdgeClampsToTheLastPixel() {
        let pixel = DisplayCoordinate.pixel(atCocoa: UnitPoint(x: 0, y: 0), displays: displays)
        XCTAssertEqual(pixel, DisplayPixel(displayID: 1, x: 0, y: 1963))
    }

    func testLastPixelColumnOfTheRetinaDisplay() {
        let pixel = DisplayCoordinate.pixel(atCocoa: UnitPoint(x: 1511.9, y: 100), displays: displays)
        XCTAssertEqual(pixel?.displayID, 1)
        XCTAssertEqual(pixel?.x, 3023)
    }

    func testSharedEdgeBelongsToTheDisplayOnTheRight() {
        let pixel = DisplayCoordinate.pixel(atCocoa: UnitPoint(x: 1512, y: 100), displays: displays)
        XCTAssertEqual(pixel, DisplayPixel(displayID: 2, x: 0, y: 980))
    }

    func testExternalDisplayKeepsOneToOnePixels() {
        let pixel = DisplayCoordinate.pixel(
            atCocoa: UnitPoint(x: 1512 + 1919.2, y: 0.1),
            displays: displays
        )
        XCTAssertEqual(pixel, DisplayPixel(displayID: 2, x: 1919, y: 1079))
    }

    func testPointOutsideEveryDisplayIsNil() {
        XCTAssertNil(DisplayCoordinate.pixel(atCocoa: UnitPoint(x: -10, y: 10), displays: displays))
    }

    func testQuartzAndCocoaPathsAgreeOnBothDisplays() {
        let samples = [
            UnitPoint(x: 10, y: 972),
            UnitPoint(x: 800, y: 10),
            UnitPoint(x: 1612, y: 50),
            UnitPoint(x: 3000, y: 900)
        ]
        let primary = DisplayCoordinate.primaryHeight(of: displays)!
        for cocoa in samples {
            let fromCocoa = DisplayCoordinate.pixel(atCocoa: cocoa, displays: displays)
            let quartz = DisplayCoordinate.quartzGlobal(fromCocoa: cocoa, primaryHeight: primary)
            let fromQuartz = DisplayCoordinate.pixel(atQuartz: quartz, displays: quartzDisplays)
            XCTAssertEqual(fromCocoa, fromQuartz, "\(cocoa)")
            let roundTrip = DisplayCoordinate.cocoaPoint(fromQuartzGlobal: quartz, primaryHeight: primary)
            XCTAssertEqual(roundTrip.x, cocoa.x, accuracy: 0.0001)
            XCTAssertEqual(roundTrip.y, cocoa.y, accuracy: 0.0001)
        }
    }

    func testExternalDisplaySitsAboveThePrimaryInQuartzSpace() {
        let origin = external.quartzOrigin(primaryHeight: 982)
        XCTAssertEqual(origin.x, 1512)
        XCTAssertEqual(origin.y, -98)
    }

    func testCaptureRectConvertsRetinaPixelsBackToQuartzPoints() {
        let pixels = PixelRect(x: 18, y: 18, width: 5, height: 5)
        let rect = DisplayCoordinate.captureRect(
            pixels: pixels,
            quartzFrame: QuartzFrame(originX: 0, originY: 0, width: 1512, height: 982),
            pixelWidth: 3024,
            pixelHeight: 1964
        )
        XCTAssertEqual(rect?.x ?? -1, 9, accuracy: 0.0001)
        XCTAssertEqual(rect?.y ?? -1, 9, accuracy: 0.0001)
        XCTAssertEqual(rect?.width ?? -1, 2.5, accuracy: 0.0001)
        XCTAssertEqual(rect?.height ?? -1, 2.5, accuracy: 0.0001)
    }

    func testCaptureRectOnTheExternalDisplayUsesItsQuartzOrigin() {
        let pixels = PixelRect(x: 99, y: 1029, width: 3, height: 3)
        let rect = DisplayCoordinate.captureRect(
            pixels: pixels,
            quartzFrame: QuartzFrame(originX: 1512, originY: -98, width: 1920, height: 1080),
            pixelWidth: 1920,
            pixelHeight: 1080
        )
        XCTAssertEqual(rect?.x ?? -1, 1611, accuracy: 0.0001)
        XCTAssertEqual(rect?.y ?? -1, 931, accuracy: 0.0001)
        XCTAssertEqual(rect?.width ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(rect?.height ?? 0, 3, accuracy: 0.0001)
    }

    func testSampleRectClipsAtTheTopLeftAndKeepsTheCursorPixel() {
        let rect = DisplayCoordinate.clippedSampleRect(
            centerX: 0, centerY: 50, radius: 5, pixelWidth: 100, pixelHeight: 100
        )
        XCTAssertEqual(rect, PixelRect(x: 0, y: 45, width: 6, height: 11))
        XCTAssertTrue(rect?.contains(x: 0, y: 50) ?? false)
    }

    func testImageLocationIsOneToOneAndScalesForRetinaCaptures() {
        let captured = PixelRect(x: 99, y: 1029, width: 3, height: 3)
        let pixel = DisplayPixel(displayID: 2, x: 100, y: 1030)
        XCTAssertEqual(
            DisplayCoordinate.imageLocation(displayPixel: pixel, captured: captured, imageWidth: 3, imageHeight: 3),
            ImagePixel(x: 1, y: 1)
        )
        XCTAssertEqual(
            DisplayCoordinate.imageLocation(displayPixel: pixel, captured: captured, imageWidth: 6, imageHeight: 6),
            ImagePixel(x: 2, y: 2)
        )
    }

    func testImageLocationRejectsAPixelOutsideTheCapture() {
        let captured = PixelRect(x: 10, y: 10, width: 4, height: 4)
        let pixel = DisplayPixel(displayID: 1, x: 14, y: 10)
        XCTAssertNil(DisplayCoordinate.imageLocation(
            displayPixel: pixel, captured: captured, imageWidth: 4, imageHeight: 4
        ))
    }

    func testLoupePrefersTheLowerRightAndDoesNotCoverTheCursor() {
        let frame = DisplayCoordinate.loupeFrame(
            cursor: UnitPoint(x: 100, y: 400),
            size: UnitSize(width: 120, height: 150),
            displays: displays,
            gap: 16
        )
        XCTAssertEqual(frame, UnitRect(x: 116, y: 234, width: 120, height: 150))
        XCTAssertFalse(frame?.contains(UnitPoint(x: 100, y: 400)) ?? true)
        XCTAssertTrue(builtIn.cocoaFrame.encloses(frame!))
    }

    func testLoupeFlipsAboveWhenTheCursorIsAtTheBottom() {
        let frame = DisplayCoordinate.loupeFrame(
            cursor: UnitPoint(x: 2, y: 2),
            size: UnitSize(width: 120, height: 150),
            display: builtIn.cocoaFrame,
            gap: 16
        )
        XCTAssertEqual(frame, UnitRect(x: 18, y: 18, width: 120, height: 150))
        XCTAssertFalse(frame.contains(UnitPoint(x: 2, y: 2)))
    }

    func testLoupeClampsInsideATightDisplay() {
        let display = UnitRect(x: 0, y: 0, width: 100, height: 100)
        let frame = DisplayCoordinate.loupeFrame(
            cursor: UnitPoint(x: 50, y: 50),
            size: UnitSize(width: 80, height: 80),
            display: display,
            gap: 16
        )
        XCTAssertTrue(display.encloses(frame))
    }

    func testCursorOnTheLeftDisplayDoesNotUseTheRightDisplay() {
        let frame = DisplayCoordinate.loupeFrame(
            cursor: UnitPoint(x: 20, y: 500),
            size: UnitSize(width: 80, height: 80),
            displays: displays,
            gap: 12
        )
        XCTAssertTrue(builtIn.cocoaFrame.encloses(frame!))
        XCTAssertLessThan(frame!.maxX, external.cocoaFrame.minX)
    }
}
