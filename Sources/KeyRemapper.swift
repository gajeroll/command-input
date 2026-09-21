import Cocoa

/// Converts single Left/Right Command key presses into Eisu/Kana key events.
///
/// The event tap is installed on the main run loop, so this type is isolated to
/// the main actor.
@MainActor
final class KeyRemapper {
    private enum KeyCode {
        static let rightCommand: CGKeyCode = 54
        static let leftCommand: CGKeyCode = 55
        static let leftShift: CGKeyCode = 56
        static let capsLock: CGKeyCode = 57
        static let leftOption: CGKeyCode = 58
        static let leftControl: CGKeyCode = 59
        static let rightShift: CGKeyCode = 60
        static let rightOption: CGKeyCode = 61
        static let rightControl: CGKeyCode = 62
        static let function: CGKeyCode = 63
        static let eisu: CGKeyCode = 102
        static let kana: CGKeyCode = 104
    }

    private enum DeviceMask {
        static let rightCommand: UInt64 = 0x10
        static let leftCommand: UInt64 = 0x08
        static let leftShift: UInt64 = 0x02
        static let rightShift: UInt64 = 0x04
        static let leftOption: UInt64 = 0x20
        static let rightOption: UInt64 = 0x40
        static let leftControl: UInt64 = 0x01
        static let rightControl: UInt64 = 0x2000
        static let function: UInt64 = 0x800000
        static let capsLock: UInt64 = 0x10000
    }

    // Modifier keyCode -> device-dependent flag bit.
    // The side-specific bits let us distinguish Left Command from Right Command.
    private let modifierMasks: [CGKeyCode: UInt64] = [
        KeyCode.rightCommand: DeviceMask.rightCommand,
        KeyCode.leftCommand: DeviceMask.leftCommand,
        KeyCode.leftShift: DeviceMask.leftShift,
        KeyCode.rightShift: DeviceMask.rightShift,
        KeyCode.leftOption: DeviceMask.leftOption,
        KeyCode.rightOption: DeviceMask.rightOption,
        KeyCode.leftControl: DeviceMask.leftControl,
        KeyCode.rightControl: DeviceMask.rightControl,
        KeyCode.function: DeviceMask.function,
        KeyCode.capsLock: DeviceMask.capsLock,
    ]

    // Caps Lock is excluded so a latched Caps Lock state does not inhibit
    // standalone Command switching.
    private let disqualifyingModifierMask: UInt64 =
        DeviceMask.rightCommand
        | DeviceMask.leftCommand
        | DeviceMask.leftShift
        | DeviceMask.rightShift
        | DeviceMask.leftOption
        | DeviceMask.rightOption
        | DeviceMask.leftControl
        | DeviceMask.rightControl
        | DeviceMask.function

    private let commandOutputKeys: [CGKeyCode: CGKeyCode] = [
        KeyCode.leftCommand: KeyCode.eisu,
        KeyCode.rightCommand: KeyCode.kana,
    ]

    private var pendingCommandKeyCode: CGKeyCode?
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
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
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
            pendingCommandKeyCode = nil

        case .flagsChanged:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            guard let changedModifierMask = modifierMasks[keyCode] else {
                pendingCommandKeyCode = nil
                return
            }
            let flags = event.flags.rawValue
            let isDown = (flags & changedModifierMask) != 0

            if isDown {
                if commandOutputKeys[keyCode] != nil,
                   activeDisqualifyingModifiers(in: flags) == changedModifierMask {
                    pendingCommandKeyCode = keyCode
                } else {
                    pendingCommandKeyCode = nil
                }
            } else {
                if pendingCommandKeyCode == keyCode,
                   let output = commandOutputKeys[keyCode],
                   activeDisqualifyingModifiers(in: flags) == 0 {
                    postKey(output)
                }
                pendingCommandKeyCode = nil
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

    private func activeDisqualifyingModifiers(in flags: UInt64) -> UInt64 {
        flags & disqualifyingModifierMask
    }

    private func setupMouseMonitor() {
        let mouseEvents: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
        ]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pendingCommandKeyCode = nil
            }
        }
    }
}
