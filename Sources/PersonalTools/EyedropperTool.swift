import AppKit
import PersonalToolsCore

/// Global eyedropper. Command taps are observed and never swallowed.
/// The 30 Hz sampler and the click/Escape tap exist only while the loupe is visible.
final class EyedropperTool: NSObject {
    private let preferencesController: PreferencesController
    private var session: EyedropperController
    private var detector = CommandDoubleTapDetector()
    private var lease = ExclusiveTapLease()
    private let pickerTap = PickerEventTap()
    private let loupe = LoupePanel()
    private let hud = CopyHUD()

    private let sectionItem = NSMenuItem()
    private let statusItem = NSMenuItem()
    private let enabledItem = NSMenuItem()
    private let screenItem = NSMenuItem()
    private let accessibilityItem = NSMenuItem()
    private let helpItem = NSMenuItem()
    private weak var menu: NSMenu?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var monitorsInstalled = false
    private var sampleTimer: Timer?
    private var lastPixel: DisplayPixel?
    private var failedSamples = 0
    private var lastLoupeFrame: UnitRect

    var onActivityChanged: (() -> Void)?
    var presentAlert: ((String, (() -> Void)?) -> Void)?

    init(preferences: PreferencesController) {
        preferencesController = preferences
        session = EyedropperController(isEnabled: preferences.preferences.eyedropperEnabled)
        lastLoupeFrame = UnitRect(x: 0, y: 0, width: 176, height: 214)
        super.init()
        sectionItem.title = ChineseCopy.eyedropperSection
        sectionItem.isEnabled = false
        statusItem.isEnabled = false
        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        screenItem.target = self
        screenItem.action = #selector(openScreenRecording)
        accessibilityItem.target = self
        accessibilityItem.action = #selector(openAccessibility)
        helpItem.target = self
        helpItem.action = #selector(showHelp)
        helpItem.title = ChineseCopy.howToPick
        screenItem.title = ChineseCopy.openScreenRecording
        accessibilityItem.title = ChineseCopy.openAccessibility
    }

    var isInspecting: Bool { session.phase == .inspecting }

    /// Re-checks permission so a global monitor can be installed after the prompt.
    /// Does not capture the screen.
    var wantsPeriodicRefresh: Bool { preferencesController.preferences.eyedropperEnabled }

    func install(into menu: NSMenu) {
        self.menu = menu
        menu.addItem(sectionItem)
        menu.addItem(statusItem)
        menu.addItem(enabledItem)
        menu.addItem(helpItem)
        refresh()
    }

    func apply(preferences: ToolPreferences) {
        if preferences.eyedropperEnabled != session.isEnabled {
            perform(session.handle(.setEnabled(preferences.eyedropperEnabled)))
        }
        if preferences.eyedropperEnabled {
            ensureMonitors()
        } else {
            removeMonitors()
            detector.reset()
        }
        refresh()
        onActivityChanged?()
    }

    func periodicRefresh() {
        guard preferencesController.preferences.eyedropperEnabled else { return }
        ensureMonitors()
        refresh()
    }

    func refresh() {
        let enabled = preferencesController.preferences.eyedropperEnabled
        let trusted = AccessibilityPermission.isTrusted
        let screen = ScreenRecordingPermission.isGranted
        enabledItem.title = ChineseCopy.eyedropperToggle
        enabledItem.state = enabled ? .on : .off
        if !enabled {
            statusItem.title = ChineseCopy.eyedropperPaused
        } else if isInspecting {
            statusItem.title = ChineseCopy.eyedropperInspecting
        } else if !screen {
            statusItem.title = ChineseCopy.eyedropperNeedsScreen
        } else if !trusted {
            statusItem.title = ChineseCopy.eyedropperNeedsAccessibility
        } else {
            statusItem.title = ChineseCopy.eyedropperReady
        }
        setVisible(screenItem, visible: enabled && !screen)
        setVisible(accessibilityItem, visible: enabled && !trusted)
    }

    func shutdown() {
        if session.phase == .inspecting {
            _ = session.handle(.escape)
        }
        dismiss(hud: nil)
        removeMonitors()
        detector.reset()
    }

    @objc private func toggleEnabled() {
        preferencesController.update { $0.eyedropperEnabled.toggle() }
    }

    @objc private func openScreenRecording() {
        presentAlert?(ChineseCopy.screenRecordingHelp, {
            ScreenRecordingPermission.openSettings()
        })
    }

    @objc private func openAccessibility() {
        presentAlert?(ChineseCopy.accessibilityHelp, {
            AccessibilityPermission.prompt()
            AccessibilityPermission.openSettings()
        })
    }

    @objc private func showHelp() {
        presentAlert?(ChineseCopy.pickInstructions, nil)
    }

