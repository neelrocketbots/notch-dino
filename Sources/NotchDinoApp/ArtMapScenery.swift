import CoreGraphics
import RunnerCore

/// Backdrops of the later maps: sky extras, the ambient tile (the stars slot), the far and near silhouette tiles, and
/// the ground. Tiles repeat side by side, so anything crossing an edge is drawn again one tile over, and every
/// periodic curve has a whole number of cycles per tile. The ground scrolls in 22 pt steps, so its pattern repeats
/// every 22 pt.
extension Art {
    private static func wrap(_ width: CGFloat, _ draw: (CGFloat) -> Void) { for dx in [-width, 0, width] { draw(dx) } }

    /// A closed silhouette from the tile's bottom up to `height(x)`.
    private static func ridge(_ width: CGFloat, _ b: CGFloat, _ height: (CGFloat) -> CGFloat) -> CGPath {
        let p = CGMutablePath(); p.move(to: CGPoint(0, b))
        for x in stride(from: 0.0, through: Double(width), by: 2) { p.addLine(to: CGPoint(CGFloat(x), b - height(CGFloat(x)))) }
        p.addLine(to: CGPoint(width, b)); p.closeSubpath()
        return p
    }

    private static func crest(_ width: CGFloat, _ b: CGFloat, _ height: (CGFloat) -> CGFloat) -> CGPath {
        let p = CGMutablePath(); p.move(to: CGPoint(0, b - height(0)))
        for x in stride(from: 2.0, through: Double(width), by: 2) { p.addLine(to: CGPoint(CGFloat(x), b - height(CGFloat(x)))) }
        return p
    }

    private static func u(_ rng: inout SeededRandom) -> CGFloat { CGFloat(rng.unit()) }

    private static func scatterStars(_ ctx: CGContext, _ m: MapPalette, count: Int, maxY: CGFloat, alpha: CGFloat, _ rng: inout SeededRandom) {
        for _ in 0..<count {
            let x = u(&rng) * 700, y = u(&rng) * maxY
            let s: CGFloat = u(&rng) < 0.2 ? 1.6 : 1
            ctx.setFillColor(rgba(m.star, alpha * (0.4 + u(&rng) * 0.6))); ctx.fill(CGRect(x: x, y: y, width: s, height: s))
        }
    }

    // MARK: Sky

    static func drawSkyExtras(_ ctx: CGContext, size: CGSize, groundY: CGFloat, map: MapTheme) {
        switch map {
        case .dunes:
            // a low sun behind the dunes, banded by haze
            let c = CGPoint(size.width * 0.7, groundY - 34)
            radial(ctx, at: c, radius: 90, [(0, rgba(255, 190, 110, 0.35)), (1, rgba(255, 140, 80, 0))])
            linear(ctx, clip: circle(c, 21), [(0, rgba(255, 238, 180, 0.95)), (1, rgba(255, 150, 90, 0.9))],
                   from: CGPoint(c.x, c.y - 21), to: CGPoint(c.x, c.y + 21))
            for (dy, hgt) in [(4.0, 2.0), (10.0, 3.0)] as [(CGFloat, CGFloat)] {
                ctx.setFillColor(rgba(150, 60, 90, 0.4)); ctx.fill(CGRect(x: c.x - 30, y: c.y + dy, width: 60, height: hgt))
            }
        case .storm:
            // heavy cloud overhead
            var rng = SeededRandom(seed: 21)
            for _ in 0..<16 {
                let c = CGPoint(u(&rng) * size.width, 20 + u(&rng) * 80), r = 40 + u(&rng) * 50
                radial(ctx, at: c, radius: r, [(0, rgba(78, 88, 102, 0.4)), (1, rgba(60, 70, 84, 0))])
            }
        default: break
        }
    }

    // MARK: Ambient (the stars tile)

