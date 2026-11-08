import CoreGraphics
import RunnerCore

extension Art {
    static func rgba(_ c: MapPalette.RGB, _ a: CGFloat) -> CGColor { rgba(c.0, c.1, c.2, a) }

    /// The sky over the whole island (the band's fade sits on top in SwiftUI), translucent near the horizon so the
    /// island's frost shows, with a haze above the ground in the map's light (ember, ice or firefly).
    static func sky(size: CGSize, fieldTop: CGFloat, fieldHeight: CGFloat, groundY: CGFloat, map: MapTheme = .volcano) -> CGImage {
        let m = map.palette
        return image(size) { ctx in
            let rect = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            let mid = (fieldTop + fieldHeight * 0.35) / size.height
            linear(ctx, clip: rect, [(0, rgba(m.skyTop, 0)), (mid, rgba(m.skyMid, 0.8)), (1, rgba(m.skyLow, 0.82))],
                   from: CGPoint(0, 0), to: CGPoint(0, size.height))
            let haze = CGPath(rect: CGRect(x: 0, y: groundY - 60, width: size.width, height: 60), transform: nil)
            linear(ctx, clip: haze, [(0, rgba(m.haze, 0)), (1, rgba(m.haze, 0.12))],
                   from: CGPoint(0, groundY - 60), to: CGPoint(0, groundY))
            if !map.isClassic { drawSkyExtras(ctx, size: size, groundY: groundY, map: map) }
        }
    }

    static let starsTileSize = CGSize(width: 700, height: 190)

    static func stars(map: MapTheme = .volcano) -> CGImage {
        guard map.isClassic else { return image(starsTileSize) { drawThemedAmbient($0, map: map) } }
        let m = map.palette
        return image(starsTileSize) { ctx in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<46 {
                let x = CGFloat(rng.unit()) * 700, y = CGFloat(rng.unit()) * 190
                let s: CGFloat = rng.unit() < 0.2 ? 1.6 : 1
                let a = 0.25 + CGFloat(rng.unit()) * 0.45
                ctx.setFillColor(rgba(m.star, a)); ctx.fill(CGRect(x: x, y: y, width: s, height: s))
            }
            if map == .grove {
                // fireflies low in the tile
                for _ in 0..<9 {
                    let c = CGPoint(CGFloat(rng.unit()) * 700, 120 + CGFloat(rng.unit()) * 60)
                    radial(ctx, at: c, radius: 4, [(0, rgba(m.haze, 0.7)), (1, rgba(m.haze, 0))])
                }
            }
        }
    }

    static let volcanoTileSize = CGSize(width: 460, height: 90)

