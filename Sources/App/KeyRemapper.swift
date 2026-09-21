import Cocoa

/// Converts single Left/Right Command key presses into Eisu/Kana key events.
///
/// The event tap is installed on the main run loop, so this type is isolated to
/// the main actor.
@MainActor
final class KeyRemapper {
    private var engine = KeyRemapEngine()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mouseMonitor: Any?

    /// Whether the event tap exists and is enabled.
    var isActive: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    /// Installs and enables the event tap. Returns false when macOS denies it,
    /// usually because Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        if let eventTap {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return true
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                // The callback executes on the main run loop. The tap is
                // listen-only, so the return value is ignored; pass the event
                // through for the defaultTap-compatible path anyway.
                if let refcon {
                    let remapper = Unmanaged<KeyRemapper>.fromOpaque(refcon).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        remapper.handle(type: type, event: event)
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setupMouseMonitor()
        NSLog("Command Input: event tap started.")
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        eventTap = nil
        runLoopSource = nil
        mouseMonitor = nil
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

        case .keyDown:
            _ = engine.handle(.keyDown)

        case .keyUp:
            _ = engine.handle(.keyUp)

        case .flagsChanged:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags.rawValue
            if case .post(let output) = engine.handle(.flagsChanged(keyCode: keyCode, flags: flags)) {
                postKey(output)
            }

        default:
            break
        }
    }

    private func postKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = []
        up?.flags = []
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func setupMouseMonitor() {
        let mouseEvents: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
        ]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.engine.handle(.pointerActivity)
            }
        }
    }
}
