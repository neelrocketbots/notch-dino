import Testing
@testable import RunnerCore

private func step(_ s: inout GameState) -> [GameEvent] {
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    return ev
}

@Test func featherBouncesOffTheCeilingOnce() {
    var s = runningGame(); s.effects.apply(.feather)
    s.pipY = Params.pipRadius - 1; s.pipVY = -100
    let ev = step(&s)
    #expect(s.phase == .running && !s.effects.feather && ev.contains(.bounced))
    #expect(abs(s.pipY - (Params.pipRadius + Params.featherInset)) < 1e-9)
    #expect(abs(s.pipVY - (-Params.flapVelocity * Params.featherBounce)) < 1e-9)   // 188, downward
    s.pipY = Params.pipRadius - 1; s.pipVY = -100
    _ = step(&s)
    #expect(s.phase == .crashed)
}

@Test func featherBouncesOffTheGroundOnce() {
    var s = runningGame(); s.effects.apply(.feather)
    s.pipY = Params.ground - Params.pipRadius + 1; s.pipVY = 200
    let ev = step(&s)
    #expect(s.phase == .running && !s.effects.feather && ev.contains(.bounced))
    #expect(abs(s.pipY - (Params.ground - Params.pipRadius - Params.featherInset)) < 1e-9)
    #expect(abs(s.pipVY - Params.flapVelocity * Params.featherBounce) < 1e-9)   // −188, upward
    s.pipY = Params.ground - Params.pipRadius + 1; s.pipVY = 200
    _ = step(&s)
    #expect(s.phase == .crashed)
}

@Test func featherBounceUsesTheScaledRadius() {
    var s = runningGame(); s.effects.apply(.feather); s.effects.apply(.bloat)
    s.pipY = Params.ground - s.pipRadius + 1; s.pipVY = 200
    _ = step(&s)
    #expect(s.phase == .running)
    #expect(abs(s.pipY - (Params.ground - Params.pipRadius * Params.bloatScale - Params.featherInset)) < 1e-9)
}

@Test func twoFeathersThroughTheRunnerGiveOneBounce() {
    var s = runningGame()
    let x = s.world.pipX - Params.gateWidth / 2
    for _ in 0..<2 {
        s.gates = [forkGate(x: x, upper: .feather, lower: nil)]
        s.pipY = s.gates[0].itemY(.upper); s.pipVY = 0
        _ = step(&s)
    }
    #expect(s.effects.feather)
    s.gates = []
    s.pipY = Params.pipRadius - 1; s.pipVY = -100
    _ = step(&s)
    #expect(s.phase == .running)
    s.pipY = Params.pipRadius - 1; s.pipVY = -100
    _ = step(&s)
    #expect(s.phase == .crashed)
}

@Test func featherNeverSavesFromAShard() {
    var s = runningGame(); s.effects.apply(.feather)
    s.gates = [Gate(id: 3, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])]
    s.pipY = 96 + 20 - Params.pipRadius + 1   // into the bottom shard
    let ev = step(&s)
    #expect(s.phase == .crashed && s.effects.feather && !ev.contains(.bounced))
}

@Test func emberAndFeatherBothResolveInOneStep() {
    // A gate whose top shard reaches y 10, and Pip touching both that shard and the ceiling.
    var s = runningGame(); s.effects.apply(.ember); s.effects.apply(.feather)
    s.gates = [Gate(id: 4, x: s.world.pipX - 2, centre: 30, gap: 40, chunk: 0, items: [])]
    s.pipY = Params.pipRadius - 1; s.pipVY = 0
    let ev = step(&s)
    #expect(s.phase == .running)
    #expect(!s.effects.emberCharge && !s.effects.feather)
    #expect(ev.contains(.melted(gateID: 4, part: .top)) && ev.contains(.bounced))
}

@Test func eachChargeIsSpentOnlyWhenNeeded() {
    // Edge only: the feather goes, the ember stays.
    var s = runningGame(); s.effects.apply(.ember); s.effects.apply(.feather)
    s.pipY = Params.ground - Params.pipRadius + 1; s.pipVY = 0
    _ = step(&s)
    #expect(s.phase == .running && s.effects.emberCharge && !s.effects.feather)
    // Shard only: the ember goes, the feather stays.
    var t = runningGame(); t.effects.apply(.ember); t.effects.apply(.feather)
    t.gates = [Gate(id: 5, x: t.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])]
    t.pipY = 96 + 20 - Params.pipRadius + 1; t.pipVY = 0
    _ = step(&t)
    #expect(t.phase == .running && !t.effects.emberCharge && t.effects.feather)
}

@Test func sameSeedSameStateWithTheNewEffects() {
    // The same bot as sameSeedSameInputsSameState, starting with every new effect running.
    func play(_ seed: UInt64) -> (state: GameState, events: [GameEvent]) {
        var s = Runner.newGame(world: World(width: 351), seed: seed, best: 0)
        for p in [Pickup.feather, .tiny, .rush] { s.effects.apply(p) }
        var ev: [GameEvent] = []
        for _ in 0..<3_000 {
            let next = s.gates.first { $0.x + Params.gateWidth > s.world.pipX - s.pipRadius }
            let target = next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY
            if s.phase == .idle || (s.pipY > target + 4 && s.pipVY > -40) { Runner.flap(&s, events: &ev) }
            ev += Runner.advance(&s, elapsed: 1.0 / 60)
        }
        return (s, ev)
    }
    let a = play(78), b = play(78)
    #expect(a.state == b.state)
    #expect(a.events == b.events)
    #expect(a.state.distance > 500)
}

@Test func featherDoesNotSaveAShardAtTheCeiling() {
    // Pip touches a top shard and the ceiling in one step, holding only a feather: the shard ends the run first.
    var s = runningGame(); s.effects.apply(.feather)
    s.gates = [Gate(id: 6, x: s.world.pipX - 2, centre: 30, gap: 40, chunk: 0, items: [])]
    s.pipY = Params.pipRadius - 1; s.pipVY = 0
    let ev = step(&s)
    #expect(s.phase == .crashed && !ev.contains(.bounced))
}
