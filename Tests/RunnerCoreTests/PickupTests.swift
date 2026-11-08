import Testing
@testable import RunnerCore

func forkGate(x: Double, upper: Pickup?, lower: Pickup?) -> Gate {
    var items: [Item] = []
    if let upper { items.append(Item(side: .upper, pickup: upper)) }
    if let lower { items.append(Item(side: .lower, pickup: lower)) }
    return Gate(id: 7, x: x, centre: 94, gap: 150, chunk: 24, items: items)
}

/// Pip parked on an opening's pickup.
func atPickup(_ p: Pickup, side: Side = .upper) -> GameState {
    var s = runningGame()
    let g = forkGate(x: s.world.pipX - Params.gateWidth / 2, upper: side == .upper ? p : nil, lower: side == .lower ? p : nil)
    s.gates = [g]; s.pipY = g.itemY(side); s.pipVY = 0
    return s
}

@Test func takingAPickupAppliesItOnce() {
    var s = atPickup(.updraft)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(ev.filter { $0 == .picked(.updraft) }.count == 1)
    #expect(s.gates[0].items[0].taken)
    #expect(s.effects.updraft > 4.9)
}

@Test func eggAddsFivePoints() {
    var s = atPickup(.egg, side: .lower); s.score = 3
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.score == 8)
}

@Test func updraftAndStoneChangeGravity() {
    for (p, scale) in [(Pickup.updraft, 0.6), (.stoneScale, 1.35)] {
        var s = runningGame(); s.effects.apply(p); s.pipY = 100; s.pipVY = 0
        var ev: [GameEvent] = []
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
        #expect(abs(s.pipVY - Params.gravity * scale * Params.fixedStep) < 1e-9)
    }
}

@Test func emberMeltsInsteadOfCrashing() {
    var s = runningGame(); s.effects.emberCharge = true
    s.gates = [Gate(id: 3, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])]
    s.pipY = 96 + 20 - Params.pipRadius + 1   // into the bottom shard
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .running && !s.effects.emberCharge)
    #expect(ev.contains(.melted(gateID: 3, part: .bottom)))
    #expect(s.gates[0].melted[.bottom] != nil)
    Runner.step(&s, dt: Params.fixedStep, events: &ev)   // melted part no longer solid
    #expect(s.phase == .running)
}

@Test func emberDoesNotStack() {
    var e = Effects(); e.apply(.ember); e.apply(.ember)
    #expect(e.emberCharge)
    var s = runningGame(); s.effects = e
    s.gates = [Gate(id: 1, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: []),
               Gate(id: 2, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])]
    s.pipY = 96 + 20 - Params.pipRadius + 1
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)   // one charge, two shards: the second ends the run
}

@Test func emberNeverSavesFromGround() {
    var s = runningGame(); s.effects.emberCharge = true
    s.pipY = Params.ground - Params.pipRadius + 1
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed && s.effects.emberCharge)
}

@Test func hiccupsAreDeterministicPerSeed() {
    func hops(seed: UInt64) -> [Double] {
        var s = runningGame(seed: seed); s.effects.apply(.hiccups); s.pipY = 100
        var times: [Double] = []
        for _ in 0..<480 {
            var ev: [GameEvent] = []
            Runner.step(&s, dt: Params.fixedStep, events: &ev)
            if ev.contains(.hiccup) { times.append(s.time) }
            s.pipY = 100
        }
        return times
    }
    #expect(hops(seed: 9) == hops(seed: 9))
    #expect(!hops(seed: 9).isEmpty)
}

@Test func pickupOutOfReachStaysUntaken() {
    // Lower item sits at y 137.5; Pip is one unit beyond pipRadius + pickupReach above it, clear of the chunk.
    var s = atPickup(.updraft, side: .lower)
    s.pipY = s.gates[0].itemY(.lower) - (Params.pipRadius + Params.pickupReach + 1)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(!s.gates[0].items[0].taken)
    #expect(!ev.contains(.picked(.updraft)))
    #expect(s.effects.updraft == 0)
}

@Test func pickupJustInsideReachIsTaken() {
    var s = atPickup(.updraft, side: .lower)
    s.pipY = s.gates[0].itemY(.lower) - (Params.pipRadius + Params.pickupReach - 1)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.gates[0].items[0].taken)
    #expect(ev.contains(.picked(.updraft)))
}

@Test func twoEmbersThroughRunnerGiveOneCharge() {
    var s = runningGame()
    let x = s.world.pipX - Params.gateWidth / 2
    // First ember.
    s.gates = [forkGate(x: x, upper: .ember, lower: nil)]
    s.pipY = s.gates[0].itemY(.upper); s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    // Second ember on a fresh gate at the same height.
    s.gates = [forkGate(x: x, upper: .ember, lower: nil)]
    s.pipY = s.gates[0].itemY(.upper); s.pipVY = 0
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.effects.emberCharge)
    #expect(ev.filter { $0 == .picked(.ember) }.count == 2)
    #expect(s.phase == .running)

    // Shard one on a plain gate: the single charge melts it and the run continues.
    s.gates = [Gate(id: 10, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])]
    s.pipY = 96 + 20 - Params.pipRadius + 1
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .running && !s.effects.emberCharge)
    #expect(s.gates[0].melted[.bottom] != nil)

    // Shard two on another gate: no charge left, so the run ends.
    s.gates.append(Gate(id: 11, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: []))
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)
}
