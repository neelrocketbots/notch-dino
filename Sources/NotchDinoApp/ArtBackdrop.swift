import CoreGraphics
import RunnerCore

extension Art {
    /// Oxblood sky over the whole island (the band's fade sits on top in SwiftUI), translucent near the horizon so the
    /// island's frost shows, with an ember haze above the ground.
    static func sky(size: CGSize, fieldTop: CGFloat, fieldHeight: CGFloat, groundY: CGFloat) -> CGImage {
        image(size) { ctx in
            let rect = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            let mid = (fieldTop + fieldHeight * 0.35) / size.height
            linear(ctx, clip: rect, [(0, rgba(10, 4, 5, 0)), (mid, rgba(16, 6, 7, 0.8)), (1, rgba(52, 16, 16, 0.82))],
                   from: CGPoint(0, 0), to: CGPoint(0, size.height))
            let haze = CGPath(rect: CGRect(x: 0, y: groundY - 60, width: size.width, height: 60), transform: nil)
            linear(ctx, clip: haze, [(0, rgba(255, 90, 60, 0)), (1, rgba(255, 90, 60, 0.12))],
                   from: CGPoint(0, groundY - 60), to: CGPoint(0, groundY))
        }
    }

    static let starsTileSize = CGSize(width: 700, height: 190)

    static func stars() -> CGImage {
        image(starsTileSize) { ctx in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<46 {
                let x = CGFloat(rng.unit()) * 700, y = CGFloat(rng.unit()) * 190
                let s: CGFloat = rng.unit() < 0.2 ? 1.6 : 1
                let a = 0.25 + CGFloat(rng.unit()) * 0.45
                ctx.setFillColor(rgba(255, 228, 214, a)); ctx.fill(CGRect(x: x, y: y, width: s, height: s))
            }
        }
    }

    static let volcanoTileSize = CGSize(width: 460, height: 90)

    static func volcanoes() -> CGImage {
        image(volcanoTileSize) { ctx in
            func volcano(_ cx: CGFloat, _ h: CGFloat, _ base: CGFloat, _ top: CGFloat, _ color: UInt32) {
                let b: CGFloat = 90
                let p = CGMutablePath(); p.move(to: CGPoint(cx - base / 2, b))
                p.addQuadCurve(to: CGPoint(cx - top / 2, b - h), control: CGPoint(cx - base * 0.18, b - h * 0.55))
                p.addLine(to: CGPoint(cx + top / 2, b - h))
                p.addQuadCurve(to: CGPoint(cx + base / 2, b), control: CGPoint(cx + base * 0.2, b - h * 0.5))
                p.closeSubpath()
                fill(ctx, p, rgb(color))
            }
            volcano(110, 74, 170, 16, Palette.hill)
            volcano(330, 50, 130, 12, Palette.hillFar)
        }
    }

    static let cycadTileSize = CGSize(width: 300, height: 60)

    static func cycads() -> CGImage {
        image(cycadTileSize) { ctx in
            func cycad(_ x: CGFloat, _ h: CGFloat) {
                let b: CGFloat = 60, top = b - h, colour = rgb(Palette.cycad)
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
        }
    }

    /// The ground strip from y = 4 (the ground line) down, with grass tufts in the 4 pt above it. The scene puts the
    /// image's top 4 pt above the ground line.
    static func ground(width: CGFloat, height: CGFloat) -> CGImage {
        image(CGSize(width: width, height: height)) { ctx in
            ctx.setFillColor(rgba(34, 12, 13, 0.66)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: height - 4))
            ctx.setFillColor(rgba(255, 190, 170, 0.12)); ctx.fill(CGRect(x: 0, y: 4, width: width, height: 1))
            var x: CGFloat = 0
            while x < width {
                let v = CGMutablePath(); v.move(to: CGPoint(x, 1)); v.addLine(to: CGPoint(x + 2, 4)); v.addLine(to: CGPoint(x + 4, 0))
                stroke(ctx, v, white(0.08), width: 1)
                x += 22
            }
        }
    }

    static func smoke(size: CGSize) -> CGImage {
        image(size) { ctx in
            let rect = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            linear(ctx, clip: rect, [(0, rgba(40, 32, 34, 0)), (60 / size.width, rgba(40, 32, 34, 0.82)), (1, rgba(40, 32, 34, 0.82))],
                   from: CGPoint(0, 0), to: CGPoint(size.width, 0))
            var rng = SeededRandom(seed: 5)
            for _ in 0..<26 {
                let c = CGPoint(30 + CGFloat(rng.unit()) * (size.width - 30), CGFloat(rng.unit()) * size.height)
                let r = 14 + CGFloat(rng.unit()) * 26
                let tone = rgba(70 + CGFloat(rng.unit()) * 30, 58 + CGFloat(rng.unit()) * 20, 60 + CGFloat(rng.unit()) * 20, 0.35)
                radial(ctx, at: c, radius: r, [(0, tone), (1, tone.copy(alpha: 0)!)])
            }
        }
    }
}