    private func ensureMonitors() {
        if monitorsInstalled, globalMonitor == nil, AccessibilityPermission.isTrusted {
            removeMonitors()
        }
        guard !monitorsInstalled else { return }
        monitorsInstalled = true
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.ingest(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.ingest(event)
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        monitorsInstalled = false
    }

    private func ingest(_ event: NSEvent) {
        if event.type == .keyDown,
           event.keyCode == InputTapSpec.escapeKeyCode,
           session.phase == .inspecting {
            perform(session.handle(.escape))
        }
        let modifiers = CocoaModifierRawValue.flags(from: event.modifierFlags.rawValue)
        let pointer: PointerDeviceEvent
        switch event.type {
        case .flagsChanged:
            pointer = .flagsChanged(modifiers, time: event.timestamp)
        case .keyDown:
            pointer = .keyDown(keyCode: event.keyCode, modifiers: modifiers, time: event.timestamp)
        default:
            return
        }
        if detector.receive(pointer) == .recognized {
            perform(session.handle(.doubleCommand))
        }
    }

    private func perform(_ action: EyedropperAction) {
        switch action {
        case .none:
            break
        case .begin:
            beginLoupe()
        case .cancel:
            dismiss(hud: nil)
        case let .copy(hex):
            dismiss(hud: hex)
        }
    }

    private func beginLoupe() {
        guard ScreenRecordingPermission.isGranted else {
            _ = session.handle(.escape)
            presentAlert?(ChineseCopy.screenRecordingHelp, {
                ScreenRecordingPermission.openSettings()
            })
            refresh()
            return
        }
        lease.start()
        guard pickerTap.start() else {
            lease.stop()
            _ = session.handle(.escape)
            presentAlert?(ChineseCopy.pickerTapFailed, {
                AccessibilityPermission.prompt()
                AccessibilityPermission.openSettings()
            })
            refresh()
            return
        }
        failedSamples = 0
        lastPixel = nil
        pickerTap.onEscape = { [weak self] in
            guard let self else { return }
            self.perform(self.session.handle(.escape))
        }
        pickerTap.onClick = { [weak self] x, y in
            self?.select(quartzX: x, quartzY: y)
        }
        startSampleTimer()
        sampleAtCursor()
        refresh()
        onActivityChanged?()
    }

    private func select(quartzX: Double, quartzY: Double) {
        guard session.phase == .inspecting else {
            dismiss(hud: nil)
            return
        }
        let displays = DisplayLayout.quartzDisplays()
        guard let pixel = DisplayCoordinate.pixel(
            atQuartz: UnitPoint(x: quartzX, y: quartzY),
            displays: displays
        ),
            let display = displays.first(where: { $0.id == pixel.displayID }),
            let grid = ScreenSampler.sample(pixel: pixel, display: display) else {
            _ = session.handle(.escape)
            dismiss(hud: nil)
            presentAlert?(ChineseCopy.captureFailed, nil)
            return
        }
        perform(session.handle(.click(grid.color)))
    }

    private func sampleAtCursor() {
        guard session.phase == .inspecting else { return }
        let logical = DisplayLayout.logicalDisplays()
        let cursor = DisplayLayout.cocoaMouseLocation()
        guard let pixel = DisplayCoordinate.pixel(atCocoa: cursor, displays: logical) else {
            noteFailure()
            return
        }
        // Same device pixel: skip the capture. The timer still stops when the loupe closes.
        if pixel == lastPixel { return }
        let primary = DisplayCoordinate.primaryHeight(of: logical) ?? 0
        guard let logicalDisplay = logical.first(where: { $0.id == pixel.displayID }) else {
            noteFailure()
            return
        }
        let quartz = DisplayLayout.quartzDisplay(for: logicalDisplay, primaryHeight: primary)
        guard let grid = ScreenSampler.sample(pixel: pixel, display: quartz) else {
            noteFailure()
            return
        }
        failedSamples = 0
        lastPixel = pixel
        loupe.update(grid: grid)
        if let frame = DisplayCoordinate.loupeFrame(
            cursor: cursor,
            size: loupe.size,
            displays: logical,
            gap: 18
        ) {
            lastLoupeFrame = frame
            loupe.show(frame: frame)
        }
    }

    private func noteFailure() {
        failedSamples += 1
        guard failedSamples >= 15 else { return }
        _ = session.handle(.escape)
        dismiss(hud: nil)
        presentAlert?(ChineseCopy.captureFailed, nil)
    }

    private func startSampleTimer() {
        stopSampleTimer()
        guard let interval = SamplingClock.timerInterval(loupeVisible: true) else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleAtCursor()
        }
        RunLoop.main.add(timer, forMode: .common)
        sampleTimer = timer
    }

    private func stopSampleTimer() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }

    private func dismiss(hud hex: String?) {
        stopSampleTimer()
        loupe.hide()
        pickerTap.stop()
        if lease.isRunning {
            lease.stop()
        }
        lastPixel = nil
        failedSamples = 0
        if let hex {
            let board = NSPasteboard.general
            board.clearContents()
            board.setString(hex, forType: .string)
            let frame = DisplayCoordinate.loupeFrame(
                cursor: DisplayLayout.cocoaMouseLocation(),
                size: UnitSize(width: 180, height: 36),
                displays: DisplayLayout.logicalDisplays(),
                gap: 18
            ) ?? lastLoupeFrame
            hud.show(ChineseCopy.copied(hex), frame: frame)
        } else {
            hud.hide()
        }
        refresh()
        onActivityChanged?()
    }

    private func setVisible(_ item: NSMenuItem, visible: Bool) {
        guard let menu else { return }
        let contains = menu.items.contains(item)
        if visible && !contains {
            let anchor = menu.index(of: enabledItem)
            let index = anchor >= 0 ? anchor + 1 : menu.items.count
            menu.insertItem(item, at: index)
        } else if !visible && contains {
            menu.removeItem(item)
        }
    }
}
