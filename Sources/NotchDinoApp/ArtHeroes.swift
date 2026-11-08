import CoreGraphics

/// The signature details of the later heroes. Pip, Moss and Nova draw entirely in ArtSprites.swift; these hook in at
/// the wing, headgear, back and overlay steps of `drawPip`, in Pip's frame (body centre at the origin, facing right).
extension Art {
    // MARK: Wings

    /// The wing outline for a hero: Pip's for most, shortened for Saffron, a fin for Tide, petals for Blossom.
    static func heroWing(up: Bool, hero: Hero) -> CGPath {
        switch hero {
        case .saffron: return stubby(wing(up: up))
        case .tide: return finWing(up: up)
        case .blossom:
            let p = CGMutablePath()
            for petal in petals(up: up) { p.addPath(petal) }
            return p
        default: return wing(up: up)
        }
    }

    /// Saffron's wings: Pip's, shrunk toward the shoulder.
    private static let stubbyRoot = CGPoint(-2, -2)
    private static func stubby(_ path: CGPath) -> CGPath {
        var t = CGAffineTransform(translationX: stubbyRoot.x, y: stubbyRoot.y).scaledBy(x: 0.62, y: 0.6)
            .translatedBy(x: -stubbyRoot.x, y: -stubbyRoot.y)
        return path.copy(using: &t)!
    }

    /// Tide's fin: spines from the shoulder, webbing scooped between them.
    private static func finTips(up: Bool) -> [CGPoint] {
        up ? [CGPoint(-6, -24), CGPoint(-12.5, -20.5), CGPoint(-17.5, -14), CGPoint(-19.5, -6)]
           : [CGPoint(-10, 16), CGPoint(-15.5, 12.5), CGPoint(-19.5, 6.5), CGPoint(-18.5, -0.5)]
    }
    private static let finRoot = CGPoint(-1, -3)

    private static func finEdge(up: Bool) -> CGMutablePath {
        let tips = finTips(up: up), p = CGMutablePath()
        p.move(to: tips[0])
        for (a, b) in zip(tips, tips.dropFirst()) {
            let mid = CGPoint((a.x + b.x) / 2, (a.y + b.y) / 2)
            p.addQuadCurve(to: b, control: CGPoint(mid.x + (finRoot.x - mid.x) * 0.3, mid.y + (finRoot.y - mid.y) * 0.3))
        }
        return p
    }

    private static func finWing(up: Bool) -> CGPath {
        let tips = finTips(up: up), p = CGMutablePath()
        p.move(to: finRoot)
        p.addQuadCurve(to: tips[0], control: up ? CGPoint(-4, -16) : CGPoint(-6, 6))
        p.addPath(finEdge(up: up))
        p.addQuadCurve(to: up ? CGPoint(-6, 0) : CGPoint(-6, -2), control: up ? CGPoint(-11, -2) : CGPoint(-11, -3))
        p.closeSubpath()
        return p
    }

    /// Blossom's wings: three notched petals fanned from the shoulder, back to front.
    private static func petals(up: Bool) -> [CGPath] {
        let root = CGPoint(-2, -3)
        let tips = up ? [CGPoint(-20, -6), CGPoint(-16, -18), CGPoint(-7, -25)]
                      : [CGPoint(-19, 1), CGPoint(-17, 10), CGPoint(-10, 16)]
        return tips.enumerated().map { i, tip in
            let d = CGPoint(tip.x - root.x, tip.y - root.y), len = (d.x * d.x + d.y * d.y).squareRoot()
            let n = CGPoint(-d.y / len, d.x / len), w = len * (i == 2 ? 0.36 : 0.32)
            func pt(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
                CGPoint(root.x + d.x * along + n.x * w * side, root.y + d.y * along + n.y * w * side)
            }
            let p = CGMutablePath(); p.move(to: root)
            p.addCurve(to: pt(0.97, 0.32), control1: pt(0.3, 0.9), control2: pt(0.85, 1.05))
            p.addQuadCurve(to: pt(0.97, -0.32), control: pt(0.84, 0))
            p.addCurve(to: root, control1: pt(0.85, -1.05), control2: pt(0.3, -0.9))
            p.closeSubpath()
            return p
        }
    }

