import Testing
@testable import RunnerCore

@Test func rulesVersionIsTwo() {
    #expect(Params.rulesVersion == 2)
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
