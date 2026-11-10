import Foundation

/// Menu, settings, and permission text. The in-app UI is Chinese.
enum ChineseCopy {
    static let appName = "个人工具"
    static let versionPrefix = "版本"
    static let scrollSection = "鼠标滚轮"
    static let reverseWheel = "反转鼠标滚轮"
    static let reverseHorizontal = "同时反转水平滚动"
    static let scrollRunning = "鼠标滚轮已反转"
    static let scrollPaused = "滚轮反转已暂停"
    static let scrollNeedsAccessibility = "需要辅助功能权限才能反转滚轮"
    static let scrollStarting = "正在启动滚轮反转…"
    static let openAccessibility = "打开辅助功能设置…"
    static let otherScrollApp = "「Mouse Scroll Flip」也在运行。两份同时运行会把滚轮翻转两次，方向会回到原来的样子。请退出其中一个。"

    static let eyedropperSection = "屏幕取色"
    static let eyedropperToggle = "启用屏幕取色"
    static let eyedropperReady = "连按两次 Command 取色"
    static let eyedropperPaused = "屏幕取色已暂停"
    static let eyedropperNeedsScreen = "需要屏幕录制权限才能取色"
    static let eyedropperNeedsAccessibility = "需要辅助功能权限才能识别 Command 连按"
    static let eyedropperInspecting = "正在取色…"
    static let openScreenRecording = "打开屏幕录制设置…"
    static let howToPick = "取色说明…"
    static let loupeHint = "点击复制，Esc 取消"
    static let copiedPrefix = "已复制"

    static let launchAtLogin = "登录时启动"
    static let launchNeedsApproval = "登录时启动（需要允许）"
    static let settings = "设置…"
    static let quit = "退出"
    static let ok = "好"
    static let openSystemSettings = "打开系统设置"

    static let pickInstructions = """
    快速连按两次 Command 键：每次都要按下再松开。

    放大镜会跟随指针。格子是周围的像素，准星是当前这一点，旁边是实时颜色。
    点击鼠标左键，把 HEX（例如 #1A2B3C）复制到剪贴板。按 Esc 取消。

    下面这些不会触发取色：
    · 按住 Command 不放
    · Command 和其他键一起按，例如 Command-C、Command-Tab、Command-Shift
    · 只按一次 Command

    平时的快捷键和滚轮不会被拦截。只有放大镜出现时，才会用掉这一下左键和 Esc。
    触控板滚动不会被改成取色，也不会被滚轮反转功能改方向。
    """

    static let accessibilityHelp = """
    「个人工具」需要辅助功能权限，用来做两件事：

    1. 反转普通鼠标的滚轮齿格。触控板和妙控鼠标保持系统原来的自然滚动。
    2. 识别 Command 键的两次点按。按住不放、或和别的键一起按，都不会被当成取色。

    请在系统弹出的提示里选择允许。如果之前点过不允许，macOS 不会反复弹窗。请打开「系统设置 → 隐私与安全性 → 辅助功能」，打开「个人工具」。

    允许之后不用注销。如果菜单仍然提示缺少权限，再退出应用重新打开。
    """

    static let screenRecordingHelp = """
    取色要读取指针下面的像素，所以需要屏幕录制权限。

    颜色只在这台 Mac 上计算，并在你点击时复制到剪贴板。应用不联网，也没有账号。

    请在系统弹出的提示里选择允许。如果之前拒绝过，macOS 不会再次弹出，请打开「系统设置 → 隐私与安全性 → 屏幕录制」，打开「个人工具」。

    改完这项权限后，如果取色仍然是空的，退出应用再打开一次。
    """

    static let captureFailed = """
    没有读到屏幕像素。请确认「系统设置 → 隐私与安全性 → 屏幕录制」里已经打开「个人工具」，然后退出应用再打开。
    """

    static let pickerTapFailed = """
    取色放大镜需要辅助功能权限才能接收点击和 Esc。请在「系统设置 → 隐私与安全性 → 辅助功能」中允许「个人工具」。
    """

    static let loginApproval = """
    请在「系统设置 → 通用 → 登录项与扩展」中允许「个人工具」。

    请把应用留在「应用程序」文件夹。之后再移动，登录项会失效。
    """

    static let settingsPickHelp = "连按两次 Command（按下并松开）打开放大镜。准星是当前像素，旁边是实时颜色。点击复制 HEX，Esc 取消。按住 Command，或和 C、Tab 等键一起按，不会触发。"

    static let scrollHelp = """
    请让系统「自然滚动」保持打开。本功能只反转离散的鼠标滚轮齿格。

    触控板、妙控鼠标，以及被罗技 Options 等驱动标成连续滚动的滚轮，都保持原样。要反转这类鼠标，请先在厂商软件里关掉平滑滚动。

    按住 Shift 时，系统会先把垂直滚轮转成水平滚动。这种横向事件跟着「同时反转水平滚动」那个开关走。
    """

    static let settingsFooter = """
    滚轮反转来自 mouse-scroll-flip（MIT，yerled）。
    需要 macOS 13 或更高版本。此安装包是临时签名（ad-hoc），没有 Apple 公证。
    """

    static func versionLine(_ version: String) -> String {
        "\(versionPrefix) \(version)"
    }

    static func copied(_ hex: String) -> String {
        "\(copiedPrefix) \(hex)"
    }
}
