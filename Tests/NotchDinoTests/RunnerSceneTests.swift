import RunnerCore
import SpriteKit
import Testing
@testable import NotchDinoApp

@MainActor @Test func pipNodeFollowsCoreState() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    s.phase = .running; s.pipY = 50; s.pipVY = 0
    scene.sync(s)
    let expected = scene.scenePoint(x: s.world.pipX, y: 50)
    #expect(abs(scene.pipNode.position.x - expected.x) < 0.01 && abs(scene.pipNode.position.y - expected.y) < 0.01)
    #expect(abs(scene.unitScale - 1.2) < 1e-9)
    // world (0,0) is the field's top-left: 12 pt in, band + 2 pt down; SpriteKit's y grows upward
    #expect(scene.scenePoint(x: 0, y: 0) == CGPoint(x: 12, y: 282 - 34))
}

@MainActor @Test func gateNodesTrackGates() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    s.gates = [Gate(id: 4, x: 100, centre: 94, gap: 150, chunk: 24, items: [Item(side: .upper, pickup: .ember)])]
    scene.sync(s)
    #expect(scene.gateNodeCount == 1)
    s.gates = []
    scene.sync(s)
    #expect(scene.gateNodeCount == 0)
}

@MainActor private func gateState(_ gates: [Gate]) -> GameState {
    var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    s.gates = gates
    return s
}

@MainActor @Test func resetRemovesGateNodes() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    scene.sync(gateState([Gate(id: 1, x: 100, centre: 94, gap: 150, chunk: 24, items: []),
                          Gate(id: 2, x: 200, centre: 94, gap: 150, chunk: 24, items: [])]))
    #expect(scene.gateNodeCount == 2)
    scene.reset()
    #expect(scene.gateNodeCount == 0)
}

@MainActor @Test func ceilingShardIsFlippedAndTipsMeetTheGap() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    let g = Gate(id: 1, x: 100, centre: 94, gap: 150, chunk: 24, items: [])
    scene.sync(gateState([g]))
    let node = scene.gateNode(id: 1)!
    #expect(node.topShard.yScale == -1)
    #expect(abs(node.topShard.position.y - scene.scenePoint(x: g.x, y: g.gapTop).y) < 0.01)
    #expect(abs(node.bottomShard.position.y - scene.scenePoint(x: g.x, y: g.gapBottom).y) < 0.01)
}

@MainActor @Test func reduceMotionFreezesParallax() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    var s = gateState([])
    scene.reduceMotion = true
    s.distance = 0; scene.sync(s)
    let v0 = scene.firstVolcano!.position.x, c0 = scene.firstCycad!.position.x
    s.distance = 500; scene.sync(s)
    #expect(scene.firstVolcano!.position.x == v0 && scene.firstCycad!.position.x == c0)
    scene.reduceMotion = false
    scene.sync(s)
    #expect(scene.firstVolcano!.position.x != v0 && scene.firstCycad!.position.x != c0)
}

@MainActor @Test func freshSceneIsInItsRestStateBeforeAnySync() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    let idle = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    let expected = scene.scenePoint(x: idle.world.pipX, y: Params.idleY)
    #expect(scene.ashIsHidden)
    #expect(scene.overlaysAreHidden)
    #expect(abs(scene.pipNode.position.x - expected.x) < 0.01 && abs(scene.pipNode.position.y - expected.y) < 0.01)
}

// MARK: Effects on Pip

@MainActor private func effectScene() -> (RunnerScene, GameState) {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    s.phase = .running; s.pipY = 96
    return (scene, s)
}

@MainActor @Test func featherOrbitComesAndGoesWithTheCharge() {
    let (scene, s0) = effectScene()
    var s = s0
    scene.sync(s)
    #expect(scene.pipEffects.featherOrbit == nil)
    s.effects.apply(.feather)
    scene.sync(s)
    let orbit = scene.pipEffects.featherOrbit
    #expect(orbit?.parent === scene.pipNode)
    s.time += 0.2; scene.sync(s)
    #expect(scene.pipEffects.featherOrbit === orbit)   // one node, moved, not remade
    s.effects.feather = false
    scene.sync(s)
    #expect(scene.pipEffects.featherOrbit == nil && orbit?.parent == nil)
}

@MainActor @Test func reduceMotionParksTheFeather() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.feather)
    scene.reduceMotion = true
    scene.sync(s)
    let p0 = scene.pipEffects.featherOrbit!.position
    s.time += 0.3; scene.sync(s)
    #expect(scene.pipEffects.featherOrbit!.position == p0)
}

@MainActor @Test(arguments: [(Pickup.tiny, 0.7), (.bloat, 1.3)])
func tinyAndBloatEasePipToTheirSize(p: Pickup, scale: Double) {
    let (scene, s0) = effectScene()
    var s = s0
    scene.sync(s)
    let normal = scene.pipNode.xScale
    s.effects.apply(p)
    scene.sync(s)
    #expect(abs(scene.pipNode.xScale - normal) < 1e-6)   // eases: no jump on the first frame
    scene.pipEffects.tick(0.1); scene.sync(s)
    let halfway = scene.pipNode.xScale / normal
    #expect(halfway > min(1, scale) + 0.01 && halfway < max(1, scale) - 0.01)
    scene.pipEffects.tick(0.15); scene.sync(s)
    #expect(abs(scene.pipNode.xScale - normal * scale) < 1e-6)
    s.effects = Effects()
    scene.sync(s); scene.pipEffects.tick(0.25); scene.sync(s)
    #expect(abs(scene.pipNode.xScale - normal) < 1e-6)
}

