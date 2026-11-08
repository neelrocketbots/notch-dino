import NotchKit
import RunnerCore
import Testing
@testable import NotchDinoApp

@Test func foldedOpensOnClickOrHotKey() {
    #expect(IslandLogic.reduce(isOpen: false, phase: .idle, event: .clickNotch) == (true, [.open]))
    #expect(IslandLogic.reduce(isOpen: false, phase: .paused, event: .hotKey) == (true, [.open]))
}

@Test func foldedIgnoresGameInput() {
    for e in [IslandEvent.flapKey, .clickField, .escape, .lostKey, .autoPause] {
        #expect(IslandLogic.reduce(isOpen: false, phase: .running, event: e) == (false, []))
    }
}

@Test func openFoldsAndPauses() {
    for e in [IslandEvent.hotKey, .escape, .lostKey, .autoPause] {
        #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: e) == (false, [.pauseGame, .fold]))
    }
    #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: .clickNotch) == (true, []))
}

@Test func flapOrRetry() {
    #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: .flapKey) == (true, [.flap]))
    #expect(IslandLogic.reduce(isOpen: true, phase: .idle, event: .clickField) == (true, [.flap]))
    #expect(IslandLogic.reduce(isOpen: true, phase: .crashed, event: .flapKey) == (true, [.newGameAndFlap]))
}

@Test func resizeOnlyWhenIdleOrPaused() {
    #expect(IslandLogic.resizeAllowed(.idle) && IslandLogic.resizeAllowed(.paused))
    #expect(!IslandLogic.resizeAllowed(.running) && !IslandLogic.resizeAllowed(.crashed))
}

@Test func keysPassThroughWhenFolded() {
    for code: UInt16 in [49, 126, 53, 12] {
        #expect(KeyRouter.action(keyCode: code, command: code == 12, isOpen: false) == nil)
    }
}

@Test func keysWhenOpen() {
    #expect(KeyRouter.action(keyCode: 49, command: false, isOpen: true) == .island(.flapKey))
    #expect(KeyRouter.action(keyCode: 126, command: false, isOpen: true) == .island(.flapKey))
    #expect(KeyRouter.action(keyCode: 53, command: false, isOpen: true) == .island(.escape))
    #expect(KeyRouter.action(keyCode: 12, command: true, isOpen: true) == .quit)
    #expect(KeyRouter.action(keyCode: 12, command: false, isOpen: true) == nil)
    #expect(KeyRouter.action(keyCode: 0, command: false, isOpen: true) == nil)
}

@Test func displayPickerPrefersBuiltInNotch() {
    let ext = NotchDisplay(id: 2, x: 0, y: 0, width: 2560, height: 1440, notch: nil, isMain: true)
    let mbp = NotchDisplay(id: 1, x: 2560, y: 0, width: 1512, height: 982, notch: Notch(width: 185, height: 32),
                           isMain: false, isBuiltIn: true)
    #expect(DisplayPicker.pick([ext, mbp])?.id == 1)
    #expect(DisplayPicker.pick([ext])?.id == 2)
    let other = NotchDisplay(id: 3, x: 0, y: 0, width: 1920, height: 1080, notch: nil, isMain: false)
    #expect(DisplayPicker.pick([other])?.id == 3)
    #expect(DisplayPicker.pick([]) == nil)
}
