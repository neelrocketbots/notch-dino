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