@MainActor @Test func reduceMotionSnapsPipToSize() {
    let (scene, s0) = effectScene()
    var s = s0
    scene.reduceMotion = true
    scene.sync(s)
    let normal = scene.pipNode.xScale
    s.effects.apply(.tiny)
    scene.sync(s)
    #expect(abs(scene.pipNode.xScale - normal * 0.7) < 1e-6)
}

@MainActor @Test func bloatSwapsInThePuffedSprite() {
    let (scene, s0) = effectScene()
    var s = s0
    scene.sync(s)
    let normal = scene.pipNode.texture
    s.effects.apply(.bloat)
    scene.sync(s)
    #expect(scene.pipNode.texture !== normal)
    s.effects = Effects()
    scene.sync(s)
    #expect(scene.pipNode.texture === normal)
}

@MainActor @Test func stoneScaleShowsCracks() {
    let (scene, s0) = effectScene()
    var s = s0
    scene.sync(s)
    #expect(scene.pipEffects.cracks.isHidden)
    s.effects.apply(.stoneScale)
    scene.sync(s)
    #expect(!scene.pipEffects.cracks.isHidden)
}

@MainActor @Test func resetDropsTheFeatherAndSize() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.feather); s.effects.apply(.bloat)
    scene.sync(s); scene.pipEffects.tick(1); scene.sync(s)
    scene.reset()
    #expect(scene.pipEffects.featherOrbit == nil && scene.pipEffects.sizeScale == 1)
}

@MainActor @Test func resizeKeepsTheEffectSize() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.tiny)
    scene.sync(s); scene.pipEffects.tick(1); scene.sync(s)
    scene.layout(islandSize: CGSize(width: 545, height: 342), band: 32)   // a taller field: 1.5 pt per unit
    scene.sync(s)
    #expect(abs(scene.pipNode.xScale - (scene.unitScale / 1.2) * 0.7) < 1e-6)
}

@MainActor @Test func heroChangeWhileBloatedRedrawsThePuff() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.bloat)
    scene.sync(s)
    let pipPuff = scene.pipNode.texture
    scene.apply(hero: .moss, map: .volcano)
    scene.sync(s)
    #expect(scene.pipNode.texture != nil && scene.pipNode.texture !== pipPuff)
}

@MainActor @Test func featherOrbitLeavesWhenPipCrashes() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.feather)
    scene.sync(s)
    s.phase = .crashed
    scene.sync(s)
    #expect(scene.pipEffects.featherOrbit == nil)
}

// MARK: Effects on the field

@MainActor @Test func speedLinesShowOnlyDuringRush() {
    let (scene, s0) = effectScene()
    var s = s0
    scene.sync(s)
    #expect(!scene.fieldEffects.speedLinesShown)
    s.effects.apply(.rush)
    scene.sync(s)
    #expect(scene.fieldEffects.speedLinesShown)
    scene.reduceMotion = true
    scene.sync(s)
    #expect(!scene.fieldEffects.speedLinesShown)
    scene.reduceMotion = false
    s.effects.tick(Params.rushTime)
    scene.sync(s)
    #expect(!scene.fieldEffects.speedLinesShown)
}

@MainActor @Test func shimmerShowsDuringUpdraftUnlessReduceMotion() {
    let (scene, s0) = effectScene()
    var s = s0
    s.effects.apply(.updraft)
    scene.sync(s)
    #expect(scene.fieldEffects.shimmerShown)
    scene.reduceMotion = true
    scene.sync(s)
    #expect(!scene.fieldEffects.shimmerShown)
}

@MainActor @Test func pickingUpPopsTheIconAndBurstsSixSparks() {
    let (scene, s) = effectScene()
    let before = scene.children.filter { $0.name == "flourish" }.count
    scene.consume([.picked(.tiny)], state: s)
    let added = scene.children.filter { $0.name == "flourish" }
    #expect(added.count == before + 3)   // name tag, icon pop, sparks
    #expect(added.compactMap { $0 as? SKEmitterNode }.map(\.numParticlesToEmit) == [6])
}

@MainActor @Test func bouncePuffSitsAtTheEdgePipTouched() {
    let (scene, s0) = effectScene()
    var s = s0
    s.pipY = Params.ground - 12
    scene.consume([.bounced], state: s)
    let ground = scene.children.last { $0.name == "flourish" }!
    #expect(abs(ground.position.y - scene.scenePoint(x: 0, y: Params.ground).y) < 0.01)
    s.pipY = 12
    scene.consume([.bounced], state: s)
    let ceiling = scene.children.last { $0.name == "flourish" }!
    #expect(abs(ceiling.position.y - scene.scenePoint(x: 0, y: 0).y) < 0.01)
}

@MainActor @Test func pausedHidesSpeedLinesAndShimmer() {
    let (scene, s0) = effectScene()
    var s = s0; s.effects.apply(.rush); s.effects.apply(.updraft)
    scene.sync(s)
    #expect(scene.fieldEffects.speedLinesShown && scene.fieldEffects.shimmerShown)
    s.phase = .paused
    scene.sync(s)
    #expect(!scene.fieldEffects.speedLinesShown && !scene.fieldEffects.shimmerShown)
}
