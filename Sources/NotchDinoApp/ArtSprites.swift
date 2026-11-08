import CoreGraphics
import RunnerCore

enum PipPose: CaseIterable { case wingUp, wingDown, crash }

extension Art {
    // MARK: Pip

    static let pipSize = CGSize(width: 52, height: 44)
    static let pipOrigin = CGPoint(27, 25)

    static func pip(_ pose: PipPose, hero: Hero = .pip) -> CGImage {
        image(pipSize) { ctx in
            ctx.translateBy(x: pipOrigin.x, y: pipOrigin.y)
            drawPip(ctx, pose, hero: hero)
        }
    }

    static func wing(up: Bool) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(-1, -3))
        if up {
            p.addQuadCurve(to: CGPoint(-7, -25), control: CGPoint(-4, -16))
            p.addQuadCurve(to: CGPoint(-13, -17), control: CGPoint(-10, -18))
            p.addQuadCurve(to: CGPoint(-17, -11), control: CGPoint(-14, -12))
            p.addQuadCurve(to: CGPoint(-18, -4), control: CGPoint(-15, -6))
            p.addQuadCurve(to: CGPoint(-6, 0), control: CGPoint(-10, -3))
        } else {
            p.addQuadCurve(to: CGPoint(-10, 16), control: CGPoint(-6, 6))
            p.addQuadCurve(to: CGPoint(-15, 10), control: CGPoint(-12, 10))
            p.addQuadCurve(to: CGPoint(-19, 4), control: CGPoint(-15, 5))
            p.addQuadCurve(to: CGPoint(-17, -2), control: CGPoint(-15, 1))
            p.addQuadCurve(to: CGPoint(-6, -2), control: CGPoint(-9, -3))
        }
        p.closeSubpath()
        return p
    }

    static func wingRibs(up: Bool) -> CGPath {
        let p = CGMutablePath()
        let root = up ? CGPoint(-2, -4) : CGPoint(-3, -2)
        let tips = up ? [CGPoint(-13, -17), CGPoint(-17, -11), CGPoint(-18, -4)]
                      : [CGPoint(-15, 10), CGPoint(-19, 4), CGPoint(-17, -2)]
        for t in tips { p.move(to: root); p.addLine(to: t) }
        return p
    }

    static func drawPip(_ ctx: CGContext, _ pose: PipPose, hero: Hero = .pip) {
        let up = pose == .wingUp, p = hero.palette
        // far wing, behind the body
        ctx.saveGState(); ctx.translateBy(x: 4, y: 1); ctx.scaleBy(x: 0.7, y: 0.75); ctx.setAlpha(0.75)
        fill(ctx, wing(up: up), rgb(p.wingFar)); ctx.restoreGState()
        // tail and spade
        let tail = CGMutablePath(); tail.move(to: CGPoint(-8, 6)); tail.addQuadCurve(to: CGPoint(-21, 7), control: CGPoint(-15, 11))
        stroke(ctx, tail, rgb(p.body), width: 3.4)
        if hero == .nova {
            // a four-point star for a tail tip
            fill(ctx, polygon([CGPoint(-23, 2.5), CGPoint(-22, 6), CGPoint(-18.5, 7), CGPoint(-22, 8),
                               CGPoint(-23, 11.5), CGPoint(-24, 8), CGPoint(-27.5, 7), CGPoint(-24, 6)]), rgb(p.spike))
        } else {
            fill(ctx, polygon([CGPoint(-20, 7), CGPoint(-24, 3.5), CGPoint(-26, 8), CGPoint(-22, 10.5)]), rgb(p.spike))
        }
        // back spikes
        for (x, y, a) in [(-6.0, -4.0, -0.6), (-1.0, -5.5, -0.3)] as [(CGFloat, CGFloat, CGFloat)] {
            at(ctx, x, y, rotate: a) {
                let s = CGMutablePath(); s.move(to: CGPoint(-2, 1.5)); s.addQuadCurve(to: CGPoint(2, 1.5), control: CGPoint(0, -4)); s.closeSubpath()
                fill(ctx, s, rgb(p.spike))
            }
        }
        drawHeadgear(ctx, hero, p)
        // legs, body, head, snout with one top-lit gradient
        let body = CGMutablePath()
        body.addPath(CGPath(roundedRect: CGRect(x: -5, y: 10, width: 3.6, height: 4.4), cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
        body.addPath(CGPath(roundedRect: CGRect(x: 1.5, y: 10, width: 3.6, height: 4.4), cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
        body.addPath(ellipse(CGPoint(-1, 4), 10.5, 8.6))
        body.addPath(circle(CGPoint(8.5, -5.5), 7.8))
        body.addPath(ellipse(CGPoint(15, -2.5), 4.8, 3.6, 0.1))
        linear(ctx, clip: body, [(0, rgb(p.light)), (0.45, rgb(p.body)), (1, rgb(p.shade))],
               from: CGPoint(-6, -14), to: CGPoint(6, 14))
        // belly and plates
        fill(ctx, ellipse(CGPoint(3, 7), 6, 4.4, -0.2), rgb(p.belly, 0.9))
        for y in [5.0, 7.5, 10.0] as [CGFloat] {
            let l = CGMutablePath(); l.move(to: CGPoint(-1.5, y)); l.addQuadCurve(to: CGPoint(7.5, y - 0.8), control: CGPoint(3, y + 1.2))
            stroke(ctx, l, rgb(p.shade, 0.45), width: 0.7)
        }
        // near wing
        fill(ctx, wing(up: up), rgb(p.shade))
        stroke(ctx, wingRibs(up: up), rgb(p.rib, 0.6), width: 0.8)
        if hero == .nova {
            for (x, y) in (up ? [(-9.0, -13.0), (-14.0, -9.0), (-12.0, -4.0)] : [(-10.0, 9.0), (-15.0, 5.0), (-12.0, 1.0)]) as [(CGFloat, CGFloat)] {
                fill(ctx, circle(CGPoint(x, y), 0.8), white(0.85))
            }
        }
        // face
        if pose == .crash {
            let x = CGMutablePath()
            x.move(to: CGPoint(9.6, -8.4)); x.addLine(to: CGPoint(12.6, -5.4))
            x.move(to: CGPoint(12.6, -8.4)); x.addLine(to: CGPoint(9.6, -5.4))
            stroke(ctx, x, rgb(Palette.eye), width: 1.2)
        } else {
            fill(ctx, circle(CGPoint(11, -6.5), 2.3), rgb(Palette.eye))
            fill(ctx, circle(CGPoint(11.8, -7.4), 0.8), white(1))
        }
        fill(ctx, circle(CGPoint(18, -4), 0.7), rgb(p.shade))
        let smile = CGMutablePath(); smile.move(to: CGPoint(12.5, -0.6))
        smile.addQuadCurve(to: CGPoint(18.5, -0.8), control: CGPoint(15.5, pose == .crash ? -1.6 : 0.6))
        stroke(ctx, smile, rgb(p.shade), width: 0.9)
        stroke(ctx, arc(CGPoint(8.5, -5.5), 5.6, from: .pi * 1.1, to: .pi * 1.5), white(0.5), width: 1.3)
    }

    /// Pip's cream horns, Moss's leaf crest, Nova's gold swept horns.
    static func drawHeadgear(_ ctx: CGContext, _ hero: Hero, _ p: HeroPalette) {
        switch hero {
        case .pip, .nova:
            let sweep: CGFloat = hero == .nova ? -0.35 : 0
            for (x, y, a) in [(5.5, -12.5, -0.7), (10.0, -13.5, -0.35)] as [(CGFloat, CGFloat, CGFloat)] {
                at(ctx, x, y, rotate: a + sweep) {
                    let h = CGMutablePath(); h.move(to: CGPoint(-1.6, 1.5))
                    h.addQuadCurve(to: CGPoint(-3.5, hero == .nova ? -7.5 : -6), control: CGPoint(-1, -4.5))
                    h.addQuadCurve(to: CGPoint(1.8, 1.5), control: CGPoint(1, -3.5)); h.closeSubpath()
                    fill(ctx, h, rgb(p.horn))
                }
            }
        case .moss:
            for (x, y, a, len) in [(3.5, -11.5, -0.9, 7.0), (7.5, -13.5, -0.45, 8.5), (11.5, -13.0, 0.05, 6.5)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                at(ctx, x, y, rotate: a) {
                    let leaf = CGMutablePath(); leaf.move(to: CGPoint(0, 1.5))
                    leaf.addQuadCurve(to: CGPoint(0, -len), control: CGPoint(-3.2, -len * 0.4))
                    leaf.addQuadCurve(to: CGPoint(0, 1.5), control: CGPoint(3.2, -len * 0.4))
                    fill(ctx, leaf, rgb(p.horn))
                    let vein = CGMutablePath(); vein.move(to: CGPoint(0, 1)); vein.addLine(to: CGPoint(0, -len + 1.5))
                    stroke(ctx, vein, rgb(p.shade, 0.6), width: 0.5)
                }
            }
        }
    }

    /// Grey patches for Stone scale, in Pip's frame.
    static func stonePatches() -> CGImage {
        image(pipSize) { ctx in
            ctx.translateBy(x: pipOrigin.x, y: pipOrigin.y)
            for (x, y, r) in [(-4.0, 2.0, 4.0), (3.0, 8.0, 3.0), (-8.0, 6.0, 2.6), (7.0, -9.0, 2.4)] as [(CGFloat, CGFloat, CGFloat)] {
                fill(ctx, ellipse(CGPoint(x, y), r, r * 0.8, 0.4), rgba(110, 100, 102, 0.75))
            }
        }
    }

    static func puff() -> CGImage {
        image(CGSize(width: 14, height: 10)) { ctx in
            for (x, y, r) in [(3.0, 5.0, 2.2), (7.0, 3.0, 1.6), (5.0, 8.0, 1.3)] as [(CGFloat, CGFloat, CGFloat)] {
                fill(ctx, circle(CGPoint(x, y), r), rgba(220, 222, 228, 0.6))
            }
        }
    }

    /// Fire breath cone; the snout end is at (0, 8).
    static func breath() -> CGImage {
        image(CGSize(width: 34, height: 18)) { ctx in
            let p = CGMutablePath(); p.move(to: CGPoint(0, 8))
            p.addQuadCurve(to: CGPoint(31, 7), control: CGPoint(16, 0))
            p.addQuadCurve(to: CGPoint(31, 15), control: CGPoint(19, 11))
            p.addQuadCurve(to: CGPoint(0, 10), control: CGPoint(16, 17)); p.closeSubpath()
            linear(ctx, clip: p, [(0, rgba(255, 245, 200, 1)), (0.4, rgba(255, 170, 60, 1)), (1, rgba(255, 80, 40, 0))],
                   from: CGPoint(0, 0), to: CGPoint(31, 0))
        }
    }

    /// Updraft wind streaks, drawn to the left of Pip.
    static func streaks() -> CGImage {
        image(CGSize(width: 40, height: 24)) { ctx in
            for (y, len) in [(2.0, 26.0), (10.0, 34.0), (19.0, 22.0)] as [(CGFloat, CGFloat)] {
                let l = CGMutablePath(); l.move(to: CGPoint(39, y)); l.addLine(to: CGPoint(39 - len, y + 1))
                stroke(ctx, l, rgba(255, 240, 225, 0.35), width: 1)
            }
        }
    }

    static func dot() -> CGImage { image(CGSize(width: 4, height: 4)) { fill($0, circle(CGPoint(2, 2), 2), white(1)) } }

    // MARK: Obsidian

    static let shardSize = CGSize(width: 18, height: 320)

    /// One shard, tip at the top. The ceiling's shards are this texture flipped. The map picks the material:
    /// obsidian, ice or thornwood.
    static func shard(map: MapTheme = .volcano) -> CGImage {
        let m = map.palette
        return image(shardSize) { ctx in
            let w: CGFloat = 18, base: CGFloat = 320, split = w * 0.42
            let outline = polygon([CGPoint(0, base), CGPoint(0, 12), CGPoint(split, 0), CGPoint(w * 0.78, 5), CGPoint(w, 15), CGPoint(w, base)])
            let left = polygon([CGPoint(0, base), CGPoint(0, 12), CGPoint(split, 0), CGPoint(split, base)])
            let right = polygon([CGPoint(split, base), CGPoint(split, 0), CGPoint(w * 0.78, 5), CGPoint(w, 15), CGPoint(w, base)])
            linear(ctx, clip: left, [(0, rgb(m.lit0)), (1, rgb(m.lit1))], from: CGPoint(0, 0), to: CGPoint(split, 0))
            linear(ctx, clip: right, [(0, rgb(m.dark0)), (0.6, rgb(m.dark1)), (1, rgb(m.dark2))],
                   from: CGPoint(split, 0), to: CGPoint(w, 0))
            ctx.saveGState(); ctx.addPath(outline); ctx.clip()
            var rng = SeededRandom(seed: 3)
            var t: CGFloat = 22 + CGFloat(rng.unit()) * 10
            while t < base {
                let r = CGMutablePath(); r.move(to: CGPoint(1, t)); r.addQuadCurve(to: CGPoint(split - 1, t - 1), control: CGPoint(4.5, t - 5))
                stroke(ctx, r, white(m.grain), width: 1)
                t += 24 + CGFloat(rng.unit()) * 14
            }
            switch map {
            case .volcano: break
            case .glacier:
                // frost glints scattered down the crystal
                var y: CGFloat = 30
                while y < base {
                    fill(ctx, circle(CGPoint(2 + CGFloat(rng.unit()) * (w - 4), y), 0.9), white(0.8))
                    y += 18 + CGFloat(rng.unit()) * 22
                }
            case .grove:
                // bark grain down the trunk, and knots
                for x in [w * 0.62, w * 0.86] {
                    let g = CGMutablePath(); g.move(to: CGPoint(x, 18)); g.addLine(to: CGPoint(x, base))
                    stroke(ctx, g, rgba(0, 0, 0, 0.35), width: 0.8)
                }
                var y: CGFloat = 48
                while y < base {
                    fill(ctx, ellipse(CGPoint(w * 0.7, y), 1.8, 3), rgba(0, 0, 0, 0.4))
                    y += 60 + CGFloat(rng.unit()) * 40
                }
            }
            let edge = CGMutablePath(); edge.move(to: CGPoint(1.2, base)); edge.addLine(to: CGPoint(1.2, 11))
            stroke(ctx, edge, white(0.32), width: 1)
            let facet = CGMutablePath(); facet.move(to: CGPoint(split, 1)); facet.addLine(to: CGPoint(split, 40))
            stroke(ctx, facet, white(0.22), width: 1)
            ctx.restoreGState()
            fill(ctx, polygon([CGPoint(split, 0), CGPoint(split - 3, 5), CGPoint(split - 0.6, 6)]), white(0.7))
            stroke(ctx, outline, white(0.14), width: 1)
        }
    }

    /// Molten overlay for the tip of a melting shard (tip at the top), faded by the scene.
    static func hotShard() -> CGImage {
        image(CGSize(width: 18, height: 60)) { ctx in
            let p = polygon([CGPoint(0, 60), CGPoint(0, 12), CGPoint(7.56, 0), CGPoint(14, 5), CGPoint(18, 15), CGPoint(18, 60)])
            linear(ctx, clip: p, [(0, rgba(255, 220, 140, 0.95)), (0.35, rgba(255, 110, 50, 0.8)), (1, rgba(255, 80, 40, 0))],
                   from: CGPoint(0, 0), to: CGPoint(0, 46))
        }
    }

    static let chunkSize = CGSize(width: 26, height: 29)

    static func chunk(map: MapTheme = .volcano) -> CGImage {
        let m = map.palette
        return image(chunkSize) { ctx in
            let w: CGFloat = 26, h: CGFloat = 29, cx = w / 2, cy = h / 2
            let pts = [(-0.5, -0.22), (-0.08, -0.5), (0.5, -0.3), (0.5, 0.22), (0.1, 0.5), (-0.5, 0.32)]
                .map { CGPoint(cx + CGFloat($0.0) * w, cy + CGFloat($0.1) * h) }
            let outline = polygon(pts)
            fill(ctx, outline, rgb(m.chunkFill))
            linear(ctx, clip: polygon([pts[0], pts[1], pts[4], pts[5]]), [(0, rgb(m.chunkLit0)), (1, rgb(m.chunkLit1))],
                   from: CGPoint(cx - w / 2, cy - h / 2), to: CGPoint(cx, cy + h / 2))
            let facet = CGMutablePath(); facet.move(to: pts[1]); facet.addLine(to: pts[4])
            stroke(ctx, facet, white(0.3), width: 1)
            stroke(ctx, outline, white(0.16), width: 1)
            fill(ctx, circle(CGPoint(pts[1].x - 1, pts[1].y + 2.5), 1.1), white(0.75))
        }
    }

    // MARK: Pickups

    static let pickupSize = CGSize(width: 34, height: 34)

    static func pickup(_ p: Pickup) -> CGImage {
        image(pickupSize) { ctx in
            ctx.translateBy(x: 17, y: 17)
            switch p {
            case .ember: drawEmber(ctx)
            case .egg: drawEgg(ctx)
            case .updraft: drawUpdraft(ctx)
            case .ashCloud: drawAsh(ctx)
            case .stoneScale: drawStone(ctx)
            case .hiccups: drawHiccups(ctx)
            }
        }
    }

    static func warmHalo(_ ctx: CGContext, _ r: CGFloat, _ a: CGFloat = 0.45) {
        radial(ctx, at: .zero, radius: r, [(0, rgba(255, 190, 110, a)), (1, rgba(255, 110, 60, 0))])
    }

    static func warnRing(_ ctx: CGContext) {
        ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [2.5, 2.5])
        stroke(ctx, circle(.zero, 10), rgba(255, 90, 60, 0.6), width: 1); ctx.restoreGState()
    }

    static func drawEmber(_ ctx: CGContext) {
        radial(ctx, at: .zero, radius: 16, [(0, rgba(255, 170, 70, 0.55)), (1, rgba(255, 90, 40, 0))])
        let f = CGMutablePath(); f.move(to: CGPoint(0, 5))
        f.addCurve(to: CGPoint(-0.5, -8), control1: CGPoint(-5, 4), control2: CGPoint(-5, -2))
        f.addCurve(to: CGPoint(4, 2), control1: CGPoint(1, -3), control2: CGPoint(5, -1))
        f.addCurve(to: CGPoint(0, 5), control1: CGPoint(3.5, 4.5), control2: CGPoint(2, 5)); f.closeSubpath()
        linear(ctx, clip: f, [(0, rgb(0xFFF0B8)), (0.5, rgb(0xFFB13B)), (1, rgb(0xFF5A3C))], from: CGPoint(0, -8), to: CGPoint(0, 5))
        fill(ctx, ellipse(CGPoint(0.4, 1.5), 1.6, 2.4), rgba(255, 250, 225, 0.9))
    }

    static func drawEgg(_ ctx: CGContext) {
        warmHalo(ctx, 15)
        linear(ctx, clip: ellipse(CGPoint(0, 0.5), 5, 6.6), [(0, rgb(0xFFF1C2)), (0.5, rgb(0xF2B65A)), (1, rgb(0xC9762E))],
               from: CGPoint(-4, -7), to: CGPoint(4, 7))
        for (x, y, r) in [(-1.8, -1.5, 0.8), (1.6, 1.0, 0.9), (-0.6, 3.0, 0.6), (2.0, -3.0, 0.6)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgba(120, 60, 20, 0.55))
        }
        stroke(ctx, arc(.zero, 4, from: .pi * 1.15, to: .pi * 1.45), white(0.7), width: 1)
    }

    static func drawUpdraft(_ ctx: CGContext) {
        warmHalo(ctx, 15, 0.35)
        fill(ctx, circle(.zero, 7.5), rgba(255, 240, 225, 0.12))
        stroke(ctx, circle(.zero, 7.5), rgba(255, 240, 225, 0.8), width: 1)
        for (y, w) in [(-3.0, 7.0), (0.0, 9.0), (3.0, 6.0)] as [(CGFloat, CGFloat)] {
            let l = CGMutablePath(); l.move(to: CGPoint(-w / 2, y + 1)); l.addQuadCurve(to: CGPoint(w / 2, y), control: CGPoint(0, y - 2))
            stroke(ctx, l, rgba(255, 240, 225, 0.8), width: 1.4)
        }
    }

    static func drawAsh(_ ctx: CGContext) {
        warnRing(ctx)
        for (x, y, r) in [(-3.5, 1.0, 3.6), (0.0, -1.5, 4.4), (3.6, 1.0, 3.4), (0.0, 2.4, 3.4)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgb(0x5C5254))
        }
        fill(ctx, ellipse(CGPoint(0, 3.4), 6, 2), rgb(0x3A3234))
    }

    static func drawStone(_ ctx: CGContext) {
        warnRing(ctx)
        fill(ctx, polygon([CGPoint(-6, 1), CGPoint(-3, -5), CGPoint(3, -5.5), CGPoint(6.5, -1), CGPoint(4, 5), CGPoint(-3.5, 5)]), rgb(0x5E5658))
        fill(ctx, polygon([CGPoint(-3, -5), CGPoint(3, -5.5), CGPoint(1, 0), CGPoint(-6, 1)]), rgb(0x7A7072))
        let crack = CGMutablePath(); crack.move(to: CGPoint(1, 0)); crack.addLine(to: CGPoint(4, 5))
        stroke(ctx, crack, rgba(0, 0, 0, 0.35), width: 0.8)
    }

    static func drawHiccups(_ ctx: CGContext) {
        warnRing(ctx)
        for (x, y, r) in [(-2.0, 2.0, 4.2), (3.4, -2.6, 2.8), (4.2, 3.4, 1.6)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgba(138, 128, 130, 0.18))
            stroke(ctx, circle(CGPoint(x, y), r), rgb(0x8A8082), width: 1.2)
        }
        fill(ctx, circle(CGPoint(-3.4, 0.6), 1), white(0.5))
    }
}
