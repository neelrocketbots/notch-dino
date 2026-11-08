import Foundation
import NotchKit
import RunnerCore
import Testing
@testable import NotchDinoApp

@MainActor private func soloModel() -> IslandModel {
    let d = UserDefaults(suiteName: "notchDino.solo.\(UUID().uuidString)")!
    let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 185, height: 32),
                               isMain: true, isBuiltIn: true, menuBarHeight: 32)
    return IslandModel(display: display, best: BestScoreStore(defaults: d), layout: LayoutStore(defaults: d),
                       looks: LookStore(defaults: d), seed: 1)
}

@Suite struct SoloPauseTests {
    @Test func pKeyIsRoutedOnlyWhileOpen() {
        #expect(KeyRouter.action(keyCode: 35, modifiers: [], isOpen: true) == .island(.pauseKey))
        #expect(KeyRouter.action(keyCode: 35, modifiers: .command, isOpen: true) == nil)
        #expect(KeyRouter.action(keyCode: 35, modifiers: [], isOpen: false) == nil)
    }

    @Test func modifiedPPassesThroughLikeSpace() {
        let combos: [KeyModifiers] = [.control, .option, .command, [.control, .option]]
        for m in combos { #expect(KeyRouter.action(keyCode: 35, modifiers: m, isOpen: true) == nil) }
        #expect(KeyRouter.action(keyCode: 35, modifiers: .shift, isOpen: true) == .island(.pauseKey))
    }

    @Test func pPausesInPlaceAndResumesThroughTheCountdown() {
        #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: .pauseKey) == (true, [.pauseGame]))
        #expect(IslandLogic.reduce(isOpen: true, phase: .paused, event: .pauseKey) == (true, [.flap]))
        for p in [Phase.idle, .crashed, .countdown(remaining: 9)] {
            #expect(IslandLogic.reduce(isOpen: true, phase: p, event: .pauseKey) == (true, []))
        }
        #expect(IslandLogic.reduce(isOpen: false, phase: .running, event: .pauseKey) == (false, []))
    }

    @Test func escDuringTheCountdownPausesAndFolds() {
        #expect(IslandLogic.reduce(isOpen: true, phase: .countdown(remaining: 100), event: .escape) == (false, [.pauseGame, .fold]))
    }

    @Test func hudShowsTheCountdownNumber() {
        var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
        #expect(HUD.make(s).countdown == nil)
        s.phase = .countdown(remaining: 252); #expect(HUD.make(s).countdown == 3)
        s.phase = .countdown(remaining: 100); #expect(HUD.make(s).countdown == 2)
        s.phase = .countdown(remaining: 3); #expect(HUD.make(s).countdown == 1)
        #expect(HUD.empty.countdown == nil)
    }

    @MainActor @Test func modelPausesInPlaceWithoutFolding() {
        let m = soloModel()
        m.handle(.hotKey); m.handle(.flapKey)
        m.game.phase = .running
        m.handle(.pauseKey)
        #expect(m.isOpen && m.game.phase == .paused && m.phase == .paused && !m.scene.isPaused)
        m.handle(.pauseKey)
        #expect(m.isOpen && m.game.phase == .countdown(remaining: Params.countdownSteps))
        #expect(m.hud.countdown == 3)
    }

    @MainActor @Test func reopeningAPausedRunShowsPausedAndSpaceCountsDown() {
        let m = soloModel()
        m.handle(.hotKey); m.handle(.flapKey)
        m.game.phase = .running
        m.handle(.escape)
        #expect(!m.isOpen && m.game.phase == .paused)
        m.handle(.hotKey)
        #expect(m.isOpen && m.phase == .paused)
        m.handle(.flapKey)
        #expect(m.game.phase == .countdown(remaining: Params.countdownSteps))
    }

    @MainActor @Test func theCountdownRunsToPlayInTheModel() {
        let m = soloModel()
        m.handle(.hotKey); m.handle(.flapKey)
        for _ in 0..<130 { _ = m.sceneTick(elapsed: 1.0 / 60) }
        #expect(m.game.phase == .running && m.phase == .running && m.hud.countdown == nil)
    }
}