    static func drawThemedAmbient(_ ctx: CGContext, map: MapTheme) {
        let m = map.palette, tw = starsTileSize.width
        var rng = SeededRandom(seed: 7)
        switch map {
        case .dunes:
            scatterStars(ctx, m, count: 30, maxY: 100, alpha: 0.55, &rng)
        case .skyisles:
            scatterStars(ctx, m, count: 18, maxY: 80, alpha: 0.5, &rng)
            for _ in 0..<7 {
                let c = CGPoint(u(&rng) * tw, 70 + u(&rng) * 110), len = 60 + u(&rng) * 90
                wrap(tw) { dx in fill(ctx, ellipse(CGPoint(c.x + dx, c.y), len / 2, 2.2), white(0.08)) }
            }
        case .bamboo:
            scatterStars(ctx, m, count: 14, maxY: 70, alpha: 0.45, &rng)
            for _ in 0..<8 {
                let c = CGPoint(u(&rng) * tw, 100 + u(&rng) * 85), len = 80 + u(&rng) * 120
                wrap(tw) { dx in fill(ctx, ellipse(CGPoint(c.x + dx, c.y), len / 2, 3.5), white(0.06)) }
            }
        case .crystal:
            // the cave roof: a dark band hung with stalactites, some tipped with crystal
            let roof = CGMutablePath(); roof.addRect(CGRect(x: 0, y: 0, width: tw, height: 10))
            var x: CGFloat = 0
            var tips: [CGPoint] = []
            while x < tw {
                let half = 5 + u(&rng) * 9, len = 18 + u(&rng) * 34
                let s = CGMutablePath(); s.move(to: CGPoint(x - half, 9))
                s.addQuadCurve(to: CGPoint(x, 9 + len), control: CGPoint(x - half * 0.3, 9 + len * 0.4))
                s.addQuadCurve(to: CGPoint(x + half, 9), control: CGPoint(x + half * 0.3, 9 + len * 0.4))
                s.closeSubpath(); roof.addPath(s)
                if u(&rng) < 0.35 { tips.append(CGPoint(x, 9 + len)) }
                x += half + 6 + u(&rng) * 26
            }
            wrap(tw) { dx in fill(ctx, roof.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, rgb(0x2A1840)) }
            for t in tips {
                radial(ctx, at: t, radius: 6, [(0, rgba(220, 140, 255, 0.5)), (1, rgba(200, 120, 255, 0))])
                fill(ctx, circle(t, 1), rgba(240, 200, 255, 0.9))
            }
            // glowing gem specks in the dark
            let hues: [(CGFloat, CGFloat, CGFloat)] = [(255, 120, 220), (120, 230, 255), (190, 140, 255), (230, 190, 255)]
            for _ in 0..<38 {
                let c = CGPoint(u(&rng) * tw, 50 + u(&rng) * 140), hue = hues[Int(u(&rng) * 4)], r = 1.6 + u(&rng) * 2.4
                radial(ctx, at: c, radius: r * 1.6, [(0, rgba(hue.0, hue.1, hue.2, 0.55)), (1, rgba(hue.0, hue.1, hue.2, 0))])
                ctx.setFillColor(rgba(hue.0, hue.1, hue.2, 0.9)); ctx.fill(CGRect(x: c.x - 0.5, y: c.y - 0.5, width: 1, height: 1))
            }
        case .storm:
            for _ in 0..<150 {
                let x = u(&rng) * tw, y = u(&rng) * 190, len = 7 + u(&rng) * 9
                let l = CGMutablePath(); l.move(to: CGPoint(x, y)); l.addLine(to: CGPoint(x - len * 0.32, y + len))
                let a = 0.12 + u(&rng) * 0.2
                wrap(tw) { dx in stroke(ctx, l.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, rgba(m.star, a), width: 0.7) }
            }
        case .autumn:
            scatterStars(ctx, m, count: 16, maxY: 80, alpha: 0.5, &rng)
            let hues: [UInt32] = [0xE8742A, 0xC8401E, 0xF0A83A, 0xD25A22]
            for _ in 0..<26 {
                let c = CGPoint(u(&rng) * tw, 30 + u(&rng) * 160), a = u(&rng) * 6.3, colour = rgb(hues[Int(u(&rng) * 4)], 0.55 + u(&rng) * 0.3)
                wrap(tw) { dx in
                    at(ctx, c.x + dx, c.y, rotate: a) {
                        let leaf = CGMutablePath(); leaf.move(to: CGPoint(-2.6, 0))
                        leaf.addQuadCurve(to: CGPoint(2.6, 0), control: CGPoint(0, -2)); leaf.addQuadCurve(to: CGPoint(-2.6, 0), control: CGPoint(0, 2))
                        fill(ctx, leaf, colour)
                    }
                }
            }
        case .ruins:
            scatterStars(ctx, m, count: 46, maxY: 190, alpha: 0.7, &rng)
            // a crescent moon
            let c = CGPoint(520, 52)
            radial(ctx, at: c, radius: 34, [(0, rgba(200, 255, 220, 0.16)), (1, rgba(200, 255, 220, 0))])
            ctx.saveGState(); ctx.addPath(circle(c, 11)); ctx.clip()
            ctx.addPath(circle(c, 11)); ctx.addPath(circle(CGPoint(c.x + 5, c.y - 3), 10))
            ctx.setFillColor(rgba(232, 248, 230, 0.9)); ctx.fillPath(using: .evenOdd); ctx.restoreGState()
        case .volcano, .glacier, .grove: break
        }
    }

    // MARK: Far layer (the volcanoes slot)