    /// The far layer: volcanoes, snow-capped peaks, or rolling hills.
    static func volcanoes(map: MapTheme = .volcano) -> CGImage {
        let m = map.palette
        return image(volcanoTileSize) { ctx in
            let b: CGFloat = 90
            switch map {
            case .volcano:
                func volcano(_ cx: CGFloat, _ h: CGFloat, _ base: CGFloat, _ top: CGFloat, _ color: UInt32) {
                    let p = CGMutablePath(); p.move(to: CGPoint(cx - base / 2, b))
                    p.addQuadCurve(to: CGPoint(cx - top / 2, b - h), control: CGPoint(cx - base * 0.18, b - h * 0.55))
                    p.addLine(to: CGPoint(cx + top / 2, b - h))
                    p.addQuadCurve(to: CGPoint(cx + base / 2, b), control: CGPoint(cx + base * 0.2, b - h * 0.5))
                    p.closeSubpath()
                    fill(ctx, p, rgb(color))
                }
                volcano(110, 74, 170, 16, m.hill)
                volcano(330, 50, 130, 12, m.hillFar)
            case .glacier:
                func peak(_ cx: CGFloat, _ h: CGFloat, _ half: CGFloat, _ color: UInt32) {
                    let top = CGPoint(cx, b - h)
                    fill(ctx, polygon([CGPoint(cx - half, b), CGPoint(cx - half * 0.45, b - h * 0.62), top,
                                       CGPoint(cx + half * 0.35, b - h * 0.7), CGPoint(cx + half, b)]), rgb(color))
                    let cap = h * 0.28
                    fill(ctx, polygon([top, CGPoint(cx + half * 0.3 * cap / h * 2.4, b - h + cap),
                                       CGPoint(cx + 2, b - h + cap * 0.7), CGPoint(cx - 4, b - h + cap),
                                       CGPoint(cx - half * 0.3 * cap / h * 2.4, b - h + cap * 0.8)]), rgba(225, 240, 250, 0.5))
                }
                peak(330, 52, 80, m.hillFar)
                peak(120, 78, 95, m.hill)
                peak(200, 46, 55, m.hill)
            case .grove:
                func hill(_ cx: CGFloat, _ h: CGFloat, _ half: CGFloat, _ color: UInt32) {
                    let p = CGMutablePath(); p.move(to: CGPoint(cx - half, b))
                    p.addCurve(to: CGPoint(cx + half, b), control1: CGPoint(cx - half * 0.5, b - h * 1.3),
                               control2: CGPoint(cx + half * 0.5, b - h * 1.3))
                    p.closeSubpath(); fill(ctx, p, rgb(color))
                }
                hill(340, 44, 130, m.hillFar)
                hill(110, 58, 140, m.hill)
            default:
                drawThemedFar(ctx, map: map)
            }
        }
    }

    static let cycadTileSize = CGSize(width: 300, height: 60)

    /// The near layer: cycads, pines, or giant mushrooms and ferns.
    static func cycads(map: MapTheme = .volcano) -> CGImage {
        let colour = rgb(map.palette.flora)
        return image(cycadTileSize) { ctx in
            let b: CGFloat = 60
            switch map {
            case .volcano:
                func cycad(_ x: CGFloat, _ h: CGFloat) {
                    let top = b - h
                    fill(ctx, polygon([CGPoint(x - 2.5, b), CGPoint(x - 1.5, top), CGPoint(x + 1.5, top), CGPoint(x + 2.5, b)]), colour)
                    for (dx, lift) in [(-1.0, 1.0), (1.0, 1.0), (-0.8, 0.4), (0.8, 0.4), (-0.3, 1.6), (0.3, 1.6)] as [(CGFloat, CGFloat)] {
                        let end = CGPoint(x + dx * 24, top + 8 - lift * 4), ctl = CGPoint(x + dx * 12, top - 8 * lift)
                        let f = CGMutablePath(); f.move(to: CGPoint(x, top)); f.addQuadCurve(to: end, control: ctl)
                        stroke(ctx, f, colour, width: 2)
                        for i in stride(from: 3, to: 11, by: 2) {
                            let t = CGFloat(i) / 12, u = 1 - t
                            let px = u * u * x + 2 * u * t * ctl.x + t * t * end.x
                            let py = u * u * top + 2 * u * t * ctl.y + t * t * end.y
                            let leaf = CGMutablePath(); leaf.move(to: CGPoint(px, py)); leaf.addLine(to: CGPoint(px + dx * 2, py + 5))
                            stroke(ctx, leaf, colour, width: 1)
                        }
                    }
                }
                cycad(60, 38); cycad(86, 24); cycad(210, 46)
            case .glacier:
                func pine(_ x: CGFloat, _ h: CGFloat) {
                    ctx.setFillColor(colour); ctx.fill(CGRect(x: x - 1.5, y: b - 6, width: 3, height: 6))
                    let tiers = 4
                    for i in 0..<tiers {
                        let t = CGFloat(i) / CGFloat(tiers)
                        let y0 = b - 4 - t * (h - 4), half = (1 - t) * h * 0.32 + 3
                        fill(ctx, polygon([CGPoint(x - half, y0), CGPoint(x, y0 - h * 0.4), CGPoint(x + half, y0)]), colour)
                    }
                }
                pine(48, 44); pine(70, 30); pine(190, 50); pine(214, 34); pine(262, 22)
            case .grove:
                func mushroom(_ x: CGFloat, _ h: CGFloat, _ capW: CGFloat) {
                    fill(ctx, polygon([CGPoint(x - 2.2, b), CGPoint(x - 1.6, b - h), CGPoint(x + 1.6, b - h), CGPoint(x + 2.2, b)]), colour)
                    let cap = CGMutablePath(); cap.move(to: CGPoint(x - capW, b - h + 2))
                    cap.addQuadCurve(to: CGPoint(x + capW, b - h + 2), control: CGPoint(x, b - h - capW * 1.1))
                    cap.closeSubpath(); fill(ctx, cap, colour)
                }
                func fern(_ x: CGFloat, _ h: CGFloat) {
                    for dx in [-1.0, -0.4, 0.4, 1.0] as [CGFloat] {
                        let f = CGMutablePath(); f.move(to: CGPoint(x, b))
                        f.addQuadCurve(to: CGPoint(x + dx * 14, b - h * (1 - abs(dx) * 0.3)), control: CGPoint(x + dx * 2, b - h))
                        stroke(ctx, f, colour, width: 1.6)
                    }
                }
                mushroom(62, 40, 14); mushroom(84, 22, 9); fern(130, 18); mushroom(220, 48, 17); fern(258, 22)
            default:
                drawThemedNear(ctx, map: map)
            }
        }
    }

