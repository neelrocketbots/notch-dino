import Foundation
import Testing
@testable import RaceCore
import RunnerCore

@Suite struct RaceSessionTests {
    @Test func handshakeSharesNamesHeroesMapAndWorld() {
        var host = RaceSession(hostingAs: neel, map: "glacier", world: raceWorld, seed: 9)
        var guest = RaceSession(joiningAs: ana, seed: 4)
        #expect(host.stage == .waiting && guest.stage == .waiting)
        #expect(host.handle(.connected, now: 0).isEmpty)
        let hello = guest.handle(.connected, now: 0)
        #expect(hello == [.send(.hello(proto: 1, rules: Params.rulesVersion, name: "Ana", hero: "moss"))])
        let welcome = host.handle(.received(sent(hello)[0]), now: 0)
        #expect(welcome == [.send(.welcome(name: "Neel", hero: "pip", map: "glacier", width: 351))])
        #expect(host.stage == .ready && host.opponent == ana)
        #expect(guest.handle(.received(sent(welcome)[0]), now: 0).isEmpty)
        #expect(guest.stage == .ready && guest.opponent == neel && guest.map == "glacier")
    }

    @Test func guestRacesTheHostsWorld() {
        var (host, guest) = readyPair()
        #expect(guest.world == host.world)
        let start = host.handle(.startPressed, now: 0)
        let cmds = guest.handle(.received(sent(start)[0]), now: 0)
        var game = Runner.newGame(world: World(width: 420), seed: 0, best: 0)   // the guest's own, wider field
        _ = RacePlay.apply(cmds, to: &game, world: guest.world!)
        #expect(game.world == raceWorld && guest.ghost?.world == raceWorld && host.ghost?.world == raceWorld)
    }

    @Test(arguments: [RaceMessage.hello(proto: 2, rules: Params.rulesVersion, name: "Ana", hero: "moss"),
                      RaceMessage.hello(proto: 1, rules: Params.rulesVersion + 1, name: "Ana", hero: "moss")])
    func aVersionMismatchIsRefusedOnBothSides(hello: RaceMessage) {
        var host = RaceSession(hostingAs: neel, map: "glacier", world: raceWorld, seed: 9)
        _ = host.handle(.connected, now: 0)
        #expect(host.handle(.received(hello), now: 0) == [.send(.refuse(.version)), .close])
        #expect(host.stage == .over(.versionMismatch))
        var guest = RaceSession(joiningAs: ana, seed: 4)
        _ = guest.handle(.connected, now: 0)
        #expect(guest.handle(.received(.refuse(.version)), now: 0) == [.close])
        #expect(guest.stage == .over(.versionMismatch))
    }

    @Test func aLateHelloIsRefusedAsFull() {
        var (host, _) = readyPair()
        let late = RaceMessage.hello(proto: 1, rules: Params.rulesVersion, name: "Sam", hero: "nova")
        #expect(host.handle(.received(late), now: 0) == [.send(.refuse(.full))])
        #expect(host.opponent == ana && host.stage == .ready)
        var sam = RaceSession(joiningAs: RacePlayer(name: "Sam", hero: "nova"), seed: 1)
        _ = sam.handle(.connected, now: 0)
        #expect(sam.handle(.received(.refuse(.full)), now: 0) == [.close] && sam.stage == .over(.full))
    }

    @Test func onlyTheHostStartsAndTheGuestMakesUpForTheRoundTrip() {
        var (host, guest) = readyPair()
        #expect(guest.handle(.startPressed, now: 0).isEmpty && guest.stage == .ready)
        _ = guest.handle(.received(.pong(t: 1.0)), now: 1.024)
        #expect(abs((guest.rtt ?? 0) - 0.024) < 1e-9)
        let start = host.handle(.startPressed, now: 2)
        guard case .start(let seed, let inMs) = sent(start).first else { Issue.record("no start"); return }
        #expect(inMs == 2_100 && host.stage == .countdown)
        #expect(start.contains(.startGame(seed: seed, countdownSteps: 252)))
        // 2100 ms − 12 ms (half the round trip) = 2088 ms ≈ 251 steps.
        #expect(guest.handle(.received(.start(seed: seed, inMs: inMs)), now: 2) == [.startGame(seed: seed, countdownSteps: 251)])
        #expect(guest.stage == .countdown)
    }

