import Foundation
import RunnerCore

public enum RaceRole: Equatable, Sendable { case host, guest }

/// A player as the other Mac sees them. `hero` is a `Hero.rawValue`.
public struct RacePlayer: Equatable, Sendable {
    public var name: String
    public var hero: String
    public init(name: String, hero: String) {
        self.name = RaceName.clean(name)
        self.hero = hero
    }
}

public enum RaceOutcome: Equatable, Sendable { case win, lose, tie }

/// Why a match ended. The app shows a card for each.
public enum RaceEnd: Equatable, Sendable { case opponentLeft, youLeft, versionMismatch, desync, full }

public enum RaceStage: Equatable, Sendable {
    /// Host: no guest yet. Guest: connecting, or waiting for the host's welcome.
    case waiting
    /// Both in. The host can start; the guest waits.
    case ready
    case countdown
    case racing
    case paused(byMe: Bool)
    case result(RaceOutcome)
    case over(RaceEnd)
}

public struct RaceScore: Equatable, Sendable {
    public var step: Int
    public var score: Int
    public init(step: Int, score: Int) { self.step = step; self.score = score }
}

public enum RaceNotice: Equatable, Sendable { case opponentCrashed(score: Int) }

/// What the app tells the session. The current time (seconds on any monotonic clock) comes with every call.
public enum RaceInput: Equatable, Sendable {
    case connected
    case disconnected
    case received(RaceMessage)
    /// Every frame, and 4 times a second while folded: the local run's step and phase.
    case tick(step: Int, phase: Phase)
    case startPressed
    case flapped(step: Int)
    case crashed(step: Int, score: Int)
    /// P while racing.
    case pausePressed
    /// The island folded, the Mac slept or locked, the app lost key, or a stalled frame paused the run.
    case folded
    case resumePressed
    case rematchPressed
    case leave(ByeReason)
}

/// What the session tells the app.
public enum RaceCommand: Equatable, Sendable {
    case send(RaceMessage)
    /// A new race run that counts down `countdownSteps` before "go".
    case startGame(seed: UInt64, countdownSteps: Int)
    /// Freeze the local run when its step reaches `atStep`.
    case freeze(atStep: Int)
    /// Count down `countdownSteps`, then carry on.
    case resume(countdownSteps: Int)
    case notice(RaceNotice)
    /// The match is over: close the link.
    case close
}

/// One match between this Mac and one other, as a pure state machine (spec §5–§7). It owns the opponent's `Ghost`;
/// the app owns the local run and the link.
public struct RaceSession: Sendable {
    public static let countdownMs = 2_100
    /// How far past this Mac's step a peer's flap or pause may be.
    public static let flapAhead = 120, pauseAhead = 24
    public static let lobbyPings = 5, lobbyPingGap = 0.1, heartbeat = 1.0, timeout = 5.0
    public static let pauseLimit = 60.0, pausesPerRace = 3

    public let role: RaceRole
    public let me: RacePlayer
    public private(set) var opponent: RacePlayer?
    /// The host's map and world. A guest learns them from `welcome`.
    public private(set) var map: String?
    public private(set) var world: World?
    public private(set) var stage: RaceStage = .waiting
    public private(set) var ghost: Ghost?
    public private(set) var myCrash: RaceScore?
    public private(set) var theirCrash: RaceScore?
    public private(set) var rematchMine = false
    public private(set) var rematchTheirs = false
    public private(set) var pausesLeft = RaceSession.pausesPerRace
    /// The latest round trip, in seconds.
    public private(set) var rtt: Double?

    private var seeds: SeededRandom
    private var localStep = 0
    private var connected = false
    private var lastHeard = 0.0
    private var lastTheirFlap = -1
    private var lastPing = -Double.infinity
    private var lobbyPingsLeft = RaceSession.lobbyPings
    private var pausedSince: Double?
    /// Both players paused at once, so either may resume (plan Decision 8).
    private var bothPaused = false

    /// `seed` feeds the race seeds a host picks; tests pass a fixed one.
    public init(hostingAs me: RacePlayer, map: String, world: World, seed: UInt64) {
        role = .host
        self.me = me
        self.map = map
        self.world = world
        seeds = SeededRandom(seed: seed)
    }

    public init(joiningAs me: RacePlayer, seed: UInt64) {
        role = .guest
        self.me = me
        seeds = SeededRandom(seed: seed)
    }

