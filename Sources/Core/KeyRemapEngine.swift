import CoreGraphics

/// Detects standalone Left and Right Command taps without touching CGEvent.
struct KeyRemapEngine {
    enum Input {
        case keyDown
        case keyUp
        case flagsChanged(keyCode: CGKeyCode, flags: UInt64)
        case pointerActivity
    }

    enum Action: Equatable {
        case none
        case post(CGKeyCode)
    }

    enum KeyCode {
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

    enum DeviceMask {
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

    private(set) var pendingCommandKeyCode: CGKeyCode?

    mutating func handle(_ input: Input) -> Action {
        switch input {
        case .keyDown:
            // keyUp is accepted as input but ignored until the tap mask
            // includes it, matching the current event-tap behavior.
            pendingCommandKeyCode = nil
            return .none

        case .keyUp:
            return .none

        case .pointerActivity:
            pendingCommandKeyCode = nil
            return .none

        case .flagsChanged(let keyCode, let flags):
            guard let changedModifierMask = modifierMasks[keyCode] else {
                pendingCommandKeyCode = nil
                return .none
            }
            let isDown = (flags & changedModifierMask) != 0

            if isDown {
                if commandOutputKeys[keyCode] != nil,
                   activeDisqualifyingModifiers(in: flags) == changedModifierMask {
                    pendingCommandKeyCode = keyCode
                } else {
                    pendingCommandKeyCode = nil
                }
                return .none
            }

            defer { pendingCommandKeyCode = nil }
            if pendingCommandKeyCode == keyCode,
               let output = commandOutputKeys[keyCode],
               activeDisqualifyingModifiers(in: flags) == 0 {
                return .post(output)
            }
            return .none
        }
    }

    private func activeDisqualifyingModifiers(in flags: UInt64) -> UInt64 {
        flags & disqualifyingModifierMask
    }
}
