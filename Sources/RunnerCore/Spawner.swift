/// Where gates go. Pure: everything comes in as arguments, randomness from the caller's RNG.
public enum Spawner {
    public static func gap(forIndex i: Int) -> Double {
        let t = min(1, Double(i) / Double(Params.gapRampGates))
        return Params.worldHeight * (Params.gapStart + (Params.gapMin - Params.gapStart) * t)
    }

    /// The 6th, 12th, 18th… gate (0-based index 5, 11, 17…).
    public static func isFork(index i: Int) -> Bool { (i + 1) % Params.forkEvery == 0 }

    /// The furthest a gap centre may move from the previous one: what Pip can climb between gates, capped.
    public static func maxCentreShift(speed: Double) -> Double {
        min(Params.maxShiftCap, Params.climbRate * Params.spacing / speed)
    }

    public static func centreRange(gap: Double) -> ClosedRange<Double> {
        (Params.topMargin + gap / 2)...(Params.ground - Params.groundMargin - gap / 2)
    }

    /// The pickup that `u` (uniform in [0, 1)) lands on when `list` is laid end to end, each taking its weight's share.
    public static func weightedPick(_ list: [Pickup], weights: [Pickup: Double], u: Double) -> Pickup {
        let total = list.reduce(0) { $0 + (weights[$1] ?? 0) }
        var t = u * total
        for p in list {
            let w = weights[p] ?? 0
            if t < w { return p }
            t -= w
        }
        return list[list.count - 1]   // only reached through rounding at u ≈ 1
    }

    /// One opening always holds a power-up; the other a power-down (55%), a second power-up (20%) or nothing (25%).
    /// Each pick is weighted (`Params.goodWeights`, `Params.badWeights`) and takes exactly one draw, as in v1, so a
    /// seed's gate geometry is unchanged.
    public static func rollItems(_ rng: inout SeededRandom) -> [Item] {
        func good() -> Pickup { weightedPick(Pickup.good, weights: Params.goodWeights, u: rng.unit()) }
        func bad() -> Pickup { weightedPick(Pickup.bad, weights: Params.badWeights, u: rng.unit()) }
        let first = good()
        let roll = rng.unit()
        let second: Pickup? = roll < 0.55 ? bad() : roll < 0.75 ? good() : nil
        let firstUpper = rng.unit() < 0.5
        var items = [Item(side: firstUpper ? .upper : .lower, pickup: first)]
        if let second { items.append(Item(side: firstUpper ? .lower : .upper, pickup: second)) }
        return items
    }

    public static func makeGate(id: Int, index: Int, x: Double, lastCentre: Double, speed: Double,
                                rng: inout SeededRandom) -> Gate {
        if isFork(index: index) {
            let gap = Params.worldHeight * Params.forkGap
            let range = centreRange(gap: gap)
            let shift = maxCentreShift(speed: speed)
            var centre = range.lowerBound + rng.unit() * (range.upperBound - range.lowerBound)
            centre = min(max(centre, lastCentre - shift), lastCentre + shift)
            centre = min(max(centre, range.lowerBound), range.upperBound)
            return Gate(id: id, x: x, centre: centre, gap: gap, chunk: Params.worldHeight * Params.chunk,
                        items: rollItems(&rng))
        }
        let gap = Spawner.gap(forIndex: index)
        let range = centreRange(gap: gap)
        let shift = maxCentreShift(speed: speed)
        var centre = range.lowerBound + rng.unit() * (range.upperBound - range.lowerBound)
        centre = min(max(centre, lastCentre - shift), lastCentre + shift)
        centre = min(max(centre, range.lowerBound), range.upperBound)
        return Gate(id: id, x: x, centre: centre, gap: gap, chunk: 0, items: [])
    }
}