    public var isOver: Bool { if case .over = stage { true } else { false } }

    /// A run is on: counting down, racing or paused.
    public var inRace: Bool {
        switch stage {
        case .countdown, .racing, .paused: true
        case .waiting, .ready, .result, .over: false
        }
    }

    public mutating func handle(_ input: RaceInput, now: Double) -> [RaceCommand] {
        guard !isOver else { return [] }
        switch input {
        case .connected:
            connected = true
            lastHeard = now
            guard role == .guest else { return [] }
            return [.send(.hello(proto: RaceMessage.protocolVersion, rules: Params.rulesVersion, name: me.name, hero: me.hero))]
        case .disconnected:
            return end(.opponentLeft, bye: nil)
        case .received(let message):
            lastHeard = now
            return receive(message, now: now)
        case .tick(let step, let phase):
            return tick(step: step, phase: phase, now: now)
        case .startPressed:
            guard role == .host, stage == .ready else { return [] }
            return start()
        case .flapped(let step):
            guard inRace else { return [] }
            return [.send(.flap(step: step))]
        case .crashed(let step, let score):
            guard inRace, myCrash == nil else { return [] }
            myCrash = RaceScore(step: step, score: score)
            return [.send(.crashed(step: step, score: score))] + settle()
        case .pausePressed:
            guard stage == .racing, pausesLeft > 0 else { return [] }
            return pause(atStep: localStep + Params.pauseLeadSteps, now: now)
        case .folded:
            guard stage == .racing || stage == .countdown else { return [] }
            guard pausesLeft > 0 else { return end(.youLeft, bye: .left) }
            return pause(atStep: localStep, now: now)
        case .resumePressed:
            guard stage == .paused(byMe: true) else { return [] }
            stage = .countdown
            pausedSince = nil
            bothPaused = false
            return [.send(.resume(inMs: Self.countdownMs)), .resume(countdownSteps: Params.countdownSteps)]
        case .rematchPressed:
            guard case .result = stage, !rematchMine else { return [] }
            rematchMine = true
            return [.send(.rematch)] + rematchIfBoth()
        case .leave(let reason):
            return end(.youLeft, bye: reason)
        }
    }

    private mutating func receive(_ message: RaceMessage, now: Double) -> [RaceCommand] {
        switch message {
        case .hello(let proto, let rules, let name, let hero):
            guard role == .host, let map, let world else { return [] }
            guard opponent == nil else { return [.send(.refuse(.full))] }
            guard proto == RaceMessage.protocolVersion, rules == Params.rulesVersion else {
                return [.send(.refuse(.version))] + end(.versionMismatch, bye: nil)
            }
            opponent = RacePlayer(name: name, hero: hero)
            stage = .ready
            return [.send(.welcome(name: me.name, hero: me.hero, map: map, width: world.width))]
        case .welcome(let name, let hero, let map, let width):
            guard role == .guest, stage == .waiting else { return [] }
            opponent = RacePlayer(name: name, hero: hero)
            self.map = map
            world = World(width: width)
            stage = .ready
            return []
        case .refuse(let reason):
            guard role == .guest else { return [] }
            return end(reason == .version ? .versionMismatch : .full, bye: nil)
        case .ping(let t):
            return [.send(.pong(t: t))]
        case .pong(let t):
            rtt = max(0, now - t)
            return []
        case .start(let seed, let inMs):
            guard role == .guest, stage == .ready || (rematchMine && rematchTheirs) else { return [] }
            return begin(seed: seed, countdownSteps: countdownSteps(inMs))
        case .flap(let step):
            guard inRace, ghost != nil else { return [] }
            guard step > lastTheirFlap, step <= localStep + Self.flapAhead else { return end(.desync, bye: .desync) }
            lastTheirFlap = step
            ghost?.add(flap: step)
            return []
        case .pause(let atStep):
            guard atStep <= localStep + Self.pauseAhead else { return end(.desync, bye: .desync) }
            switch stage {
            case .countdown, .racing:
                stage = .paused(byMe: false)
                pausedSince = now
                return [.freeze(atStep: atStep)]
            case .paused(byMe: true):
                // Both pressed P at once: each run keeps the earlier step, and either player may resume.
                bothPaused = true
                return [.freeze(atStep: atStep)]
            case .waiting, .ready, .paused(byMe: false), .result, .over:
                return []
            }
        case .resume(let inMs):
            // Only the player who paused resumes (§6). A resume of this Mac's own pause is ignored, not a desync.
            guard stage == .paused(byMe: false) || (stage == .paused(byMe: true) && bothPaused) else { return [] }
            stage = .countdown
            pausedSince = nil
            bothPaused = false
            return [.resume(countdownSteps: countdownSteps(inMs))]
        case .crashed(let step, let score):
            guard inRace, theirCrash == nil, var g = ghost else { return [] }
            g.advance(to: step)
            guard g.state.crashStep == step, g.state.score == score else { return end(.desync, bye: .desync) }
            ghost = g
            theirCrash = RaceScore(step: step, score: score)
            return (myCrash == nil ? [.notice(.opponentCrashed(score: score))] : []) + settle()
        case .rematch:
            guard case .result = stage, !rematchTheirs else { return [] }
            rematchTheirs = true
            return rematchIfBoth()
        case .bye(let reason):
            return end(reason == .desync ? .desync : .opponentLeft, bye: nil)
        }
    }