    static func drawNearWing(_ ctx: CGContext, up: Bool, hero: Hero, _ p: HeroPalette) {
        switch hero {
        case .saffron:
            fill(ctx, stubby(wing(up: up)), rgb(p.shade))
            stroke(ctx, stubby(wingRibs(up: up)), rgb(p.rib, 0.6), width: 0.7)
        case .tide:
            let tips = finTips(up: up)
            fill(ctx, finWing(up: up), rgb(p.shade))
            // translucent webbing toward the edge, then the pale fin rim and the spines
            linear(ctx, clip: finWing(up: up), [(0, rgb(p.shade, 0)), (0.55, rgb(p.shade, 0)), (1, rgb(p.light, 0.45))],
                   from: finRoot, to: up ? CGPoint(-14, -20) : CGPoint(-16, 11))
            stroke(ctx, finEdge(up: up), rgb(p.light, 0.9), width: 1.1)
            let spines = CGMutablePath()
            for t in tips.dropFirst() { spines.move(to: finRoot); spines.addLine(to: t) }
            stroke(ctx, spines, rgb(p.rib, 0.7), width: 0.8)
            for t in tips { fill(ctx, circle(t, 0.75), rgb(p.light)) }
        case .blossom:
            for petal in petals(up: up) {
                linear(ctx, clip: petal, [(0, rgb(p.spike)), (1, rgb(p.horn))],
                       from: CGPoint(-2, -3), to: up ? CGPoint(-14, -20) : CGPoint(-15, 12))
                stroke(ctx, petal, rgb(p.rib, 0.55), width: 0.6)
            }
            let veins = CGMutablePath()
            for tip in (up ? [CGPoint(-17, -6), CGPoint(-14, -15.5), CGPoint(-7, -21)]
                           : [CGPoint(-16, 0.5), CGPoint(-14.5, 8.5), CGPoint(-9, 13)]) {
                veins.move(to: CGPoint(-3, -3)); veins.addLine(to: tip)
            }
            stroke(ctx, veins, rgb(p.rib, 0.35), width: 0.5)
        default:
            fill(ctx, wing(up: up), rgb(p.shade))
            stroke(ctx, wingRibs(up: up), rgb(p.rib, 0.6), width: 0.8)
        }
    }

    // MARK: Head and back

    /// Coral's frilled fin ear: rays fanned back from the side of the head, the webbing scalloped between them.
    private static func frill() -> (web: CGPath, rays: CGPath, tips: [CGPoint]) {
        let root = CGPoint(5, -6)
        let tips = [CGPoint(-1.5, -7.5), CGPoint(-2.2, -12.2), CGPoint(-0.2, -16.6), CGPoint(3.6, -19.4)]
        let web = CGMutablePath(); web.move(to: CGPoint(4.8, -3.6))
        web.addQuadCurve(to: tips[0], control: CGPoint(1, -4.2))
        for (a, b) in zip(tips, tips.dropFirst()) {
            let mid = CGPoint((a.x + b.x) / 2, (a.y + b.y) / 2)
            web.addQuadCurve(to: b, control: CGPoint(mid.x + (root.x - mid.x) * 0.32, mid.y + (root.y - mid.y) * 0.32))
        }
        web.addQuadCurve(to: CGPoint(7.4, -9.5), control: CGPoint(6.8, -15.5))
        web.closeSubpath()
        let rays = CGMutablePath()
        for t in tips { rays.move(to: root); rays.addLine(to: t) }
        return (web, rays, tips)
    }

    /// The far frill peeks out behind the head, before the body is drawn.
    static func drawFarFrill(_ ctx: CGContext, _ p: HeroPalette) {
        ctx.saveGState(); ctx.translateBy(x: 4.5, y: -1.5); ctx.scaleBy(x: 0.8, y: 0.85)
        fill(ctx, frill().web, rgb(p.shade)); ctx.restoreGState()
    }

    static func drawNearFrill(_ ctx: CGContext, _ p: HeroPalette) {
        let f = frill()
        linear(ctx, clip: f.web, [(0, rgb(p.horn)), (1, rgb(p.belly))], from: CGPoint(5, -6), to: CGPoint(0, -17))
        stroke(ctx, f.rays, rgb(p.spike, 0.85), width: 0.8)
        stroke(ctx, f.web, rgb(p.shade, 0.7), width: 0.6)
        for t in f.tips { fill(ctx, circle(t, 0.7), rgb(p.spike)) }
    }

