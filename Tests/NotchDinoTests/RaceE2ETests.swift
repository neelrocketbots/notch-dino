import Foundation
import NotchKit
import RaceCore
import RunnerCore
import Testing
@testable import NotchDinoApp

// End-to-end races between two full `IslandModel`s in this process, over real Bonjour (`_notchdino._tcp`) and real
// TCP through `NWRaceNetwork`. They touch the network, so they only run with NOTCHDINO_E2E=1 (scripts/e2e-race.sh);
// a plain `swift test` skips them.

enum E2E {
    static let enabled = ProcessInfo.processInfo.environment["NOTCHDINO_E2E"] == "1"
    /// About 120 scene ticks a second.
    static let frame = Duration.microseconds(8_333)
}

/// A wait that ran out. Thrown so a scenario stops at the first step that didn't happen.
struct E2ETimeout: Error, CustomStringConvertible {
    let description: String
}

/// Pip's height and score at one step of a run, as the player's own Mac had it.
struct E2ESample: Equatable {
    var pipY: Double
    var score: Int
}

/// Flaps for one player whenever Pip is below the next opening and not already rising. It aims a seeded few units
/// off centre and gives up after a seeded number of gates, so every race ends. Seeded per player, so its choices
/// are the same on every run (the timing it sees is real, so the race itself isn't).
@MainActor struct E2EAutopilot {
    private var rng: SeededRandom
    private(set) var budget = 0
    private var aim = 0.0

    init(seed: UInt64) {
        rng = SeededRandom(seed: seed)
        newRace()
    }

    /// A new race: a new gate budget (2…4) and a new aim (−6…+6 units from the opening's centre).
    mutating func newRace() {
        budget = 2 + Int(rng.next() % 3)
        aim = rng.unit() * 12 - 6
    }

    /// Whether to press Space now.
    func wantsFlap(_ game: GameState) -> Bool {
        guard game.phase == .running, game.score < budget else { return false }
        let next = game.gates.first { $0.x + Params.gateWidth > game.world.pipX - Params.pipRadius }
        let target = (next.map { $0.isFork ? $0.itemY(.upper) : $0.centre } ?? Params.idleY) + aim
        return game.pipY > target + 4 && game.pipVY > -40
    }
}

/// One player: a full island model with its own defaults, its own real `NWRaceNetwork`, and no panel.
@MainActor final class E2EPlayer {
    let name: String
    let model: IslandModel
    private let suite: String
    var pilot: E2EAutopilot
    /// The race (by seed) the flaps and history below belong to.
    private(set) var raceSeed: UInt64?
    /// This player's own flap steps in the current race.
    private(set) var flaps: [Int] = []
    /// This player's own run, step by step, in the current race.
    private(set) var history: [Int: E2ESample] = [:]
    /// When the current race's countdown ended on this Mac (wall clock).
    private(set) var wentAt: ContinuousClock.Instant?
    /// The other player's flaps this player's ghost has received so far, and how late each one was (in steps).
    private var ghostFlapsSeen = 0
    var maxFlapLag = 0
    /// True once the scenario has cut this player off the network: no more ticks, no more messages.
    var dropped = false

