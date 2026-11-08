import RunnerCore
import SpriteKit

/// What the effects look like on Pip: the orbiting feather, the Tiny/Bloat size and puffed sprite, the stone cracks.
/// It mirrors `Effects` and decides nothing.
@MainActor final class PipEffects {
    /// Seconds Pip takes to grow or shrink to a new size.
    static let sizeEase = 0.2

    private(set) var featherOrbit: SKSpriteNode?
    let cracks = SKSpriteNode(texture: SKTexture(cgImage: Art.stoneCracks()))
    private let featherTexture = SKTexture(cgImage: Art.featherCharge())
    private var puffed: [PipPose: SKTexture] = [:]
    private weak var pip: SKSpriteNode?
    private var sizeFrom: CGFloat = 1, sizeTo: CGFloat = 1, sizeT: CGFloat = 1

    init() {}

    /// Pip's drawn size relative to normal, eased in and out between sizes.
    var sizeScale: CGFloat {
        let t = sizeT * sizeT * (3 - 2 * sizeT)
        return sizeFrom + (sizeTo - sizeFrom) * t
    }

    func attach(to pip: SKSpriteNode) {
        self.pip = pip
        cracks.zPosition = 1.5; cracks.isHidden = true; pip.addChild(cracks)
    }

    func makeTextures(hero: Hero) {
        puffed = Dictionary(uniqueKeysWithValues: PipPose.allCases.map { ($0, SKTexture(cgImage: Art.puffedPip($0, hero: hero))) })
    }

    /// The texture for `pose`: the puffed variant while Bloat runs, else `normal`.
    func texture(_ pose: PipPose, normal: SKTexture?, bloated: Bool) -> SKTexture? { bloated ? puffed[pose] : normal }

    func tick(_ dt: Double) { sizeT = min(1, sizeT + CGFloat(dt / Self.sizeEase)) }

    func sync(_ s: GameState, reduceMotion: Bool) {
        let target = CGFloat(s.effects.radiusScale)
        if target != sizeTo {
            sizeFrom = sizeScale; sizeTo = target
            sizeT = reduceMotion ? 1 : 0
        }

        let showFeather = s.effects.feather && s.phase != .crashed
        if showFeather, featherOrbit == nil, let pip {
            let f = SKSpriteNode(texture: featherTexture, size: Art.featherChargeSize)
            pip.addChild(f); featherOrbit = f
        } else if !showFeather, let f = featherOrbit {
            f.removeFromParent(); featherOrbit = nil
        }
        if let f = featherOrbit {
            if reduceMotion {
                // Still shown, but parked above Pip's back instead of circling.
                f.position = CGPoint(x: -12, y: 16); f.zRotation = 0.3; f.zPosition = 2
            } else {
                let a = s.time * 4
                f.position = CGPoint(x: cos(a) * 21, y: sin(a) * 11 + 3)
                f.zRotation = CGFloat(sin(a) * 0.4)
                f.zPosition = sin(a) > 0 ? 2 : -1   // passes behind Pip on the far half of the loop
            }
        }

        cracks.isHidden = s.effects.stoneScale == 0 || s.phase == .crashed
    }

    func reset() {
        sizeFrom = 1; sizeTo = 1; sizeT = 1
        featherOrbit?.removeFromParent(); featherOrbit = nil
    }
}
