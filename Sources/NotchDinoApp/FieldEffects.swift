import AppKit
import RunnerCore
import SpriteKit

/// What the effects look like on the field: Rush's speed lines, Updraft's heat shimmer, the pickup pop and burst, and
/// the feather bounce's puff. It mirrors `Effects` and events; it decides nothing.
@MainActor final class FieldEffects {
    /// Points per second the speed lines stream left.
    static let lineSpeed: CGFloat = 520

    /// Two tiles side by side, so the lines wrap without a seam.
    let speedLines = SKNode()
    private var lineTiles: [SKSpriteNode] = []
    let shimmer = SKSpriteNode(texture: SKTexture(cgImage: Art.shimmer()))
    private let puffTexture = SKTexture(cgImage: Art.bouncePuff())
    private let dotTexture = SKTexture(cgImage: Art.dot())
    private let pickupTextures = Dictionary(uniqueKeysWithValues: Pickup.allCases.map { ($0, SKTexture(cgImage: Art.pickup($0))) })

    init() {}

    var speedLinesShown: Bool { !speedLines.isHidden }
    var shimmerShown: Bool { !shimmer.isHidden }

    func attach(to scene: SKNode) {
        speedLines.zPosition = 2.5; speedLines.isHidden = true; scene.addChild(speedLines)
        shimmer.anchorPoint = CGPoint(x: 0.5, y: 1); shimmer.zPosition = 4; shimmer.isHidden = true; scene.addChild(shimmer)
    }

    /// Sizes the speed lines to the field, whose bottom edge sits at `fieldBottom` in scene points.
    func layout(width: CGFloat, fieldHeight: CGFloat, fieldBottom: CGFloat) {
        lineTiles.forEach { $0.removeFromParent() }
        let size = CGSize(width: width, height: fieldHeight)
        let tex = SKTexture(cgImage: Art.speedLines(size: size))
        lineTiles = (0..<2).map { _ in
            let n = SKSpriteNode(texture: tex, size: size)
            n.anchorPoint = .zero; speedLines.addChild(n); return n
        }
        speedLines.position = CGPoint(x: 0, y: fieldBottom)
    }

    func sync(_ s: GameState, pip: CGPoint, artScale: CGFloat, reduceMotion: Bool) {
        speedLines.isHidden = s.effects.rush == 0 || s.phase != .running || reduceMotion
        if !speedLines.isHidden, let w = lineTiles.first?.size.width, w > 0 {
            let off = (CGFloat(s.time) * Self.lineSpeed).truncatingRemainder(dividingBy: w)
            for (i, n) in lineTiles.enumerated() { n.position = CGPoint(x: CGFloat(i) * w - off, y: 0) }
        }
        shimmer.isHidden = s.effects.updraft == 0 || s.phase != .running || reduceMotion
        if !shimmer.isHidden {
            shimmer.setScale(artScale)
            shimmer.position = CGPoint(x: pip.x + CGFloat(sin(s.time * 7)) * 1.5 * artScale, y: pip.y - 10 * artScale)
            shimmer.alpha = 0.75 + CGFloat(sin(s.time * 5)) * 0.25
        }
    }

    /// The pickup's icon pops (grows and fades) where Pip took it, with six sparks in its colour.
    func pickupPop(_ p: Pickup, at point: CGPoint, in scene: SKNode, artScale: CGFloat) {
        let icon = SKSpriteNode(texture: pickupTextures[p])
        icon.name = "flourish"; icon.zPosition = 7; icon.position = point; icon.setScale(artScale)
        scene.addChild(icon)
        icon.run(.sequence([.group([.scale(to: artScale * 1.8, duration: 0.25), .fadeOut(withDuration: 0.25)]),
                            .removeFromParent()]))

        let e = SKEmitterNode()
        e.name = "flourish"
        e.particleTexture = dotTexture
        e.numParticlesToEmit = 6; e.particleBirthRate = 400
        e.particleLifetime = 0.5; e.particleSpeed = 90; e.particleSpeedRange = 30
        e.emissionAngleRange = .pi * 2
        e.particleScale = 0.45; e.particleScaleRange = 0.15
        e.particleAlphaSpeed = -1.8
        e.particleColor = NSColor(cgColor: Art.rgb(Art.pickupTint(p))) ?? .orange
        e.particleColorBlendFactor = 1
        e.position = point; e.zPosition = 7
        scene.addChild(e)
        e.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }

    /// A puff at the ceiling or ground where a feather bounce happened.
    func bouncePuff(at point: CGPoint, ceiling: Bool, in scene: SKNode, artScale: CGFloat, reduceMotion: Bool) {
        let n = SKSpriteNode(texture: puffTexture)
        n.name = "flourish"; n.zPosition = 6.5; n.position = point; n.setScale(artScale)
        if ceiling { n.yScale = -artScale }
        scene.addChild(n)
        let grow: SKAction = reduceMotion ? .wait(forDuration: 0.35) : .scaleX(to: artScale * 1.6, duration: 0.35)
        n.run(.sequence([.group([grow, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }
}
