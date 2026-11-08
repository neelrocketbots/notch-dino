import Foundation
import Testing
@testable import RaceCore
import RunnerCore

private func isPing(_ m: RaceMessage) -> Bool { if case .ping = m { true } else { false } }
private func freezes(_ c: [RaceCommand]) -> [RaceCommand] { c.filter { if case .freeze = $0 { true } else { false } } }

@Suite struct RacePauseTests {
    @Test func pFreezesBothMacsOnTheSameStep() {
        var (host, guest, _) = racingPair()
        _ = host.handle(.tick(step: 100, phase: .running), now: 1)
        _ = guest.handle(.tick(step: 100, phase: .running), now: 1)
        let out = host.handle(.pausePressed, now: 1)
        #expect(out == [.send(.pause(atStep: 112)), .freeze(atStep: 112)])
        #expect(host.stage == .paused(byMe: true) && host.pausesLeft == 2)
        #expect(guest.handle(.received(.pause(atStep: 112)), now: 1) == [.freeze(atStep: 112)])
        #expect(guest.stage == .paused(byMe: false) && guest.pausesLeft == 3)
    }

    @Test func bothRunsStopOnThatStepEvenWhenOneIsAFewStepsAhead() {
        var a = Ghost.start(seed: 1, world: raceWorld), b = a
        var ev: [GameEvent] = []
        for _ in 0..<100 { Runner.step(&a, dt: Params.fixedStep, events: &ev) }
        for _ in 0..<103 { Runner.step(&b, dt: Params.fixedStep, events: &ev) }
        _ = RacePlay.apply([.freeze(atStep: 112)], to: &a, world: raceWorld)
        _ = RacePlay.apply([.freeze(atStep: 112)], to: &b, world: raceWorld)
        for _ in 0..<40 {
            Runner.step(&a, dt: Params.fixedStep, events: &ev)
            Runner.step(&b, dt: Params.fixedStep, events: &ev)
        }
        #expect(a.phase == .paused && b.phase == .paused && a.step == 112 && b.step == 112)
    }

    @Test func onlyThePauserResumesAndBothCountDown() {
        var (host, guest, _) = racingPair()
        let pause = host.handle(.pausePressed, now: 1)
        _ = guest.handle(.received(sent(pause)[0]), now: 1)
        #expect(guest.handle(.resumePressed, now: 2).isEmpty && guest.stage == .paused(byMe: false))
        let resume = host.handle(.resumePressed, now: 2)
        #expect(resume == [.send(.resume(inMs: 2_100)), .resume(countdownSteps: 252)] && host.stage == .countdown)
        #expect(guest.handle(.received(.resume(inMs: 2_100)), now: 2) == [.resume(countdownSteps: 252)])
        #expect(guest.stage == .countdown)
        _ = guest.handle(.tick(step: 12, phase: .running), now: 4.2)
        #expect(guest.stage == .racing)
    }

    @Test func aPeerCannotResumeAPauseThisMacStarted() {
        var (host, _, _) = racingPair()
        _ = host.handle(.pausePressed, now: 1)
        #expect(host.handle(.received(.resume(inMs: 2_100)), now: 2).isEmpty)
        #expect(host.stage == .paused(byMe: true) && !host.isOver)
        _ = host.handle(.received(.ping(t: 2)), now: 2)
        _ = host.handle(.tick(step: 12, phase: .paused), now: 3)
        #expect(host.stage == .paused(byMe: true))
        #expect(host.handle(.resumePressed, now: 3) == [.send(.resume(inMs: 2_100)), .resume(countdownSteps: 252)])
        #expect(host.stage == .countdown)
    }

    @Test func aPeerCanResumeAPauseThePeerStarted() {
        var (host, guest, _) = racingPair()
        _ = host.handle(.received(sent(guest.handle(.pausePressed, now: 1))[0]), now: 1)
        #expect(host.stage == .paused(byMe: false))
        #expect(host.handle(.received(.resume(inMs: 2_100)), now: 2) == [.resume(countdownSteps: 252)])
        #expect(host.stage == .countdown)
    }

    @Test func afterSimultaneousPausesTheHostCanResumeToo() {
        var (host, guest, _) = racingPair()
        let hostPause = host.handle(.pausePressed, now: 1)
        let guestPause = guest.handle(.pausePressed, now: 1)
        _ = host.handle(.received(sent(guestPause)[0]), now: 1)
        _ = guest.handle(.received(sent(hostPause)[0]), now: 1)
        let resume = host.handle(.resumePressed, now: 2)
        #expect(sent(resume) == [.resume(inMs: 2_100)])
        #expect(guest.handle(.received(.resume(inMs: 2_100)), now: 2) == [.resume(countdownSteps: 252)])
        #expect(host.stage == .countdown && guest.stage == .countdown)
    }

