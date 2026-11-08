import Foundation

public struct World: Equatable, Sendable {
    public var width: Double
    public init(width: Double) { self.width = width }
    /// A world exactly as wide as the field, 200 units tall.
    public static func forField(width: Double, height: Double) -> World { World(width: Params.worldHeight * width / height) }
    public var pipX: Double { width * Params.pipXFraction }
}

public enum Phase: Equatable, Sendable { case idle, running, paused, crashed }
public enum Side: Equatable, Sendable { case upper, lower }

public enum Pickup: String, CaseIterable, Equatable, Sendable {
    case ember, egg, updraft, ashCloud, stoneScale, hiccups
    public static let good: [Pickup] = [.ember, .egg, .updraft]
    public static let bad: [Pickup] = [.ashCloud, .stoneScale, .hiccups]
    public var isGood: Bool { Pickup.good.contains(self) }
    public var label: String {
        switch self {
        case .ember: "Ember"
        case .egg: "+5"
        case .updraft: "Updraft"
        case .ashCloud: "Ash cloud"
        case .stoneScale: "Stone scale"
        case .hiccups: "Hiccups!"
        }
    }
    /// Seconds a timed effect lasts; 0 for instant pickups.
    public var duration: Double {
        switch self {
        case .updraft: Params.updraftTime
        case .stoneScale: Params.stoneTime
        case .hiccups: Params.hiccupTime
        case .ashCloud: Params.ashTime
        case .ember, .egg: 0
        }
    }
}

public struct Item: Equatable, Sendable {
    public var side: Side
    public var pickup: Pickup
    public var taken: Bool
    public init(side: Side, pickup: Pickup, taken: Bool = false) { self.side = side; self.pickup = pickup; self.taken = taken }
}

public enum GatePart: Hashable, Sendable { case top, bottom, chunk }

public struct Gate: Equatable, Sendable, Identifiable {
    public var id: Int
    public var x: Double            // left edge
    public var centre: Double
    public var gap: Double
    public var chunk: Double        // 0 for a plain gate
    public var items: [Item]
    /// Seconds since each melted part began melting.
    public var melted: [GatePart: Double] = [:]
    public var passed = false

    public init(id: Int, x: Double, centre: Double, gap: Double, chunk: Double, items: [Item]) {
        self.id = id; self.x = x; self.centre = centre; self.gap = gap; self.chunk = chunk; self.items = items
    }

    public var isFork: Bool { chunk > 0 }
    public var gapTop: Double { centre - gap / 2 }
    public var gapBottom: Double { centre + gap / 2 }
    public var openingHeight: Double { (gap - chunk) / 2 }
    public var itemX: Double { x + Params.gateWidth / 2 }
    public func itemY(_ side: Side) -> Double {
        side == .upper ? centre - chunk / 2 - openingHeight / 2 : centre + chunk / 2 + openingHeight / 2
    }
}

public struct Effects: Equatable, Sendable {
    public var emberCharge = false
    public var updraft = 0.0, stoneScale = 0.0, hiccups = 0.0, ashCloud = 0.0
    public init() {}

    public var gravityScale: Double {
        (updraft > 0 ? Params.updraftGravity : 1) * (stoneScale > 0 ? Params.stoneGravity : 1)
    }

    public mutating func tick(_ dt: Double) {
        updraft = max(0, updraft - dt); stoneScale = max(0, stoneScale - dt)
        hiccups = max(0, hiccups - dt); ashCloud = max(0, ashCloud - dt)
    }

    /// Applies a pickup's lasting effect. Timers refresh rather than stack; Updraft and Stone scale cancel each other.
    /// The egg's points are handled by the runner.
    public mutating func apply(_ p: Pickup) {
        switch p {
        case .ember: emberCharge = true
        case .egg: break
        case .updraft: updraft = p.duration; stoneScale = 0
        case .stoneScale: stoneScale = p.duration; updraft = 0
        case .hiccups: hiccups = p.duration
        case .ashCloud: ashCloud = p.duration
        }
    }

    public func remaining(_ p: Pickup) -> Double {
        switch p {
        case .updraft: updraft
        case .stoneScale: stoneScale
        case .hiccups: hiccups
        case .ashCloud: ashCloud
        case .ember: emberCharge ? 1 : 0
        case .egg: 0
        }
    }

    /// Share of a timed effect left, 0…1.
    public func fraction(_ p: Pickup) -> Double { p.duration > 0 ? remaining(p) / p.duration : remaining(p) }
}

public struct GameState: Equatable, Sendable {
    public var world: World
    public var phase: Phase = .idle
    public var pipY = Params.idleY
    public var pipVY = 0.0
    public var gates: [Gate] = []
    public var nextGateX: Double
    public var lastCentre = Params.idleY
    public var spawned = 0
    public var distance = 0.0
    public var speed = Params.speedStart
    public var score = 0
    public var best: Int
    public var newBest = false
    public var effects = Effects()
    public var rng: SeededRandom
    public var time = 0.0
    public var accumulator = 0.0

    public init(world: World, seed: UInt64, best: Int) {
        self.world = world
        self.best = best
        self.rng = SeededRandom(seed: seed)
        self.nextGateX = world.width + Params.spawnAhead
    }
}

public enum GameEvent: Equatable, Sendable {
    case flapped
    case gatePassed(score: Int)
    case milestone(score: Int)
    case crashed(score: Int)
    case newBest(score: Int)
    case picked(Pickup)
    case melted(gateID: Int, part: GatePart)
    case hiccup
}
