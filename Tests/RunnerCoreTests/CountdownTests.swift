import Testing
@testable import RunnerCore

private func steps(_ s: inout GameState, _ n: Int) {
    var ev: [GameEvent] = []
    for _ in 0..<n { Runner.step(&s, dt: Params.fixedStep, events: &ev) }
}

@Suite struct CountdownTests {
    @Test func countdownNumbersAre84StepsEach() {
        #expect(Params.countdownSteps == 3 * Params.countdownStepsPerNumber)
        #expect(Phase.countdown(remaining: 252).countdownNumber == 3)
        #expect(Phase.countdown(remaining: 169).countdownNumber == 3)
        #expect(Phase.countdown(remaining: 168).countdownNumber == 2)
        #expect(Phase.countdown(remaining: 85).countdownNumber == 2)
        #expect(Phase.countdown(remaining: 84).countdownNumber == 1)
        #expect(Phase.countdown(remaining: 1).countdownNumber == 1)
        #expect(Phase.running.countdownNumber == nil && Phase.paused.countdownNumber == nil)
    }

    @Test func countdownFromIdleLastsExactly252Steps() {
        var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
        var ev: [GameEvent] = []
        Runner.flap(&s, events: &ev)
        #expect(s.phase == .countdown(remaining: 252) && ev.isEmpty)
        steps(&s, 251)
        #expect(s.phase == .countdown(remaining: 1) && s.step == 0 && s.distance == 0)
        steps(&s, 1)
        #expect(s.phase == .running && s.step == 0 && s.pipY == Params.idleY && s.pipVY == 0)
        steps(&s, 1)
        #expect(s.step == 1 && s.distance > 0)
    }

    @Test func aRetryAfterACrashCountsDownTheSame() {
        var crashed = runningGame(); crashed.pipY = Params.ground
        steps(&crashed, 1)
        #expect(crashed.phase == .crashed)
        // The app retries with a fresh game and the same key.
        var s = Runner.newGame(world: crashed.world, seed: 2, best: crashed.best)
        var ev: [GameEvent] = []
        Runner.flap(&s, events: &ev)
        steps(&s, 251); #expect(s.phase == .countdown(remaining: 1))
        steps(&s, 1); #expect(s.phase == .running)
    }

    @Test func resumeCountsDownWithTheWorldFrozenThenCarriesOn() {
        var s = runningGame(); s.pipY = 80; s.pipVY = 50; s.step = 40; s.distance = 300
        Runner.pause(&s)
        var ev: [GameEvent] = []
        Runner.flap(&s, events: &ev)
        #expect(s.phase == .countdown(remaining: 252) && ev.isEmpty)
        steps(&s, 251)
        #expect(s.pipY == 80 && s.pipVY == 50 && s.step == 40 && s.distance == 300)
        steps(&s, 1)
        #expect(s.phase == .running && s.pipY == 80 && s.pipVY == 50 && s.step == 40)
    }

    @Test func keysAreIgnoredDuringTheCountdown() {
        var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
        var ev: [GameEvent] = []
        Runner.flap(&s, events: &ev)
        steps(&s, 10)
        let before = s
        Runner.flap(&s, events: &ev)
        #expect(s == before && ev.isEmpty)
    }

    @Test func aShortenedCountdownEndsInTheSameStartState() {
        var full = Runner.newGame(world: World(width: 350), seed: 5, best: 0)
        var short = full
        Runner.startCountdown(&full)
        Runner.startCountdown(&short, steps: 200)
        steps(&full, 252); steps(&short, 200)
        #expect(full.phase == .running && short.phase == .running)
        #expect(full.pipY == short.pipY && full.pipVY == short.pipVY && full.step == short.step)
    }

    @Test func countdownLengthIsClamped() {
        var s = runningGame()
        Runner.startCountdown(&s, steps: 900); #expect(s.phase == .countdown(remaining: 252))
        Runner.startCountdown(&s, steps: -4); #expect(s.phase == .countdown(remaining: 1))
    }

    @Test func pPauseFreezesRunningAndCountdownButLeavesACrash() {
        var running = runningGame(); Runner.pause(&running); #expect(running.phase == .paused)
        var counting = runningGame(); Runner.startCountdown(&counting); Runner.pause(&counting)
        #expect(counting.phase == .paused)
        var crashed = runningGame(); crashed.phase = .crashed; Runner.pause(&crashed)
        #expect(crashed.phase == .crashed)
    }

    @Test func stepCountsRunningAndCrashedButNotPaused() {
        var s = runningGame()
        steps(&s, 5); #expect(s.step == 5)
        Runner.pause(&s); steps(&s, 5); #expect(s.step == 5)
        s.phase = .running; s.pipY = Params.ground
        steps(&s, 1)
        #expect(s.phase == .crashed && s.crashStep == 6 && s.step == 6)
        steps(&s, 3)
        #expect(s.step == 9 && s.crashStep == 6)
    }

    @Test func scheduledPauseFreezesOnThatStep() {
        var s = runningGame()
        steps(&s, 3)
        Runner.schedulePause(&s, atStep: 3 + Params.pauseLeadSteps)
        #expect(s.phase == .running && s.freezeAt == 15)
        steps(&s, 12); #expect(s.phase == .running && s.step == 15)
        steps(&s, 1); #expect(s.phase == .paused && s.step == 15 && s.freezeAt == nil)
        steps(&s, 5); #expect(s.step == 15)
    }

    @Test func aPauseForAStepAlreadyPassedFreezesNow() {
        var s = runningGame()
        steps(&s, 20)
        Runner.schedulePause(&s, atStep: 15)
        #expect(s.phase == .paused && s.step == 20)
    }

    @Test func twoScheduledPausesKeepTheEarlierStep() {
        var s = runningGame()
        Runner.schedulePause(&s, atStep: 13)
        Runner.schedulePause(&s, atStep: 12)
        Runner.schedulePause(&s, atStep: 14)
        #expect(s.freezeAt == 12)
    }

    @Test func aScheduledPauseDuringACountdownFreezesAtOnce() {
        var s = Runner.newGame(world: World(width: 350), seed: 1, best: 0)
        Runner.startCountdown(&s)
        Runner.schedulePause(&s, atStep: 0)
        #expect(s.phase == .paused)
    }

    @Test func startingACountdownCancelsAPendingFreeze() {
        var s = runningGame()
        Runner.schedulePause(&s, atStep: 12)
        Runner.startCountdown(&s)
        #expect(s.freezeAt == nil)
    }

    @Test func aCrashedRunsClockFreezesForARacePause() {
        var s = runningGame(); s.pipY = Params.ground
        steps(&s, 1)
        steps(&s, 4)
        #expect(s.phase == .crashed && s.crashStep == 1 && s.step == 5)
        Runner.schedulePause(&s, atStep: 5)
        #expect(s.phase == .paused)
        steps(&s, 10); #expect(s.step == 5)
        Runner.startCountdown(&s)
        steps(&s, Params.countdownSteps)
        #expect(s.phase == .crashed && s.crashStep == 1)
        steps(&s, 2); #expect(s.step == 7)
    }
}