    @Test func aSimultaneousPauseDoesNotCarryIntoTheNextPause() {
        // Simultaneous once, then a fresh pause by this Mac alone: the peer can't resume that one.
        var (h2, g2, _) = racingPair()
        let hp = h2.handle(.pausePressed, now: 1)
        _ = h2.handle(.received(sent(g2.handle(.pausePressed, now: 1))[0]), now: 1)
        _ = g2.handle(.received(sent(hp)[0]), now: 1)
        _ = h2.handle(.received(.resume(inMs: 2_100)), now: 2)
        _ = h2.handle(.tick(step: 20, phase: .running), now: 4.2)
        #expect(h2.stage == .racing)
        _ = h2.handle(.pausePressed, now: 5)
        #expect(h2.handle(.received(.resume(inMs: 2_100)), now: 6).isEmpty && h2.stage == .paused(byMe: true))
    }

    @Test func pDoesNothingDuringTheCountdownButFoldingPauses() {
        var (host, _) = readyPair()
        _ = host.handle(.startPressed, now: 0)
        #expect(host.handle(.pausePressed, now: 0).isEmpty)
        #expect(host.handle(.folded, now: 0) == [.send(.pause(atStep: 0)), .freeze(atStep: 0)])
        #expect(host.stage == .paused(byMe: true))
    }

    @Test func foldingPausesAtTheCurrentStepOnce() {
        var (host, _, _) = racingPair()
        _ = host.handle(.tick(step: 340, phase: .running), now: 1)
        #expect(host.handle(.folded, now: 1) == [.send(.pause(atStep: 340)), .freeze(atStep: 340)])
        #expect(host.handle(.folded, now: 1).isEmpty)
        #expect(host.pausesLeft == 2)
    }

    @Test func foldingOutsideARaceDoesNothing() {
        var (host, _) = readyPair()
        #expect(host.handle(.folded, now: 0).isEmpty && host.stage == .ready)
    }

    @Test func threePausesPerRaceThenPDoesNothingAndFoldingLeaves() {
        var (host, _, _) = racingPair()
        for i in 0..<3 {
            #expect(!host.handle(.pausePressed, now: Double(i)).isEmpty)
            _ = host.handle(.resumePressed, now: Double(i))
            _ = host.handle(.tick(step: 0, phase: .running), now: Double(i))
        }
        #expect(host.pausesLeft == 0 && host.stage == .racing)
        #expect(host.handle(.pausePressed, now: 3).isEmpty)
        #expect(host.handle(.folded, now: 3) == [.send(.bye(.left)), .close] && host.stage == .over(.youLeft))
    }

    @Test func aRematchGivesThreeNewPauses() {
        var (host, guest, seed) = racingPair()
        _ = host.handle(.pausePressed, now: 0)
        _ = host.handle(.resumePressed, now: 0)
        _ = host.handle(.tick(step: 0, phase: .running), now: 0)
        bothFall(&host, &guest, seed: seed)
        _ = host.handle(.rematchPressed, now: 0)
        _ = host.handle(.received(.rematch), now: 0)
        #expect(host.stage == .countdown && host.pausesLeft == 3)
    }

    @Test func aPauseEndsTheMatchAfter60Seconds() {
        var (host, guest, _) = racingPair()
        let pause = host.handle(.pausePressed, now: 10)
        _ = guest.handle(.received(sent(pause)[0]), now: 10)
        for t in stride(from: 11.0, through: 69.0, by: 1) {
            // The heartbeat continues while paused, so neither side times out.
            _ = host.handle(.received(.ping(t: t)), now: t)
            _ = guest.handle(.received(.ping(t: t)), now: t)
            #expect(!sent(host.handle(.tick(step: 12, phase: .paused), now: t)).contains(.bye(.pauseLimit)))
            _ = guest.handle(.tick(step: 12, phase: .paused), now: t)
        }
        #expect(host.stage == .paused(byMe: true) && guest.stage == .paused(byMe: false))
        _ = host.handle(.received(.ping(t: 70)), now: 70)
        #expect(sent(host.handle(.tick(step: 12, phase: .paused), now: 70)).contains(.bye(.pauseLimit)))
        #expect(host.stage == .over(.youLeft))
        _ = guest.handle(.received(.ping(t: 70)), now: 70)
        _ = guest.handle(.tick(step: 12, phase: .paused), now: 70)
        #expect(guest.stage == .over(.opponentLeft))
    }

