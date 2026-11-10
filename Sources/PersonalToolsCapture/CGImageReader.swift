import CoreGraphics
import PersonalToolsCore

/// Copies a `CGImage` into a top-left BGRA buffer.
///
/// Screen captures stay in this module so the portable core does not import CoreGraphics.
/// `PersonalToolsMacTests` checks that the top row of a context stays the top row here.
public enum CGImageReader {
    public static func bitmap(from image: CGImage) -> BitmapBuffer? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let drew = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            guard let context = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: info
            ) else {
                return false
            }
            context.interpolationQuality = .none
            context.setAllowsAntialiasing(false)
            context.setShouldAntialias(false)
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        // On macOS 26 the draw above still leaves the source's bottom row at index 0.
        // Swap so row 0 is the top. PersonalToolsMacTests locks that contract.
        var topFirst = [UInt8](repeating: 0, count: bytes.count)
        for row in 0..<height {
            let source = (height - 1 - row) * bytesPerRow
            let destination = row * bytesPerRow
            topFirst.replaceSubrange(
                destination..<(destination + bytesPerRow),
                with: bytes[source..<(source + bytesPerRow)]
            )
        }
        return BitmapBuffer(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            order: .bgra,
            premultipliedAlpha: true,
            bytes: topFirst
        )
    }
}
