import AppKit
import RunnerCore
import SpriteKit

@MainActor protocol RunnerSceneDriver: AnyObject {
    func sceneTick(elapsed: Double) -> (state: GameState, events: [GameEvent])
    func sceneClicked()
}

/// Renders `GameState`. It holds no rules: positions come from the state, flourishes (puff, breath, pops, burst) from
/// events. The scene covers the whole open island; the field is the body below the band.
@MainActor final class RunnerScene: SKScene {
    weak var driver: RunnerSceneDriver?
    var reduceMotion = false

    private(set) var islandSize: CGSize
    private(set) var band: CGFloat
    private var fieldTop: CGFloat { band + 2 }
    private var fieldHeight: CGFloat { islandSize.height - band - 2 - 8 }
    var unitScale: CGFloat { fieldHeight / CGFloat(Params.worldHeight) }
    /// Art is drawn for 1.2 pt/unit; sprites scale by this when the island is resized.
    private var artScale: CGFloat { unitScale / 1.2 }

    /// The hero and map the art is drawn for. Changing either redraws the textures; rules are untouched.
    private(set) var hero: Hero
    private(set) var map: MapTheme

    // Textures, remade only when the look changes.
    private var pipTextures: [PipPose: SKTexture] = [:]
    private var shardTexture = SKTexture()
    private let hotTexture = SKTexture(cgImage: Art.hotShard())
    private var chunkTexture = SKTexture()
    private let pickupTextures = Dictionary(uniqueKeysWithValues: Pickup.allCases.map { ($0, SKTexture(cgImage: Art.pickup($0))) })
    private let dotTexture = SKTexture(cgImage: Art.dot())

    // Layers.
    private let sky = SKSpriteNode()
    private var stars: [SKSpriteNode] = [], volcanoes: [SKSpriteNode] = [], cycads: [SKSpriteNode] = []
    private let ground = SKSpriteNode()
    private let gateLayer = SKNode()
    private var gateNodes: [Int: GateNode] = [:]
    private(set) var pipNode = SKSpriteNode()
    private let puff = SKSpriteNode(texture: SKTexture(cgImage: Art.puff()))
    private let chargeEmber = SKSpriteNode()
    private let breath = SKSpriteNode(texture: SKTexture(cgImage: Art.breath()))
    private let stone = SKSpriteNode(texture: SKTexture(cgImage: Art.stonePatches()))
    private let streaks = SKSpriteNode(texture: SKTexture(cgImage: Art.streaks()))
    private let ash = SKSpriteNode()
    let pipEffects = PipEffects()

    // Flourish timers, driven by events.
    private var flapTimer = 0.0, puffTimer = 0.0, breathTimer = 0.0, breathAngle: CGFloat = 0
    private var lastTime: TimeInterval = 0

    var gateNodeCount: Int { gateNodes.count }
    func gateNode(id: Int) -> GateNode? { gateNodes[id] }
    var firstVolcano: SKSpriteNode? { volcanoes.first }
    var firstCycad: SKSpriteNode? { cycads.first }
    var ashIsHidden: Bool { ash.isHidden || ash.alpha == 0 }
    var overlaysAreHidden: Bool { chargeEmber.isHidden && breath.isHidden && puff.alpha == 0 && stone.isHidden }

