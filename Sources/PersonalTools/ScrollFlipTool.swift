import AppKit
import PersonalToolsCore

/// Menu and lifecycle for the mouse-scroll-flip feature.
///
/// The event tap thread blocks in `CFRunLoopRun`. It is not a polling loop.
/// A one-second timer exists only while this feature or the eyedropper is enabled,
/// so a newly granted Accessibility permission is noticed without a relaunch.
final class ScrollFlipTool: NSObject {
    private let preferencesController: PreferencesController
    private let sectionItem = NSMenuItem()
    private let statusItem = NSMenuItem()
    private let enabledItem = NSMenuItem()
    private let horizontalItem = NSMenuItem()
    private let permissionItem = NSMenuItem()
    private let conflictItem = NSMenuItem()
    private weak var menu: NSMenu?

    var onActivityChanged: (() -> Void)?
    var presentAlert: ((String, (() -> Void)?) -> Void)?

    init(preferences: PreferencesController) {
        preferencesController = preferences
        super.init()
        _ = ScrollEventTap.shared
        sectionItem.title = ChineseCopy.scrollSection
        sectionItem.isEnabled = false
        statusItem.isEnabled = false
        conflictItem.isEnabled = false
        enabledItem.target = self
        enabledItem.action = #selector(toggleEnabled)
        horizontalItem.target = self
        horizontalItem.action = #selector(toggleHorizontal)
        permissionItem.target = self
        permissionItem.action = #selector(openAccessibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tapUnavailable),
            name: .scrollTapUnavailable,
            object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(machineWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(machineWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    var featureEnabled: Bool { preferencesController.preferences.scrollFlipEnabled }

    var wantsPeriodicRefresh: Bool { featureEnabled }

    func install(into menu: NSMenu) {
        self.menu = menu
        menu.addItem(sectionItem)
        menu.addItem(statusItem)
        menu.addItem(enabledItem)
        menu.addItem(horizontalItem)
        refresh()
    }

    func apply(preferences: ToolPreferences) {
        ScrollEventTap.shared.setReverseHorizontal(preferences.reverseHorizontalScroll)
        if preferences.scrollFlipEnabled {
            if !ScrollEventTap.shared.isTapEnabled {
                ScrollEventTap.shared.revive()
            }
        } else {
            ScrollEventTap.shared.stop()
        }
        refresh()
        onActivityChanged?()
    }

    func periodicRefresh() {
        apply(preferences: preferencesController.preferences)
    }

    func refresh() {
        let preferences = preferencesController.preferences
        let trusted = AccessibilityPermission.isTrusted
        let running = ScrollEventTap.shared.isTapEnabled
        enabledItem.title = ChineseCopy.reverseWheel
        enabledItem.state = preferences.scrollFlipEnabled ? .on : .off
        horizontalItem.title = ChineseCopy.reverseHorizontal
        horizontalItem.state = preferences.reverseHorizontalScroll ? .on : .off
        horizontalItem.isEnabled = preferences.scrollFlipEnabled
        permissionItem.title = ChineseCopy.openAccessibility

        if !preferences.scrollFlipEnabled {
            statusItem.title = ChineseCopy.scrollPaused
        } else if running {
            statusItem.title = ChineseCopy.scrollRunning
        } else if !trusted {
            statusItem.title = ChineseCopy.scrollNeedsAccessibility
        } else {
            statusItem.title = ChineseCopy.scrollStarting
        }

        setVisible(permissionItem, visible: preferences.scrollFlipEnabled && !trusted && !running)
        let conflict = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.yerled.mousescrollflip"
        ).isEmpty
        conflictItem.title = ChineseCopy.otherScrollApp
        setVisible(conflictItem, visible: conflict)
    }

    func shutdown() {
        ScrollEventTap.shared.stop()
    }

    @objc private func tapUnavailable() {
        refresh()
        onActivityChanged?()
    }

    /// Sleep can disable the tap. Retry shortly after wake, in addition to the 1 Hz check.
    @objc private func machineWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.periodicRefresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.periodicRefresh()
        }
    }

    @objc private func toggleEnabled() {
        preferencesController.update { $0.scrollFlipEnabled.toggle() }
    }

    @objc private func toggleHorizontal() {
        preferencesController.update { $0.reverseHorizontalScroll.toggle() }
    }

    @objc private func openAccessibility() {
        presentAlert?(ChineseCopy.accessibilityHelp, {
            AccessibilityPermission.prompt()
            AccessibilityPermission.openSettings()
        })
    }

    /// Insert and remove so the menu still works on macOS 13, where `isHidden` is newer.
    private func setVisible(_ item: NSMenuItem, visible: Bool) {
        guard let menu else { return }
        let contains = menu.items.contains(item)
        if visible && !contains {
            let anchor = menu.index(of: horizontalItem)
            let index = anchor >= 0 ? anchor + 1 : menu.items.count
            menu.insertItem(item, at: index)
        } else if !visible && contains {
            menu.removeItem(item)
        }
    }
}
