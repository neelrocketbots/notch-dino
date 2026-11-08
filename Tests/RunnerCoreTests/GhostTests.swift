import Testing
@testable import RunnerCore

private let raceWorld = World(width: 351)

/// Plays like a player at 60 fps: counts down, then flaps whenever Pip sinks below the next opening, until
/// `flyFrames` frames have passed, then lets go. Returns the final state and the steps it flapped on.
private func playLive(seed: UInt64, frames: Int = 3_000, flyFrames: Int = 2_000,
                      countdown: Int = Params.countdownSteps) -> (state: GameState, flaps: [Int]) {
    var s = Runner.newGame(world: raceWorld, seed: seed, best: Int.max)
    Runner.startCountdown(&s, steps: countdown)
    var flaps: [Int] = []
    var ev: [GameEvent] = []
    for frame in 0..<frames {
        if s.phase == .running, frame < flyFrames {
            let next = s.gates.first { $0.x + Params.gateWidth > s.world.pipX - Params.pipRadius }
            let target = next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY
            if s.pipY > target + 4 && s.pipVY > -40 {
                Runner.flap(&s, events: &ev)
                flaps.append(s.step)
            }
        }
        _ = Runner.advance(&s, elapsed: 1.0 / 60)
    }
    return (s, flaps)
}

/// The parts of a run both Macs must agree on: everything but wall time and the frame remainder.
private func course(_ s: GameState) -> GameState {
    var c = s
    c.time = 0
    c.accumulator = 0
    return c
}

@Suite struct GhostTests {
    @Test func ghostReplayEqualsTheLiveRunAcross100Seeds() {
        var crashes = 0
        for seed in UInt64(1)...100 {
            let live = playLive(seed: seed, frames: 1_500, flyFrames: 1_200)
            var g = Ghost(seed: seed, world: raceWorld)
            for f in live.flaps { g.add(flap: f) }
            g.advance(to: live.state.step)
            #expect(course(g.state) == course(live.state), "seed \(seed)")
            if live.state.phase == .crashed {
                crashes += 1
                #expect(g.state.crashStep == live.state.crashStep && g.state.score == live.state.score)
            }
        }
        #expect(crashes > 50)
    }

    @Test(arguments: [1, 3, 30])
    func aLateFlapEqualsTheOnTimeRun(lateBy: Int) {
        for seed in UInt64(1)...20 {
            let live = playLive(seed: seed, frames: 1_500, flyFrames: 1_200)
            var g = Ghost(seed: seed, world: raceWorld)
            for f in live.flaps {
                g.advance(to: f + lateBy)      // the ghost glides past the flap's step before the flap arrives
                g.add(flap: f)
            }
            g.advance(to: live.state.step)
            #expect(course(g.state) == course(live.state), "seed \(seed)")
        }
    }

    @Test func aShortenedCountdownRunsTheSameCourse() {
        let full = playLive(seed: 42)
        let short = playLive(seed: 42, countdown: 230)
        var g = Ghost(seed: 42, world: raceWorld)
        for f in short.flaps { g.add(flap: f) }
        g.advance(to: short.state.step)
        #expect(course(g.state) == course(short.state))
        // Same start state, so the same decisions at the same steps.
        #expect(full.flaps.filter { $0 < 1_000 } == short.flaps.filter { $0 < 1_000 })
    }

    @Test func aGhostStartsAtGo() {
        let g = Ghost(seed: 7, world: raceWorld)
        #expect(g.state.phase == .running && g.state.step == 0 && g.state.pipY == Params.idleY && g.state.pipVY == 0)
    }

    @Test func aCrashedGhostKeepsCountingSteps() {
        var g = Ghost(seed: 3, world: raceWorld)
        g.advance(to: 2_000)
        #expect(g.state.phase == .crashed && g.state.step == 2_000 && g.state.crashStep! < 200)
    }

    @Test func flapsThatDoNotIncreaseAreIgnored() {
        var g = Ghost(seed: 3, world: raceWorld)
        g.add(flap: 10); g.add(flap: 10); g.add(flap: 4); g.add(flap: -1)
        #expect(g.flaps == [10])
    }

    @Test func aFlapExactlyAtTheGhostsStepIsNotLate() {
        var a = Ghost(seed: 9, world: raceWorld), b = a
        a.add(flap: 20); a.advance(to: 60)
        b.advance(to: 20); b.add(flap: 20); b.advance(to: 60)
        #expect(a == b)
    }
}
