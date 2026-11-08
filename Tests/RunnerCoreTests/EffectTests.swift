import Testing
@testable import RunnerCore

@Test func rulesVersionIsThree() {
    #expect(Params.rulesVersion == 3)
}

@Test func newPickupsSortIntoGoodAndBad() {
    #expect(Pickup.good == [.ember, .egg, .updraft, .feather, .tiny])
    #expect(Pickup.bad == [.ashCloud, .stoneScale, .hiccups, .rush, .bloat])
    #expect(Set(Pickup.good + Pickup.bad) == Set(Pickup.allCases))
    #expect([Pickup.feather, .tiny].allSatisfy(\.isGood) && ![Pickup.rush, .bloat].contains(where: \.isGood))
}

@Test func newPickupsHaveTagsAndDurations() {
    #expect([Pickup.feather, .tiny, .rush, .bloat].map(\.label) == ["Feather!", "Tiny!", "Rush!", "Bloat!"])
    #expect(Pickup.feather.duration == 0)
    #expect(Pickup.tiny.duration == 5 && Pickup.bloat.duration == 5 && Pickup.rush.duration == 4)
}

@Test func featherIsOneChargeThatDoesNotStack() {
    var e = Effects(); e.apply(.feather); e.apply(.feather)
    #expect(e.feather && e.remaining(.feather) == 1 && e.fraction(.feather) == 1)
    e.tick(100)
    #expect(e.feather)   // a charge never times out
}

@Test func tinyAndBloatScaleTheRadius() {
    var e = Effects()
    #expect(e.radiusScale == 1)
    e.apply(.tiny)
    #expect(e.radiusScale == Params.tinyScale)
    e.tick(Params.tinyTime)
    #expect(e.radiusScale == 1)
    e.apply(.bloat)
    #expect(e.radiusScale == Params.bloatScale)
}

@Test func tinyAndBloatCancelEachOther() {
    var e = Effects(); e.apply(.tiny); e.apply(.bloat)
    #expect(e.tiny == 0 && e.bloat == Params.bloatTime && e.radiusScale == Params.bloatScale)
    e.apply(.tiny)
    #expect(e.bloat == 0 && e.tiny == Params.tinyTime && e.radiusScale == Params.tinyScale)
}

@Test func rushScalesSpeedWhileItRuns() {
    var e = Effects()
    #expect(e.speedScale == 1)
    e.apply(.rush)
    #expect(e.speedScale == Params.rushSpeed)
    e.tick(Params.rushTime)
    #expect(e.speedScale == 1)
}

@Test(arguments: [Pickup.tiny, .bloat, .rush])
func takingATimedEffectAgainRefreshesIt(p: Pickup) {
    var e = Effects(); e.apply(p)
    e.tick(3)
    #expect(abs(e.remaining(p) - (p.duration - 3)) < 1e-9)
    e.apply(p)
    #expect(e.remaining(p) == p.duration && e.fraction(p) == 1)
}

@Test func newEffectsLeaveTheOldOnesAlone() {
    var e = Effects(); e.apply(.updraft); e.apply(.ember)
    for p in [Pickup.feather, .tiny, .rush, .bloat] { e.apply(p) }
    #expect(e.updraft == Params.updraftTime && e.emberCharge && e.gravityScale == Params.updraftGravity)
}

@Test func stateRadiusAndScrollSpeedFollowEffects() {
    var s = runningGame()
    #expect(s.pipRadius == Params.pipRadius && s.scrollSpeed == Params.speedStart)
    s.effects.apply(.bloat); s.effects.apply(.rush)
    #expect(abs(s.pipRadius - Params.pipRadius * Params.bloatScale) < 1e-9)
    #expect(abs(s.scrollSpeed - Params.speedStart * Params.rushSpeed) < 1e-9)
    s.speed = 250
    #expect(s.scrollSpeed == Params.speedMax)   // the cap applies after the multiplier
}

// MARK: Rules: radius and speed

/// A plain gate around Pip whose gap runs from y 76 to 116.
private func gateAroundPip(_ s: GameState) -> Gate {
    Gate(id: 3, x: s.world.pipX - 2, centre: 96, gap: 40, chunk: 0, items: [])
}

@Test func tinySlipsPastAShardThatHitsNormalPip() {
    // Pip's top edge is 1 unit into the top shard at the normal radius, 1.7 units clear of it when tiny.
    for (tiny, crashed) in [(false, true), (true, false)] {
        var s = runningGame()
        if tiny { s.effects.apply(.tiny) }
        s.gates = [gateAroundPip(s)]
        s.pipY = 76 + Params.pipRadius - 1; s.pipVY = 0
        var ev: [GameEvent] = []
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
        #expect((s.phase == .crashed) == crashed)
    }
}

@Test func bloatHitsAShardThatMissesNormalPip() {
    // Pip's top edge is 2 units clear of the top shard at the normal radius, 0.7 units into it when bloated.
    for (bloat, crashed) in [(false, false), (true, true)] {
        var s = runningGame()
        if bloat { s.effects.apply(.bloat) }
        s.gates = [gateAroundPip(s)]
        s.pipY = 76 + Params.pipRadius + 2; s.pipVY = 0
        var ev: [GameEvent] = []
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
        #expect((s.phase == .crashed) == crashed)
    }
}