    init(name: String, hero: Hero, map: MapTheme, notchWidth: Double, pilotSeed: UInt64) {
        self.name = name
        suite = "notchDino.e2e.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let looks = LookStore(defaults: defaults)
        looks.save(hero: hero)
        looks.save(map: map)
        let store = RaceStore(defaults: defaults, fullName: { name })
        store.save(name: name)
        store.setExplained()
        let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982,
                                   notch: Notch(width: notchWidth, height: 32), isMain: true, isBuiltIn: true,
                                   menuBarHeight: 32)
        model = IslandModel(display: display, best: BestScoreStore(defaults: defaults),
                            layout: LayoutStore(defaults: defaults), looks: looks, race: store,
                            network: NWRaceNetwork(), seed: pilotSeed)
        pilot = E2EAutopilot(seed: pilotSeed)
    }

    var session: RaceSession? { model.session }
    var stage: RaceStage? { model.session?.stage }

    /// Starts this player's bookkeeping afresh when a new race (a new seed) has begun.
    func followRace() {
        let seed = model.session?.ghost?.seed
        guard seed != raceSeed else { return }
        raceSeed = seed
        flaps = []
        history = [:]
        wentAt = nil
        ghostFlapsSeen = 0
        pilot.newRace()
    }

    /// One scene frame: the autopilot's Space, then the scene tick, then what the run looked like.
    func frame(elapsed: Double, at now: ContinuousClock.Instant) {
        guard model.isOpen, !dropped else { return }
        followRace()
        if case .match(.racing, _)? = model.race, pilot.wantsFlap(model.game) {
            model.handle(.flapKey)
            flaps.append(model.game.step)
        }
        _ = model.sceneTick(elapsed: elapsed)
        followRace()
        guard raceSeed != nil else { return }
        if wentAt == nil, model.game.phase == .running { wentAt = now }
        // Only a moving run: a countdown or pause holds the step it froze on, already recorded.
        if model.game.phase == .running || model.game.phase == .crashed, history[model.game.step] == nil {
            history[model.game.step] = E2ESample(pipY: model.game.pipY, score: model.game.score)
        }
    }

    /// Checks this player's ghost of `other` against `other`'s own run. Once every flap `other` made up to the
    /// ghost's step has arrived, the ghost is that step exactly. Returns whether a step was confirmed and compared.
    @discardableResult
    func checkGhost(of other: E2EPlayer) -> Bool {
        guard !dropped, let ghost = model.session?.ghost, ghost.seed == other.raceSeed else { return false }
        for f in ghost.flaps.dropFirst(ghostFlapsSeen) { maxFlapLag = max(maxFlapLag, model.game.step - f) }
        ghostFlapsSeen = ghost.flaps.count
        let g = ghost.state.step
        guard other.flaps.filter({ $0 <= g }) == ghost.flaps.filter({ $0 <= g }),
              let live = other.history[g] else { return false }
        let seen = E2ESample(pipY: ghost.state.pipY, score: ghost.state.score)
        #expect(seen == live, "\(name)'s ghost of \(other.name) at step \(g): \(seen), but \(other.name) had \(live)")
        return true
    }

    /// Back to solo (bye if a match is on), listener, browser and link closed, defaults removed. Safe to call twice.
    func tearDown() {
        model.closeRace()
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}

/// Two players driven together in real time.
@MainActor final class E2ERig {
    let ana: E2EPlayer
    let sam: E2EPlayer
    private let clock = ContinuousClock()
    private var last: ContinuousClock.Instant
    let began: ContinuousClock.Instant
    /// Ghost steps compared exactly, and frames whose ghost was still waiting on a flap.
    var confirmed = 0
    var pending = 0
    var frames = 0
    /// Frames whose real gap was over 0.1 s (the scene is given at most 0.1 s, as a stalled frame).
    var slowFrames = 0
    var checkingGhosts = true

    init() {
        // Ana hosts on Glacier as Moss; Sam joins as Nova from a Mac with a wider notch (so his own world differs
        // and he must race on Ana's).
        ana = E2EPlayer(name: "Ana", hero: .moss, map: .glacier, notchWidth: 185, pilotSeed: 0xA4A)
        sam = E2EPlayer(name: "Sam", hero: .nova, map: .grove, notchWidth: 200, pilotSeed: 0x5A3)
        last = clock.now
        began = last
    }

    var players: [E2EPlayer] { [ana, sam] }

    func seconds(since t: ContinuousClock.Instant) -> Double { seconds(clock.now - t) }
    func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    /// One frame for both: sleep about 1/120 s (the network's callbacks run on the main queue meanwhile), then tick.
    func frame() async {
        try? await Task.sleep(for: E2E.frame)
        let now = clock.now
        var elapsed = seconds(now - last)
        last = now
        if elapsed > 0.1 { slowFrames += 1; elapsed = 0.1 }
        frames += 1
        for p in players { p.frame(elapsed: elapsed, at: now) }
        guard checkingGhosts else { return }
        for (p, o) in [(ana, sam), (sam, ana)] where p.session?.ghost != nil {
            if p.checkGhost(of: o) { confirmed += 1 } else { pending += 1 }
        }
    }

    /// Runs frames until `done`, or throws "<failure> within N s". Returns the seconds it took.
    @discardableResult
    func wait(_ failure: @autoclosure () -> String, within limit: Double,
              until done: () -> Bool) async throws -> Double {
        let start = clock.now
        while !done() {
            if seconds(since: start) > limit {
                throw E2ETimeout(description: "\(failure()) within \(limit) s")
            }
            await frame()
        }
        return seconds(since: start)
    }

