import Foundation
import RaceCore
import RunnerCore
import Testing
@testable import NotchDinoApp

/// One Mac in a simulated race: its session, its run at 120 fps, its end of the link, and an autopilot that flaps
/// whenever Pip sinks below the next opening for `flyFrames` running frames, then lets go.
@MainActor final class SimMac {
    var session: RaceSession
    var game = Runner.newGame(world: World(width: 351), seed: 0, best: Int.max)
    let link: LoopbackRaceLink
    let flyFrames: Int
    var flown = 0
    var now = 0.0
    var notices: [RaceNotice] = []
    /// The step the run was on each time it froze.
    var frozeAt: [Int] = []
    /// When the first countdown ended.
    var wentAt: Double?
    var pauseAt: Double?
    var resumeAt: Double?
    private var wasPaused = false

    init(_ session: RaceSession, link: LoopbackRaceLink, flyFrames: Int) {
        self.session = session
        self.link = link
        self.flyFrames = flyFrames
        link.onMessage = { [unowned self] m in self.feed(.received(m)) }
        link.onState = { [unowned self] state in
            switch state {
            case .ready: self.feed(.connected)
            case .failed: self.feed(.disconnected)
            case .connecting: break
            }
        }
    }

    func feed(_ input: RaceInput) {
        let commands = session.handle(input, now: now)
        for c in RacePlay.apply(commands, to: &game, world: session.world ?? game.world) {
            switch c {
            case .send(let m): link.send(m)
            case .notice(let n): notices.append(n)
            case .close: link.close()
            case .startGame, .freeze, .resume: break
            }
        }
    }

    func frame(at t: Double) {
        now = t
        link.pump(to: t)
        if let p = pauseAt, t >= p { pauseAt = nil; feed(.pausePressed) }
        if let r = resumeAt, t >= r, session.stage == .paused(byMe: true) { resumeAt = nil; feed(.resumePressed) }
        if game.phase == .running, flown < flyFrames {
            flown += 1
            let next = game.gates.first { $0.x + Params.gateWidth > game.world.pipX - Params.pipRadius }
            let target = next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY
            if game.pipY > target + 4, game.pipVY > -40 {
                var ev: [GameEvent] = []
                Runner.flap(&game, events: &ev)
                feed(.flapped(step: game.step))
            }
        }
        let events = Runner.advance(&game, elapsed: Params.fixedStep)
        if wentAt == nil, game.phase == .running { wentAt = t }
        let paused = game.phase == .paused
        if paused, !wasPaused { frozeAt.append(game.step) }
        wasPaused = paused
        if events.contains(where: { if case .crashed = $0 { true } else { false } }), let step = game.crashStep {
            feed(.crashed(step: step, score: game.score))
        }
        feed(.tick(step: game.step, phase: game.phase))
    }
}

/// Two Macs joined over a loopback link, driven frame by frame.
@MainActor final class SimRace {
    let host: SimMac
    let guest: SimMac
    var t = 0.0

    init(delay: ClosedRange<Double>, hostFly: Int, guestFly: Int) {
        let (hostLink, guestLink) = LoopbackRaceLink.pair(delay: delay, seed: 3)
        host = SimMac(RaceSession(hostingAs: RacePlayer(name: "Neel", hero: "pip"), map: "glacier",
                                  world: World(width: 351), seed: 11), link: hostLink, flyFrames: hostFly)
        guest = SimMac(RaceSession(joiningAs: RacePlayer(name: "Ana", hero: "moss"), seed: 5),
                       link: guestLink, flyFrames: guestFly)
        hostLink.connect()
    }

    func run(until end: Double, stopWhen done: () -> Bool = { false }) {
        while t < end, !done() {
            t += Params.fixedStep
            host.frame(at: t)
            guest.frame(at: t)
        }
    }

    var settled: Bool { Self.settled(host.session) && Self.settled(guest.session) }
    static func settled(_ s: RaceSession) -> Bool { if case .result = s.stage { true } else { s.isOver } }

