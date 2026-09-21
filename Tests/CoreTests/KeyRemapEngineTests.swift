import Testing
@testable import CommandInputCore

@Suite("KeyRemapEngine")
struct KeyRemapEngineTests {

    @Test("Left Command tap posts Eisu")
    func leftCommandAlone() {
        var engine = KeyRemapEngine()
        #expect(
            engine.handle(
                .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.leftCommand)
            ) == .none
        )
        #expect(
            engine.handle(.flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: 0))
                == .post(KeyRemapEngine.KeyCode.eisu)
        )
    }

    @Test("Right Command tap posts Kana")
    func rightCommandAlone() {
        var engine = KeyRemapEngine()
        #expect(
            engine.handle(
                .flagsChanged(
                    keyCode: KeyRemapEngine.KeyCode.rightCommand,
                    flags: KeyRemapEngine.DeviceMask.rightCommand
                )
            ) == .none
        )
        #expect(
            engine.handle(.flagsChanged(keyCode: KeyRemapEngine.KeyCode.rightCommand, flags: 0))
                == .post(KeyRemapEngine.KeyCode.kana)
        )
    }

    @Test("Command-A cancels the pending switch")
    func commandShortcut() {
        var engine = KeyRemapEngine()
        _ = engine.handle(
            .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.leftCommand)
        )
        #expect(engine.handle(.keyDown) == .none)
        #expect(engine.pendingCommandKeyCode == nil)
        #expect(
            engine.handle(.flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: 0)) == .none
        )
    }

    @Test("Shift-Command does not switch")
    func shiftCommand() {
        var engine = KeyRemapEngine()
        let both = KeyRemapEngine.DeviceMask.leftShift | KeyRemapEngine.DeviceMask.leftCommand
        _ = engine.handle(
            .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftShift, flags: KeyRemapEngine.DeviceMask.leftShift)
        )
        #expect(
            engine.handle(
                .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: both)
            ) == .none
        )
        #expect(engine.pendingCommandKeyCode == nil)
        #expect(
            engine.handle(
                .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.leftShift)
            ) == .none
        )
    }

    @Test("Latched Caps Lock still allows a Command tap")
    func capsLockDoesNotBlock() {
        var engine = KeyRemapEngine()
        let flags = KeyRemapEngine.DeviceMask.leftCommand | KeyRemapEngine.DeviceMask.capsLock
        _ = engine.handle(
            .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: flags)
        )
        #expect(
            engine.handle(
                .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.capsLock)
            ) == .post(KeyRemapEngine.KeyCode.eisu)
        )
    }

    @Test("A down, Command tap, A up does not switch")
    func heldLetterThenCommandDoesNotPost() {
        var engine = KeyRemapEngine()
        #expect(engine.handle(.keyDown) == .none)
        _ = engine.handle(
            .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.leftCommand)
        )
        #expect(engine.handle(.keyUp) == .none)
        #expect(engine.pendingCommandKeyCode == nil)
        #expect(
            engine.handle(.flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: 0)) == .none
        )
    }

    @Test("Pointer activity cancels a pending switch")
    func pointerActivityClearsPending() {
        var engine = KeyRemapEngine()
        _ = engine.handle(
            .flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: KeyRemapEngine.DeviceMask.leftCommand)
        )
        #expect(engine.handle(.pointerActivity) == .none)
        #expect(engine.pendingCommandKeyCode == nil)
        #expect(
            engine.handle(.flagsChanged(keyCode: KeyRemapEngine.KeyCode.leftCommand, flags: 0)) == .none
        )
    }
}
