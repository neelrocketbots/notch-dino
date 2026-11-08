import RunnerCore
import Testing
@testable import NotchDinoApp

@Test func hudShowsScoreBestAndChips() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 31)
    s.score = 12
    s.effects.apply(.ember)
    s.effects.apply(.hiccups)
    s.effects.tick(1)   // 3 of 4 s left
    let hud = HUD.make(s)
    #expect(hud.score == 12 && hud.best == 31)
    #expect(hud.chips == [HUD.Chip(pickup: .ember, fraction: 1), HUD.Chip(pickup: .hiccups, fraction: 0.75)])
}

@Test func hudFractionsAreQuantisedSoSwiftUIUpdatesRarely() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    s.effects.apply(.updraft)
    s.effects.tick(0.01)
    #expect(HUD.make(s).chips.first?.fraction == 1)
}