    @Test func fivePingsInTheLobbyThenOneASecond() {
        var (host, _) = readyPair()
        var pings: [Int] = []
        for i in 0...40 {
            let out = host.handle(.tick(step: 0, phase: .idle), now: Double(i) * 0.05)
            if sent(out).contains(where: isPing) { pings.append(i) }
        }
        #expect(pings == [0, 2, 4, 6, 8, 28])
    }

    @Test func noPingsBeforeTheHandshake() {
        var guest = RaceSession(joiningAs: ana, seed: 4)
        _ = guest.handle(.connected, now: 0)
        #expect(!sent(guest.handle(.tick(step: 0, phase: .idle), now: 0.5)).contains(where: isPing))
    }

    @Test func silenceFor5SecondsIsTheOpponentLeaving() {
        var (_, guest, _) = racingPair()
        _ = guest.handle(.received(.ping(t: 3)), now: 3)
        _ = guest.handle(.tick(step: 1, phase: .running), now: 7.9)
        #expect(!guest.isOver)
        let out = guest.handle(.tick(step: 1, phase: .running), now: 8)
        #expect(sent(out).contains(.bye(.timeout)) && out.last == .close && guest.stage == .over(.opponentLeft))
    }

    @Test func aHostWithNoGuestNeverTimesOut() {
        var host = RaceSession(hostingAs: neel, map: "glacier", world: raceWorld, seed: 9)
        #expect(host.handle(.tick(step: 0, phase: .idle), now: 600).isEmpty && host.stage == .waiting)
    }

    @Test func aPauseTooFarAheadIsADesync() {
        var (host, _, _) = racingPair()
        _ = host.handle(.tick(step: 50, phase: .running), now: 0)
        #expect(host.handle(.received(.pause(atStep: 74)), now: 0) == [.freeze(atStep: 74)])
        var (other, _, _) = racingPair()
        _ = other.handle(.tick(step: 50, phase: .running), now: 0)
        #expect(other.handle(.received(.pause(atStep: 75)), now: 0) == [.send(.bye(.desync)), .close])
    }

    @Test func simultaneousPausesFreezeTogetherAndEitherResumes() {
        var (host, guest, _) = racingPair()
        _ = host.handle(.tick(step: 100, phase: .running), now: 1)
        _ = guest.handle(.tick(step: 101, phase: .running), now: 1)
        let hostPause = host.handle(.pausePressed, now: 1)
        let guestPause = guest.handle(.pausePressed, now: 1)
        let hostGets = host.handle(.received(sent(guestPause)[0]), now: 1)
        let guestGets = guest.handle(.received(sent(hostPause)[0]), now: 1)
        #expect(hostGets == [.freeze(atStep: 113)] && guestGets == [.freeze(atStep: 112)])
        var a = Ghost.start(seed: 1, world: raceWorld), b = a
        _ = RacePlay.apply(freezes(hostPause) + hostGets, to: &a, world: raceWorld)
        _ = RacePlay.apply(freezes(guestPause) + guestGets, to: &b, world: raceWorld)
        #expect(a.freezeAt == 112 && b.freezeAt == 112)
        let resume = guest.handle(.resumePressed, now: 2)
        #expect(sent(resume) == [.resume(inMs: 2_100)])
        #expect(host.handle(.received(.resume(inMs: 2_100)), now: 2) == [.resume(countdownSteps: 252)])
        #expect(host.stage == .countdown && guest.stage == .countdown)
    }

    @Test func aCrashedPlayerCanStillPauseTheRace() {
        var (host, _, seed) = racingPair()
        let fall = pilotRun(seed: seed, flyUntil: 0).crash
        _ = host.handle(.crashed(step: fall.step, score: fall.score), now: 0)
        _ = host.handle(.tick(step: fall.step + 30, phase: .crashed), now: 1)
        let at = fall.step + 30 + Params.pauseLeadSteps
        #expect(host.handle(.pausePressed, now: 1) == [.send(.pause(atStep: at)), .freeze(atStep: at)])
        #expect(host.handle(.resumePressed, now: 2).contains(.resume(countdownSteps: 252)))
        _ = host.handle(.tick(step: at, phase: .crashed), now: 4.2)
        #expect(host.stage == .racing)
        _ = host.handle(.tick(step: at + 20, phase: .crashed), now: 4.3)
        #expect(host.ghost?.state.step == at + 20)
    }
}
