import Foundation

public struct RGBAPixel: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

public enum PixelByteOrder: Equatable, Sendable {
    case rgba
    case bgra
}

/// Tight or padded 8-bit bitmap. Row 0 is the top of the image.
public struct BitmapBuffer: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var bytesPerRow: Int
    public var order: PixelByteOrder
    public var premultipliedAlpha: Bool
    public var bytes: [UInt8]

    public init(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        order: PixelByteOrder,
        premultipliedAlpha: Bool,
        bytes: [UInt8]
    ) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.order = order
        self.premultipliedAlpha = premultipliedAlpha
        self.bytes = bytes
    }

    public func pixel(x: Int, y: Int) -> RGBAPixel? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let offset = y * bytesPerRow + x * 4
        guard offset >= 0, offset + 3 < bytes.count else { return nil }
        let b0 = bytes[offset]
        let b1 = bytes[offset + 1]
        let b2 = bytes[offset + 2]
        let b3 = bytes[offset + 3]
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
        switch order {
        case .rgba:
            (r, g, b, a) = (b0, b1, b2, b3)
        case .bgra:
            (r, g, b, a) = (b2, b1, b0, b3)
        }
        if premultipliedAlpha, a > 0, a < 255 {
            return RGBAPixel(
                r: Self.unpremultiply(r, alpha: a),
                g: Self.unpremultiply(g, alpha: a),
                b: Self.unpremultiply(b, alpha: a),
                a: a
            )
        }
        return RGBAPixel(r: r, g: g, b: b, a: a)
    }

    private static func unpremultiply(_ channel: UInt8, alpha: UInt8) -> UInt8 {
        let value = (Int(channel) * 255 + Int(alpha) / 2) / Int(alpha)
        return UInt8(min(255, max(0, value)))
    }
}

public enum ColorFormatting {
    /// Clipboard text. Uppercase `#RRGGBB`, alpha omitted. Screen pixels are opaque.
    public static func hex(_ pixel: RGBAPixel) -> String {
        String(format: "#%02X%02X%02X", pixel.r, pixel.g, pixel.b)
    }

    /// Rec. 709 luma in 0...255. The loupe uses it to pick a contrasting crosshair.
    public static func luminance(_ pixel: RGBAPixel) -> Double {
        0.2126 * Double(pixel.r) + 0.7152 * Double(pixel.g) + 0.0722 * Double(pixel.b)
    }

    public static func isLight(_ pixel: RGBAPixel) -> Bool {
        luminance(pixel) >= 160
    }
}
