import Testing
@testable import RunnerCore

@Test func sameSeedSameSequence() {
    var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
    for _ in 0..<100 { #expect(a.next() == b.next()) }
}

@Test func differentSeedsDiffer() {
    var a = SeededRandom(seed: 1), b = SeededRandom(seed: 2)
    #expect(a.next() != b.next())
}

@Test func unitIsInHalfOpenRange() {
    var r = SeededRandom(seed: 7)
    for _ in 0..<10_000 { let u = r.unit(); #expect(u >= 0 && u < 1) }
}

@Test func worldPipSitsAtQuarterWidth() {
    let w = World.forField(width: 421, height: 240)
    #expect(abs(w.width - 200 * 421 / 240) < 1e-9)
    #expect(abs(w.pipX - w.width * 0.25) < 1e-9)
}

@Test func gateGeometry() {
    let g = Gate(id: 0, x: 10, centre: 94, gap: 150, chunk: 24, items: [])
    #expect(g.isFork)
    #expect(g.gapTop == 19 && g.gapBottom == 169)
    #expect(g.openingHeight == 63)
    #expect(g.itemY(.upper) == 94 - 12 - 31.5)
    #expect(g.itemY(.lower) == 94 + 12 + 31.5)
    #expect(g.itemX == 10 + Params.gateWidth / 2)
}

@Test func effectsCancelAndRefresh() {
    var e = Effects()
    e.apply(.updraft); #expect(e.updraft == 5 && e.gravityScale == 0.6)
    e.apply(.stoneScale); #expect(e.updraft == 0 && e.stoneScale == 5 && e.gravityScale == 1.35)
    e.tick(2); e.apply(.stoneScale); #expect(e.stoneScale == 5)  // refresh, not stack
    e.apply(.ember); e.apply(.ember); #expect(e.emberCharge)
    #expect(e.fraction(.stoneScale) == 1)
}