    /// Runs frames for `duration` seconds.
    func run(for duration: Double) async {
        let start = clock.now
        while seconds(since: start) < duration { await frame() }
    }

    func tearDown() {
        for p in players { p.tearDown() }
    }

    /// Lets the closes and Bonjour goodbyes go out before the next scenario browses.
    func settle() async {
        try? await Task.sleep(for: .milliseconds(500))
    }

    // MARK: Steps both scenarios share

    /// Ana opens Race and hosts on the "Host a race" row.
    func anaHosts() async throws {
        ana.model.handle(.hotKey)
        ana.model.handle(.raceKey)
        guard case .lobby(let hosts, _)? = ana.model.race else {
            throw E2ETimeout(description: "Ana's R opened \(String(describing: ana.model.race)), not the lobby")
        }
        // Down past every row lands on "Host a race", in the same turn as Space, so no lobby update slips in.
        for _ in 0...hosts.count { ana.model.handle(.downKey) }
        ana.model.handle(.flapKey)
        #expect(ana.model.race == .match(.waiting, .host))
        #expect(ana.session?.role == .host && ana.session?.map == "glacier")
    }

    /// Sam opens Race; Ana's race shows up in his lobby. Returns the seconds it took to appear.
    func samSeesAna() async throws -> (host: RaceHost, seconds: Double) {
        sam.model.handle(.hotKey)
        sam.model.handle(.raceKey)
        var found: RaceHost?
        let took = try await wait("Sam never saw Ana's race", within: 5) {
            if case .denied? = sam.model.race { return true }
            guard case .lobby(let hosts, _)? = sam.model.race else { return false }
            found = hosts.first { $0.name == "Ana" }
            return found != nil
        }
        if case .denied? = sam.model.race {
            throw E2ETimeout(description: "Sam's browser was denied Local Network access (DNS -65570, PolicyDenied)")
        }
        guard let host = found else { throw E2ETimeout(description: "Ana's row vanished") }
        #expect(host.hero == "moss", "Ana's row shows hero \(host.hero)")
        #expect(host.map == "glacier", "Ana's row shows map \(host.map)")
        #expect(RaceCopy.lobbyDetail(host) == "Glacier · waiting")
        return (host, took)
    }

    /// Sam moves to Ana's row and presses Space; both reach "ready".
    @discardableResult
    func samJoins(_ host: RaceHost) async throws -> Double {
        guard case .lobby(let hosts, let selection)? = sam.model.race,
              let row = hosts.firstIndex(where: { $0.id == host.id }) else {
            throw E2ETimeout(description: "Ana's row left Sam's lobby before he could join")
        }
        let key: IslandEvent = row < selection ? .upKey : .downKey
        for _ in 0..<abs(row - selection) { sam.model.handle(key) }
        sam.model.handle(.flapKey)
        #expect(sam.model.race == .match(.waiting, .guest))
        let took = try await wait("Ana and Sam never both reached ready", within: 5) {
            ana.model.race == .match(.ready, .host) && sam.model.race == .match(.ready, .guest)
        }
        #expect(ana.session?.opponent == RacePlayer(name: "Sam", hero: "nova"))
        #expect(sam.session?.opponent == RacePlayer(name: "Ana", hero: "moss"))
        #expect(RaceCopy.readyTitle(.host, opponent: ana.session?.opponent?.name ?? "") == "Sam joined")
        #expect(RaceCopy.readyTitle(.guest, opponent: sam.session?.opponent?.name ?? "") == "Waiting for Ana to start")
        // Sam races on Ana's map and world, not his own.
        #expect(sam.session?.map == "glacier")
        #expect(sam.session?.world == ana.session?.world)
        #expect(sam.model.soloWorld != ana.model.soloWorld)
        return took
    }

