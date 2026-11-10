import Foundation

/// Converts between Cocoa points, Quartz points, and device pixels.
///
/// Cocoa global points: origin at the bottom-left of the main display, y up.
/// Quartz global points: origin at the top-left of the main display, y down.
/// Device pixels: origin at the top-left of the display that contains the point.
/// Retina scale is `pixelSize / pointSize` for that display, not a global 2x.
public enum DisplayCoordinate {
    public static func primaryHeight(of displays: [LogicalDisplay]) -> Double? {
        if let primary = displays.first(where: { $0.cocoaFrame.minX == 0 && $0.cocoaFrame.minY == 0 }) {
            return primary.cocoaFrame.height
        }
        if let containing = displays.first(where: { $0.cocoaFrame.contains(UnitPoint(x: 0, y: 0)) }) {
            return containing.cocoaFrame.maxY
        }
        return displays.map(\.cocoaFrame.maxY).max()
    }

    public static func display(containing point: UnitPoint, displays: [LogicalDisplay]) -> LogicalDisplay? {
        displays.first { $0.cocoaFrame.contains(point) }
    }

    /// Pixel under a Cocoa point. Returns nil when the point is outside every display.
    /// A point on a shared edge belongs to the display whose minimum edge includes it
    /// (`CGRect.contains` is max-exclusive). The exact minimum edge clamps into the
    /// last pixel instead of landing one past the buffer.
    public static func pixel(atCocoa point: UnitPoint, displays: [LogicalDisplay]) -> DisplayPixel? {
        guard let display = display(containing: point, displays: displays) else { return nil }
        return pixel(localX: point.x - display.cocoaFrame.minX,
                     localYFromTop: display.cocoaFrame.maxY - point.y,
                     display: display)
    }

    public static func pixel(atQuartz point: UnitPoint, displays: [QuartzDisplay]) -> DisplayPixel? {
        guard let display = quartzDisplay(containing: point, displays: displays) else { return nil }
        return pixel(localX: point.x - display.frame.originX,
                     localYFromTop: point.y - display.frame.originY,
                     id: display.id,
                     pointWidth: display.frame.width,
                     pointHeight: display.frame.height,
                     pixelWidth: display.pixelWidth,
                     pixelHeight: display.pixelHeight)
    }

