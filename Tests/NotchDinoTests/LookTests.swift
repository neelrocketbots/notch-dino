import CoreGraphics
import Foundation
import RunnerCore
import SpriteKit
import Testing
@testable import NotchDinoApp

private func alpha(_ img: CGImage, px x: Int, _ y: Int) -> UInt8 {
    let data = img.dataProvider!.data! as Data
    return data[y * img.bytesPerRow + x * 4 + 3]
}

private func pixels(_ img: CGImage) -> Data { img.dataProvider!.data! as Data }

@Test func lookStoreDefaultsAndRoundTrips() {
    let d = freshDefaults(); let s = LookStore(defaults: d)
    #expect(s.hero() == .pip && s.map() == .volcano)
    s.save(hero: .nova); s.save(map: .glacier)
    #expect(s.hero() == .nova && s.map() == .glacier)
}

@Test func unknownLookLoadsAsDefault() {
    let d = freshDefaults()
    d.set("trex", forKey: LookStore.heroKey); d.set(42, forKey: LookStore.mapKey)
    let s = LookStore(defaults: d)
    #expect(s.hero() == .pip && s.map() == .volcano)
}

@Test func everyHeroIsSolidAndDistinct() {
    let images = Hero.allCases.map { Art.pip(.wingDown, hero: $0) }
    for img in images {
        #expect(img.width == 104 && img.height == 88)
        #expect(alpha(img, px: 54, 50) > 200)  // body centre
    }
    #expect(Set(images.map(pixels)).count == Hero.allCases.count)
}

@Test func everyMapDrawsItsOwnBackdropAndObstacles() {
    for m in MapTheme.allCases {
        #expect(Art.shard(map: m).width == 36 && Art.chunk(map: m).width == 52)
        #expect(Art.volcanoes(map: m).width == 920 && Art.cycads(map: m).width == 600 && Art.stars(map: m).width == 1400)
        #expect(alpha(Art.shard(map: m), px: 18, 400) > 200)  // the shard body is opaque
    }
    #expect(Set(MapTheme.allCases.map { pixels(Art.shard(map: $0)) }).count == MapTheme.allCases.count)
    #expect(Set(MapTheme.allCases.map { pixels(Art.cycads(map: $0)) }).count == MapTheme.allCases.count)
    #expect(Set(MapTheme.allCases.map { pixels(Art.volcanoes(map: $0)) }).count == MapTheme.allCases.count)
}

@MainActor @Test func switchingLookRedrawsAndRebuildsGates() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
    s.gates = [Gate(id: 4, x: 100, centre: 94, gap: 150, chunk: 24, items: [Item(side: .upper, pickup: .ember)])]
    scene.sync(s)
    let oldGate = scene.gateNode(id: 4)
    let oldPip = scene.pipNode.texture
    scene.apply(hero: .moss, map: .grove)
    #expect(scene.hero == .moss && scene.map == .grove)
    #expect(scene.gateNodeCount == 0 && scene.pipNode.texture !== oldPip)
    scene.sync(s)
    #expect(scene.gateNodeCount == 1 && scene.gateNode(id: 4) !== oldGate)
}

@MainActor @Test func modelChoosesAndRemembersLook() {
    let d = freshDefaults()
    let m = IslandModel(display: nil, best: BestScoreStore(defaults: d), layout: LayoutStore(defaults: d),
                        looks: LookStore(defaults: d), seed: 1)
    #expect(m.hero == .pip && m.map == .volcano)
    m.choose(hero: .nova); m.choose(map: .glacier)
    #expect(m.scene.hero == .nova && m.scene.map == .glacier)
    let again = IslandModel(display: nil, best: BestScoreStore(defaults: d), layout: LayoutStore(defaults: d),
                            looks: LookStore(defaults: d), seed: 1)
    #expect(again.hero == .nova && again.map == .glacier)
}
