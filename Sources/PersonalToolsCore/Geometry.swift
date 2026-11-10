import Foundation

/// A point in either Cocoa (y up) or Quartz (y down) space. The caller names the space.
public struct UnitPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct UnitSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Rectangle in the same point space as its origin. Maximum edges are outside the rect,
/// matching `CGRect.contains`.
public struct UnitRect: Equatable, Sendable {
    public var origin: UnitPoint
    public var size: UnitSize

    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = UnitPoint(x: x, y: y)
        size = UnitSize(width: width, height: height)
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var width: Double { size.width }
    public var height: Double { size.height }

    public func contains(_ point: UnitPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    public func encloses(_ other: UnitRect) -> Bool {
        other.minX >= minX && other.minY >= minY && other.maxX <= maxX && other.maxY <= maxY
    }
}

public struct QuartzFrame: Equatable, Sendable {
    public var originX: Double
    public var originY: Double
    public var width: Double
    public var height: Double

    public init(originX: Double, originY: Double, width: Double, height: Double) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }
}

/// One monitor in Cocoa global points. Origin is bottom-left, y increases upward.
public struct LogicalDisplay: Equatable, Sendable {
    public var id: UInt32
    public var cocoaFrame: UnitRect
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(id: UInt32, cocoaFrame: UnitRect, pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.cocoaFrame = cocoaFrame
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Quartz global origin (points, y down) of this display's top-left.
    /// `primaryHeight` is the Cocoa height of the display whose frame origin is (0, 0).
    public func quartzOrigin(primaryHeight: Double) -> UnitPoint {
        UnitPoint(x: cocoaFrame.minX, y: primaryHeight - cocoaFrame.maxY)
    }
}

/// One monitor in Quartz global points. Origin is top-left of the main display, y increases downward.
public struct QuartzDisplay: Equatable, Sendable {
    public var id: UInt32
    public var frame: QuartzFrame
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(id: UInt32, frame: QuartzFrame, pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.frame = frame
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct DisplayPixel: Equatable, Sendable {
    public var displayID: UInt32
    /// Device pixel, 0 at the left edge of that display.
    public var x: Int
    /// Device pixel, 0 at the top edge of that display.
    public var y: Int

    public init(displayID: UInt32, x: Int, y: Int) {
        self.displayID = displayID
        self.x = x
        self.y = y
    }
}

public struct PixelRect: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(x pixelX: Int, y pixelY: Int) -> Bool {
        pixelX >= x && pixelY >= y && pixelX < x + width && pixelY < y + height
    }
}

public struct CaptureRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ImagePixel: Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}
