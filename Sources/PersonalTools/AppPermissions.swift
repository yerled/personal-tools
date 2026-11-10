import AppKit
import ApplicationServices
import CoreGraphics
import PersonalToolsCore
import ServiceManagement

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt the first time. Later calls only report the current choice.
    static func prompt() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        open([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ])
    }
}

enum ScreenRecordingPermission {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Normal macOS prompt. The system will not show it again after a denial.
    @discardableResult
    static func prompt() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openSettings() {
        open([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ])
    }
}

enum LoginItemController {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func openSettings() {
        open([
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.Users-Groups.extension"
        ])
    }
}

func openSystemSettings(_ candidates: [String]) {
    open(candidates)
}

private func open(_ candidates: [String]) {
    for candidate in candidates {
        guard let url = URL(string: candidate) else { continue }
        if NSWorkspace.shared.open(url) {
            return
        }
    }
}

enum PermissionPrompts {
    private static var didPromptAccessibility = false
    private static var didPromptScreen = false

    /// One system prompt per launch. A denial is explained in Chinese from the menu.
    static func promptIfNeeded(preferences: ToolPreferences) {
        let needsAccessibility = preferences.scrollFlipEnabled || preferences.eyedropperEnabled
        if needsAccessibility, !didPromptAccessibility, !AccessibilityPermission.isTrusted {
            didPromptAccessibility = true
            AccessibilityPermission.prompt()
            return
        }
        if preferences.eyedropperEnabled, !didPromptScreen, !ScreenRecordingPermission.isGranted {
            didPromptScreen = true
            ScreenRecordingPermission.prompt()
        }
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// Keeps the scroll tap out of App Nap while that feature is on, and keeps the
/// loupe responsive while it is visible. Released when neither is needed.
/// This does not prevent the display from sleeping.
final class ResponsivenessAssertion {
    private var token: NSObjectProtocol?

    func setNeeded(_ needed: Bool) {
        if needed {
            guard token == nil else { return }
            token = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
                reason: "Keep scroll inversion and the color loupe responsive"
            )
        } else if let token {
            ProcessInfo.processInfo.endActivity(token)
            self.token = nil
        }
    }
}
