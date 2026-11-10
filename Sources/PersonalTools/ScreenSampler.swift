import CoreGraphics
import PersonalToolsCapture
import PersonalToolsCore

/// Reads a small block of device pixels around one point.
///
/// The capture rect is in Quartz points. `bestResolution` asks for device pixels
/// on Retina displays. One loupe cell is one device pixel; a 2x image is sampled
/// at the top-left of each device pixel so the grid is not a blur.
enum ScreenSampler {
    struct Grid {
        var rows: [[RGBAPixel]]
        var cursorColumn: Int
        var cursorRow: Int
        var color: RGBAPixel
    }

    static func sample(pixel: DisplayPixel, display: QuartzDisplay, radius: Int = 5) -> Grid? {
        guard let sample = DisplayCoordinate.clippedSampleRect(
            centerX: pixel.x,
            centerY: pixel.y,
            radius: radius,
            pixelWidth: display.pixelWidth,
            pixelHeight: display.pixelHeight
        ) else {
            return nil
        }
        guard let capture = DisplayCoordinate.captureRect(
            pixels: sample,
            quartzFrame: display.frame,
            pixelWidth: display.pixelWidth,
            pixelHeight: display.pixelHeight
        ) else {
            return nil
        }
        let rect = CGRect(x: capture.x, y: capture.y, width: capture.width, height: capture.height)
        guard let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            return nil
        }
        guard image.width > 0, image.height > 0, let buffer = CGImageReader.bitmap(from: image) else {
            return nil
        }
        let scaleX = max(1, buffer.width / sample.width)
        let scaleY = max(1, buffer.height / sample.height)
        var rows: [[RGBAPixel]] = []
        rows.reserveCapacity(sample.height)
        for row in 0..<sample.height {
            var line: [RGBAPixel] = []
            line.reserveCapacity(sample.width)
            for column in 0..<sample.width {
                let imageX = min(buffer.width - 1, column * scaleX)
                let imageY = min(buffer.height - 1, row * scaleY)
                line.append(buffer.pixel(x: imageX, y: imageY) ?? RGBAPixel(r: 0, g: 0, b: 0, a: 0))
            }
            rows.append(line)
        }
        let cursorColumn = pixel.x - sample.x
        let cursorRow = pixel.y - sample.y
        guard rows.indices.contains(cursorRow), rows[cursorRow].indices.contains(cursorColumn) else {
            return nil
        }
        return Grid(
            rows: rows,
            cursorColumn: cursorColumn,
            cursorRow: cursorRow,
            color: rows[cursorRow][cursorColumn]
        )
    }
}