    /// Frost's small crystal horns: faceted points with a lit face, and a glint.
    static func drawCrystalHorns(_ ctx: CGContext, _ p: HeroPalette) {
        for (x, y, a, k) in [(3.0, -11.0, -0.95, 0.7), (6.0, -12.8, -0.55, 1.0), (10.5, -13.6, -0.15, 1.05)]
            as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            at(ctx, x, y, rotate: a) {
                ctx.scaleBy(x: k, y: k)
                let crystal = polygon([CGPoint(-1.9, 1.5), CGPoint(-2, -3.6), CGPoint(-0.2, -7.6), CGPoint(1.7, -3.8), CGPoint(1.8, 1.5)])
                fill(ctx, crystal, rgb(p.horn))
                fill(ctx, polygon([CGPoint(-1.9, 1.5), CGPoint(-2, -3.6), CGPoint(-0.2, -7.6), CGPoint(0, 1.5)]), white(0.75))
                stroke(ctx, crystal, rgb(p.shade, 0.8), width: 0.5)
            }
        }
        // a four-point glint by the tallest crystal
        fill(ctx, polygon([CGPoint(14.2, -21), CGPoint(14.7, -19.6), CGPoint(16.1, -19.1), CGPoint(14.7, -18.6),
                           CGPoint(14.2, -17.2), CGPoint(13.7, -18.6), CGPoint(12.3, -19.1), CGPoint(13.7, -19.6)]), white(0.9))
    }

    /// Rust's plated back: overlapping shield scales from the neck down the tail, drawn before the body.
    static func drawBackPlates(_ ctx: CGContext, _ p: HeroPalette) {
        let plates: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-17.5, 6.6, -1.35, 0.5), (-13.5, 6.0, -1.25, 0.62), (-10, 0.8, -0.95, 0.85), (-6.4, -3.2, -0.62, 1),
            (-2.2, -5.4, -0.32, 1.05), (2.2, -8.8, -0.08, 0.9),
        ]
        for (x, y, a, k) in plates {
            at(ctx, x, y, rotate: a) {
                ctx.scaleBy(x: k, y: k)
                // a kite-shaped plate with a lit left face and a bright rim
                let kite = polygon([CGPoint(-2.8, 2.5), CGPoint(-3, -1.2), CGPoint(0, -6), CGPoint(3, -1.2), CGPoint(2.8, 2.5)])
                fill(ctx, kite, rgb(p.spike))
                fill(ctx, polygon([CGPoint(-2.8, 2.5), CGPoint(-3, -1.2), CGPoint(0, -6), CGPoint(0, 2.5)]), rgb(p.light, 0.35))
                let rim = CGMutablePath(); rim.move(to: CGPoint(-3, -1.2)); rim.addLine(to: CGPoint(0, -6)); rim.addLine(to: CGPoint(3, -1.2))
                stroke(ctx, rim, rgb(p.light, 0.9), width: 0.7)
            }
        }
    }

    /// Details drawn over the body and near wing: Coral's near frill, Sable's ember freckles, Rust's scale seams.
    static func drawHeroOverlay(_ ctx: CGContext, _ hero: Hero, _ p: HeroPalette) {
        switch hero {
        case .coral: drawNearFrill(ctx, p)
        case .sable:
            let freckles: [(CGFloat, CGFloat, CGFloat)] = [
                (13.6, -2.6, 1), (15.6, -3.6, 0.8), (14.6, -0.9, 0.75),   // cheek
                (5.5, -10.5, 0.9), (8.2, -11.8, 0.8), (3.6, -8, 0.7),     // crown
                (-3.5, 9, 0.85), (-6.8, 6.6, 0.75), (-1, 11.2, 0.6),     // haunch
                (-15, 9.2, 0.7), (-18.5, 8.6, 0.6),                      // tail
            ]
            for (x, y, k) in freckles {
                radial(ctx, at: CGPoint(x, y), radius: 2.6 * k, [(0, rgba(255, 150, 60, 0.65)), (1, rgba(255, 90, 30, 0))])
                fill(ctx, circle(CGPoint(x, y), 0.65 * k), rgb(0xFFD27A))
            }
        case .rust:
            // seams of the plating on the neck
            for (x, y) in [(2.8, -3.6), (5.0, -1.6)] as [(CGFloat, CGFloat)] {
                stroke(ctx, arc(CGPoint(x, y), 3.2, from: .pi * 1.05, to: .pi * 1.55, steps: 8), rgb(p.shade, 0.55), width: 0.7)
            }
        default: break
        }
    }
}
