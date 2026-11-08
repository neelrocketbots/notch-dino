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

@Test func heroesAndMapsComeInMenuOrderWithUniqueNames() {
    #expect(Hero.allCases.map(\.rawValue) == ["pip", "moss", "nova", "coral", "frost", "sable", "saffron", "tide", "rust", "blossom"])
    #expect(MapTheme.allCases.map(\.rawValue) == ["volcano", "glacier", "grove", "dunes", "skyisles", "bamboo", "crystal", "storm",
                                                  "autumn", "ruins"])
    #expect(Set(Hero.allCases.map(\.name)).count == Hero.allCases.count)
    #expect(Set(MapTheme.allCases.map(\.name)).count == MapTheme.allCases.count)
    #expect(MapTheme.allCases.map(\.name).suffix(7) == ["Dune Sea", "Sky Isles", "Bamboo Vale", "Crystal Caves", "Storm Coast",
                                                        "Autumn Woods", "Lost Ruins"])
}

@Test func lookStoreRoundTripsEveryHeroAndMap() {
    let d = freshDefaults(); let s = LookStore(defaults: d)
    for h in Hero.allCases {
        s.save(hero: h)
        #expect(d.string(forKey: LookStore.heroKey) == h.rawValue && s.hero() == h)
    }
    for m in MapTheme.allCases {
        s.save(map: m)
        #expect(d.string(forKey: LookStore.mapKey) == m.rawValue && s.map() == m)
    }
    d.set("coralreef", forKey: LookStore.heroKey); d.set("dune", forKey: LookStore.mapKey)
    #expect(s.hero() == .pip && s.map() == .volcano)
}

@Test func everyHeroPoseRendersDistinctly() {
    for h in Hero.allCases {
        let poses = PipPose.allCases.map { Art.pip($0, hero: h) }
        for img in poses { #expect(alpha(img, px: 54, 50) > 200) }
        #expect(Set(poses.map(pixels)).count == PipPose.allCases.count)
    }
}

@Test func everyMapFillsItsObstacleTilesAndDrawsEveryLayer() {
    for m in MapTheme.allCases {
        let shard = Art.shard(map: m), chunk = Art.chunk(map: m)
        #expect(shard.height == 640 && chunk.height == 58)
        // the shard fills its tile edge to edge below the tip, and the chunk is solid at its centre
        for x in [1, 18, 34] { #expect(alpha(shard, px: x, 300) > 200 && alpha(shard, px: x, 620) > 200) }
        #expect(alpha(chunk, px: 26, 29) > 200)
        let ground = Art.ground(width: 489, height: 24, map: m)
        #expect(alpha(ground, px: 100, 30) > 0)
        for img in [Art.stars(map: m), Art.volcanoes(map: m), Art.cycads(map: m), ground] {
            #expect(pixels(img).contains { $0 != 0 })
        }
    }
    #expect(Set(MapTheme.allCases.map { pixels(Art.chunk(map: $0)) }).count == MapTheme.allCases.count)
    #expect(Set(MapTheme.allCases.map { pixels(Art.stars(map: $0)) }).count == MapTheme.allCases.count)
    #expect(Set(MapTheme.allCases.map { pixels(Art.ground(width: 489, height: 24, map: $0)) }).count == MapTheme.allCases.count)
    let size = CGSize(width: 445, height: 282)
    #expect(Set(MapTheme.allCases.map { pixels(Art.sky(size: size, fieldTop: 34, fieldHeight: 240, groundY: 259.6, map: $0)) }).count
        == MapTheme.allCases.count)
}

@MainActor @Test func everyLookAppliesToTheScene() {
    let scene = RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32)
    for (h, m) in zip(Hero.allCases, MapTheme.allCases.reversed()) {
        scene.apply(hero: h, map: m)
        #expect(scene.hero == h && scene.map == m)
    }
}