    /// `quartzY = primaryHeight - cocoaY`, and the same function converts back.
    public static func cocoaPoint(fromQuartzGlobal point: UnitPoint, primaryHeight: Double) -> UnitPoint {
        UnitPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func quartzGlobal(fromCocoa point: UnitPoint, primaryHeight: Double) -> UnitPoint {
        UnitPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Capture rectangle in Quartz global points for `CGWindowListCreateImage`.
    public static func captureRect(
        pixels: PixelRect,
        quartzFrame: QuartzFrame,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> CaptureRect? {
        guard pixels.width > 0, pixels.height > 0 else { return nil }
        guard quartzFrame.width > 0, quartzFrame.height > 0 else { return nil }
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let scaleX = Double(pixelWidth) / quartzFrame.width
        let scaleY = Double(pixelHeight) / quartzFrame.height
        guard scaleX > 0, scaleY > 0 else { return nil }
        return CaptureRect(
            x: quartzFrame.originX + Double(pixels.x) / scaleX,
            y: quartzFrame.originY + Double(pixels.y) / scaleY,
            width: Double(pixels.width) / scaleX,
            height: Double(pixels.height) / scaleY
        )
    }

    /// Region around a device pixel, clipped to the display. Never invents pixels past the edge.
    /// The cursor pixel stays inside the rect, so the crosshair may be off-center at the bezel.
    public static func clippedSampleRect(
        centerX: Int,
        centerY: Int,
        radius: Int,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> PixelRect? {
        guard radius >= 0, pixelWidth > 0, pixelHeight > 0 else { return nil }
        guard centerX >= 0, centerY >= 0, centerX < pixelWidth, centerY < pixelHeight else { return nil }
        let x0 = max(0, centerX - radius)
        let y0 = max(0, centerY - radius)
        let x1 = min(pixelWidth, centerX + radius + 1)
        let y1 = min(pixelHeight, centerY + radius + 1)
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Maps a display pixel into a captured image that may be 1x or a Retina multiple of the requested pixel rect.
    public static func imageLocation(
        displayPixel: DisplayPixel,
        captured: PixelRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> ImagePixel? {
        guard captured.width > 0, captured.height > 0, imageWidth > 0, imageHeight > 0 else { return nil }
        guard captured.contains(x: displayPixel.x, y: displayPixel.y) else { return nil }
        let relativeX = displayPixel.x - captured.x
        let relativeY = displayPixel.y - captured.y
        let scaleX = Double(imageWidth) / Double(captured.width)
        let scaleY = Double(imageHeight) / Double(captured.height)
        let x = min(imageWidth - 1, max(0, floored(Double(relativeX) * scaleX)))
        let y = min(imageHeight - 1, max(0, floored(Double(relativeY) * scaleY)))
        return ImagePixel(x: x, y: y)
    }

    /// Places the loupe on the display that contains the cursor, preferring a corner that does not cover it.
    public static func loupeFrame(
        cursor: UnitPoint,
        size: UnitSize,
        displays: [LogicalDisplay],
        gap: Double
    ) -> UnitRect? {
        guard size.width > 0, size.height > 0, gap >= 0 else { return nil }
        guard let display = display(containing: cursor, displays: displays) else { return nil }
        return loupeFrame(cursor: cursor, size: size, display: display.cocoaFrame, gap: gap)
    }

    public static func loupeFrame(
        cursor: UnitPoint,
        size: UnitSize,
        display: UnitRect,
        gap: Double
    ) -> UnitRect {
        let candidates = [
            UnitPoint(x: cursor.x + gap, y: cursor.y - gap - size.height),
            UnitPoint(x: cursor.x - gap - size.width, y: cursor.y - gap - size.height),
            UnitPoint(x: cursor.x + gap, y: cursor.y + gap),
            UnitPoint(x: cursor.x - gap - size.width, y: cursor.y + gap)
        ]
        for origin in candidates {
            let frame = UnitRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
            if display.encloses(frame) {
                return frame
            }
        }
        let maxX = display.maxX - size.width
        let maxY = display.maxY - size.height
        let x = min(max(cursor.x + gap, display.minX), max(display.minX, maxX))
        let y = min(max(cursor.y - gap - size.height, display.minY), max(display.minY, maxY))
        return UnitRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func quartzDisplay(containing point: UnitPoint, displays: [QuartzDisplay]) -> QuartzDisplay? {
        let strict = displays.first { containsQuartz(point, frame: $0.frame, includeMaxEdge: false) }
        if let strict {
            return strict
        }
        return displays.first { containsQuartz(point, frame: $0.frame, includeMaxEdge: true) }
    }

    private static func containsQuartz(_ point: UnitPoint, frame: QuartzFrame, includeMaxEdge: Bool) -> Bool {
        let maxX = frame.originX + frame.width
        let maxY = frame.originY + frame.height
        let insideX = point.x >= frame.originX && (includeMaxEdge ? point.x <= maxX : point.x < maxX)
        let insideY = point.y >= frame.originY && (includeMaxEdge ? point.y <= maxY : point.y < maxY)
        return insideX && insideY
    }

    private static func pixel(localX: Double, localYFromTop: Double, display: LogicalDisplay) -> DisplayPixel? {
        pixel(localX: localX,
              localYFromTop: localYFromTop,
              id: display.id,
              pointWidth: display.cocoaFrame.width,
              pointHeight: display.cocoaFrame.height,
              pixelWidth: display.pixelWidth,
              pixelHeight: display.pixelHeight)
    }

    private static func pixel(
        localX: Double,
        localYFromTop: Double,
        id: UInt32,
        pointWidth: Double,
        pointHeight: Double,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> DisplayPixel? {
        guard pointWidth > 0, pointHeight > 0, pixelWidth > 0, pixelHeight > 0 else { return nil }
        guard localX >= 0, localYFromTop >= 0 else { return nil }
        let scaleX = Double(pixelWidth) / pointWidth
        let scaleY = Double(pixelHeight) / pointHeight
        let px = min(pixelWidth - 1, max(0, floored(localX * scaleX)))
        let py = min(pixelHeight - 1, max(0, floored(localYFromTop * scaleY)))
        return DisplayPixel(displayID: id, x: px, y: py)
    }

    /// Toward -infinity, without importing Darwin. Local coordinates are non-negative.
    private static func floored(_ value: Double) -> Int {
        if value >= 0 {
            return Int(value)
        }
        let truncated = Int(value)
        if Double(truncated) == value {
            return truncated
        }
        return truncated - 1
    }
}
