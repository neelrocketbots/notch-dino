import CoreGraphics
import RunnerCore

/// The ten pickup icons, 34 × 34 pt, centred. Good ones are a warm glowing core in a soft halo; bad ones are ashen
/// on a dark disc inside a dashed red ring. Both read on every map's sky: the halo and the disc carry the contrast.
extension Art {
    /// The colour a pickup is known by: its burst, its chip and its glow.
    static func pickupTint(_ p: Pickup) -> UInt32 {
        switch p {
        case .ember: 0xFF8A3C
        case .egg: 0xF2B65A
        case .updraft: 0xFFE7C2
        case .feather: 0xFFD9A0
        case .tiny: 0xFFC46B
        case .ashCloud: 0x8A7F82
        case .stoneScale: 0x9A9092
        case .hiccups: 0xB0A6A8
        case .rush: 0xA89A9C
        case .bloat: 0x9C9294
        }
    }

    static func pickupIcon(_ p: Pickup) -> CGImage {
        image(pickupSize) { ctx in
            ctx.translateBy(x: 17, y: 17)
            if p.isGood { goodBase(ctx) } else { badBase(ctx) }
            switch p {
            case .ember: iconEmber(ctx)
            case .egg: iconEgg(ctx)
            case .updraft: iconUpdraft(ctx)
            case .feather: iconFeather(ctx)
            case .tiny: iconTiny(ctx)
            case .ashCloud: iconAsh(ctx)
            case .stoneScale: iconStone(ctx)
            case .hiccups: iconHiccups(ctx)
            case .rush: iconRush(ctx)
            case .bloat: iconBloat(ctx)
            }
        }
    }

    // MARK: Bases

    /// A soft warm halo with a faint solid rim: reads as "glowing" on dark skies and as a warm disc on light ground.
    static func goodBase(_ ctx: CGContext) {
        radial(ctx, at: .zero, radius: 16.5, [(0, rgba(255, 214, 140, 0.62)), (0.5, rgba(255, 150, 70, 0.3)),
                                               (1, rgba(255, 110, 60, 0))])
        fill(ctx, circle(.zero, 10), rgba(70, 24, 10, 0.45))
        stroke(ctx, circle(.zero, 10), rgba(255, 214, 150, 0.7), width: 1)
    }

