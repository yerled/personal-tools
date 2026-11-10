import AppKit
import PersonalToolsCore

/// Menu-bar owner. Tools add their own items. One 1 Hz timer runs only while
/// at least one feature is enabled, to notice permission changes. It does not
/// sample the screen.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let preferences = PreferencesController()
    private let scrollTool: ScrollFlipTool
    private let eyedropperTool: EyedropperTool
    private let power = ResponsivenessAssertion()
    private let settings: SettingsWindowController
    private let loginItem = NSMenuItem()
    private var timer: Timer?
    private var displayedSymbol: String?

    override init() {
        scrollTool = ScrollFlipTool(preferences: preferences)
        eyedropperTool = EyedropperTool(preferences: preferences)
        settings = SettingsWindowController(preferences: preferences)
        super.init()
        scrollTool.onActivityChanged = { [weak self] in self?.syncChrome() }
        eyedropperTool.onActivityChanged = { [weak self] in self?.syncChrome() }
        scrollTool.presentAlert = { [weak self] message, action in
            self?.present(message, then: action)
        }
        eyedropperTool.presentAlert = { [weak self] message, action in
            self?.present(message, then: action)
        }
        preferences.onChange = { [weak self] updated in
            self?.apply(updated)
        }
        settings.onChanged = { [weak self] in
            self?.syncChrome()
        }
    }

    func start() {
        buildMenu()
        apply(preferences.preferences)
        PermissionPrompts.promptIfNeeded(preferences: preferences.preferences)
        ensureTimer()
        syncChrome()
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        settings.close()
        scrollTool.shutdown()
        eyedropperTool.shutdown()
        power.setNeeded(false)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: ChineseCopy.appName, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let version = NSMenuItem(title: ChineseCopy.versionLine(AppInfo.version), action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        menu.addItem(.separator())
        scrollTool.install(into: menu)
        menu.addItem(.separator())
        eyedropperTool.install(into: menu)
        menu.addItem(.separator())

        loginItem.target = self
        loginItem.action = #selector(toggleLogin)
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(title: ChineseCopy.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quit = NSMenuItem(
            title: ChineseCopy.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        refreshLoginItem()
    }

    func menuWillOpen(_ menu: NSMenu) {
        scrollTool.refresh()
        eyedropperTool.refresh()
        refreshLoginItem()
        syncChrome()
    }

    private func apply(_ updated: ToolPreferences) {
        scrollTool.apply(preferences: updated)
        eyedropperTool.apply(preferences: updated)
        ensureTimer()
        syncChrome()
    }

    private func ensureTimer() {
        let needed = scrollTool.wantsPeriodicRefresh || eyedropperTool.wantsPeriodicRefresh
        if needed, timer == nil {
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !needed {
            timer?.invalidate()
            timer = nil
        }
    }

    private func tick() {
        PermissionPrompts.promptIfNeeded(preferences: preferences.preferences)
        if scrollTool.wantsPeriodicRefresh {
            scrollTool.periodicRefresh()
        }
        if eyedropperTool.wantsPeriodicRefresh {
            eyedropperTool.periodicRefresh()
        }
        ensureTimer()
        syncChrome()
    }

    private func syncChrome() {
        let active = scrollTool.featureEnabled || eyedropperTool.isInspecting || preferences.preferences.eyedropperEnabled
        power.setNeeded(scrollTool.featureEnabled || eyedropperTool.isInspecting)
        applyIcon(active: active && (AccessibilityPermission.isTrusted || scrollTool.featureEnabled))
        settings.refresh()
    }

    private func applyIcon(active: Bool) {
        let symbol = active ? "eyedropper.halffull" : "eyedropper"
        if displayedSymbol == symbol, statusItem.button?.image != nil {
            return
        }
        displayedSymbol = symbol
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let configured = NSImage(systemSymbolName: symbol, accessibilityDescription: ChineseCopy.appName)?
            .withSymbolConfiguration(configuration)
        let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: ChineseCopy.appName)
        if let image = configured ?? fallback {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.title = ""
        } else {
            statusItem.button?.title = "具"
        }
        statusItem.button?.appearsDisabled = !active
        statusItem.button?.toolTip = ChineseCopy.appName
    }

    private func refreshLoginItem() {
        switch LoginItemController.status {
        case .enabled:
            loginItem.title = ChineseCopy.launchAtLogin
            loginItem.state = .on
        case .requiresApproval:
            loginItem.title = ChineseCopy.launchNeedsApproval
            loginItem.state = .mixed
        default:
            loginItem.title = ChineseCopy.launchAtLogin
            loginItem.state = .off
        }
    }

    @objc private func toggleLogin() {
        switch LoginItemController.status {
        case .requiresApproval:
            present(ChineseCopy.loginApproval) {
                LoginItemController.openSettings()
            }
        case .enabled:
            if let message = LoginItemController.setEnabled(false) {
                present(message, then: nil)
            }
        default:
            if let message = LoginItemController.setEnabled(true) {
                present(message, then: nil)
            } else if LoginItemController.status == .requiresApproval {
                present(ChineseCopy.loginApproval) {
                    LoginItemController.openSettings()
                }
            }
        }
        refreshLoginItem()
    }

    @objc private func openSettings() {
        settings.show()
    }

    private func present(_ message: String, then action: (() -> Void)?) {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.messageText = ChineseCopy.appName
        alert.informativeText = message
        alert.alertStyle = .informational
        if action != nil {
            alert.addButton(withTitle: ChineseCopy.openSystemSettings)
            alert.addButton(withTitle: ChineseCopy.ok)
        } else {
            alert.addButton(withTitle: ChineseCopy.ok)
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action?()
        }
    }
}