    /// Ana presses Space once both have a round-trip time; both count down and go. Returns the gap between the two
    /// countdowns ending, in seconds.
    @discardableResult
    func anaStarts() async throws -> Double {
        try await wait("The lobby pings never measured a round trip", within: 3) {
            ana.session?.rtt != nil && sam.session?.rtt != nil
        }
        ana.model.handle(.flapKey)
        #expect(ana.stage == .countdown)
        try await wait("Sam never got Ana's start", within: 2) { sam.stage == .countdown }
        try await wait("The countdowns never ended", within: 4) { ana.wentAt != nil && sam.wentAt != nil }
        guard let a = ana.wentAt, let s = sam.wentAt else { return .infinity }
        let gap = abs(seconds(a - s))
        #expect(gap <= 0.050, "the countdowns ended \(Int(gap * 1000)) ms apart")
        try await wait("The stages never became racing", within: 1) {
            ana.stage == .racing && sam.stage == .racing
        }
        #expect(ana.raceSeed == sam.raceSeed && ana.raceSeed != nil)
        return gap
    }
}

@Suite(.serialized, .enabled(if: E2E.enabled, "set NOTCHDINO_E2E=1 to race over real Bonjour"))
struct RaceE2ETests {
    @MainActor @Test(.timeLimit(.minutes(2))) func raceOverRealBonjour() async throws {
        let rig = E2ERig()
        defer { rig.tearDown() }
        var log: [String] = []
        func note(_ s: String) { log.append(s); print("[e2e] \(s)") }

        // 1. Ana hosts.
        try await rig.anaHosts()
        note("Ana hosts")

        // 2. Sam's lobby lists Ana with her hero and map.
        let (host, seen) = try await rig.samSeesAna()
        note(String(format: "Sam saw Ana's race in %.3f s", seen))

        // 3. Sam joins.
        let joined = try await rig.samJoins(host)
        note(String(format: "both ready %.3f s after Sam's Space", joined))

        // 4. Ana starts; the countdowns end together.
        let gap = try await rig.anaStarts()
        note(String(format: "countdowns ended %.1f ms apart; rtt %.1f ms", gap * 1000,
                    (rig.sam.session?.rtt ?? 0) * 1000))
        let firstSeed = rig.ana.raceSeed

        // 5. Racing: the ghosts are checked every frame (in `frame`). Fly a second before the pause.
        await rig.run(for: 1.0)

        // 6. Ana presses P: both freeze on the same step, and Sam sees Ana paused.
        rig.ana.model.handle(.pauseKey)
        #expect(rig.ana.stage == .paused(byMe: true))
        try await rig.wait("Ana's pause never froze both runs", within: 2) {
            rig.ana.model.game.phase == .paused && rig.sam.model.game.phase == .paused
        }
        let frozeA = rig.ana.model.game.step, frozeS = rig.sam.model.game.step
        #expect(frozeA == frozeS, "Ana froze on step \(frozeA), Sam on \(frozeS)")
        #expect(rig.sam.model.race == .match(.paused(byMe: false), .guest))
        #expect(RaceCopy.pausedTitle(byMe: false, opponent: rig.sam.session?.opponent?.name ?? "") == "Ana paused")
        note("both froze on step \(frozeA)")
        await rig.run(for: 0.3)
        #expect(rig.ana.model.game.step == frozeA && rig.sam.model.game.step == frozeS)
        rig.ana.model.handle(.pauseKey)   // P again resumes
        #expect(rig.ana.stage == .countdown)
        try await rig.wait("Sam never got Ana's resume", within: 2) { rig.sam.stage == .countdown }
        try await rig.wait("The race never ran again after the resume", within: 4) {
            rig.ana.stage == .racing && rig.sam.stage == .racing
                && rig.ana.model.game.step > frozeA && rig.sam.model.game.step > frozeS
        }
        note("resumed")

        // 7. Both crash; both result cards agree.
        let raced = try await rig.wait("The race never reached a result on both", within: 45) {
            if case .result? = rig.ana.stage, case .result? = rig.sam.stage { return true }
            return false
        }
        let a = try #require(rig.ana.session), s = try #require(rig.sam.session)
        let aMine = try #require(a.myCrash), aTheirs = try #require(a.theirCrash)
        let sMine = try #require(s.myCrash), sTheirs = try #require(s.theirCrash)
        #expect(aMine == sTheirs && sMine == aTheirs, "Ana has \(aMine) v \(aTheirs), Sam has \(sMine) v \(sTheirs)")
        let expected: (RaceOutcome, RaceOutcome) = aMine.score > sMine.score ? (.win, .lose)
            : aMine.score < sMine.score ? (.lose, .win) : (.tie, .tie)
        #expect(a.stage == .result(expected.0) && s.stage == .result(expected.1))
        #expect(rig.ana.model.raceHUD?.score == rig.sam.model.raceHUD?.opponentScore)
        #expect(rig.sam.model.raceHUD?.score == rig.ana.model.raceHUD?.opponentScore)
        note("result after \(String(format: "%.1f", raced)) s more: Ana \(aMine.score) (step \(aMine.step)), "
             + "Sam \(sMine.score) (step \(sMine.step)), \(a.stage)")
        note("ghost steps compared exactly: \(rig.confirmed); frames waiting on a flap: \(rig.pending); "
             + "worst flap lag: Ana's ghost \(rig.ana.maxFlapLag), Sam's ghost \(rig.sam.maxFlapLag) steps")
        #expect(rig.confirmed > 200, "only \(rig.confirmed) ghost steps were compared")
        #expect(rig.ana.flaps.count + rig.sam.flaps.count > 0, "the autopilots never flapped")
        #expect(max(rig.ana.maxFlapLag, rig.sam.maxFlapLag) <= 12, "a flap took more than 12 steps to arrive")

        // 8. Both press Space: a rematch with a new seed.
        rig.ana.model.handle(.flapKey)
        #expect(rig.ana.model.rematchAsked)
        rig.sam.model.handle(.flapKey)
        try await rig.wait("The rematch never started", within: 3) {
            rig.ana.stage == .countdown && rig.sam.stage == .countdown
        }
        try await rig.wait("The rematch never got going", within: 4) {
            rig.ana.stage == .racing && rig.sam.stage == .racing
        }
        #expect(rig.ana.raceSeed != firstSeed && rig.ana.raceSeed == rig.sam.raceSeed)
        note("rematch on a new seed")
        await rig.run(for: 0.3)

        // 9. Sam leaves: Esc folds (pausing the race), the hot key reopens, Esc on the paused panel leaves.
        rig.sam.model.handle(.escape)
        #expect(!rig.sam.model.isOpen && rig.sam.stage == .paused(byMe: true))
        rig.sam.model.handle(.hotKey)
        rig.sam.model.handle(.escape)
        #expect(rig.sam.model.race == .match(.over(.youLeft), .guest))
        let left = try await rig.wait("Ana never saw that Sam left", within: 5) {
            rig.ana.model.race == .match(.over(.opponentLeft), .host)
        }
        #expect(RaceCopy.endTitle(.opponentLeft, opponent: rig.ana.session?.opponent?.name) == "Sam left the race")
        note(String(format: "Ana saw Sam leave in %.3f s", left))
        note("frames \(rig.frames), slow frames \(rig.slowFrames), total \(String(format: "%.1f", rig.seconds(since: rig.began))) s")

        rig.tearDown()
        await rig.settle()
    }