    private mutating func tick(step: Int, phase: Phase, now: Double) -> [RaceCommand] {
        localStep = step
        if stage == .countdown, phase == .running || phase == .crashed { stage = .racing }
        if inRace { ghost?.advance(to: step) }
        var out: [RaceCommand] = []
        if connected {
            if opponent != nil {
                // 5 quick pings measure the round trip; then one a second is the heartbeat.
                let gap = lobbyPingsLeft > 0 ? Self.lobbyPingGap : Self.heartbeat
                if now - lastPing >= gap - 1e-9 {
                    lastPing = now
                    lobbyPingsLeft = max(0, lobbyPingsLeft - 1)
                    out.append(.send(.ping(t: now)))
                }
            }
            if now - lastHeard >= Self.timeout { return out + end(.opponentLeft, bye: .timeout) }
        }
        if case .paused(let byMe) = stage, let since = pausedSince, now - since >= Self.pauseLimit {
            return out + end(byMe ? .youLeft : .opponentLeft, bye: .pauseLimit)
        }
        return out
    }

    private mutating func pause(atStep: Int, now: Double) -> [RaceCommand] {
        pausesLeft -= 1
        stage = .paused(byMe: true)
        pausedSince = now
        bothPaused = false
        return [.send(.pause(atStep: atStep)), .freeze(atStep: atStep)]
    }

    /// Both crashed: the higher score wins, equal scores tie.
    private mutating func settle() -> [RaceCommand] {
        guard let mine = myCrash, let theirs = theirCrash else { return [] }
        stage = .result(mine.score > theirs.score ? .win : mine.score < theirs.score ? .lose : .tie)
        pausedSince = nil
        return []
    }

    private mutating func rematchIfBoth() -> [RaceCommand] {
        guard rematchMine, rematchTheirs, role == .host else { return [] }
        return start()
    }

    /// Host: a fresh seed on the same map, a full countdown here, and `start` for the guest.
    private mutating func start() -> [RaceCommand] {
        let seed = seeds.next()
        return [.send(.start(seed: seed, inMs: Self.countdownMs))] + begin(seed: seed, countdownSteps: Params.countdownSteps)
    }

    private mutating func begin(seed: UInt64, countdownSteps: Int) -> [RaceCommand] {
        guard let world else { return [] }
        ghost = Ghost(seed: seed, world: world)
        myCrash = nil
        theirCrash = nil
        rematchMine = false
        rematchTheirs = false
        lastTheirFlap = -1
        pausesLeft = Self.pausesPerRace
        pausedSince = nil
        bothPaused = false
        localStep = 0
        stage = .countdown
        return [.startGame(seed: seed, countdownSteps: countdownSteps)]
    }

    /// The steps left of a countdown the other Mac began `inMs` before its end, less the half round trip the
    /// message took to get here.
    public func countdownSteps(_ inMs: Int) -> Int {
        let ms = Double(inMs) - (rtt ?? 0) * 1_000 / 2
        return min(Params.countdownSteps, max(1, Int((ms / 1_000 / Params.fixedStep).rounded())))
    }

    private mutating func end(_ reason: RaceEnd, bye: ByeReason?) -> [RaceCommand] {
        stage = .over(reason)
        pausedSince = nil
        return (bye.map { [RaceCommand.send(.bye($0))] } ?? []) + [.close]
    }
}