    /// A dark ashen disc inside a dashed red ring. The ring sits on a thin dark band so the red holds up on the warm
    /// skies (dunes, autumn), where red on orange alone would melt.
    static func badBase(_ ctx: CGContext) {
        fill(ctx, circle(.zero, 10.5), rgba(30, 24, 26, 0.8))
        stroke(ctx, circle(.zero, 11), rgba(20, 10, 12, 0.55), width: 3)
        ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [3, 2.2])
        stroke(ctx, circle(.zero, 11), rgba(255, 70, 48, 1), width: 1.8); ctx.restoreGState()
    }

    // MARK: Good

    static func iconEmber(_ ctx: CGContext) {
        let f = CGMutablePath(); f.move(to: CGPoint(0, 6.5))
        f.addCurve(to: CGPoint(-0.5, -8.5), control1: CGPoint(-6, 5), control2: CGPoint(-6, -2))
        f.addCurve(to: CGPoint(5, 2), control1: CGPoint(1, -3), control2: CGPoint(6, -1))
        f.addCurve(to: CGPoint(0, 6.5), control1: CGPoint(4.5, 5.5), control2: CGPoint(2.5, 6.5)); f.closeSubpath()
        linear(ctx, clip: f, [(0, rgb(0xFFF4C8)), (0.5, rgb(0xFFB13B)), (1, rgb(0xFF5A3C))], from: CGPoint(0, -8.5), to: CGPoint(0, 6.5))
        fill(ctx, ellipse(CGPoint(0.4, 2.2), 1.8, 2.8), rgba(255, 250, 225, 0.95))
    }

    static func iconEgg(_ ctx: CGContext) {
        linear(ctx, clip: ellipse(CGPoint(0, 0.5), 5.4, 7), [(0, rgb(0xFFF4CC)), (0.5, rgb(0xF2B65A)), (1, rgb(0xC9762E))],
               from: CGPoint(-4, -7), to: CGPoint(4, 7))
        for (x, y, r) in [(-1.8, -1.5, 0.8), (1.6, 1.0, 0.9), (-0.6, 3.2, 0.6), (2.0, -3.2, 0.6)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgba(120, 60, 20, 0.55))
        }
        stroke(ctx, arc(.zero, 4.2, from: .pi * 1.15, to: .pi * 1.45), white(0.8), width: 1)
    }

    /// Three warm arcs rising.
    static func iconUpdraft(_ ctx: CGContext) {
        for (y, w) in [(-4.0, 7.0), (0.0, 10.0), (4.0, 7.0)] as [(CGFloat, CGFloat)] {
            let l = CGMutablePath(); l.move(to: CGPoint(-w / 2, y + 1.5)); l.addQuadCurve(to: CGPoint(w / 2, y + 1.5), control: CGPoint(0, y - 2.5))
            stroke(ctx, l, rgb(0xFFE7C2), width: 1.8)
        }
    }

    /// A cream quill, tilted, with a warm shaft.
    static func iconFeather(_ ctx: CGContext) {
        at(ctx, 0, 0, rotate: 0.6) {
            let vane = CGMutablePath(); vane.move(to: CGPoint(0, 7.5))
            vane.addQuadCurve(to: CGPoint(0, -8.5), control: CGPoint(-6.5, -1))
            vane.addQuadCurve(to: CGPoint(0, 7.5), control: CGPoint(5.5, 0)); vane.closeSubpath()
            linear(ctx, clip: vane, [(0, rgb(0xFFF8E6)), (1, rgb(0xFFC97A))], from: CGPoint(0, -8.5), to: CGPoint(0, 7.5))
            for y in [-4.0, -1.0, 2.0] as [CGFloat] {
                let b = CGMutablePath(); b.move(to: CGPoint(0, y + 2)); b.addLine(to: CGPoint(-3.6, y))
                b.move(to: CGPoint(0, y + 2)); b.addLine(to: CGPoint(3.2, y))
                stroke(ctx, b, rgba(200, 120, 50, 0.55), width: 0.6)
            }
            let shaft = CGMutablePath(); shaft.move(to: CGPoint(0, 10)); shaft.addLine(to: CGPoint(0, -7.5))
            stroke(ctx, shaft, rgb(0xE07A2E), width: 1)
        }
    }

    /// A small bright dot with four corner brackets pointing in.
    static func iconTiny(_ ctx: CGContext) {
        radial(ctx, at: .zero, radius: 4, [(0, rgb(0xFFF4C8)), (0.6, rgb(0xFFB13B)), (1, rgba(255, 120, 50, 0))])
        fill(ctx, circle(.zero, 2.2), rgb(0xFFF4C8))
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] as [(CGFloat, CGFloat)] {
            let c = CGMutablePath()
            c.move(to: CGPoint(sx * 7, sy * 3.5)); c.addLine(to: CGPoint(sx * 4.5, sy * 4.5)); c.addLine(to: CGPoint(sx * 3.5, sy * 7))
            stroke(ctx, c, rgb(0xFFD9A0), width: 1.5)
        }
    }

    // MARK: Bad

    static func iconAsh(_ ctx: CGContext) {
        for (x, y, r) in [(-3.5, 1.0, 3.4), (0.0, -1.5, 4.2), (3.6, 1.0, 3.2), (0.0, 2.4, 3.2)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgb(0x8A7F82))
        }
        fill(ctx, ellipse(CGPoint(0, 3.6), 5.6, 1.8), rgb(0x5C5254))
        stroke(ctx, arc(CGPoint(0, -1.5), 4.2, from: .pi * 1.1, to: .pi * 1.6), white(0.35), width: 0.9)
    }

    static func iconStone(_ ctx: CGContext) {
        fill(ctx, polygon([CGPoint(-6, 1), CGPoint(-3, -5), CGPoint(3, -5.5), CGPoint(6.5, -1), CGPoint(4, 5), CGPoint(-3.5, 5)]), rgb(0x8A8082))
        fill(ctx, polygon([CGPoint(-3, -5), CGPoint(3, -5.5), CGPoint(1, 0), CGPoint(-6, 1)]), rgb(0xACA2A4))
        let crack = CGMutablePath(); crack.move(to: CGPoint(1, 0)); crack.addLine(to: CGPoint(2.5, 2.5)); crack.addLine(to: CGPoint(1.8, 5))
        stroke(ctx, crack, rgba(20, 14, 16, 0.7), width: 0.9)
    }

    static func iconHiccups(_ ctx: CGContext) {
        for (x, y, r) in [(-2.0, 2.0, 4.0), (3.4, -2.8, 2.6), (4.0, 3.6, 1.5)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(ctx, circle(CGPoint(x, y), r), rgba(176, 166, 168, 0.22))
            stroke(ctx, circle(CGPoint(x, y), r), rgb(0xB0A6A8), width: 1.3)
        }
        fill(ctx, circle(CGPoint(-3.4, 0.6), 1), white(0.6))
    }

    /// Two ashen chevrons with speed lines behind them.
    static func iconRush(_ ctx: CGContext) {
        for x in [-1.5, 3.0] as [CGFloat] {
            let c = CGMutablePath(); c.move(to: CGPoint(x - 2.5, -4.5)); c.addLine(to: CGPoint(x + 1.5, 0)); c.addLine(to: CGPoint(x - 2.5, 4.5))
            stroke(ctx, c, rgb(0xB8ACAE), width: 1.8)
        }
        for (y, len) in [(-2.5, 3.0), (2.5, 3.0)] as [(CGFloat, CGFloat)] {
            let l = CGMutablePath(); l.move(to: CGPoint(-5.5, y)); l.addLine(to: CGPoint(-5.5 - len, y))
            stroke(ctx, l, rgb(0x8A7F82), width: 1.1)
        }
    }

    /// A puffed grey ball with outward ticks.
    static func iconBloat(_ ctx: CGContext) {
        linear(ctx, clip: circle(.zero, 5.6), [(0, rgb(0xB0A6A8)), (1, rgb(0x6E6466))], from: CGPoint(-4, -5), to: CGPoint(4, 5))
        stroke(ctx, arc(.zero, 3.8, from: .pi * 1.1, to: .pi * 1.45), white(0.5), width: 0.9)
        for a in stride(from: CGFloat.pi / 4, to: .pi * 2, by: .pi / 2) {
            let t = CGMutablePath()
            t.move(to: CGPoint(cos(a) * 7, sin(a) * 7)); t.addLine(to: CGPoint(cos(a) * 8.8, sin(a) * 8.8))
            stroke(ctx, t, rgb(0x9C9294), width: 1.2)
        }
    }
}
