import AppKit

@main
enum PersonalToolsMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // `run` returns only at quit, so this local delegate stays alive.
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if anotherCopyIsRunning() {
            NSApp.terminate(nil)
            return
        }
        menu = StatusMenuController()
        menu?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menu?.shutdown()
        menu = nil
    }

    /// Two copies of this app would each invert the wheel, which cancels out.
    private func anotherCopyIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}
