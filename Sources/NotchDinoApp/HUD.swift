import RunnerCore

/// What the band's ears show. Fractions are rounded up to 1/20 so the SwiftUI HUD only changes a few times a second,
/// never every frame.
public struct HUD: Equatable, Sendable {
    public struct Chip: Equatable, Sendable {
        public var pickup: Pickup
        public var fraction: Double
        public init(pickup: Pickup, fraction: Double) { self.pickup = pickup; self.fraction = fraction }
    }
    public var score: Int
    public var best: Int
    public var chips: [Chip]

    public static let empty = HUD(score: 0, best: 0, chips: [])

    public static func make(_ s: GameState) -> HUD {
        var chips: [Chip] = []
        if s.effects.emberCharge { chips.append(Chip(pickup: .ember, fraction: 1)) }
        for p in [Pickup.updraft, .stoneScale, .hiccups, .ashCloud] {
            let f = s.effects.fraction(p)
            if f > 0 { chips.append(Chip(pickup: p, fraction: min(1, (f * 20).rounded(.up) / 20))) }
        }
        return HUD(score: s.score, best: s.best, chips: chips)
    }
}
