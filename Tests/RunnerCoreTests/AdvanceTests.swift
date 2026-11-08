import Testing
@testable import RunnerCore

@Test func advanceSplitsIntoFixedSteps() {
    var s = runningGame()
    _ = Runner.advance(&s, elapsed: 3 * Params.fixedStep + 0.001)
    #expect(abs(s.time - 3 * Params.fixedStep) < 1e-9)
    #expect(abs(s.accumulator - 0.001) < 1e-9)
}

@Test func advanceCapsAtEightSteps() {
    var s = runningGame()
    _ = Runner.advance(&s, elapsed: 0.2)
    #expect(abs(s.time - 8 * Params.fixedStep) < 1e-9)
    #expect(s.accumulator == 0)
}

@Test func longFrameGapPausesInsteadOfTeleporting() {
    var s = runningGame(); s.pipY = 80
    let ev = Runner.advance(&s, elapsed: 0.3)
    #expect(s.phase == .paused && s.pipY == 80 && ev.isEmpty)
}

@Test func sameSeedSameInputsSameState() {
    // Flaps whenever Pip sinks below the next gap's centre, so the run survives long enough to cover real ground.
    func play(_ seed: UInt64) -> (state: GameState, events: [GameEvent]) {
        var s = Runner.newGame(world: World(width: 351), seed: seed, best: 0)
        var ev: [GameEvent] = []
        for _ in 0..<3_000 {
            let next = s.gates.first { $0.x + Params.gateWidth > s.world.pipX - Params.pipRadius }
            let target = next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY
            if s.phase == .idle || (s.pipY > target + 4 && s.pipVY > -40) { Runner.flap(&s, events: &ev) }
            ev += Runner.advance(&s, elapsed: 1.0 / 60)
        }
        return (s, ev)
    }
    let a = play(77), b = play(77)
    #expect(a.state == b.state)
    #expect(a.events == b.events)
    #expect(a.state.distance > 1000)
}

@Test func resizeNarrowingKeepsPipAndGatesInPlace() {
    var s = runningGame()
    s.nextGateX = 200
    s.gates = [Gate(id: 0, x: 300, centre: 96, gap: 90, chunk: 0, items: [])]
    s.pipY = 80
    Runner.pause(&s)
    let gatesBefore = s.gates, pipYBefore = s.pipY
    Runner.resize(&s, world: World(width: 250))
    #expect(s.world.width == 250 && s.world.pipX == 62.5)
    #expect(s.nextGateX == 300 + Params.spacing)
    #expect(s.gates == gatesBefore && s.pipY == pipYBefore)
    #expect(s.phase == .paused)
}

@Test func resizeWideningResumesSpawningPastNewEdge() {
    var s = runningGame()
    s.nextGateX = 200
    Runner.pause(&s)
    Runner.resize(&s, world: World(width: 500))
    #expect(s.nextGateX == 500 + Params.spawnAhead)
}