    @Test func theCountdownEndsWhenTheRunGoes() {
        var (host, _) = readyPair()
        _ = host.handle(.startPressed, now: 0)
        _ = host.handle(.tick(step: 0, phase: .countdown(remaining: 100)), now: 0)
        #expect(host.stage == .countdown)
        _ = host.handle(.tick(step: 0, phase: .running), now: 0)
        #expect(host.stage == .racing)
    }

    @Test func flapsGoOutAndComeInToTheGhost() {
        var (host, guest, _) = racingPair()
        #expect(guest.handle(.flapped(step: 10), now: 0) == [.send(.flap(step: 10))])
        _ = host.handle(.tick(step: 30, phase: .running), now: 0)
        #expect(host.handle(.received(.flap(step: 10)), now: 0).isEmpty)
        #expect(host.ghost?.flaps == [10] && host.ghost?.state.step == 30)
    }

    @Test(arguments: [10, 5, 151])
    func aFlapOutOfOrderOrTooFarAheadIsADesync(second: Int) {
        var (host, _, _) = racingPair()
        _ = host.handle(.tick(step: 30, phase: .running), now: 0)
        _ = host.handle(.received(.flap(step: 10)), now: 0)
        #expect(host.handle(.received(.flap(step: second)), now: 0) == [.send(.bye(.desync)), .close])
        #expect(host.stage == .over(.desync))
    }

