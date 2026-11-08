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
