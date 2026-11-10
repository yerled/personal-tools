import CoreGraphics
import PersonalToolsCore

/// Session event tap used only while the loupe is visible.
///
/// It is installed on the main run loop. The callback records the click or Escape
/// and returns immediately; AppKit work is deferred with `async` so the callback
/// never waits on the main queue. `stop` removes the mach port. Scroll events are
/// not in the mask, and the callback passes every key except Escape.
final class PickerEventTap {
    var onEscape: (() -> Void)?
    var onClick: ((Double, Double) -> Void)?

    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var loupeVisible = false

    var isInstalled: Bool { port != nil }

    func start() -> Bool {
        if port != nil { return true }
        loupeVisible = true
        let mask = CGEventMask(InputTapSpec.eyedropperMask().rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: pickerTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            loupeVisible = false
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            loupeVisible = false
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    /// Idempotent. Safe on the main thread after the callback has returned.
    func stop() {
        loupeVisible = false
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(port)
        self.port = nil
        self.source = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        let keyCode: UInt16? = type == .keyDown
            ? UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            : nil
        let decision = InputTapSpec.eyedropperIntercept(
            type: type.rawValue,
            keyCode: keyCode,
            loupeVisible: loupeVisible
        )
        guard decision == .swallow else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown {
            DispatchQueue.main.async { [weak self] in
                self?.onEscape?()
            }
        } else if type == .leftMouseDown {
            let location = event.location
            DispatchQueue.main.async { [weak self] in
                self?.onClick?(Double(location.x), Double(location.y))
            }
        }
        return nil
    }
}

private let pickerTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<PickerEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
