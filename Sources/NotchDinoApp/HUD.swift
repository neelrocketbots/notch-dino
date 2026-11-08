import RunnerCore

/// What the band's ears show. Fractions are rounded up to 1/20 so the SwiftUI HUD only changes a few times a second,
/// never every frame.
public struct HUD: Equatable, Sendable {
    public enum Ring: Equatable, Sendable { case good, bad }
    public struct Chip: Equatable, Sendable {
        public var pickup: Pickup
        public var fraction: Double
        public init(pickup: Pickup, fraction: Double) { self.pickup = pickup; self.fraction = fraction }
        /// The draining ring around a timed chip: amber for a power-up, red for a power-down. Charges have none.
        public var ring: Ring? { pickup.duration == 0 ? nil : pickup.isGood ? .good : .bad }
    }
    public var score: Int
    public var best: Int
    public var chips: [Chip]

    public static let empty = HUD(score: 0, best: 0, chips: [])

    public static func make(_ s: GameState) -> HUD {
        var chips: [Chip] = []
        if s.effects.emberCharge { chips.append(Chip(pickup: .ember, fraction: 1)) }
        if s.effects.feather { chips.append(Chip(pickup: .feather, fraction: 1)) }
        for p in [Pickup.updraft, .tiny, .stoneScale, .hiccups, .ashCloud, .rush, .bloat] {
            let f = s.effects.fraction(p)
            if f > 0 { chips.append(Chip(pickup: p, fraction: min(1, (f * 20).rounded(.up) / 20))) }
        }
        return HUD(score: s.score, best: s.best, chips: chips)
    }
}