    init(islandSize: CGSize, band: CGFloat, hero: Hero = .pip, map: MapTheme = .volcano) {
        self.islandSize = islandSize
        self.band = band
        self.hero = hero
        self.map = map
        super.init(size: islandSize)
        makeLookTextures()
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        sky.anchorPoint = .zero; sky.zPosition = -10; addChild(sky)
        ground.anchorPoint = CGPoint(x: 0, y: 1); ground.zPosition = 2; addChild(ground)
        gateLayer.zPosition = 3; addChild(gateLayer)
        streaks.anchorPoint = CGPoint(x: 1, y: 0.5); streaks.zPosition = 4; addChild(streaks)
        pipNode.anchorPoint = CGPoint(x: Art.pipOrigin.x / Art.pipSize.width, y: 1 - Art.pipOrigin.y / Art.pipSize.height)
        pipNode.texture = pipTextures[.wingUp]; pipNode.size = Art.pipSize; pipNode.zPosition = 5; addChild(pipNode)
        stone.zPosition = 1; pipNode.addChild(stone)
        puff.position = CGPoint(x: 22, y: 5); puff.zPosition = 2; pipNode.addChild(puff)
        chargeEmber.texture = pickupTextures[.ember]; chargeEmber.size = CGSize(width: 15, height: 15)
        chargeEmber.position = CGPoint(x: 20, y: 4); chargeEmber.zRotation = -.pi / 2; chargeEmber.zPosition = 2; pipNode.addChild(chargeEmber)
        breath.anchorPoint = CGPoint(x: 0, y: 1 - 8.0 / 18.0); breath.position = CGPoint(x: 18, y: 2); breath.zPosition = 3; pipNode.addChild(breath)
        ash.anchorPoint = .zero; ash.zPosition = 6; addChild(ash)
        pipEffects.attach(to: pipNode)
        layout(islandSize: islandSize, band: band)
        // Nothing is drawn raw: until the first update the scene shows an idle game for the world it was laid out for.
        if fieldHeight > 0 {
            sync(Runner.newGame(world: World.forField(width: Double(islandSize.width - 24), height: Double(fieldHeight)), seed: 0, best: 0))
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func makeLookTextures() {
        pipTextures = Dictionary(uniqueKeysWithValues: PipPose.allCases.map { ($0, SKTexture(cgImage: Art.pip($0, hero: hero))) })
        shardTexture = SKTexture(cgImage: Art.shard(map: map))
        chunkTexture = SKTexture(cgImage: Art.chunk(map: map))
        pipEffects.makeTextures(hero: hero)
    }

    /// Switches hero and map. Gate nodes are dropped and rebuilt from the next state, so they pick up the new material.
    func apply(hero: Hero, map: MapTheme) {
        guard hero != self.hero || map != self.map else { return }
        self.hero = hero
        self.map = map
        makeLookTextures()
        pipNode.texture = pipTextures[.wingUp]
        gateNodes.values.forEach { $0.removeFromParent() }
        gateNodes = [:]
        layout(islandSize: islandSize, band: band)
    }

    /// World units (y down, field top-left origin) to scene points (y up, island bottom-left origin).
    func scenePoint(x: Double, y: Double) -> CGPoint {
        CGPoint(x: 12 + CGFloat(x) * unitScale, y: islandSize.height - (fieldTop + CGFloat(y) * unitScale))
    }

    func layout(islandSize: CGSize, band: CGFloat) {
        guard islandSize.width > 0, islandSize.height > 0, islandSize.height - band - 2 - 8 > 0 else { return }
        self.islandSize = islandSize
        self.band = band
        size = islandSize
        let groundY = fieldTop + CGFloat(Params.ground) * unitScale
        sky.texture = SKTexture(cgImage: Art.sky(size: islandSize, fieldTop: fieldTop, fieldHeight: fieldHeight, groundY: groundY, map: map))
        sky.size = islandSize
        func tiles(_ old: [SKSpriteNode], _ img: CGImage, _ tile: CGSize, z: CGFloat) -> [SKSpriteNode] {
            old.forEach { $0.removeFromParent() }
            let w = tile.width * artScale
            let count = Int((islandSize.width / w).rounded(.up)) + 1
            let tex = SKTexture(cgImage: img)
            return (0..<count).map { _ in
                let n = SKSpriteNode(texture: tex, size: CGSize(width: w, height: tile.height * artScale))
                n.anchorPoint = .zero; n.zPosition = z; addChild(n); return n
            }
        }
        stars = tiles(stars, Art.stars(map: map), Art.starsTileSize, z: -9)
        volcanoes = tiles(volcanoes, Art.volcanoes(map: map), Art.volcanoTileSize, z: -8)
        cycads = tiles(cycads, Art.cycads(map: map), Art.cycadTileSize, z: -7)
        let groundHeight = islandSize.height - groundY + 4
        ground.texture = SKTexture(cgImage: Art.ground(width: islandSize.width + 22, height: groundHeight, map: map))
        ground.size = CGSize(width: islandSize.width + 22, height: groundHeight)
        let ashSize = CGSize(width: islandSize.width, height: islandSize.height)
        ash.texture = SKTexture(cgImage: Art.smoke(size: ashSize, map: map)); ash.size = ashSize
        pipNode.setScale(artScale)
    }

    // MARK: Per-frame

    override var isPaused: Bool { didSet { lastTime = 0 } }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        guard let driver else { return }
        let (state, events) = driver.sceneTick(elapsed: dt)
        consume(events, state: state)
        tickFlourishes(dt)
        sync(state)
    }

    override func mouseDown(with event: NSEvent) { driver?.sceneClicked() }

    func reset() {
        gateNodes.values.forEach { $0.removeFromParent() }
        gateNodes = [:]
        flapTimer = 0; puffTimer = 0; breathTimer = 0
        pipEffects.reset()
        children.filter { $0.name == "flourish" }.forEach { $0.removeFromParent() }
    }

    func consume(_ events: [GameEvent], state: GameState) {
        let pip = scenePoint(x: state.world.pipX, y: state.pipY)
        for e in events {
            switch e {
            case .flapped, .hiccup: flapTimer = 0.12; puffTimer = 0.4
            case .melted(_, let part):
                breathTimer = 0.32
                breathAngle = part == .bottom ? -0.8 : part == .top ? 0.8 : 0
            case .picked(let p): pop(p.label, good: p.isGood, at: pip)
            case .crashed: burst(at: pip)
            case .gatePassed, .milestone, .newBest: break
            case .bounced: break
            }
            if case .hiccup = e { pop("hic", good: false, at: pip, size: 11) }
        }
    }

    private func tickFlourishes(_ dt: Double) {
        flapTimer = max(0, flapTimer - dt); puffTimer = max(0, puffTimer - dt); breathTimer = max(0, breathTimer - dt)
        pipEffects.tick(dt)
    }

    func sync(_ s: GameState) {
        let px = s.world.pipX
        let distancePt = CGFloat(s.distance) * unitScale * (reduceMotion ? 0 : 1)
        func scroll(_ nodes: [SKSpriteNode], factor: CGFloat, y: CGFloat) {
            guard let w = nodes.first?.size.width else { return }
            let off = (distancePt * factor).truncatingRemainder(dividingBy: w)
            for (i, n) in nodes.enumerated() { n.position = CGPoint(x: CGFloat(i) * w - off, y: y) }
        }
        let groundScene = scenePoint(x: 0, y: Params.ground).y
        scroll(stars, factor: 0.03, y: islandSize.height - fieldTop - (stars.first?.size.height ?? 0) + 20)
        scroll(volcanoes, factor: 0.15, y: groundScene)
        scroll(cycads, factor: 0.4, y: groundScene)
        ground.position = CGPoint(x: -(CGFloat(s.distance) * unitScale).truncatingRemainder(dividingBy: 22), y: groundScene + 4)

        // gates
        var seen = Set<Int>()
        for g in s.gates {
            seen.insert(g.id)
            let node = gateNodes[g.id] ?? makeGateNode(g)
            node.update(g, scene: self, time: s.time)
        }
        for (id, node) in gateNodes where !seen.contains(id) { node.removeFromParent(); gateNodes[id] = nil }

        // Pip
        pipNode.position = scenePoint(x: px, y: s.pipY)
        let tilt = s.phase == .crashed ? 0.45 : max(-0.4, min(0.6, s.pipVY * 0.0026))
        pipNode.zRotation = -CGFloat(tilt)
        let pose: PipPose = s.phase == .crashed ? .crash
            : flapTimer > 0 ? .wingDown
            : (Int(s.time * (s.phase == .idle ? 9 : 8)) % 2 == 0 ? .wingUp : .wingDown)
        pipNode.texture = pipEffects.texture(pose, normal: pipTextures[pose], bloated: s.effects.bloat > 0)
        pipEffects.sync(s, reduceMotion: reduceMotion)
        pipNode.setScale(artScale * pipEffects.sizeScale)
        puff.alpha = s.effects.emberCharge ? 0 : CGFloat(puffTimer / 0.4)
        chargeEmber.isHidden = !(s.effects.emberCharge && breathTimer == 0) || s.phase == .crashed
        breath.isHidden = breathTimer == 0
        breath.alpha = CGFloat(min(1, breathTimer / 0.15))
        breath.zRotation = breathAngle
        stone.isHidden = s.effects.stoneScale == 0 || s.phase == .crashed
        streaks.isHidden = s.effects.updraft == 0 || s.phase != .running
        streaks.position = CGPoint(x: pipNode.position.x - 24 * artScale - CGFloat((s.time * 90).truncatingRemainder(dividingBy: 18)),
                                   y: pipNode.position.y)
        ash.isHidden = s.effects.ashCloud == 0
        ash.alpha = CGFloat(min(1, s.effects.ashCloud / 0.6))
        ash.position = CGPoint(x: pipNode.position.x + 26 * artScale, y: 0)
    }

    private func makeGateNode(_ g: Gate) -> GateNode {
        let n = GateNode(gate: g, shard: shardTexture, hot: hotTexture, chunk: chunkTexture, pickups: pickupTextures, dot: dotTexture)
        gateLayer.addChild(n)
        gateNodes[g.id] = n
        return n
    }

    private func pop(_ text: String, good: Bool, at p: CGPoint, size: CGFloat = 13) {
        let label = SKLabelNode(attributedText: NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: good ? NSColor(srgbRed: 1, green: 0.816, blue: 0.541, alpha: 1)
                                   : NSColor(srgbRed: 0.741, green: 0.702, blue: 0.71, alpha: 1),
        ]))
        label.name = "flourish"; label.zPosition = 8
        label.position = CGPoint(x: p.x + 18, y: p.y + 22)
        addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 26, duration: 1.1), .fadeOut(withDuration: 1.1)]), .removeFromParent()]))
    }

    private func burst(at p: CGPoint) {
        let e = SKEmitterNode()
        e.name = "flourish"
        e.particleTexture = dotTexture
        e.numParticlesToEmit = 18; e.particleBirthRate = 600
        e.particleLifetime = 1.4; e.particleSpeed = 120; e.particleSpeedRange = 80
        e.emissionAngle = .pi / 2; e.emissionAngleRange = .pi * 1.2
        e.yAcceleration = -500
        e.particleScale = 0.5; e.particleScaleRange = 0.3
        e.particleAlphaSpeed = -0.7
        e.particleColor = NSColor(cgColor: Art.rgb(hero.palette.body)) ?? .systemRed
        e.particleColorBlendFactor = 1
        e.position = p; e.zPosition = 7
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.6), .removeFromParent()]))
    }
}