    /// The ground strip from y = 4 (the ground line) down, with tufts in the 4 pt above it. The scene puts the image's
    /// top 4 pt above the ground line.
    static func ground(width: CGFloat, height: CGFloat, map: MapTheme = .volcano) -> CGImage {
        guard map.isClassic else { return image(CGSize(width: width, height: height)) { drawThemedGround($0, width: width, height: height, map: map) } }
        let m = map.palette
        return image(CGSize(width: width, height: height)) { ctx in
            ctx.setFillColor(rgba(m.ground, map == .glacier ? 0.32 : 0.66)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: height - 4))
            ctx.setFillColor(rgba(m.groundLine, map == .glacier ? 0.35 : 0.12)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: 1))
            var x: CGFloat = 0
            while x < width {
                let v = CGMutablePath(); v.move(to: CGPoint(x, 1)); v.addLine(to: CGPoint(x + 2, 4)); v.addLine(to: CGPoint(x + 4, 0))
                stroke(ctx, v, rgba(m.groundLine, map == .volcano ? 0.08 : 0.16), width: 1)
                x += 22
            }
        }
    }

    static func smoke(size: CGSize, map: MapTheme = .volcano) -> CGImage {
        let m = map.palette
        return image(size) { ctx in
            let rect = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            linear(ctx, clip: rect, [(0, rgba(m.smoke, 0)), (60 / size.width, rgba(m.smoke, 0.82)), (1, rgba(m.smoke, 0.82))],
                   from: CGPoint(0, 0), to: CGPoint(size.width, 0))
            var rng = SeededRandom(seed: 5)
            for _ in 0..<26 {
                let c = CGPoint(30 + CGFloat(rng.unit()) * (size.width - 30), CGFloat(rng.unit()) * size.height)
                let r = 14 + CGFloat(rng.unit()) * 26
                let j = (CGFloat(rng.unit()), CGFloat(rng.unit()), CGFloat(rng.unit()))
                let tone = rgba(min(255, m.smoke.0 + 30 + j.0 * 30), min(255, m.smoke.1 + 26 + j.1 * 20), min(255, m.smoke.2 + 26 + j.2 * 20), 0.35)
                radial(ctx, at: c, radius: r, [(0, tone), (1, tone.copy(alpha: 0)!)])
            }
        }
    }
}