    static func drawThemedFar(_ ctx: CGContext, map: MapTheme) {
        let m = map.palette, tw = volcanoTileSize.width, b = volcanoTileSize.height, k = 2 * CGFloat.pi / tw
        var rng = SeededRandom(seed: 13)
        switch map {
        case .dunes:
            let back: (CGFloat) -> CGFloat = { x in 42 + 12 * sin(k * x * 2 + 0.5) + 6 * sin(k * x * 3 + 2) + 3 * sin(k * x * 7) }
            let front: (CGFloat) -> CGFloat = { x in 20 + 8 * sin(k * x * 2 + 2.6) + 5 * sin(k * x * 5 + 1) }
            fill(ctx, ridge(tw, b, back), rgb(m.hillFar))
            stroke(ctx, crest(tw, b, back), rgba(255, 150, 110, 0.35), width: 1.2)
            fill(ctx, ridge(tw, b, front), rgb(m.hill))
            stroke(ctx, crest(tw, b, front), rgba(255, 170, 120, 0.3), width: 1)
        case .skyisles:
            func bank(_ colour: CGColor, _ n: Int, _ y0: CGFloat, _ yr: CGFloat, _ r0: CGFloat, _ rr: CGFloat) {
                let p = CGMutablePath(); p.addRect(CGRect(x: 0, y: b - y0 + 6, width: tw, height: y0))
                for i in 0..<n {
                    let x = CGFloat(i) / CGFloat(n) * tw + u(&rng) * 14, r = r0 + u(&rng) * rr
                    p.addPath(circle(CGPoint(x, b - y0 - u(&rng) * yr + r * 0.5), r))
                }
                wrap(tw) { dx in
                    fill(ctx, p.copy(using: [CGAffineTransform(translationX: dx - 1, y: -2)])!, white(0.22))
                    fill(ctx, p.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, colour)
                }
            }
            bank(rgb(m.hillFar), 15, 30, 18, 14, 14)
            bank(rgb(m.hill), 18, 12, 8, 10, 9)
        case .bamboo:
            func peaks(_ x: CGFloat, _ n: CGFloat, _ phase: CGFloat) -> CGFloat { pow(0.5 + 0.5 * cos(k * n * x + phase), 1.6) }
            let mist = CGPath(rect: CGRect(x: 0, y: 0, width: tw, height: b), transform: nil)
            fill(ctx, ridge(tw, b) { x in 46 + 36 * peaks(x, 4, 0.3) + 4 * sin(k * x * 9) }, rgb(0x5C716A))
            linear(ctx, clip: mist, [(0, white(0)), (0.55, white(0)), (0.8, white(0.1)), (1, white(0))], from: CGPoint(0, 0), to: CGPoint(0, b))
            fill(ctx, ridge(tw, b) { x in 26 + 28 * peaks(x, 3, 1.9) + 3 * sin(k * x * 11) }, rgb(m.hillFar))
            linear(ctx, clip: mist, [(0, white(0)), (0.75, white(0)), (0.9, white(0.1)), (1, white(0))], from: CGPoint(0, 0), to: CGPoint(0, b))
            fill(ctx, ridge(tw, b) { x in 10 + 16 * peaks(x, 5, 0.6) }, rgb(m.hill))
        case .crystal:
            func spires(_ colour: CGColor, _ n: Int, _ h0: CGFloat, _ hr: CGFloat) {
                let p = CGMutablePath()
                for i in 0..<n {
                    let x = CGFloat(i) / CGFloat(n) * tw + u(&rng) * 18, h = h0 + u(&rng) * hr, half = 7 + u(&rng) * 10
                    p.move(to: CGPoint(x - half, b))
                    p.addQuadCurve(to: CGPoint(x, b - h), control: CGPoint(x - half * 0.25, b - h * 0.45))
                    p.addQuadCurve(to: CGPoint(x + half, b), control: CGPoint(x + half * 0.25, b - h * 0.45))
                    p.closeSubpath()
                }
                p.addRect(CGRect(x: 0, y: b - 8, width: tw, height: 8))
                wrap(tw) { dx in fill(ctx, p.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, colour) }
            }
            spires(rgb(m.hillFar), 11, 34, 44)
            spires(rgb(m.hill), 8, 14, 22)
            // faint crystal glints in the rock
            for _ in 0..<6 {
                let c = CGPoint(u(&rng) * tw, b - 6 - u(&rng) * 14), h = 6 + u(&rng) * 8
                radial(ctx, at: c, radius: 10, [(0, rgba(200, 120, 255, 0.3)), (1, rgba(200, 120, 255, 0))])
                fill(ctx, polygon([CGPoint(c.x - 2, c.y + 2), CGPoint(c.x, c.y - h), CGPoint(c.x + 2, c.y + 2)]), rgba(190, 130, 250, 0.6))
            }
        case .storm:
            // the sea, a headland with its lighthouse, a lower cliff, and the beam
            let sea = CGRect(x: 0, y: b - 16, width: tw, height: 16)
            ctx.setFillColor(rgb(0x18202A)); ctx.fill(sea)
            let horizon = CGMutablePath(); horizon.move(to: CGPoint(0, b - 16)); horizon.addLine(to: CGPoint(tw, b - 16))
            stroke(ctx, horizon, rgba(120, 140, 160, 0.35), width: 0.8)
            for _ in 0..<22 {
                let x = u(&rng) * tw, y = b - 13 + u(&rng) * 12, len = 3 + u(&rng) * 7
                let l = CGMutablePath(); l.move(to: CGPoint(x, y)); l.addLine(to: CGPoint(x + len, y))
                stroke(ctx, l, white(0.16), width: 0.7)
            }
            let top: CGFloat = b - 50
            let lx: CGFloat = 132
            // the beam first, so the headland sits in front of its base
            let beam = polygon([CGPoint(lx, top - 22), CGPoint(lx + 170, top - 40), CGPoint(lx + 170, top - 6)])
            linear(ctx, clip: beam, [(0, rgba(255, 236, 170, 0.35)), (1, rgba(255, 236, 170, 0))], from: CGPoint(lx, 0), to: CGPoint(lx + 170, 0))
            let back = polygon([CGPoint(lx, top - 22), CGPoint(lx - 70, top - 32), CGPoint(lx - 70, top - 14)])
            linear(ctx, clip: back, [(0, rgba(255, 236, 170, 0.18)), (1, rgba(255, 236, 170, 0))], from: CGPoint(lx, 0), to: CGPoint(lx - 70, 0))
            fill(ctx, polygon([CGPoint(16, b - 14), CGPoint(34, top + 8), CGPoint(48, top + 2), CGPoint(70, top), CGPoint(110, top - 1),
                               CGPoint(160, top + 1), CGPoint(176, top + 6), CGPoint(186, top + 18), CGPoint(200, b - 14)]), rgb(m.hill))
            fill(ctx, polygon([CGPoint(296, b - 14), CGPoint(310, b - 30), CGPoint(340, b - 36), CGPoint(380, b - 34),
                               CGPoint(400, b - 24), CGPoint(418, b - 14)]), rgb(m.hillFar))
            // the lighthouse: striped tower, gallery, lit lantern, cap
            let tower = polygon([CGPoint(lx - 3.6, top), CGPoint(lx - 2.4, top - 20), CGPoint(lx + 2.4, top - 20), CGPoint(lx + 3.6, top)])
            fill(ctx, tower, rgba(200, 206, 214, 0.85))
            ctx.saveGState(); ctx.addPath(tower); ctx.clip()
            ctx.setFillColor(rgba(160, 60, 56, 0.85)); ctx.fill(CGRect(x: lx - 5, y: top - 7, width: 10, height: 3.4))
            ctx.fill(CGRect(x: lx - 5, y: top - 15, width: 10, height: 3.4)); ctx.restoreGState()
            ctx.setFillColor(rgb(0x1A1E24)); ctx.fill(CGRect(x: lx - 3.6, y: top - 21, width: 7.2, height: 1.4))
            radial(ctx, at: CGPoint(lx, top - 23), radius: 10, [(0, rgba(255, 236, 170, 0.6)), (1, rgba(255, 236, 170, 0))])
            ctx.setFillColor(rgb(0xFFEBA8)); ctx.fill(CGRect(x: lx - 2, y: top - 25, width: 4, height: 3.6))
            fill(ctx, polygon([CGPoint(lx - 2.8, top - 25), CGPoint(lx, top - 28.5), CGPoint(lx + 2.8, top - 25)]), rgb(0x1A1E24))
        case .autumn:
            func canopy(_ colour: CGColor, _ light: CGColor, _ h: @escaping (CGFloat) -> CGFloat, _ r0: CGFloat, _ step: CGFloat) {
                let p = CGMutablePath(); p.addPath(ridge(tw, b, h))
                var x: CGFloat = 0
                var tops: [CGPoint] = []
                while x < tw {
                    let r = r0 + u(&rng) * 4
                    let c = CGPoint(x, b - h(x) + r * 0.45)
                    p.addPath(circle(c, r)); tops.append(CGPoint(c.x - r * 0.25, c.y - r * 0.4))
                    x += step + u(&rng) * 4
                }
                wrap(tw) { dx in fill(ctx, p.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, colour) }
                for t in tops { wrap(tw) { dx in fill(ctx, circle(CGPoint(t.x + dx, t.y), 2.2), light) } }
            }
            canopy(rgb(m.hillFar), rgb(0x7A3A22, 0.8), { x in 46 + 10 * sin(k * x * 2 + 1) + 6 * sin(k * x * 3) }, 7, 11)
            canopy(rgb(m.hill), rgb(0xC0622A, 0.8), { x in 22 + 8 * sin(k * x * 3 + 2) + 4 * sin(k * x * 5 + 0.4) }, 6, 9)
        case .ruins:
            func temple(_ cx: CGFloat, _ w: CGFloat, _ steps: Int, _ stepH: CGFloat, _ colour: CGColor) {
                var y = b, half = w / 2
                for _ in 0..<steps {
                    ctx.setFillColor(colour); ctx.fill(CGRect(x: cx - half, y: y - stepH, width: half * 2, height: stepH))
                    y -= stepH; half *= 0.8
                }
                // the stair up the middle, then the shrine with its dark door
                ctx.setFillColor(rgba(120, 180, 140, 0.08)); ctx.fill(CGRect(x: cx - 4, y: y, width: 8, height: b - y))
                for s in stride(from: Double(y) + 2, to: Double(b), by: 2.4) {
                    let l = CGMutablePath(); l.move(to: CGPoint(cx - 4, CGFloat(s))); l.addLine(to: CGPoint(cx + 4, CGFloat(s)))
                    stroke(ctx, l, rgba(0, 0, 0, 0.3), width: 0.5)
                }
                let shrineW = half * 1.2, shrineH = stepH * 1.6
                ctx.setFillColor(colour); ctx.fill(CGRect(x: cx - shrineW / 2, y: y - shrineH, width: shrineW, height: shrineH))
                ctx.fill(CGRect(x: cx - shrineW / 2 - 2, y: y - shrineH - 2.4, width: shrineW + 4, height: 2.4))
                ctx.setFillColor(rgb(m.flora)); ctx.fill(CGRect(x: cx - 2.4, y: y - shrineH * 0.7, width: 4.8, height: shrineH * 0.7))
            }
            temple(140, 150, 5, 11, rgb(m.hill))
            temple(360, 90, 4, 8, rgb(m.hillFar))
            let jungle = CGMutablePath(); jungle.addRect(CGRect(x: 0, y: b - 6, width: tw, height: 6))
            var x: CGFloat = 0
            while x < tw { jungle.addPath(circle(CGPoint(x, b - 4 - u(&rng) * 6), 6 + u(&rng) * 8)); x += 10 + u(&rng) * 10 }
            wrap(tw) { dx in fill(ctx, jungle.copy(using: [CGAffineTransform(translationX: dx, y: 0)])!, rgb(0x0C1A12)) }
        case .volcano, .glacier, .grove: break
        }
    }