/// One gate: two shards, an optional chunk, pickups, drips.
@MainActor final class GateNode: SKNode {
    private let top: SKSpriteNode, bottom: SKSpriteNode
    private let topHot: SKSpriteNode, bottomHot: SKSpriteNode
    private var chunk: SKSpriteNode?
    private var items: [(Side, SKSpriteNode)] = []
    private var drips: [SKSpriteNode] = []
    var topShard: SKSpriteNode { top }
    var bottomShard: SKSpriteNode { bottom }

    init(gate: Gate, shard: SKTexture, hot: SKTexture, chunk chunkTexture: SKTexture, pickups: [Pickup: SKTexture], dot: SKTexture) {
        top = SKSpriteNode(texture: shard); bottom = SKSpriteNode(texture: shard)
        topHot = SKSpriteNode(texture: hot); bottomHot = SKSpriteNode(texture: hot)
        super.init()
        // Bottom shard: tip up at the gap, extending down. Top shard: the same texture flipped.
        for (s, h) in [(bottom, bottomHot), (top, topHot)] {
            s.anchorPoint = CGPoint(x: 0, y: 1); addChild(s)
            h.anchorPoint = CGPoint(x: 0, y: 1); h.isHidden = true; s.addChild(h)
        }
        top.yScale = -1
        if gate.isFork {
            let c = SKSpriteNode(texture: chunkTexture); addChild(c); chunk = c
            for item in gate.items {
                let n = SKSpriteNode(texture: pickups[item.pickup]); n.zPosition = 1; addChild(n)
                items.append((item.side, n))
            }
        }
        for _ in 0..<3 {
            let d = SKSpriteNode(texture: dot); d.color = NSColor(srgbRed: 1, green: 0.59, blue: 0.235, alpha: 1)
            d.colorBlendFactor = 1; d.isHidden = true; addChild(d); drips.append(d)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func update(_ g: Gate, scene: RunnerScene, time: Double) {
        let k = scene.unitScale / 1.2
        let x = scene.scenePoint(x: g.x, y: 0).x
        let width = CGFloat(Params.gateWidth) * scene.unitScale
        for s in [top, bottom] { s.size = CGSize(width: width, height: Art.shardSize.height * k) }
        for h in [topHot, bottomHot] { h.size = CGSize(width: width, height: 60 * k) }
        let topTip = scene.scenePoint(x: g.x, y: g.gapTop).y
        let bottomTip = scene.scenePoint(x: g.x, y: g.gapBottom).y
        place(top, hot: topHot, x: x, tip: topTip, away: 1, melt: g.melted[.top])
        place(bottom, hot: bottomHot, x: x, tip: bottomTip, away: -1, melt: g.melted[.bottom])

        if let chunk {
            let c = scene.scenePoint(x: g.itemX, y: g.centre)
            chunk.position = c
            let melt = g.melted[.chunk].map { min(1, $0 / 0.45) } ?? 0
            chunk.size = CGSize(width: Art.chunkSize.width * k, height: CGFloat(g.chunk) * scene.unitScale)
            chunk.setScale(1 - 0.8 * melt)
            chunk.color = .orange; chunk.colorBlendFactor = g.melted[.chunk] == nil ? 0 : 0.7
            chunk.isHidden = melt >= 1
        }
        for (side, node) in items {
            let item = g.items.first { $0.side == side }
            node.isHidden = item?.taken ?? true
            let p = scene.scenePoint(x: g.itemX, y: g.itemY(side))
            node.position = CGPoint(x: p.x, y: p.y + CGFloat(sin(time * 4 + g.x * 0.05) * 1.5))
            node.size = CGSize(width: Art.pickupSize.width * k, height: Art.pickupSize.height * k)
        }
        // drips under whichever part is melting
        let melting = [GatePart.top, .bottom, .chunk].compactMap { p in g.melted[p].flatMap { $0 < 0.45 ? (p, $0) : nil } }
        if let hot = melting.min(by: { $0.1 < $1.1 }) {
            let part = hot.0
            let melt = CGFloat(hot.1 / 0.45)
            let tipY = part == .top ? topTip : part == .bottom ? bottomTip : scene.scenePoint(x: g.x, y: g.centre).y
            let dir: CGFloat = -1
            for (i, d) in drips.enumerated() {
                d.isHidden = false
                d.alpha = 1 - melt
                d.size = CGSize(width: 3 * k, height: 3 * k)
                d.position = CGPoint(x: x + width * [0.3, 0.55, 0.75][i], y: tipY + dir * ([0, 7, 3][i] + melt * 26) * k)
            }
        } else {
            drips.forEach { $0.isHidden = true }
        }
    }

    /// `away`: +1 when the shard's base is above its tip (ceiling), −1 when below (ground).
    private func place(_ s: SKSpriteNode, hot: SKSpriteNode, x: CGFloat, tip: CGFloat, away: CGFloat, melt: Double?) {
        let m = melt.map { CGFloat(min(1, $0 / 0.45)) } ?? 0
        s.isHidden = m >= 1
        s.position = CGPoint(x: x, y: tip + away * m * 120)
        hot.isHidden = melt == nil
        hot.alpha = 1 - m * 0.3
        s.color = .orange; s.colorBlendFactor = melt == nil ? 0 : 0.35
    }
}
