import Testing
@testable import RunnerCore

func plainGate(id: Int = 0, x: Double, centre: Double = 96, gap: Double = 90) -> Gate {
    Gate(id: id, x: x, centre: centre, gap: gap, chunk: 0, items: [])
}

@Test func passingAGateScoresOnceAndSpeedsUp() {
    var s = runningGame()
    let px = s.world.pipX
    s.gates = [plainGate(x: px - Params.gateWidth - Params.pipRadius + 0.5)]
    s.pipY = 96; s.pipVY = 0
    var ev: [GameEvent] = []
    for _ in 0..<10 { Runner.step(&s, dt: Params.fixedStep, events: &ev); s.pipY = 96; s.pipVY = 0 }
    #expect(s.score == 1)
    #expect(s.speed == Params.speedStart + Params.speedPerGate)
    #expect(ev.filter { if case .gatePassed = $0 { true } else { false } }.count == 1)
}

@Test func hittingAShardCrashes() {
    var s = runningGame()
    s.gates = [plainGate(x: s.world.pipX - 2, centre: 96, gap: 40)]
    s.pipY = 96 - 20 + Params.pipRadius - 1   // overlaps the top shard
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)
}

@Test func nearMissInsideGapIsSafe() {
    var s = runningGame()
    s.gates = [plainGate(x: s.world.pipX - 2, centre: 96, gap: 40)]
    s.pipY = 96; s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .running)
}

@Test func forkChunkIsSolid() {
    var s = runningGame()
    s.gates = [Gate(id: 0, x: s.world.pipX - 2, centre: 94, gap: 150, chunk: 24, items: [])]
    s.pipY = 94; s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed)
}

@Test func milestoneEveryTenAndSpeedCaps() {
    var s = runningGame(); s.score = 9; s.speed = Params.speedMax
    s.gates = [plainGate(x: s.world.pipX - Params.gateWidth - Params.pipRadius - 0.01 + 0.0001)]
    s.pipY = 96
    var ev: [GameEvent] = []
    for _ in 0..<5 { Runner.step(&s, dt: Params.fixedStep, events: &ev); s.pipY = 96; s.pipVY = 0 }
    #expect(ev.contains(.milestone(score: 10)))
    #expect(s.speed == Params.speedMax)
}

@Test func gatesSpawnAheadAndDespawnBehind() {
    var s = runningGame(); s.nextGateX = s.world.width
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.gates.count >= 1 && s.gates[0].id == 0)
    s.gates[0].x = Params.despawnX + 0.1
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(!s.gates.contains { $0.id == 0 })
}