@Test func scaledRadiusAppliesToTheGroundToo() {
    var s = runningGame(); s.effects.apply(.tiny)
    s.pipY = Params.ground - Params.pipRadius + 1; s.pipVY = 0   // would touch the ground at the normal radius
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .running)
    s.effects = Effects(); s.effects.apply(.bloat)
    s.pipY = Params.ground - Params.pipRadius - 2; s.pipVY = 0   // clear at the normal radius
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)
}

@Test func pickupReachUsesTheScaledRadius() {
    // 16 units from the item: out of reach at the normal radius (9 + 6), in reach when bloated (11.7 + 6).
    for (bloat, taken) in [(false, false), (true, true)] {
        var s = atPickup(.egg, side: .lower)
        if bloat { s.effects.apply(.bloat) }
        s.pipY = s.gates[0].itemY(.lower) - 16
        var ev: [GameEvent] = []
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
        #expect(s.gates[0].items[0].taken == taken)
    }
    // 14 units away: in reach at the normal radius, out of reach when tiny (6.3 + 6).
    for (tiny, taken) in [(false, true), (true, false)] {
        var s = atPickup(.egg, side: .lower)
        if tiny { s.effects.apply(.tiny) }
        s.pipY = s.gates[0].itemY(.lower) - 14
        var ev: [GameEvent] = []
        Runner.step(&s, dt: Params.fixedStep, events: &ev)
        #expect(s.gates[0].items[0].taken == taken)
    }
}

@Test func rushScrollsFasterWithoutTouchingTheRamp() {
    var s = runningGame(); s.pipY = 100; s.effects.apply(.rush)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(abs(s.distance - Params.speedStart * Params.rushSpeed * Params.fixedStep) < 1e-9)
    #expect(s.speed == Params.speedStart)   // the ramp itself is untouched
}

@Test func rushRespectsTheSpeedCap() {
    var s = runningGame(); s.pipY = 100; s.speed = 250; s.effects.apply(.rush)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(abs(s.distance - Params.speedMax * Params.fixedStep) < 1e-9)
}

@Test func rushWearsOff() {
    var s = runningGame(); s.pipY = 100; s.effects.apply(.rush)
    s.effects.tick(Params.rushTime)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(abs(s.distance - Params.speedStart * Params.fixedStep) < 1e-9)
}

@Test func takingTinyThroughTheRunnerShrinksPip() {
    var s = atPickup(.tiny)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(ev.contains(.picked(.tiny)))
    #expect(abs(s.pipRadius - Params.pipRadius * Params.tinyScale) < 1e-9)
}

// MARK: Rules: growing near an edge

/// A fork whose bottom shard sits below the ground and whose lower Bloat sits near the ground, so Pip can take it
/// there without touching obsidian at either radius.
private func bloatNearTheGround(_ s: GameState) -> Gate {
    Gate(id: 8, x: s.world.pipX - Params.gateWidth / 2, centre: 150, gap: 80, chunk: 10,
         items: [Item(side: .lower, pickup: .bloat)])
}

private func insideTheField(_ s: GameState) -> Bool {
    s.pipY - s.pipRadius >= 0 && s.pipY + s.pipRadius <= Params.ground
}

@Test func takingBloatOneUnitFromTheGroundNudgesPipInsteadOfCrashing() {
    var s = runningGame()
    s.gates = [bloatNearTheGround(s)]
    s.pipY = Params.ground - Params.pipRadius - 1; s.pipVY = 0   // 1 unit clear now, 1.7 units into the ground bloated
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(ev.contains(.picked(.bloat)))
    #expect(s.phase == .running && !ev.contains(where: { if case .crashed = $0 { true } else { false } }))
    #expect(insideTheField(s))
    #expect(s.pipY + s.pipRadius == Params.ground)   // the edge sits exactly on the ground
}

@Test func takingBloatAtTheCeilingNudgesPipDown() {
    var s = runningGame()
    let g = Gate(id: 9, x: s.world.pipX - Params.gateWidth / 2, centre: 40, gap: 80, chunk: 10,
                 items: [Item(side: .upper, pickup: .bloat)])
    s.gates = [g]
    s.pipY = Params.pipRadius + 1; s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(ev.contains(.picked(.bloat)) && s.phase == .running)
    #expect(insideTheField(s) && s.pipY - s.pipRadius == 0)
}

@Test func tinyEndingNearTheGroundNudgesPipInsteadOfCrashing() {
    var s = runningGame(); s.effects.apply(.tiny)
    s.effects.tick(Params.tinyTime - Params.fixedStep / 2)   // ends during the next step
    s.pipY = Params.ground - Params.pipRadius + 1; s.pipVY = 0   // clear when tiny, 1 unit into the ground at full size
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.effects.tiny == 0 && s.phase == .running)
    #expect(insideTheField(s) && s.pipY + s.pipRadius == Params.ground)
}

@Test func growingDoesNotRescueAPipAlreadyIntoTheGround() {
    // Pip's tiny edge is already past the ground when Tiny ends: the run still crashes.
    var s = runningGame(); s.effects.apply(.tiny)
    s.effects.tick(Params.tinyTime - Params.fixedStep / 2)
    s.pipY = Params.ground - Params.pipRadius * Params.tinyScale + 1; s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)
}
