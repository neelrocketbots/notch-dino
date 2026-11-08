import Testing
@testable import RunnerCore

@Test func gapRampsFrom45To32Percent() {
    #expect(Spawner.gap(forIndex: 0) == 90)
    #expect(abs(Spawner.gap(forIndex: 20) - 77) < 1e-9)
    #expect(abs(Spawner.gap(forIndex: 40) - 64) < 1e-9)
    #expect(abs(Spawner.gap(forIndex: 400) - 64) < 1e-9)
}

@Test func everySixthGateIsAFork() {
    let forks = (0..<24).filter(Spawner.isFork(index:))
    #expect(forks == [5, 11, 17, 23])
}

@Test func forkGateShape() {
    var rng = SeededRandom(seed: 3)
    let g = Spawner.makeGate(id: 5, index: 5, x: 0, lastCentre: 96, speed: 150, rng: &rng)
    #expect(g.isFork)
    #expect(g.gap == 150 && g.chunk == 24)
    #expect(Spawner.centreRange(gap: 150).contains(g.centre))
    #expect(g.openingHeight >= 2 * Params.pipRadius + 20)
}

@Test func everyGapIsReachable() {
    // 10,000 seeds x 200 gates: centre shift within reach, gap inside the field.
    var violations = 0
    for seed in UInt64(0)..<10_000 {
        var rng = SeededRandom(seed: seed)
        var last = Params.idleY
        for i in 0..<200 {
            let speed = min(Params.speedMax, Params.speedStart + Params.speedPerGate * Double(i))
            let g = Spawner.makeGate(id: i, index: i, x: 0, lastCentre: last, speed: speed, rng: &rng)
            if abs(g.centre - last) > Spawner.maxCentreShift(speed: speed) + 1e-9 { violations += 1 }
            if g.gapTop < 0 || g.gapBottom > Params.ground { violations += 1 }
            last = g.centre
        }
    }
    #expect(violations == 0)
}

@Test func forkAlwaysOffersOnePowerUp() {
    var rng = SeededRandom(seed: 11)
    var bad = 0, good2 = 0, empty = 0
    let n = 10_000
    for _ in 0..<n {
        let items = Spawner.rollItems(&rng)
        #expect(items.contains { $0.pickup.isGood })
        #expect(Set(items.map(\.side)).count == items.count)
        if items.count == 1 { empty += 1 } else if items.allSatisfy(\.pickup.isGood) { good2 += 1 } else { bad += 1 }
    }
    #expect(abs(Double(bad) / Double(n) - 0.55) < 0.02)
    #expect(abs(Double(good2) / Double(n) - 0.20) < 0.02)
    #expect(abs(Double(empty) / Double(n) - 0.25) < 0.02)
}

@Test func openingsUseTheWholeFieldHeight() {
    // Early gaps (90 units) must reach near the ceiling and the ground, not just the middle third.
    var lowest = Double.infinity, highest = -Double.infinity
    var forkCentres = Set<Int>()
    for seed in UInt64(0)..<2_000 {
        var rng = SeededRandom(seed: seed)
        var last = Params.idleY
        for i in 0..<12 {
            let g = Spawner.makeGate(id: i, index: i, x: 0, lastCentre: last, speed: Params.speedStart, rng: &rng)
            if g.isFork { forkCentres.insert(Int(g.centre.rounded())) } else if i < 5 {
                lowest = min(lowest, g.centre); highest = max(highest, g.centre)
            }
            last = g.centre
        }
    }
    #expect(lowest <= 58)     // gap top within ~13 units of the ceiling
    #expect(highest >= 132)   // gap bottom within ~11 units of the ground
    #expect(forkCentres.count > 5)  // fork openings are not always dead centre
}

// MARK: Weighted fork odds

@Test func everyPickupHasAPositiveWeight() {
    #expect(Set(Params.goodWeights.keys) == Set(Pickup.good) && Pickup.good.allSatisfy { Params.goodWeights[$0]! > 0 })
    #expect(Set(Params.badWeights.keys) == Set(Pickup.bad) && Pickup.bad.allSatisfy { Params.badWeights[$0]! > 0 })
}

@Test func weightedPickLaysTheListEndToEnd() {
    // good weights 3, 3, 2, 1.5, 1.5 out of 11
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 0) == .ember)
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 2.99 / 11) == .ember)
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 3.01 / 11) == .egg)
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 7.9 / 11) == .updraft)
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 8.1 / 11) == .feather)
    #expect(Spawner.weightedPick(Pickup.good, weights: Params.goodWeights, u: 0.999_999) == .tiny)
}

@Test func forkPicksMatchTheirWeights() {
    var rng = SeededRandom(seed: 2026)
    var good: [Pickup: Int] = [:], bad: [Pickup: Int] = [:]
    for _ in 0..<100_000 {
        for item in Spawner.rollItems(&rng) {
            if item.pickup.isGood { good[item.pickup, default: 0] += 1 } else { bad[item.pickup, default: 0] += 1 }
        }
    }
    for (counts, weights) in [(good, Params.goodWeights), (bad, Params.badWeights)] {
        let n = Double(counts.values.reduce(0, +)), total = weights.values.reduce(0, +)
        for (p, w) in weights {
            let share = Double(counts[p, default: 0]) / n
            #expect(abs(share - w / total) < 0.01, "\(p): \(share) vs \(w / total)")
        }
    }
}

/// The v1 roll, kept here as the reference: uniform picks over three-item lists.
private func v1RollItems(_ rng: inout SeededRandom) -> [Item] {
    let good: [Pickup] = [.ember, .egg, .updraft], bad: [Pickup] = [.ashCloud, .stoneScale, .hiccups]
    func pick(_ list: [Pickup]) -> Pickup { list[min(list.count - 1, Int(rng.unit() * Double(list.count)))] }
    let first = pick(good)
    let roll = rng.unit()
    let second: Pickup? = roll < 0.55 ? pick(bad) : roll < 0.75 ? pick(good) : nil
    let firstUpper = rng.unit() < 0.5
    var items = [Item(side: firstUpper ? .upper : .lower, pickup: first)]
    if let second { items.append(Item(side: firstUpper ? .lower : .upper, pickup: second)) }
    return items
}

@Test func weightedRollDrawsAsOftenAsV1AndKeepsTheSides() {
    // Same draws per fork ⇒ the RNG is in the same state after every fork ⇒ every later gate is placed as in v1.
    for seed in UInt64(0)..<10_000 {
        var new = SeededRandom(seed: seed), old = SeededRandom(seed: seed)
        let a = Spawner.rollItems(&new), b = v1RollItems(&old)
        #expect(new == old)
        #expect(a.map(\.side) == b.map(\.side))
        #expect(a.map(\.pickup.isGood) == b.map(\.pickup.isGood))
    }
}
