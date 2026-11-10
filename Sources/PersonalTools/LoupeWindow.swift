import AppKit
import PersonalToolsCore

/// Magnified pixels, crosshair, and live HEX. The window ignores mouse events
/// so scrolling and clicks fall through; the picker tap handles the selecting click.
/// `sharingType = .none` keeps this window out of the screen capture.
final class LoupePanel {
    let size = UnitSize(width: 176, height: 214)
    private let panel: NSPanel
    private let magnifier = MagnifierView()
    private let swatch = NSView()
    private let hexLabel = NSTextField(labelWithString: "#000000")
    private let hintLabel = NSTextField(labelWithString: ChineseCopy.loupeHint)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.sharingType = NSWindow.SharingType.none
        panel.isReleasedWhenClosed = false
        buildContent()
    }

    func show(frame: UnitRect) {
        panel.setFrame(nsRect(frame), display: true)
        panel.orderFrontRegardless()
    }

    func update(grid: ScreenSampler.Grid) {
        magnifier.rows = grid.rows
        magnifier.cursorColumn = grid.cursorColumn
        magnifier.cursorRow = grid.cursorRow
        magnifier.needsDisplay = true
        let color = grid.color
        hexLabel.stringValue = ColorFormatting.hex(color)
        swatch.layer?.backgroundColor = NSColor(
            srgbRed: CGFloat(color.r) / 255,
            green: CGFloat(color.g) / 255,
            blue: CGFloat(color.b) / 255,
            alpha: 1
        ).cgColor
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func buildContent() {
        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 0.94).cgColor
        background.layer?.cornerRadius = 12
        panel.contentView = background

        magnifier.translatesAutoresizingMaskIntoConstraints = false
        swatch.translatesAutoresizingMaskIntoConstraints = false
        hexLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 4
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.white.withAlphaComponent(0.45).cgColor

        hexLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        hexLabel.textColor = .white
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.72)

        background.addSubview(magnifier)
        background.addSubview(swatch)
        background.addSubview(hexLabel)
        background.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            magnifier.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            magnifier.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            magnifier.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            magnifier.heightAnchor.constraint(equalToConstant: 140),

            swatch.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            swatch.topAnchor.constraint(equalTo: magnifier.bottomAnchor, constant: 10),
            swatch.widthAnchor.constraint(equalToConstant: 18),
            swatch.heightAnchor.constraint(equalToConstant: 18),

            hexLabel.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 8),
            hexLabel.centerYAnchor.constraint(equalTo: swatch.centerYAnchor),

            hintLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            hintLabel.topAnchor.constraint(equalTo: swatch.bottomAnchor, constant: 6)
        ])
    }

    private func nsRect(_ frame: UnitRect) -> NSRect {
        NSRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height)
    }
}

final class MagnifierView: NSView {
    var rows: [[RGBAPixel]] = []
    var cursorColumn = 0
    var cursorRow = 0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let first = rows.first, !first.isEmpty else { return }
        let columns = first.count
        let rowCount = rows.count
        let cell = min(bounds.width / CGFloat(columns), bounds.height / CGFloat(rowCount))
        let originX = (bounds.width - cell * CGFloat(columns)) / 2
        let originY = (bounds.height - cell * CGFloat(rowCount)) / 2
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, pixel) in row.enumerated() {
                let rect = NSRect(
                    x: originX + CGFloat(columnIndex) * cell,
                    y: originY + CGFloat(rowIndex) * cell,
                    width: cell,
                    height: cell
                )
                NSColor(
                    srgbRed: CGFloat(pixel.r) / 255,
                    green: CGFloat(pixel.g) / 255,
                    blue: CGFloat(pixel.b) / 255,
                    alpha: 1
                ).setFill()
                rect.fill()
                if rowIndex == cursorRow && columnIndex == cursorColumn {
                    let light = ColorFormatting.isLight(pixel)
                    let inner = light ? NSColor.black : NSColor.white
                    let outer = light ? NSColor.white : NSColor.black
                    outer.setStroke()
                    let outerPath = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                    outerPath.lineWidth = 1
                    outerPath.stroke()
                    inner.setStroke()
                    let innerPath = NSBezierPath(rect: rect.insetBy(dx: 1.5, dy: 1.5))
                    innerPath.lineWidth = 1
                    innerPath.stroke()
                }
            }
        }
    }
}

/// One-shot confirmation. The timer is invalidated when the HUD hides or the app quits.
final class CopyHUD {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var timer: Timer?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.sharingType = NSWindow.SharingType.none
        panel.isReleasedWhenClosed = false

        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 0.94).cgColor
        background.layer?.cornerRadius = 8
        panel.contentView = background
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])
    }

    func show(_ text: String, frame: UnitRect) {
        label.stringValue = text
        panel.setFrame(
            NSRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height),
            display: true
        )
        panel.orderFrontRegardless()
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.hide()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
    }
}
