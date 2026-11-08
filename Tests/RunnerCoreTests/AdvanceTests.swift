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

/// A gate Pip has already passed (with its gap well above Pip, so Pip would hit it if it came back) and an unscored one
/// just ahead of Pip, in the 350-wide world where Pip sits at x 87.5.
private func pausedGameAroundPip() -> GameState {
    var s = runningGame()
    var behind = Gate(id: 0, x: 60, centre: 40, gap: 90, chunk: 0, items: [])
    behind.passed = true
    s.gates = [behind, Gate(id: 1, x: 120, centre: 96, gap: 90, chunk: 0, items: [])]
    s.pipY = 96
    Runner.pause(&s)
    return s
}

@Test(arguments: [200.0, 600.0])
func resizeKeepsEveryGateWhereItWasRelativeToPip(width: Double) {
    var s = pausedGameAroundPip()
    let before = s
    let offsets = s.gates.map { $0.x - s.world.pipX }
    Runner.resize(&s, world: World(width: width))
    #expect(s.world.width == width && s.world.pipX == width * Params.pipXFraction)
    #expect(s.gates.map { $0.x - s.world.pipX } == offsets)
    #expect(s.gates.map(\.passed) == before.gates.map(\.passed))
    #expect(s.gates.map(\.id) == before.gates.map(\.id))
    #expect(s.pipY == before.pipY && s.phase == .paused && s.score == before.score)
    #expect(s.nextGateX >= s.world.width + Params.spawnAhead)
    #expect(s.nextGateX >= s.gates.map(\.x).max()! + Params.spacing)
}

@Test(arguments: [200.0, 600.0])
func resizedRunResumesWithoutCrashOrFreePoints(width: Double) {
    var s = pausedGameAroundPip()
    Runner.resize(&s, world: World(width: width))
    var events: [GameEvent] = []
    Runner.flap(&s, events: &events)
    for _ in 0..<Params.countdownSteps { Runner.step(&s, dt: Params.fixedStep, events: &events) }
    #expect(s.phase == .running)
    for _ in 0..<10 { Runner.step(&s, dt: Params.fixedStep, events: &events) }
    #expect(s.phase == .running && s.score == 0)
    #expect(!events.contains { if case .gatePassed = $0 { true } else if case .crashed = $0 { true } else { false } })
}

@Test func resizeShiftsPendingSpawnWithPip() {
    var s = runningGame()
    s.gates = [Gate(id: 0, x: 300, centre: 96, gap: 90, chunk: 0, items: [])]
    s.nextGateX = 900
    Runner.pause(&s)
    Runner.resize(&s, world: World(width: 250))
    let shift = 250 * Params.pipXFraction - 350 * Params.pipXFraction
    #expect(s.gates[0].x == 300 + shift)
    #expect(s.nextGateX == 900 + shift)
}

@Test func resizeWideningResumesSpawningPastNewEdge() {
    var s = runningGame()
    s.nextGateX = 200
    Runner.pause(&s)
    Runner.resize(&s, world: World(width: 500))
    #expect(s.nextGateX == 500 + Params.spawnAhead)
}
