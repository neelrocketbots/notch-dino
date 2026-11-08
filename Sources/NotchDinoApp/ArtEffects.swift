import CoreGraphics
import RunnerCore

/// Sprites for the effects on Pip and the field. The scene shows and moves them; the rules live in RunnerCore.
extension Art {
    // MARK: On Pip

    /// Pip puffed up for Bloat, same size and origin as `pip(_:hero:)` so the scene can swap textures: a rounder belly
    /// over the body, the hero's near wing and details redrawn on top, and a puffed cheek.
    static func puffedPip(_ pose: PipPose, hero: Hero = .pip) -> CGImage {
        let p = hero.palette, up = pose == .wingUp
        return image(pipSize) { ctx in
            ctx.translateBy(x: pipOrigin.x, y: pipOrigin.y)
            drawPip(ctx, pose, hero: hero)
            linear(ctx, clip: ellipse(CGPoint(0, 4.5), 12, 10.5), [(0, rgb(p.light)), (0.45, rgb(p.body)), (1, rgb(p.shade))],
                   from: CGPoint(-6, -8), to: CGPoint(6, 15))
            fill(ctx, ellipse(CGPoint(3, 7.5), 7.5, 5.5, -0.2), rgb(p.belly, 0.9))
            stroke(ctx, arc(CGPoint(0, 4.5), 9.5, from: .pi * 1.1, to: .pi * 1.4), white(0.4), width: 1.2)
            // the hero's own near wing and overlay (frill, freckles, seams) back on top of the puffed belly
            drawNearWing(ctx, up: up, hero: hero, p)
            if hero == .nova {
                for (x, y) in (up ? [(-9.0, -13.0), (-14.0, -9.0), (-12.0, -4.0)] : [(-10.0, 9.0), (-15.0, 5.0), (-12.0, 1.0)]) as [(CGFloat, CGFloat)] {
                    fill(ctx, circle(CGPoint(x, y), 0.8), white(0.85))
                }
            }
            drawHeroOverlay(ctx, hero, p)
            fill(ctx, circle(CGPoint(13, -1.8), 2.4), rgb(p.light, 0.85))
        }
    }

    /// Grey cracks for Stone scale, in Pip's frame, drawn over the stone patches.
    static func stoneCracks() -> CGImage {
        image(pipSize) { ctx in
            ctx.translateBy(x: pipOrigin.x, y: pipOrigin.y)
            for pts in [[(-7.0, -1.0), (-4.0, 2.0), (-5.0, 5.5), (-2.0, 8.0)],
                        [(2.0, 1.0), (4.5, 3.5), (3.5, 7.0)],
                        [(5.0, -11.0), (7.5, -8.0), (6.5, -5.5)]] as [[(CGFloat, CGFloat)]] {
                let c = CGMutablePath(); c.addLines(between: pts.map { CGPoint($0.0, $0.1) })
                stroke(ctx, c, rgba(70, 64, 66, 0.9), width: 1.1)
                stroke(ctx, c, rgba(190, 182, 184, 0.35), width: 0.4)
            }
        }
    }

    static let featherChargeSize = CGSize(width: 16, height: 16)

    /// The small feather that circles Pip while the feather charge is held.
    static func featherCharge() -> CGImage {
        image(featherChargeSize) { ctx in
            ctx.translateBy(x: 8, y: 8); ctx.scaleBy(x: 0.75, y: 0.75)
            iconFeather(ctx)
        }
    }
}

/// Sprites for the field effects.
extension Art {
    // MARK: On the field

    /// Rush's speed lines for a field of `size`: thin pale streaks at seeded heights, tiled sideways by the scene.
    static func speedLines(size: CGSize) -> CGImage {
        image(size) { ctx in
            var rng = SeededRandom(seed: 21)
            let count = max(6, Int(size.height / 14))
            for _ in 0..<count {
                let y = CGFloat(rng.unit()) * size.height, x = CGFloat(rng.unit()) * size.width
                let len = 30 + CGFloat(rng.unit()) * 60, a = 0.18 + CGFloat(rng.unit()) * 0.25
                let l = CGMutablePath(); l.move(to: CGPoint(x, y)); l.addLine(to: CGPoint(x + len, y))
                stroke(ctx, l, rgba(255, 222, 212, a), width: 1)
            }
        }
    }

    static let shimmerSize = CGSize(width: 30, height: 34)

    /// Updraft's heat shimmer: warm wavy lines rising under Pip.
    static func shimmer() -> CGImage {
        image(shimmerSize) { ctx in
            for (i, x) in ([6.0, 12.0, 18.0, 24.0] as [CGFloat]).enumerated() {
                let l = CGMutablePath(); l.move(to: CGPoint(x, 33))
                let d: CGFloat = i % 2 == 0 ? 2.2 : -2.2
                l.addCurve(to: CGPoint(x, 3), control1: CGPoint(x + d, 23), control2: CGPoint(x - d, 13))
                stroke(ctx, l, rgba(255, 206, 150, 0.4), width: 1.2)
            }
        }
    }

    /// The puff where a feather bounce meets the ceiling or the ground.
    static func bouncePuff() -> CGImage {
        image(CGSize(width: 30, height: 14)) { ctx in
            for (x, y, r) in [(6.0, 8.0, 4.5), (13.0, 6.0, 5.5), (21.0, 7.5, 4.8), (26.0, 9.0, 3.2), (10.0, 10.0, 3.6)]
                as [(CGFloat, CGFloat, CGFloat)] {
                fill(ctx, circle(CGPoint(x, y), r), rgba(236, 232, 236, 0.75))
            }
        }
    }
}
