import Testing
@testable import RunnerCore

/// A running game with no gates in reach.
func runningGame(seed: UInt64 = 1, best: Int = 0) -> GameState {
    var s = Runner.newGame(world: World(width: 350), seed: seed, best: best)
    s.phase = .running
    s.nextGateX = 1_000_000
    return s
}

@Test func flapWhileRunningIsAnImpulse() {
    var s = runningGame(); s.pipVY = 50
    var ev: [GameEvent] = []
    Runner.flap(&s, events: &ev)
    #expect(s.phase == .running && s.pipVY == Params.flapVelocity && ev == [.flapped])
}

@Test func gravityIntegratesOneStep() {
    var s = runningGame(); s.pipY = 100; s.pipVY = 0
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    let vy = Params.gravity * Params.fixedStep
    #expect(abs(s.pipVY - vy) < 1e-9)
    #expect(abs(s.pipY - (100 + vy * Params.fixedStep)) < 1e-9)
}

@Test func fallSpeedIsCapped() {
    // Starts just under the cap; one gravity step would overshoot it, so the clamp is what holds it at maxFall.
    var s = runningGame(); s.pipY = 50; s.pipVY = Params.maxFall - 5
    var ev: [GameEvent] = []
    for _ in 0..<5 { Runner.step(&s, dt: Params.fixedStep, events: &ev) }
    #expect(s.pipVY == Params.maxFall)
    #expect(s.phase == .running)
}

@Test func groundCrashes() {
    var s = runningGame(best: 3); s.pipY = Params.ground - Params.pipRadius - 0.1; s.pipVY = 200; s.score = 2
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed && ev == [.crashed(score: 2)] && !s.newBest)
}

@Test func ceilingCrashesAndRecordsNewBest() {
    var s = runningGame(best: 1); s.pipY = Params.pipRadius + 0.1; s.pipVY = -200; s.score = 4
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.phase == .crashed && s.best == 4 && s.newBest)
    #expect(ev == [.newBest(score: 4), .crashed(score: 4)])
}

@Test func flapOnPausedStartsTheCountdownWithoutImpulse() {
    var s = runningGame(); s.pipVY = 50
    Runner.pause(&s)
    #expect(s.phase == .paused)
    var ev: [GameEvent] = []
    Runner.flap(&s, events: &ev)
    #expect(s.phase == .countdown(remaining: Params.countdownSteps) && s.pipVY == 50 && ev.isEmpty)
}

@Test func flapDoesNothingWhenCrashed() {
    var s = runningGame(); s.phase = .crashed; s.pipVY = 10
    var ev: [GameEvent] = []
    Runner.flap(&s, events: &ev)
    #expect(s.phase == .crashed && s.pipVY == 10 && ev.isEmpty)
}

@Test func idleBobsAndDoesNotFall() {
    var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
    var ev: [GameEvent] = []
    for _ in 0..<600 { Runner.step(&s, dt: Params.fixedStep, events: &ev) }
    #expect(abs(s.pipY - Params.idleY) <= 6.0001 && s.phase == .idle && ev.isEmpty)
}

@Test func pausedAndCrashedDoNotMove() {
    var s = runningGame(); s.pipY = 80; Runner.pause(&s)
    var ev: [GameEvent] = []
    Runner.step(&s, dt: Params.fixedStep, events: &ev)
    #expect(s.pipY == 80)
}