    // MARK: Near layer (the cycads slot)

    static func drawThemedNear(_ ctx: CGContext, map: MapTheme) {
        let m = map.palette, colour = rgb(m.flora), b = cycadTileSize.height
        switch map {
        case .dunes:
            func saguaro(_ x: CGFloat, _ h: CGFloat) {
                fill(ctx, CGPath(roundedRect: CGRect(x: x - 3, y: b - h, width: 6, height: h), cornerWidth: 3, cornerHeight: 3, transform: nil), colour)
                let arms = CGMutablePath()
                arms.move(to: CGPoint(x, b - h * 0.42)); arms.addLine(to: CGPoint(x - 7, b - h * 0.42)); arms.addLine(to: CGPoint(x - 7, b - h * 0.72))
                arms.move(to: CGPoint(x, b - h * 0.58)); arms.addLine(to: CGPoint(x + 6.5, b - h * 0.58)); arms.addLine(to: CGPoint(x + 6.5, b - h * 0.82))
                stroke(ctx, arms, colour, width: 4.4)
            }
            func barrel(_ x: CGFloat, _ r: CGFloat) { fill(ctx, ellipse(CGPoint(x, b - r * 0.9), r, r * 1.1), colour) }
            func shrub(_ x: CGFloat) {
                for a in stride(from: -1.2, through: 1.2, by: 0.4) {
                    let l = CGMutablePath(); l.move(to: CGPoint(x, b)); l.addLine(to: CGPoint(x + sin(a) * 9, b - cos(a) * 8))
                    stroke(ctx, l, colour, width: 1)
                }
            }
            saguaro(58, 46); barrel(82, 4.5); shrub(130); fill(ctx, ellipse(CGPoint(168, b - 2), 9, 4), colour)
            saguaro(212, 32); barrel(236, 3.4); shrub(268)
        case .skyisles:
            func island(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, tree: Bool) {
                let rock = polygon([CGPoint(cx - w / 2, cy), CGPoint(cx + w / 2, cy), CGPoint(cx + w * 0.42, cy + w * 0.1),
                                    CGPoint(cx + w * 0.3, cy + w * 0.14), CGPoint(cx + w * 0.22, cy + w * 0.3), CGPoint(cx + w * 0.08, cy + w * 0.32),
                                    CGPoint(cx, cy + w * 0.46), CGPoint(cx - w * 0.1, cy + w * 0.3), CGPoint(cx - w * 0.26, cy + w * 0.22),
                                    CGPoint(cx - w * 0.4, cy + w * 0.1)])
                fill(ctx, rock, colour)
                for dx in [-0.25, 0.0, 0.18] as [CGFloat] {
                    let r = CGMutablePath(); r.move(to: CGPoint(cx + dx * w, cy + w * 0.2))
                    r.addQuadCurve(to: CGPoint(cx + dx * w - 1, cy + w * 0.2 + 7), control: CGPoint(cx + dx * w + 2, cy + w * 0.2 + 3))
                    stroke(ctx, r, colour, width: 0.8)
                }
                fill(ctx, ellipse(CGPoint(cx, cy), w / 2 + 1, 2.6), rgb(0x56709C))
                if tree {
                    // a pair of round bushes and a little ruin on the islet
                    fill(ctx, circle(CGPoint(cx - w * 0.22, cy - 2.6), 3.6), rgb(0x56709C))
                    fill(ctx, circle(CGPoint(cx - w * 0.1, cy - 2), 2.6), rgb(0x56709C))
                    ctx.setFillColor(rgb(0x56709C)); ctx.fill(CGRect(x: cx + w * 0.12, y: cy - 7, width: 2.2, height: 6))
                    ctx.fill(CGRect(x: cx + w * 0.24, y: cy - 5, width: 2.2, height: 4))
                }
            }
            island(72, 22, 46, tree: true); island(186, 12, 26, tree: false); island(258, 34, 18, tree: false)
        case .bamboo:
            func stalk(_ x: CGFloat, _ lean: CGFloat) {
                let s = CGMutablePath(); s.move(to: CGPoint(x, b)); s.addLine(to: CGPoint(x + lean, -2))
                stroke(ctx, s, colour, width: 2.4)
                for t in stride(from: 0.15, to: 1.0, by: 0.17) {
                    let y = b - (b + 2) * CGFloat(t), xx = x + lean * CGFloat(t)
                    let n = CGMutablePath(); n.move(to: CGPoint(xx - 1.8, y)); n.addLine(to: CGPoint(xx + 1.8, y))
                    stroke(ctx, n, colour, width: 1)
                }
            }
            func spray(_ x: CGFloat, _ y: CGFloat, _ dir: CGFloat) {
                for (a, len) in [(-0.5, 9.0), (-0.1, 11.0), (0.35, 8.0)] as [(CGFloat, CGFloat)] {
                    at(ctx, x, y, rotate: dir > 0 ? a : .pi - a) {
                        let leaf = CGMutablePath(); leaf.move(to: .zero)
                        leaf.addQuadCurve(to: CGPoint(len, 1.5), control: CGPoint(len * 0.5, -2))
                        leaf.addQuadCurve(to: .zero, control: CGPoint(len * 0.5, 2)); fill(ctx, leaf, colour)
                    }
                }
            }
            func lantern(_ x: CGFloat, _ y: CGFloat) {
                radial(ctx, at: CGPoint(x, y), radius: 16, [(0, rgba(255, 170, 90, 0.45)), (1, rgba(255, 140, 70, 0))])
                let body = ellipse(CGPoint(x, y), 4.2, 5.6)
                linear(ctx, clip: body, [(0, rgb(0xFFC27A)), (0.5, rgb(0xF0703C)), (1, rgb(0xB83A28))], from: CGPoint(x - 4, y), to: CGPoint(x + 4, y))
                for dx in [-1.8, 0, 1.8] as [CGFloat] {
                    let l = CGMutablePath(); l.move(to: CGPoint(x + dx, y - 5)); l.addQuadCurve(to: CGPoint(x + dx, y + 5), control: CGPoint(x + dx * 1.6, y))
                    stroke(ctx, l, rgba(120, 30, 20, 0.45), width: 0.5)
                }
                ctx.setFillColor(colour); ctx.fill(CGRect(x: x - 2.4, y: y - 6.6, width: 4.8, height: 1.6)); ctx.fill(CGRect(x: x - 2.4, y: y + 5, width: 4.8, height: 1.6))
                let tassel = CGMutablePath(); tassel.move(to: CGPoint(x, y + 6.6)); tassel.addLine(to: CGPoint(x, y + 10))
                stroke(ctx, tassel, rgb(0xB83A28), width: 0.8)
            }
            stalk(30, 3); stalk(38, -2); stalk(44, 5); spray(41, 14, 1); spray(33, 24, -1); spray(46, 6, 1)
            // a lantern on a post with an arm
            let post = CGMutablePath(); post.move(to: CGPoint(118, b)); post.addLine(to: CGPoint(118, 20)); post.addLine(to: CGPoint(128, 20))
            stroke(ctx, post, colour, width: 1.8)
            let cord = CGMutablePath(); cord.move(to: CGPoint(127, 20)); cord.addLine(to: CGPoint(127, 25)); stroke(ctx, cord, colour, width: 0.7)
            lantern(127, 31)
            stalk(196, -3); stalk(204, 2); spray(201, 10, -1); spray(197, 22, 1)
            let cord2 = CGMutablePath(); cord2.move(to: CGPoint(206, 12)); cord2.addLine(to: CGPoint(214, 14)); cord2.addLine(to: CGPoint(214, 20))
            stroke(ctx, cord2, colour, width: 0.7)
            lantern(214, 26)
            stalk(266, 4); spray(269, 18, 1)
        case .crystal:
            func cluster(_ x: CGFloat, _ h: CGFloat) {
                for (dx, sh, lean, wdt) in [(-6.0, 0.6, -0.35, 3.4), (0.0, 1.0, 0.05, 4.4), (5.5, 0.75, 0.3, 3.6), (10.0, 0.4, 0.5, 2.6)]
                    as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                    let hh = h * sh, bx = x + dx, tip = CGPoint(bx + lean * hh, b - hh)
                    let c = polygon([CGPoint(bx - wdt, b), CGPoint(bx - wdt + lean * hh * 0.85, b - hh * 0.85), tip,
                                     CGPoint(bx + wdt + lean * hh * 0.85, b - hh * 0.85), CGPoint(bx + wdt, b)])
                    fill(ctx, c, colour)
                    let edge = CGMutablePath(); edge.move(to: CGPoint(bx - wdt, b)); edge.addLine(to: CGPoint(bx - wdt + lean * hh * 0.85, b - hh * 0.85))
                    edge.addLine(to: tip)
                    stroke(ctx, edge, rgba(200, 140, 255, 0.4), width: 0.7)
                }
            }
            cluster(40, 38); cluster(124, 20); cluster(206, 46); cluster(272, 16)
        case .storm:
            func stack(_ x: CGFloat, _ h: CGFloat, _ w: CGFloat) {
                fill(ctx, polygon([CGPoint(x - w * 1.3, b), CGPoint(x - w, b - h * 0.35), CGPoint(x - w * 0.7, b - h * 0.42),
                                   CGPoint(x - w * 0.75, b - h * 0.8), CGPoint(x - w * 0.3, b - h), CGPoint(x + w * 0.2, b - h * 0.9),
                                   CGPoint(x + w * 0.5, b - h * 0.94), CGPoint(x + w * 0.65, b - h * 0.55), CGPoint(x + w, b - h * 0.4),
                                   CGPoint(x + w * 1.4, b)]), colour)
            }
            func grass(_ x: CGFloat) {
                for i in 0..<5 {
                    let h = 8 + CGFloat(i % 3) * 3
                    let g = CGMutablePath(); g.move(to: CGPoint(x + CGFloat(i) * 1.6, b))
                    g.addQuadCurve(to: CGPoint(x + CGFloat(i) * 1.6 - 7, b - h), control: CGPoint(x + CGFloat(i) * 1.6, b - h * 0.8))
                    stroke(ctx, g, colour, width: 1)
                }
            }
            stack(66, 32, 8); stack(88, 18, 6); grass(140); grass(168); fill(ctx, ellipse(CGPoint(200, b - 2), 10, 4), colour)
            stack(244, 24, 7); grass(280)
        case .autumn:
            func birch(_ x: CGFloat, _ lean: CGFloat, _ w: CGFloat) {
                let t = CGMutablePath(); t.move(to: CGPoint(x, b)); t.addLine(to: CGPoint(x + lean, -2))
                stroke(ctx, t, colour, width: w)
                for (f, dir) in [(0.45, 1.0), (0.62, -1.0), (0.8, 1.0)] as [(CGFloat, CGFloat)] {
                    let p = CGPoint(x + lean * f, b - (b + 2) * f)
                    let br = CGMutablePath(); br.move(to: p); br.addLine(to: CGPoint(p.x + dir * 8, p.y - 6))
                    stroke(ctx, br, colour, width: 1)
                    fill(ctx, circle(CGPoint(p.x + dir * 9, p.y - 7), 3.4), rgb(0x4A1E0C))
                }
            }
            birch(40, 2, 3); birch(52, -1, 2.2); birch(176, 1.5, 3.2); birch(262, -2, 2.6)
            fill(ctx, ellipse(CGPoint(110, b), 20, 7), colour); fill(ctx, ellipse(CGPoint(226, b), 14, 5), colour)
        case .ruins:
            func palm(_ x: CGFloat, _ h: CGFloat, _ lean: CGFloat) {
                let crown = CGPoint(x + lean, b - h)
                let trunk = CGMutablePath(); trunk.move(to: CGPoint(x, b)); trunk.addQuadCurve(to: crown, control: CGPoint(x - lean * 0.3, b - h * 0.5))
                stroke(ctx, trunk, colour, width: 3)
                for a in [-2.7, -2.1, -1.4, -0.9, -0.3, 0.3] as [CGFloat] {
                    let tip = CGPoint(crown.x + cos(a) * 17, crown.y + sin(a) * 9 + 9)
                    let ctl = CGPoint(crown.x + cos(a) * 10, crown.y + sin(a) * 9 - 3)
                    let f = CGMutablePath(); f.move(to: crown); f.addQuadCurve(to: tip, control: ctl)
                    f.addQuadCurve(to: crown, control: CGPoint(ctl.x, ctl.y + 4)); fill(ctx, f, colour)
                }
                for dx in [-9.0, 7.0] as [CGFloat] {
                    let v = CGMutablePath(); v.move(to: CGPoint(crown.x + dx, crown.y + 4))
                    v.addQuadCurve(to: CGPoint(crown.x + dx + 1, crown.y + 24), control: CGPoint(crown.x + dx - 2, crown.y + 14))
                    stroke(ctx, v, colour, width: 0.7)
                }
            }
            func fern(_ x: CGFloat) {
                for dx in [-1.0, -0.5, 0.5, 1.0] as [CGFloat] {
                    let f = CGMutablePath(); f.move(to: CGPoint(x, b))
                    f.addQuadCurve(to: CGPoint(x + dx * 12, b - 12 * (1 - abs(dx) * 0.4)), control: CGPoint(x + dx * 2, b - 14))
                    stroke(ctx, f, colour, width: 1.6)
                }
            }
            palm(46, 50, 8); fern(96)
            // a broken column stump
            ctx.setFillColor(colour); ctx.fill(CGRect(x: 132, y: b - 22, width: 9, height: 22)); ctx.fill(CGRect(x: 130, y: b - 4, width: 13, height: 4))
            fill(ctx, polygon([CGPoint(132, b - 22), CGPoint(135, b - 26), CGPoint(138, b - 23), CGPoint(141, b - 25), CGPoint(141, b - 22)]), colour)
            palm(214, 42, -6); fern(250); fern(284)
        case .volcano, .glacier, .grove: break
        }
    }

    // MARK: Ground

    static func drawThemedGround(_ ctx: CGContext, width: CGFloat, height: CGFloat, map: MapTheme) {
        let m = map.palette
        func base(_ a: CGFloat, line: CGFloat) {
            ctx.setFillColor(rgba(m.ground, a)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: height - 4))
            ctx.setFillColor(rgba(m.groundLine, line)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: 1))
        }
        let tiles = stride(from: 0.0, to: Double(width), by: 22).map { CGFloat($0) }
        switch map {
        case .dunes:
            base(0.7, line: 0.2)
            for x in tiles {
                for (x0, y, len) in [(2.0, 9.0, 11.0), (12.0, 14.5, 9.0), (5.0, 20.0, 12.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    let r = CGMutablePath(); r.move(to: CGPoint(x + x0, y)); r.addQuadCurve(to: CGPoint(x + x0 + len, y), control: CGPoint(x + x0 + len / 2, y - 2.2))
                    stroke(ctx, r, rgba(m.groundLine, 0.2), width: 0.8)
                }
            }
        case .skyisles:
            let cloud = CGMutablePath(); cloud.addRect(CGRect(x: 0, y: 7, width: width, height: height - 7))
            for x in tiles { cloud.addPath(circle(CGPoint(x + 5.5, 8), 5.6)); cloud.addPath(circle(CGPoint(x + 15, 7), 6.2)) }
            ctx.addPath(cloud); ctx.setFillColor(rgba(m.ground, 0.45)); ctx.fillPath()
            for x in tiles {
                stroke(ctx, arc(CGPoint(x + 15, 7), 5.2, from: .pi * 1.1, to: .pi * 1.6, steps: 6), white(0.4), width: 0.9)
                stroke(ctx, arc(CGPoint(x + 5.5, 8), 4.6, from: .pi * 1.1, to: .pi * 1.6, steps: 6), white(0.32), width: 0.8)
            }
        case .bamboo:
            base(0.72, line: 0.14)
            for x in tiles {
                for (dx, r) in [(3.0, 2.6), (8.5, 1.8), (14.0, 3.0), (19.0, 2.0)] as [(CGFloat, CGFloat)] {
                    fill(ctx, ellipse(CGPoint(x + dx, 4.6), r, r * 0.7), rgba(80, 130, 64, 0.85))
                }
                let tuft = CGMutablePath(); tuft.move(to: CGPoint(x + 11, 4)); tuft.addLine(to: CGPoint(x + 10, 0.8))
                tuft.move(to: CGPoint(x + 11.5, 4)); tuft.addLine(to: CGPoint(x + 12.8, 1.4))
                stroke(ctx, tuft, rgba(140, 200, 110, 0.6), width: 0.7)
                fill(ctx, ellipse(CGPoint(x + 6, 13), 2, 1.2), rgba(150, 210, 120, 0.12))
            }
        case .crystal:
            base(0.75, line: 0.16)
            for x in tiles {
                for (dx, y, r) in [(4.0, 9.0, 1.6), (11.0, 15.0, 2.2), (18.0, 8.0, 1.2), (7.0, 20.0, 1.4)] as [(CGFloat, CGFloat, CGFloat)] {
                    fill(ctx, ellipse(CGPoint(x + dx, y), r * 1.3, r), rgba(90, 70, 115, 0.5))
                }
                radial(ctx, at: CGPoint(x + 15, 11), radius: 3, [(0, rgba(210, 120, 255, 0.55)), (1, rgba(210, 120, 255, 0))])
                fill(ctx, polygon([CGPoint(x + 2, 4), CGPoint(x + 3.2, 1.4), CGPoint(x + 4.4, 4)]), rgba(190, 130, 250, 0.5))
            }
        case .storm:
            base(0.78, line: 0.38)
            for x in tiles {
                for (x0, y, len) in [(1.0, 8.0, 9.0), (12.0, 12.5, 7.0), (4.0, 18.0, 11.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    let l = CGMutablePath(); l.move(to: CGPoint(x + x0, y)); l.addLine(to: CGPoint(x + x0 + len, y))
                    stroke(ctx, l, rgba(m.groundLine, 0.16), width: 0.8)
                }
                fill(ctx, ellipse(CGPoint(x + 16, 22), 5, 1.4), rgba(140, 170, 200, 0.12))
            }
        case .autumn:
            base(0.75, line: 0.14)
            let hues: [UInt32] = [0xE8742A, 0xC8401E, 0xF0A83A, 0xD25A22, 0x8A3A1A]
            for x in tiles {
                for (i, (dx, y, a)) in ([(3.0, 3.2, 0.4), (9.0, 7.5, -0.8), (15.0, 3.6, 1.2), (19.0, 11.0, 0.2), (6.0, 15.0, 2.0)]
                                        as [(CGFloat, CGFloat, CGFloat)]).enumerated() {
                    fill(ctx, ellipse(CGPoint(x + dx, y), 2.4, 1.2, a), rgb(hues[i], 0.8))
                }
            }
        case .ruins:
            base(0.8, line: 0.14)
            for x in tiles {
                let j = CGMutablePath()
                j.move(to: CGPoint(x, 5)); j.addLine(to: CGPoint(x, 13))
                j.move(to: CGPoint(x, 13)); j.addLine(to: CGPoint(x + 22, 13))
                j.move(to: CGPoint(x + 11, 13)); j.addLine(to: CGPoint(x + 11, height))
                stroke(ctx, j, rgba(0, 0, 0, 0.45), width: 0.9)
                let lit = CGMutablePath(); lit.move(to: CGPoint(x + 1, 6)); lit.addLine(to: CGPoint(x + 21, 6))
                lit.move(to: CGPoint(x + 1, 14)); lit.addLine(to: CGPoint(x + 10, 14)); lit.move(to: CGPoint(x + 12, 14)); lit.addLine(to: CGPoint(x + 21, 14))
                stroke(ctx, lit, rgba(m.groundLine, 0.12), width: 0.7)
                for (dx, y) in [(0.6, 9.0), (11.4, 18.0), (6.0, 13.2)] as [(CGFloat, CGFloat)] {
                    fill(ctx, circle(CGPoint(x + dx, y), 0.9), rgba(90, 170, 90, 0.7))
                }
                let tuft = CGMutablePath(); tuft.move(to: CGPoint(x + 16, 4)); tuft.addLine(to: CGPoint(x + 15, 1)); tuft.move(to: CGPoint(x + 16.6, 4)); tuft.addLine(to: CGPoint(x + 18, 1.6))
                stroke(ctx, tuft, rgba(110, 190, 110, 0.5), width: 0.7)
            }
        case .volcano, .glacier, .grove: break
        }
    }
}