    @MainActor @Test(.timeLimit(.minutes(1))) func guestDropMidRace() async throws {
        let rig = E2ERig()
        defer { rig.tearDown() }

        try await rig.anaHosts()
        let (host, _) = try await rig.samSeesAna()
        try await rig.samJoins(host)
        try await rig.anaStarts()
        await rig.run(for: 1.0)

        // Sam's Wi-Fi goes off: from now on nothing he says reaches Ana and nothing she says is answered, with no
        // bye and no FIN. His socket stays open, as a dead peer's does, so only the heartbeat can notice.
        rig.checkingGhosts = false
        rig.sam.dropped = true
        rig.sam.model.link?.onMessage = nil
        rig.sam.model.link?.onState = nil
        rig.sam.model.raceTimer?.invalidate()
        rig.sam.model.raceTimer = nil

        let took = try await rig.wait("Ana never noticed Sam had gone", within: 5.5) {
            rig.ana.model.race == .match(.over(.opponentLeft), .host)
        }
        #expect(took <= 5.0 + 0.1, "the heartbeat timeout took \(took) s")
        #expect(RaceCopy.endTitle(.opponentLeft, opponent: rig.ana.session?.opponent?.name) == "Sam left the race")
        print(String(format: "[e2e] Ana saw Sam drop in %.3f s", took))

        // Space on the end card: back to solo.
        rig.ana.model.handle(.flapKey)
        #expect(rig.ana.model.race == nil && rig.ana.model.session == nil)
        #expect(rig.ana.model.phase == .idle)

        rig.tearDown()
        await rig.settle()
    }
}