    /// Lobby, then the host presses Space, then the race runs until both have a result.
    func raceToTheEnd() {
        run(until: 1)
        host.feed(.startPressed)
        run(until: 120) { self.settled }
    }
}

@Suite struct LoopbackRaceTests {
    @MainActor @Test func framesTravelThroughTheLoopback() {
        let (a, b) = LoopbackRaceLink.pair(delay: 0.01...0.01)
        var got: [RaceMessage] = []
        b.onMessage = { got.append($0) }
        a.send(.flap(step: 4)); a.send(.rematch)
        a.pump(to: 0.005); #expect(got.isEmpty)
        a.pump(to: 0.02); #expect(got == [.flap(step: 4), .rematch] && a.sent == got)
    }

    @MainActor @Test func closingDeliversWhatWasSentThenReportsTheLinkLost() {
        let (a, b) = LoopbackRaceLink.pair()
        var got: [RaceMessage] = [], states: [RaceLinkState] = []
        b.onMessage = { got.append($0) }
        b.onState = { states.append($0) }
        a.send(.bye(.left)); a.close(); a.send(.rematch)
        a.pump(to: 0)
        #expect(got == [.bye(.left)] && states == [.failed(.lost)] && a.isClosed && b.isClosed)
    }

    @MainActor @Test(arguments: [0.0...0.0, 0.002...0.03])
    func twoMacsReachTheSameResult(delay: ClosedRange<Double>) {
        let race = SimRace(delay: delay, hostFly: 2_400, guestFly: 600)
        race.run(until: 1)
        #expect(race.host.session.stage == .ready && race.guest.session.stage == .ready)
        race.host.feed(.startPressed)
        race.run(until: 120) { race.settled }
        guard case .result(let h) = race.host.session.stage, case .result(let g) = race.guest.session.stage else {
            Issue.record("no result: \(race.host.session.stage) / \(race.guest.session.stage)"); return
        }
        let mirror: [RaceOutcome: RaceOutcome] = [.win: .lose, .lose: .win, .tie: .tie]
        #expect(mirror[h] == g)
        #expect(race.host.session.myCrash == race.guest.session.theirCrash)
        #expect(race.guest.session.myCrash == race.host.session.theirCrash)
        let hs = race.host.game.score, gs = race.guest.game.score
        #expect(h == (hs > gs ? .win : hs < gs ? .lose : .tie))
        // Both countdowns end within the one-way delay plus a frame or two.
        #expect(abs(race.host.wentAt! - race.guest.wentAt!) <= delay.upperBound + 2 * Params.fixedStep)
    }

    @MainActor @Test func aPauseFreezesBothMacsOnTheSameStepAndTheRaceStillAgrees() throws {
        let race = SimRace(delay: 0.002...0.03, hostFly: 2_400, guestFly: 2_400)
        race.host.pauseAt = 5
        race.host.resumeAt = 7
        race.raceToTheEnd()
        try #require(race.host.frozeAt.count == 1)
        #expect(race.host.frozeAt == race.guest.frozeAt)
        guard case .result = race.host.session.stage, case .result = race.guest.session.stage else {
            Issue.record("no result"); return
        }
        #expect(race.host.session.myCrash == race.guest.session.theirCrash)
        #expect(race.guest.session.myCrash == race.host.session.theirCrash)
    }

    @MainActor @Test func leavingEndsTheMatchOnBothMacs() {
        let race = SimRace(delay: 0.002...0.03, hostFly: 2_400, guestFly: 2_400)
        race.run(until: 1)
        race.host.feed(.startPressed)
        race.run(until: 4)
        race.host.feed(.leave(.left))
        race.run(until: 4.2)
        #expect(race.host.session.stage == .over(.youLeft) && race.guest.session.stage == .over(.opponentLeft))
        #expect(race.host.link.isClosed && race.guest.link.isClosed)
    }
}
