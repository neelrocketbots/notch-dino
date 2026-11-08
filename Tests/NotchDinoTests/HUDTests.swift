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

@Test func hudShowsTheNewEffectsWithTheirRings() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    s.effects.apply(.ember); s.effects.apply(.feather)
    s.effects.apply(.tiny); s.effects.apply(.rush)
    s.effects.tick(1)   // tiny 4 of 5 s left, rush 3 of 4 s left
    let chips = HUD.make(s).chips
    #expect(chips == [HUD.Chip(pickup: .ember, fraction: 1), HUD.Chip(pickup: .feather, fraction: 1),
                      HUD.Chip(pickup: .tiny, fraction: 0.8), HUD.Chip(pickup: .rush, fraction: 0.75)])
    #expect(chips.map(\.ring) == [nil, nil, .good, .bad])
}

@Test func hudShowsBloatAsAPowerDown() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    s.effects.apply(.bloat)
    let chips = HUD.make(s).chips
    #expect(chips == [HUD.Chip(pickup: .bloat, fraction: 1)] && chips[0].ring == .bad)
}

@Test func hudDropsAChipWhenItsEffectEnds() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    s.effects.apply(.feather); s.effects.apply(.tiny)
    s.effects.feather = false; s.effects.tick(Params.tinyTime)
    #expect(HUD.make(s).chips.isEmpty)
}

@Test func everyEffectAtOnceGivesSevenChipsInAFixedOrder() {
    // Updraft/Stone and Tiny/Bloat cancel, so at most two charges and five timers run together.
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    for p in Pickup.allCases { s.effects.apply(p) }   // the later of each cancelling pair wins: stone scale, bloat
    #expect(HUD.make(s).chips.map(\.pickup) == [.ember, .feather, .stoneScale, .hiccups, .ashCloud, .rush, .bloat])
}
