import CoreGraphics

/// Detects standalone Left and Right Command taps without touching CGEvent.
public struct KeyRemapEngine {
    public enum Input {
        case keyDown
        case keyUp
        case flagsChanged(keyCode: CGKeyCode, flags: UInt64)
        case pointerActivity
    }

    public enum Action: Equatable {
        case none
        case post(CGKeyCode)
    }

    public enum KeyCode {
        public static let rightCommand: CGKeyCode = 54
        public static let leftCommand: CGKeyCode = 55
        public static let leftShift: CGKeyCode = 56
        public static let capsLock: CGKeyCode = 57
        public static let leftOption: CGKeyCode = 58
        public static let leftControl: CGKeyCode = 59
        public static let rightShift: CGKeyCode = 60
        public static let rightOption: CGKeyCode = 61
        public static let rightControl: CGKeyCode = 62
        public static let function: CGKeyCode = 63
        public static let eisu: CGKeyCode = 102
        public static let kana: CGKeyCode = 104
    }

    public enum DeviceMask {
        public static let rightCommand: UInt64 = 0x10
        public static let leftCommand: UInt64 = 0x08
        public static let leftShift: UInt64 = 0x02
        public static let rightShift: UInt64 = 0x04
        public static let leftOption: UInt64 = 0x20
        public static let rightOption: UInt64 = 0x40
        public static let leftControl: UInt64 = 0x01
        public static let rightControl: UInt64 = 0x2000
        public static let function: UInt64 = 0x800000
        public static let capsLock: UInt64 = 0x10000
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

    public private(set) var pendingCommandKeyCode: CGKeyCode?

    public init() {}

    public mutating func handle(_ input: Input) -> Action {
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
