import AppKit

/// Chinese settings window. Switches are the same preferences as the menu.
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesController
    private let scrollToggle = NSButton(checkboxWithTitle: ChineseCopy.reverseWheel, target: nil, action: nil)
    private let horizontalToggle = NSButton(checkboxWithTitle: ChineseCopy.reverseHorizontal, target: nil, action: nil)
    private let eyedropperToggle = NSButton(checkboxWithTitle: ChineseCopy.eyedropperToggle, target: nil, action: nil)
    private let loginToggle = NSButton(checkboxWithTitle: ChineseCopy.launchAtLogin, target: nil, action: nil)
    var onChanged: (() -> Void)?

    init(preferences: PreferencesController) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = ChineseCopy.settings.replacingOccurrences(of: "…", with: "")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show() {
        refresh()
        window?.center()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh() {
        guard window?.contentView != nil else { return }
        let values = preferences.preferences
        scrollToggle.state = values.scrollFlipEnabled ? .on : .off
        horizontalToggle.state = values.reverseHorizontalScroll ? .on : .off
        horizontalToggle.isEnabled = values.scrollFlipEnabled
        eyedropperToggle.state = values.eyedropperEnabled ? .on : .off
        switch LoginItemController.status {
        case .enabled:
            loginToggle.state = .on
        case .requiresApproval:
            loginToggle.state = .mixed
        default:
            loginToggle.state = .off
        }
    }

    private func build() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollToggle.target = self
        scrollToggle.action = #selector(toggleScroll)
        horizontalToggle.target = self
        horizontalToggle.action = #selector(toggleHorizontal)
        eyedropperToggle.target = self
        eyedropperToggle.action = #selector(toggleEyedropper)
        loginToggle.target = self
        loginToggle.action = #selector(toggleLogin)

        stack.addArrangedSubview(heading("鼠标滚轮"))
        stack.addArrangedSubview(scrollToggle)
        stack.addArrangedSubview(horizontalToggle)
        stack.addArrangedSubview(body(ChineseCopy.scrollHelp))
        stack.addArrangedSubview(button(ChineseCopy.openAccessibility, action: #selector(openAccessibility)))

        stack.addArrangedSubview(heading("屏幕取色"))
        stack.addArrangedSubview(eyedropperToggle)
        stack.addArrangedSubview(body(ChineseCopy.settingsPickHelp))
        stack.addArrangedSubview(button(ChineseCopy.openScreenRecording, action: #selector(openScreen)))
        stack.addArrangedSubview(button(ChineseCopy.openAccessibility, action: #selector(openAccessibility)))

        stack.addArrangedSubview(heading("通用"))
        stack.addArrangedSubview(loginToggle)
        stack.addArrangedSubview(body(ChineseCopy.loginApproval))
        stack.addArrangedSubview(body(ChineseCopy.settingsFooter))
        stack.addArrangedSubview(body("\(ChineseCopy.appName)  \(ChineseCopy.versionLine(AppInfo.version))"))

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -18)
        ])

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.documentView = document
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
    }

    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func body(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 420
        return label
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func toggleScroll() {
        preferences.update { $0.scrollFlipEnabled = scrollToggle.state == .on }
        onChanged?()
    }

    @objc private func toggleHorizontal() {
        preferences.update { $0.reverseHorizontalScroll = horizontalToggle.state == .on }
        onChanged?()
    }

    @objc private func toggleEyedropper() {
        preferences.update { $0.eyedropperEnabled = eyedropperToggle.state == .on }
        onChanged?()
    }

    @objc private func toggleLogin() {
        let enable = loginToggle.state == .on
        if let message = LoginItemController.setEnabled(enable) {
            let alert = NSAlert()
            alert.messageText = ChineseCopy.appName
            alert.informativeText = message
            alert.runModal()
        } else if enable, LoginItemController.status == .requiresApproval {
            LoginItemController.openSettings()
        }
        refresh()
    }

    @objc private func openAccessibility() {
        AccessibilityPermission.prompt()
        AccessibilityPermission.openSettings()
    }

    @objc private func openScreen() {
        ScreenRecordingPermission.openSettings()
    }
}
