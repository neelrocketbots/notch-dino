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

    /// One opening always holds a power-up; the other a power-down (55%), a second power-up (20%) or nothing (25%).
    public static func rollItems(_ rng: inout SeededRandom) -> [Item] {
        func pick(_ list: [Pickup]) -> Pickup { list[min(list.count - 1, Int(rng.unit() * Double(list.count)))] }
        let first = pick(Pickup.good)
        let roll = rng.unit()
        let second: Pickup? = roll < 0.55 ? pick(Pickup.bad) : roll < 0.75 ? pick(Pickup.good) : nil
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