    @Test func theFirstCrashTellsTheOtherPlayerWhatToBeat() {
        var (host, guest, seed) = racingPair()
        let fall = pilotRun(seed: seed, flyUntil: 0).crash
        #expect(guest.handle(.crashed(step: fall.step, score: fall.score), now: 0)
                == [.send(.crashed(step: fall.step, score: fall.score))])
        #expect(guest.stage == .racing && guest.myCrash == fall)
        let out = host.handle(.received(.crashed(step: fall.step, score: fall.score)), now: 0)
        #expect(out == [.notice(.opponentCrashed(score: fall.score))])
        #expect(host.theirCrash == fall && host.stage == .racing)
    }

    @Test func whenBothHaveCrashedTheHigherScoreWins() throws {
        var (host, guest, seed) = racingPair()
        let hostRun = pilotRun(seed: seed, flyUntil: 1_200)
        let guestRun = pilotRun(seed: seed, flyUntil: 0)
        try #require(hostRun.crash.score > guestRun.crash.score)
        // The guest falls first; the host flies on and its flaps reach the guest as they happen.
        _ = guest.handle(.crashed(step: guestRun.crash.step, score: guestRun.crash.score), now: 0)
        _ = host.handle(.received(.crashed(step: guestRun.crash.step, score: guestRun.crash.score)), now: 0)
        for f in hostRun.flaps {
            _ = guest.handle(.tick(step: f, phase: .crashed), now: 0)
            _ = guest.handle(.received(.flap(step: f)), now: 0)
        }
        _ = host.handle(.crashed(step: hostRun.crash.step, score: hostRun.crash.score), now: 0)
        _ = guest.handle(.received(.crashed(step: hostRun.crash.step, score: hostRun.crash.score)), now: 0)
        #expect(host.stage == .result(.win) && guest.stage == .result(.lose))
    }

    @Test func equalScoresTie() {
        var (host, guest, seed) = racingPair()
        bothFall(&host, &guest, seed: seed)
        #expect(host.stage == .result(.tie) && guest.stage == .result(.tie))
    }

    @Test func aCrashThatDisagreesWithTheGhostIsADesync() {
        var (host, _, seed) = racingPair()
        let fall = pilotRun(seed: seed, flyUntil: 0).crash
        #expect(host.handle(.received(.crashed(step: fall.step, score: fall.score + 1)), now: 0) == [.send(.bye(.desync)), .close])
        #expect(host.stage == .over(.desync))
        var (again, _, _) = racingPair()
        #expect(again.handle(.received(.crashed(step: fall.step + 3, score: fall.score)), now: 0) == [.send(.bye(.desync)), .close])
    }

    @Test func aRematchNeedsBothPlayers() {
        var (host, guest, seed) = racingPair()
        bothFall(&host, &guest, seed: seed)
        #expect(host.handle(.rematchPressed, now: 0) == [.send(.rematch)] && host.stage == .result(.tie))
        #expect(host.handle(.rematchPressed, now: 0).isEmpty)
        #expect(guest.handle(.received(.rematch), now: 0).isEmpty && guest.stage == .result(.tie))
        #expect(guest.handle(.rematchPressed, now: 0) == [.send(.rematch)])
        let start = host.handle(.received(.rematch), now: 0)
        guard case .start(let next, 2_100) = sent(start).first else { Issue.record("no start"); return }
        #expect(next != seed && host.stage == .countdown && start.contains(.startGame(seed: next, countdownSteps: 252)))
        #expect(guest.handle(.received(.start(seed: next, inMs: 2_100)), now: 0) == [.startGame(seed: next, countdownSteps: 252)])
        #expect(guest.stage == .countdown && guest.myCrash == nil && guest.theirCrash == nil && !guest.rematchMine)
    }

    @Test func byeEndsTheMatchWithoutAReply() {
        var (host, guest) = readyPair()
        #expect(host.handle(.received(.bye(.quit)), now: 0) == [.close] && host.stage == .over(.opponentLeft))
        #expect(guest.handle(.received(.bye(.desync)), now: 0) == [.close] && guest.stage == .over(.desync))
    }

    @Test(arguments: [ByeReason.left, .quit])
    func leavingSaysByeAndEndsTheMatch(reason: ByeReason) {
        var (host, _, _) = racingPair()
        #expect(host.handle(.leave(reason), now: 0) == [.send(.bye(reason)), .close])
        #expect(host.stage == .over(.youLeft))
    }

    @Test func aLostConnectionIsTheOpponentLeaving() {
        var (_, guest, _) = racingPair()
        #expect(guest.handle(.disconnected, now: 0) == [.close] && guest.stage == .over(.opponentLeft))
    }

    @Test func nothingHappensOnceTheMatchIsOver() {
        var (host, _) = readyPair()
        _ = host.handle(.leave(.left), now: 0)
        #expect(host.handle(.startPressed, now: 0).isEmpty)
        #expect(host.handle(.received(.ping(t: 1)), now: 1).isEmpty)
        #expect(host.handle(.tick(step: 1, phase: .running), now: 99).isEmpty)
        #expect(host.handle(.disconnected, now: 99).isEmpty)
    }

    @Test func racePlayDrivesTheLocalRunAndPassesTheRestOn() {
        var game = Runner.newGame(world: World(width: 400), seed: 0, best: 12)
        let rest = RacePlay.apply([.send(.rematch), .startGame(seed: 5, countdownSteps: 200),
                                   .notice(.opponentCrashed(score: 1)), .close], to: &game, world: raceWorld)
        #expect(rest == [.send(.rematch), .notice(.opponentCrashed(score: 1)), .close])
        // Race scores never touch the solo best: a race run's best is out of reach.
        #expect(game.world == raceWorld && game.phase == .countdown(remaining: 200) && game.best == Int.max)
        game.phase = .running
        _ = RacePlay.apply([.freeze(atStep: 0)], to: &game, world: raceWorld)
        #expect(game.phase == .paused)
        _ = RacePlay.apply([.resume(countdownSteps: 252)], to: &game, world: raceWorld)
        #expect(game.phase == .countdown(remaining: 252))
    }
}
