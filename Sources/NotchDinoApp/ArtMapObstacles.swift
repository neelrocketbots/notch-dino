import CoreGraphics
import RunnerCore

/// Obstacle materials of the later maps. Each shard fills the same 18 × 320 pt tile as obsidian (tip at the top; the
/// ceiling's shard is this texture flipped), and each chunk the same 26 × 29 pt tile, so hitboxes are unchanged.
extension Art {
    /// Lit on the left, shaded on the right, like the obsidian faces.
    private static func sideLight(_ ctx: CGContext, clip: CGPath, width w: CGFloat) {
        linear(ctx, clip: clip, [(0, white(0.24)), (0.3, white(0.04)), (0.62, rgba(0, 0, 0, 0)), (1, rgba(0, 0, 0, 0.38))],
               from: CGPoint(0, 0), to: CGPoint(w, 0))
    }

    private static func unit(_ rng: inout SeededRandom) -> CGFloat { CGFloat(rng.unit()) }

    static func drawThemedShard(_ ctx: CGContext, map: MapTheme) {
        let m = map.palette, w: CGFloat = 18, base: CGFloat = 320
        var rng = SeededRandom(seed: 11)
        switch map {
        case .dunes:
            // sandstone: wind-cut strata, each band its own tone and inset
            let tones: [UInt32] = [m.lit0, 0xE4A86E, 0xEDB87E, 0xCF8C56, 0xF6D29E, 0xDA9C64]
            let body = CGMutablePath()
            var y: CGFloat = 0, i = 0
            while y < base {
                let h = 7 + unit(&rng) * 13, li = unit(&rng) * 1.6, ri = unit(&rng) * 1.6
                let r = CGRect(x: 0, y: y, width: w, height: min(h, base - y) + 0.6)
                let band = i == 0 ? CGPath(roundedRect: CGRect(x: 0.6, y: 0, width: w - 1.2, height: h + 4), cornerWidth: 4, cornerHeight: 4,
                                           transform: nil)
                                  : CGPath(rect: r, transform: nil)
                fill(ctx, band, rgb(tones[Int(unit(&rng) * CGFloat(tones.count))]))
                body.addPath(band)
                if i > 0 {
                    // wind-scoured edges, shaded inside the tile so the stone still fills it
                    ctx.setFillColor(rgba(110, 50, 24, 0.3))
                    ctx.fill(CGRect(x: 0, y: y, width: li, height: r.height)); ctx.fill(CGRect(x: w - ri, y: y, width: ri, height: r.height))
                    let l = CGMutablePath(); l.move(to: CGPoint(0, y)); l.addLine(to: CGPoint(w, y))
                    stroke(ctx, l, rgba(110, 50, 24, 0.45), width: 0.8)
                }
                // pits in the stone
                if unit(&rng) < 0.5 { fill(ctx, ellipse(CGPoint(3 + unit(&rng) * 12, y + h / 2), 1.2, 0.7), rgba(120, 60, 30, 0.35)) }
                y += h; i += 1
            }
            sideLight(ctx, clip: body, width: w)
            let cap = CGMutablePath(); cap.move(to: CGPoint(3, 1.2)); cap.addLine(to: CGPoint(w - 4, 1.2))
            stroke(ctx, cap, white(0.55), width: 1)
            stroke(ctx, body, rgba(90, 40, 20, 0.35), width: 0.6)

        case .skyisles:
            // a rock spire: jagged tip, ledges with moss, roots dangling down its face
            let outline = polygon([CGPoint(0, base), CGPoint(0, 15), CGPoint(2.5, 9), CGPoint(5, 10.5), CGPoint(8.5, 0),
                                   CGPoint(12, 6), CGPoint(14.5, 4.5), CGPoint(w, 13), CGPoint(w, base)])
            linear(ctx, clip: outline, [(0, rgb(m.lit0)), (0.45, rgb(m.lit1)), (0.5, rgb(m.dark2)), (1, rgb(m.dark0))],
                   from: CGPoint(0, 0), to: CGPoint(w, 0))
            ctx.saveGState(); ctx.addPath(outline); ctx.clip()
            var y: CGFloat = 26
            while y < base {
                let ledge = CGMutablePath(); ledge.move(to: CGPoint(0, y)); ledge.addLine(to: CGPoint(w, y - 2 + unit(&rng) * 4))
                stroke(ctx, ledge, rgba(30, 20, 24, 0.55), width: 1)
                stroke(ctx, ledge.copy(using: [CGAffineTransform(translationX: 0, y: 1.1)])!, white(0.16), width: 0.7)
                for _ in 0..<3 { fill(ctx, ellipse(CGPoint(1 + unit(&rng) * 16, y - 0.8), 1.6, 1), rgb(0x7CC46A, 0.9)) }
                y += 26 + unit(&rng) * 22
            }
            for x0 in [3.5, 9.0, 14.0] as [CGFloat] {
                let start = 8 + unit(&rng) * 6, len = 50 + unit(&rng) * 90
                let r = CGMutablePath(); r.move(to: CGPoint(x0, start))
                var t = start
                while t < start + len {
                    r.addQuadCurve(to: CGPoint(x0, t + 12), control: CGPoint(x0 + (Int(t) % 2 == 0 ? 2.4 : -2.4), t + 6)); t += 12
                }
                stroke(ctx, r, rgb(0x2E2016, 0.85), width: 1.1)
                fill(ctx, circle(CGPoint(x0, start + len), 0.9), rgb(0x2E2016, 0.85))
            }
            ctx.restoreGState()
            fill(ctx, ellipse(CGPoint(8.5, 3), 2.2, 1.4), rgb(0x8AD474))
            stroke(ctx, outline, white(0.2), width: 1)

        case .bamboo:
            // three stalks with nodes, cut on a slant, bound with twine
            let stalks: [(CGFloat, CGFloat, CGFloat)] = [(0, 6.4, 4), (5.8, 12.4, 0), (11.8, 18, 6)]
            for (x0, x1, top) in stalks {
                let sw = x1 - x0
                let shape = polygon([CGPoint(x0, base), CGPoint(x0, top + 3), CGPoint(x1, top), CGPoint(x1, base)])
                linear(ctx, clip: shape, [(0, rgb(m.lit0)), (0.35, rgb(m.lit1)), (1, rgb(m.dark0))],
                       from: CGPoint(x0, 0), to: CGPoint(x1, 0))
                // the hollow, seen through the slanted cut
                fill(ctx, ellipse(CGPoint(x0 + sw / 2, top + 1.5), sw / 2 - 0.3, 1.5, -0.45), rgb(0xF4F2C8))
                fill(ctx, ellipse(CGPoint(x0 + sw / 2, top + 1.6), sw / 2 - 1.6, 0.8, -0.45), rgb(0x5E6A2A))
                var y = top + 14 + unit(&rng) * 14
                while y < base {
                    let node = CGMutablePath(); node.move(to: CGPoint(x0 + 0.3, y)); node.addQuadCurve(to: CGPoint(x1 - 0.3, y), control: CGPoint(x0 + sw / 2, y + 1.4))
                    stroke(ctx, node, rgb(m.dark0, 0.9), width: 1.3)
                    let lip = CGMutablePath(); lip.move(to: CGPoint(x0 + 0.8, y - 1.3)); lip.addQuadCurve(to: CGPoint(x1 - 0.8, y - 1.3), control: CGPoint(x0 + sw / 2, y))
                    stroke(ctx, lip, white(0.45), width: 0.7)
                    y += 24 + unit(&rng) * 12
                }
                let shine = CGMutablePath(); shine.move(to: CGPoint(x0 + 1.5, top + 5)); shine.addLine(to: CGPoint(x0 + 1.5, base))
                stroke(ctx, shine, white(0.3), width: 0.8)
                stroke(ctx, shape, rgb(m.dark0, 0.6), width: 0.6)
            }
            var y: CGFloat = 52
            while y < base {
                ctx.setFillColor(rgb(0xC9A060)); ctx.fill(CGRect(x: 0, y: y, width: w, height: 3.4))
                for x in stride(from: 0.0, to: Double(w), by: 2.6) {
                    let t = CGMutablePath(); t.move(to: CGPoint(x, y + 3.4)); t.addLine(to: CGPoint(x + 2, y))
                    stroke(ctx, t, rgba(90, 60, 20, 0.6), width: 0.6)
                }
                y += 96
            }

        case .crystal:
            // an amethyst cluster: a central point with two shorter ones, each faceted, pale at the tip, deep below
            let outline = polygon([CGPoint(0, base), CGPoint(0, 12), CGPoint(2.8, 5), CGPoint(5.4, 10.5), CGPoint(9, 0),
                                   CGPoint(12.6, 10.5), CGPoint(15.2, 3.5), CGPoint(w, 11), CGPoint(w, base)])
            linear(ctx, clip: outline, [(0, rgb(m.lit0)), (0.12, rgb(m.lit1)), (0.4, rgb(m.dark1)), (1, rgb(m.dark0))],
                   from: CGPoint(0, 0), to: CGPoint(0, 180))
            ctx.saveGState(); ctx.addPath(outline); ctx.clip()
            // facets: lit left of each point, shaded right
            for (tip, l, r) in [(CGPoint(2.8, 5), 0.0, 5.4), (CGPoint(9, 0), 5.4, 12.6), (CGPoint(15.2, 3.5), 12.6, 18.0)] as [(CGPoint, CGFloat, CGFloat)] {
                fill(ctx, polygon([tip, CGPoint(l, tip.y + 12), CGPoint(l, base), CGPoint(tip.x, base)]), white(0.18))
                fill(ctx, polygon([tip, CGPoint(r, tip.y + 12), CGPoint(r, base), CGPoint(tip.x, base)]), rgba(30, 0, 60, 0.28))
                let ridge = CGMutablePath(); ridge.move(to: tip); ridge.addLine(to: CGPoint(tip.x, base))
                stroke(ctx, ridge, white(0.3), width: 0.7)
            }
            // growth bands following the points
            var y: CGFloat = 34
            while y < base {
                let band = CGMutablePath(); band.move(to: CGPoint(0, y)); band.addLine(to: CGPoint(9, y - 7)); band.addLine(to: CGPoint(w, y))
                stroke(ctx, band, white(m.grain * 0.5), width: 1)
                y += 30 + unit(&rng) * 18
            }
            var g: CGFloat = 20
            while g < base {
                fill(ctx, circle(CGPoint(2 + unit(&rng) * 14, g), 0.8), white(0.75)); g += 22 + unit(&rng) * 26
            }
            ctx.restoreGState()
            for tip in [CGPoint(2.8, 5), CGPoint(9, 0), CGPoint(15.2, 3.5)] {
                fill(ctx, polygon([tip, CGPoint(tip.x - 2, tip.y + 4.5), CGPoint(tip.x - 0.4, tip.y + 5)]), white(0.85))
            }
            stroke(ctx, outline, rgba(255, 220, 255, 0.35), width: 0.8)

        case .storm:
            // two basalt columns, hexagonal tops at different heights, cross-jointed, wet
            for (x0, x1, top) in [(8.6, 18.0, 6.0), (0.0, 9.4, 0.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let cw = x1 - x0, a = x0 + cw * 0.3, b = x0 + cw * 0.74
                let capH: CGFloat = 3.2
                let front = polygon([CGPoint(x0, top + capH / 2), CGPoint(a, top + capH), CGPoint(b, top + capH),
                                     CGPoint(x1, top + capH / 2), CGPoint(x1, base), CGPoint(x0, base)])
                fill(ctx, polygon([CGPoint(x0, top + capH / 2), CGPoint(a, top + capH), CGPoint(a, base), CGPoint(x0, base)]), rgb(m.lit1))
                fill(ctx, polygon([CGPoint(a, top + capH), CGPoint(b, top + capH), CGPoint(b, base), CGPoint(a, base)]), rgb(m.dark2))
                fill(ctx, polygon([CGPoint(b, top + capH), CGPoint(x1, top + capH / 2), CGPoint(x1, base), CGPoint(b, base)]), rgb(m.dark0))
                let cap = polygon([CGPoint(x0, top + capH / 2), CGPoint(a, top), CGPoint(b, top), CGPoint(x1, top + capH / 2),
                                   CGPoint(b, top + capH), CGPoint(a, top + capH)])
                fill(ctx, cap, rgb(m.lit0))
                stroke(ctx, cap, white(0.35), width: 0.6)
                ctx.saveGState(); ctx.addPath(front); ctx.clip()
                var y = top + 20 + unit(&rng) * 20
                while y < base {
                    let tilt = (unit(&rng) - 0.5) * 3
                    let j = CGMutablePath(); j.move(to: CGPoint(x0, y)); j.addLine(to: CGPoint(x1, y + tilt))
                    stroke(ctx, j, rgba(0, 0, 0, 0.6), width: 1)
                    stroke(ctx, j.copy(using: [CGAffineTransform(translationX: 0, y: 1)])!, white(0.18), width: 0.6)
                    y += 26 + unit(&rng) * 26
                }
                // rain sheen running down the lit face
                var s = top + 6
                while s < base {
                    let len = 10 + unit(&rng) * 26
                    let l = CGMutablePath(); l.move(to: CGPoint(x0 + 1.2, s)); l.addLine(to: CGPoint(x0 + 1.2, s + len))
                    stroke(ctx, l, white(0.32), width: 0.8)
                    s += len + 6 + unit(&rng) * 14
                }
                ctx.restoreGState()
                for e in [a, b] {
                    let l = CGMutablePath(); l.move(to: CGPoint(e, top + capH)); l.addLine(to: CGPoint(e, base))
                    stroke(ctx, l, white(0.1), width: 0.5)
                }
            }

        case .autumn:
            // a birch trunk: white bark, dark lenticels and scars, snapped at the top
            let outline = polygon([CGPoint(0, base), CGPoint(0, 8), CGPoint(2.6, 4), CGPoint(4.6, 7), CGPoint(7.6, 0.5),
                                   CGPoint(10.4, 5.5), CGPoint(12.8, 2), CGPoint(15.4, 6.5), CGPoint(w, 3.5), CGPoint(w, base)])
            linear(ctx, clip: outline, [(0, rgb(m.dark2)), (0.25, rgb(m.lit0)), (0.6, rgb(m.lit1)), (1, rgb(m.dark0))],
                   from: CGPoint(0, 0), to: CGPoint(w, 0))
            ctx.saveGState(); ctx.addPath(outline); ctx.clip()
            // split heartwood at the break
            fill(ctx, polygon([CGPoint(0, 8), CGPoint(2.6, 4), CGPoint(4.6, 7), CGPoint(7.6, 0.5), CGPoint(10.4, 5.5), CGPoint(12.8, 2),
                               CGPoint(15.4, 6.5), CGPoint(w, 3.5), CGPoint(w, 9), CGPoint(0, 11)]), rgb(0xE2B47A))
            let rim = CGMutablePath(); rim.move(to: CGPoint(0, 11)); rim.addLine(to: CGPoint(w, 9))
            stroke(ctx, rim, rgba(90, 50, 20, 0.6), width: 0.8)
            var y: CGFloat = 16
            while y < base {
                let fromLeft = unit(&rng) < 0.5, len = 3 + unit(&rng) * 7
                let x0 = fromLeft ? unit(&rng) * 3 : w - len - unit(&rng) * 3
                let mark = CGMutablePath(); mark.move(to: CGPoint(x0, y)); mark.addLine(to: CGPoint(x0 + len, y + (unit(&rng) - 0.5)))
                stroke(ctx, mark, rgb(0x2A2420, 0.85), width: 0.8 + unit(&rng) * 1.1)
                if unit(&rng) < 0.16 {
                    // a branch scar: the dark chevron birches wear
                    let cx = 5 + unit(&rng) * 8
                    fill(ctx, polygon([CGPoint(cx - 4, y + 2), CGPoint(cx, y + 5), CGPoint(cx + 4, y + 2), CGPoint(cx, y + 3.4)]), rgb(0x2A2420, 0.9))
                    fill(ctx, ellipse(CGPoint(cx, y + 6.2), 1.2, 0.9), rgb(0x2A2420, 0.9))
                    y += 6
                }
                y += 4 + unit(&rng) * 9
            }
            ctx.restoreGState()
            stroke(ctx, outline, rgba(60, 40, 30, 0.35), width: 0.8)

        case .ruins:
            // a carved stone column: a capital, fluted drums with glyphs, a vine winding down
            let capital = CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: 4.2), cornerWidth: 1, cornerHeight: 1, transform: nil)
            let echinus = CGPath(rect: CGRect(x: 0, y: 4, width: w, height: 4.5), transform: nil)
            let shaft = CGPath(rect: CGRect(x: 0, y: 8, width: w, height: base - 8), transform: nil)
            let body = CGMutablePath(); body.addPath(capital); body.addPath(echinus); body.addPath(shaft)
            linear(ctx, clip: body, [(0, rgb(m.lit0)), (0.4, rgb(m.lit1)), (1, rgb(m.dark0))], from: CGPoint(0, 0), to: CGPoint(w, 0))
            let mould = CGMutablePath(); mould.move(to: CGPoint(0.5, 4.1)); mould.addLine(to: CGPoint(w - 0.5, 4.1))
            mould.move(to: CGPoint(0.5, 8.6)); mould.addLine(to: CGPoint(w - 0.5, 8.6))
            // the shaft's edges in shadow, so the column reads narrower than its capital
            for x in [0.0, w - 1.4] as [CGFloat] { ctx.setFillColor(rgba(0, 0, 0, 0.25)); ctx.fill(CGRect(x: x, y: 8.6, width: 1.4, height: base)) }
            stroke(ctx, mould, rgba(0, 0, 0, 0.45), width: 0.8)
            let top = CGMutablePath(); top.move(to: CGPoint(0.8, 0.8)); top.addLine(to: CGPoint(w - 0.8, 0.8))
            stroke(ctx, top, white(0.45), width: 0.8)
            ctx.saveGState(); ctx.addPath(shaft); ctx.clip()
            for x in [5.0, 9.0, 13.0] as [CGFloat] {
                let f = CGMutablePath(); f.move(to: CGPoint(x, 9)); f.addLine(to: CGPoint(x, base))
                stroke(ctx, f, rgba(0, 0, 0, 0.22), width: 0.9)
                stroke(ctx, f.copy(using: [CGAffineTransform(translationX: 0.9, y: 0)])!, white(0.14), width: 0.5)
            }
            var y: CGFloat = 9, drum = 0
            while y < base {
                let h = 34 + unit(&rng) * 12
                if drum % 2 == 0 {
                    // a carved glyph panel: a square spiral
                    let gy = y + 8, panel = CGRect(x: 4, y: gy, width: 10, height: 10)
                    ctx.setFillColor(rgba(0, 0, 0, 0.18)); ctx.fill(panel)
                    let s = CGMutablePath(); s.move(to: CGPoint(6, gy + 8)); s.addLine(to: CGPoint(6, gy + 2)); s.addLine(to: CGPoint(12, gy + 2))
                    s.addLine(to: CGPoint(12, gy + 8)); s.addLine(to: CGPoint(8.2, gy + 8)); s.addLine(to: CGPoint(8.2, gy + 4.4)); s.addLine(to: CGPoint(10, gy + 4.4))
                    stroke(ctx, s, rgba(0, 0, 0, 0.5), width: 0.9)
                    stroke(ctx, s.copy(using: [CGAffineTransform(translationX: 0.5, y: 0.6)])!, white(0.2), width: 0.5)
                }
                y += h; drum += 1
                let joint = CGMutablePath(); joint.move(to: CGPoint(1, y)); joint.addLine(to: CGPoint(w - 1, y))
                stroke(ctx, joint, rgba(0, 0, 0, 0.45), width: 0.9)
                stroke(ctx, joint.copy(using: [CGAffineTransform(translationX: 0, y: 1)])!, white(0.18), width: 0.6)
                // a chip off the edge
                fill(ctx, polygon([CGPoint(w - 1.2, y - 4), CGPoint(w - 3.4, y - 1), CGPoint(w - 1.2, y + 2)]), rgba(0, 0, 0, 0.3))
            }
            ctx.restoreGState()
            // the vine: a lazy sine down the column, leaves alternating
            let vine = CGMutablePath(); vine.move(to: CGPoint(2, 3))
            var t: CGFloat = 3
            var leaves: [(CGPoint, CGFloat)] = []
            while t < 170 {
                let x = 9 + sin(t / 11) * 6.5
                vine.addLine(to: CGPoint(x, t))
                if Int(t) % 9 == 0 { leaves.append((CGPoint(x, t), Int(t) % 18 == 0 ? 0.7 : -0.7 + .pi)) }
                t += 1
            }
            stroke(ctx, vine, rgb(0x2E6A2E), width: 1.2)
            for (p, a) in leaves {
                at(ctx, p.x, p.y, rotate: a) {
                    fill(ctx, ellipse(CGPoint(2.4, 0), 2.6, 1.3), rgb(0x5CB85A))
                    let v = CGMutablePath(); v.move(to: .zero); v.addLine(to: CGPoint(4, 0)); stroke(ctx, v, rgb(0x2E6A2E, 0.6), width: 0.4)
                }
            }
            stroke(ctx, body, rgba(0, 0, 0, 0.25), width: 0.6)

        case .volcano, .glacier, .grove: break
        }
    }

    static func drawThemedChunk(_ ctx: CGContext, map: MapTheme) {
        let m = map.palette, w: CGFloat = 26
        switch map {
        case .dunes:
            // a sandstone boulder, wind-rounded, with its strata
            let b = CGMutablePath(); b.move(to: CGPoint(3, 10))
            b.addCurve(to: CGPoint(15, 2), control1: CGPoint(4, 4), control2: CGPoint(10, 1.5))
            b.addCurve(to: CGPoint(25, 14), control1: CGPoint(22, 2.5), control2: CGPoint(25.5, 8))
            b.addCurve(to: CGPoint(16, 27.5), control1: CGPoint(24.5, 22), control2: CGPoint(21, 27.5))
            b.addCurve(to: CGPoint(1, 18), control1: CGPoint(8, 27.5), control2: CGPoint(0.5, 24))
            b.addCurve(to: CGPoint(3, 10), control1: CGPoint(1.2, 14), control2: CGPoint(2, 12)); b.closeSubpath()
            linear(ctx, clip: b, [(0, rgb(m.chunkLit0)), (0.55, rgb(m.chunkLit1)), (1, rgb(m.chunkFill))], from: CGPoint(4, 2), to: CGPoint(20, 28))
            ctx.saveGState(); ctx.addPath(b); ctx.clip()
            for (y, d) in [(9.0, 1.5), (14.5, -1.0), (20.0, 1.2), (24.5, -0.5)] as [(CGFloat, CGFloat)] {
                let l = CGMutablePath(); l.move(to: CGPoint(0, y)); l.addQuadCurve(to: CGPoint(w, y + d), control: CGPoint(13, y + 2.2))
                stroke(ctx, l, rgba(110, 50, 24, 0.45), width: 0.9)
            }
            ctx.restoreGState()
            stroke(ctx, b, rgba(90, 40, 20, 0.5), width: 0.8)
            fill(ctx, ellipse(CGPoint(9, 6.5), 3, 1.2, -0.4), white(0.45))

        case .skyisles:
            // a small floating islet: a grassy top, a rock cone, dangling roots
            let rock = CGMutablePath(); rock.move(to: CGPoint(1, 9))
            rock.addLine(to: CGPoint(25, 9)); rock.addLine(to: CGPoint(21, 16)); rock.addLine(to: CGPoint(17, 19))
            rock.addLine(to: CGPoint(14, 26)); rock.addLine(to: CGPoint(10.5, 20)); rock.addLine(to: CGPoint(5, 16)); rock.closeSubpath()
            linear(ctx, clip: rock, [(0, rgb(m.lit0)), (0.5, rgb(m.lit1)), (1, rgb(m.dark0))], from: CGPoint(2, 9), to: CGPoint(22, 22))
            let facet = CGMutablePath(); facet.move(to: CGPoint(12, 9.5)); facet.addLine(to: CGPoint(14, 25))
            stroke(ctx, facet, white(0.22), width: 0.8)
            for (x, len) in [(6.5, 9.0), (11.5, 7.0), (18.5, 8.5)] as [(CGFloat, CGFloat)] {
                let r = CGMutablePath(); r.move(to: CGPoint(x, 15))
                r.addQuadCurve(to: CGPoint(x - 0.5, 15 + len), control: CGPoint(x + 2.2, 15 + len * 0.5))
                stroke(ctx, r, rgb(0x2E2016, 0.9), width: 0.9)
            }
            let grass = CGMutablePath(); grass.move(to: CGPoint(0.5, 10))
            grass.addQuadCurve(to: CGPoint(25.5, 10), control: CGPoint(13, 0.5)); grass.addQuadCurve(to: CGPoint(0.5, 10), control: CGPoint(13, 12.5))
            linear(ctx, clip: grass, [(0, rgb(0xA6E07E)), (1, rgb(0x4E9A44))], from: CGPoint(0, 4), to: CGPoint(0, 11))
            for x in [5.0, 9.5, 15.0, 20.0] as [CGFloat] {
                let t = CGMutablePath(); t.move(to: CGPoint(x, 6.5)); t.addLine(to: CGPoint(x + 0.8, 4.2)); stroke(ctx, t, rgb(0xC8F0A0), width: 0.7)
            }
            stroke(ctx, rock, rgba(30, 20, 24, 0.5), width: 0.7)

        case .bamboo:
            // a bound bundle of short cut stalks
            for (x0, top) in [(0.6, 4.0), (6.8, 1.5), (13.0, 3.0), (19.2, 5.5)] as [(CGFloat, CGFloat)] {
                let sw: CGFloat = 6.4, bottom: CGFloat = 27.5
                let s = polygon([CGPoint(x0, bottom), CGPoint(x0, top + 2.4), CGPoint(x0 + sw, top), CGPoint(x0 + sw, bottom)])
                linear(ctx, clip: s, [(0, rgb(m.lit0)), (0.4, rgb(m.lit1)), (1, rgb(m.dark0))], from: CGPoint(x0, 0), to: CGPoint(x0 + sw, 0))
                fill(ctx, ellipse(CGPoint(x0 + sw / 2, top + 1.2), sw / 2 - 0.2, 1.3, -0.4), rgb(0xF4F2C8))
                fill(ctx, ellipse(CGPoint(x0 + sw / 2, top + 1.3), sw / 2 - 1.4, 0.7, -0.4), rgb(0x5E6A2A))
                let node = CGMutablePath(); node.move(to: CGPoint(x0 + 0.3, top + 9)); node.addLine(to: CGPoint(x0 + sw - 0.3, top + 9))
                stroke(ctx, node, rgb(m.dark0), width: 1)
                ctx.setFillColor(rgb(0x2E4A18, 0.6)); ctx.fill(CGRect(x: x0, y: bottom - 1.2, width: sw, height: 1.2))
                stroke(ctx, s, rgb(m.dark0, 0.6), width: 0.5)
            }
            ctx.setFillColor(rgb(0xC9A060)); ctx.fill(CGRect(x: 0.5, y: 16, width: w - 1, height: 4))
            for x in stride(from: 1.0, to: Double(w - 1), by: 2.6) {
                let t = CGMutablePath(); t.move(to: CGPoint(x, 20)); t.addLine(to: CGPoint(x + 2, 16))
                stroke(ctx, t, rgba(90, 60, 20, 0.6), width: 0.6)
            }
            let knot = CGMutablePath(); knot.move(to: CGPoint(13, 20)); knot.addQuadCurve(to: CGPoint(11, 25), control: CGPoint(11, 22))
            knot.move(to: CGPoint(13, 20)); knot.addQuadCurve(to: CGPoint(15.5, 24.5), control: CGPoint(15, 22))
            stroke(ctx, knot, rgb(0xC9A060), width: 1)

        case .crystal:
            // a split geode: a rough rind round a ring of amethyst teeth
            let rind = CGMutablePath(); rind.move(to: CGPoint(13, 0.8))
            rind.addLine(to: CGPoint(21, 3)); rind.addLine(to: CGPoint(25.4, 11)); rind.addLine(to: CGPoint(24.5, 20))
            rind.addLine(to: CGPoint(18.5, 27.6)); rind.addLine(to: CGPoint(8, 28)); rind.addLine(to: CGPoint(1.4, 21))
            rind.addLine(to: CGPoint(0.8, 10)); rind.addLine(to: CGPoint(5.5, 3)); rind.closeSubpath()
            linear(ctx, clip: rind, [(0, rgb(m.chunkLit0)), (1, rgb(m.chunkFill))], from: CGPoint(2, 2), to: CGPoint(22, 28))
            let c = CGPoint(13, 14.6)
            fill(ctx, ellipse(c, 9.4, 10.4), rgb(0xD9C2E6))
            fill(ctx, ellipse(c, 8.4, 9.4), rgb(m.dark0))
            for i in 0..<14 {
                let a = CGFloat(i) / 14 * 2 * .pi, a2 = a + 2 * .pi / 14
                let o1 = CGPoint(c.x + cos(a) * 8.4, c.y + sin(a) * 9.4), o2 = CGPoint(c.x + cos(a2) * 8.4, c.y + sin(a2) * 9.4)
                let am = (a + a2) / 2, inner = CGPoint(c.x + cos(am) * 4, c.y + sin(am) * 4.5)
                let lit = sin(am + 0.8) < 0
                fill(ctx, polygon([o1, inner, o2]), rgb(lit ? m.lit0 : m.dark2))
                stroke(ctx, polygon([o1, inner, o2]), rgb(m.dark0, 0.5), width: 0.4)
            }
            fill(ctx, ellipse(c, 3.2, 3.6), rgb(0x2A0E4A))
            fill(ctx, polygon([CGPoint(9.6, 8), CGPoint(10.8, 9.6), CGPoint(12.4, 10), CGPoint(10.8, 10.4), CGPoint(9.6, 12),
                               CGPoint(8.4, 10.4), CGPoint(6.8, 10), CGPoint(8.4, 9.6)]), white(0.9))
            stroke(ctx, rind, rgba(255, 220, 255, 0.25), width: 0.7)

        case .storm:
            // a basalt block, seen end-on: a hexagon with bevelled faces
            let outer = [CGPoint(1, 14.5), CGPoint(7, 1.5), CGPoint(19, 1.5), CGPoint(25, 14.5), CGPoint(19, 27.5), CGPoint(7, 27.5)]
            let inner = [CGPoint(5.2, 14.5), CGPoint(9.2, 5.6), CGPoint(16.8, 5.6), CGPoint(20.8, 14.5), CGPoint(16.8, 23.4), CGPoint(9.2, 23.4)]
            let tones: [UInt32] = [m.lit1, m.chunkLit0, m.lit1, m.dark2, m.dark0, m.dark1]
            for i in 0..<6 {
                let j = (i + 1) % 6
                fill(ctx, polygon([outer[i], outer[j], inner[j], inner[i]]), rgb(tones[i]))
            }
            linear(ctx, clip: polygon(inner), [(0, rgb(m.chunkLit1)), (1, rgb(m.chunkFill))], from: CGPoint(8, 6), to: CGPoint(18, 23))
            let crack = CGMutablePath(); crack.move(to: CGPoint(11, 8)); crack.addLine(to: CGPoint(13.5, 14)); crack.addLine(to: CGPoint(12, 20))
            stroke(ctx, crack, rgba(0, 0, 0, 0.45), width: 0.8)
            stroke(ctx, polygon(outer), white(0.28), width: 0.7)
            let wet = CGMutablePath(); wet.move(to: CGPoint(8.2, 4)); wet.addLine(to: CGPoint(17.5, 4))
            stroke(ctx, wet, white(0.55), width: 0.8)

        case .autumn:
            // a log end: bark round heartwood rings, a crack and a knot
            let c = CGPoint(13, 14.5)
            fill(ctx, ellipse(c, 12.4, 13.8), rgb(0x4A2A16))
            linear(ctx, clip: ellipse(c, 10.4, 11.8), [(0, rgb(0xEBC48A)), (1, rgb(m.chunkLit0))], from: CGPoint(4, 3), to: CGPoint(20, 26))
            for r in [8.4, 6.2, 4.0, 2.0] as [CGFloat] {
                stroke(ctx, ellipse(CGPoint(c.x + 0.6, c.y + 0.4), r, r * 1.12), rgba(150, 90, 40, 0.6), width: 0.7)
            }
            fill(ctx, circle(CGPoint(c.x + 0.6, c.y + 0.4), 0.9), rgb(0x8A5A34))
            let crack = CGMutablePath(); crack.move(to: CGPoint(c.x + 0.6, c.y)); crack.addLine(to: CGPoint(21, 6)); crack.addLine(to: CGPoint(22.4, 4.6))
            stroke(ctx, crack, rgb(0x4A2A16), width: 1)
            for a in stride(from: 0.0, to: 2 * Double.pi, by: 0.5) {
                let p0 = CGPoint(c.x + cos(a) * 11.2, c.y + sin(a) * 12.6), p1 = CGPoint(c.x + cos(a) * 12.2, c.y + sin(a) * 13.6)
                let l = CGMutablePath(); l.move(to: p0); l.addLine(to: p1); stroke(ctx, l, rgb(0x2A160A), width: 0.7)
            }
            stroke(ctx, arc(c, 11.6, from: .pi * 1.05, to: .pi * 1.45), white(0.3), width: 0.8)

        case .ruins:
            // a carved block: bevelled, a stepped-spiral glyph, a vine over a corner
            let block = CGRect(x: 1, y: 2, width: 24, height: 25)
            fill(ctx, CGPath(rect: block, transform: nil), rgb(m.chunkFill))
            fill(ctx, polygon([CGPoint(1, 2), CGPoint(25, 2), CGPoint(22.5, 4.5), CGPoint(3.5, 4.5), CGPoint(3.5, 24.5), CGPoint(1, 27)]), rgb(m.chunkLit0))
            linear(ctx, clip: CGPath(rect: CGRect(x: 3.5, y: 4.5, width: 19, height: 20), transform: nil),
                   [(0, rgb(m.chunkLit0)), (1, rgb(m.chunkLit1))], from: CGPoint(3, 4), to: CGPoint(22, 24))
            let s = CGMutablePath()
            s.move(to: CGPoint(7, 21)); s.addLine(to: CGPoint(7, 8)); s.addLine(to: CGPoint(19, 8)); s.addLine(to: CGPoint(19, 21))
            s.addLine(to: CGPoint(10.5, 21)); s.addLine(to: CGPoint(10.5, 11.5)); s.addLine(to: CGPoint(15.5, 11.5)); s.addLine(to: CGPoint(15.5, 17.5))
            s.addLine(to: CGPoint(13, 17.5))
            stroke(ctx, s, rgba(0, 0, 0, 0.5), width: 1.4)
            stroke(ctx, s.copy(using: [CGAffineTransform(translationX: 0.6, y: 0.7)])!, white(0.22), width: 0.6)
            stroke(ctx, CGPath(rect: block, transform: nil), rgba(0, 0, 0, 0.35), width: 0.7)
            let vine = CGMutablePath(); vine.move(to: CGPoint(14, 2)); vine.addQuadCurve(to: CGPoint(25, 13), control: CGPoint(23, 2))
            stroke(ctx, vine, rgb(0x2E6A2E), width: 1.1)
            for (x, y, a) in [(17.0, 3.0, -0.4), (21.5, 5.0, 0.6), (24.0, 10.0, 1.3)] as [(CGFloat, CGFloat, CGFloat)] {
                at(ctx, x, y, rotate: a) { fill(ctx, ellipse(CGPoint(2, 0), 2.4, 1.2), rgb(0x5CB85A)) }
            }

        case .volcano, .glacier, .grove: break
        }
    }
}
