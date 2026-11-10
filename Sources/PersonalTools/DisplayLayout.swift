import AppKit
import CoreGraphics
import PersonalToolsCore

enum DisplayLayout {
    static func logicalDisplays() -> [LogicalDisplay] {
        NSScreen.screens.map { screen in
            let frame = screen.frame
            let id = displayID(of: screen)
            var pixelWidth = Int((frame.width * screen.backingScaleFactor).rounded())
            var pixelHeight = Int((frame.height * screen.backingScaleFactor).rounded())
            if id != 0 {
                let wide = Int(CGDisplayPixelsWide(id))
                let high = Int(CGDisplayPixelsHigh(id))
                if wide > 0 { pixelWidth = wide }
                if high > 0 { pixelHeight = high }
            }
            return LogicalDisplay(
                id: id,
                cocoaFrame: UnitRect(
                    x: frame.origin.x,
                    y: frame.origin.y,
                    width: frame.width,
                    height: frame.height
                ),
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight
            )
        }
    }

    static func quartzDisplays() -> [QuartzDisplay] {
        let logical = logicalDisplays()
        let primary = DisplayCoordinate.primaryHeight(of: logical) ?? 0
        return logical.map { quartzDisplay(for: $0, primaryHeight: primary) }
    }

    static func quartzDisplay(for display: LogicalDisplay, primaryHeight: Double) -> QuartzDisplay {
        if display.id != 0 {
            let bounds = CGDisplayBounds(display.id)
            if bounds.width > 0, bounds.height > 0 {
                return QuartzDisplay(
                    id: display.id,
                    frame: QuartzFrame(
                        originX: bounds.origin.x,
                        originY: bounds.origin.y,
                        width: bounds.width,
                        height: bounds.height
                    ),
                    pixelWidth: display.pixelWidth,
                    pixelHeight: display.pixelHeight
                )
            }
        }
        let origin = display.quartzOrigin(primaryHeight: primaryHeight)
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

    static func cocoaMouseLocation() -> UnitPoint {
        let mouse = NSEvent.mouseLocation
        return UnitPoint(x: mouse.x, y: mouse.y)
    }

    private static func displayID(of screen: NSScreen) -> UInt32 {
        let key = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        let number = screen.deviceDescription[key] as? NSNumber
        return number?.uint32Value ?? 0
    }
}
