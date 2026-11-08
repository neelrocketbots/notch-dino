import Foundation
import RaceCore
import RunnerCore
import SpriteKit
import Testing
@testable import NotchDinoApp

@MainActor private func scene() -> RunnerScene { RunnerScene(islandSize: CGSize(width: 445, height: 282), band: 32) }

@Suite struct GhostNodeTests {
    @MainActor @Test func theGhostNodeIsCreatedTintedAndRemoved() throws {
        let sc = scene()
        #expect(sc.ghostNode == nil)
        sc.setGhost(hero: .moss, name: "Ana")
        let node = try #require(sc.ghostNode)
        // SpriteKit keeps alpha and blend factors as Float: compare within a tolerance.
        #expect(node.parent === sc && node.alpha == 0.5 && abs(node.colorBlendFactor - 0.15) < 1e-6)
        #expect(sc.ghostTag?.text == "Ana")
        var s = Runner.newGame(world: World.forField(width: 421, height: 240), seed: 1, best: 0)
        s.phase = .running; s.pipY = 60
        sc.syncGhost(s)
        let p = sc.scenePoint(x: s.world.pipX, y: 60)
        #expect(!node.isHidden && abs(node.position.x - p.x) < 1e-6 && abs(node.position.y - p.y) < 1e-6)
        s.phase = .crashed
        sc.syncGhost(s)
        #expect(abs(node.alpha - 0.35) < 1e-6)
        sc.syncGhost(nil)
        #expect(node.isHidden && sc.ghostTag?.isHidden == true)
        sc.setGhost(hero: nil, name: "")
        #expect(sc.ghostNode == nil && sc.ghostTag == nil && node.parent == nil)
    }

    @MainActor @Test func aWiderOrNarrowerWorldIsFittedSymmetrically() {
        let sc = scene()
        // Field 421 × 240 pt: 1.2 pt per unit, so the island's own world is 350.8 units wide.
        let own = World.forField(width: 421, height: 240)
        #expect(sc.scenePoint(x: 0, y: 0).x == 12 && sc.letterboxBars.allSatisfy(\.isHidden))
        for w in [320.0, 380.0] {
            sc.fit(worldWidth: w)
            let offset = (421 - w * 1.2) / 2
            #expect(abs(sc.unitScale - 1.2) < 1e-9)
            #expect(abs(sc.scenePoint(x: 0, y: 0).x - (12 + offset)) < 1e-6)
            #expect(abs(sc.scenePoint(x: w / 2, y: 0).x - (12 + 421.0 / 2)) < 1e-6)
            var s = Runner.newGame(world: World(width: w), seed: 1, best: 0)
            s.phase = .running
            sc.sync(s)
            #expect(abs(sc.pipNode.position.x - sc.scenePoint(x: w * Params.pipXFraction, y: 0).x) < 1e-6)
            let narrower = w < own.width
            #expect(sc.letterboxBars.allSatisfy { $0.isHidden == !narrower })
            if narrower {
                #expect(abs(sc.letterboxBars[0].size.width - offset) < 1e-6)
                #expect(abs(sc.letterboxBars[0].position.x - 12) < 1e-6)
                #expect(abs(sc.letterboxBars[1].position.x - (12 + 421 - offset)) < 1e-6)
            }
        }
        sc.fit(worldWidth: nil)
        #expect(sc.scenePoint(x: 0, y: 0).x == 12 && sc.letterboxBars.allSatisfy(\.isHidden))
    }

    @MainActor @Test func theModelShowsTheOpponentsGhostDuringARaceOnly() {
        let (m, _, _, _, _) = racing()
        #expect(m.scene.ghostNode != nil && m.scene.ghostTag?.text == "Ana")
        #expect(m.sceneGhost?.step == m.game.step)
        m.closeRace()
        #expect(m.scene.ghostNode == nil && m.sceneGhost == nil)
    }

    @MainActor @Test func aGuestLaysOutTheHostsWorldThenGoesBackToItsOwn() {
        let (m, net, clock) = raceModel()
        net.hosts = [RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")]
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)
        let host = net.remotes[0]
        _ = farEnd(host)
        net.links[0].connect()
        host.send(.welcome(name: "Ana", hero: "moss", map: "glacier", width: 400))
        host.send(.start(seed: 77, inMs: 2_100))
        pump(net, to: clock.now)
        #expect(m.scene.worldWidth == 400 && m.game.world.width == 400)
        m.closeRace()
        #expect(m.scene.worldWidth == nil && m.game.world == m.soloWorld)
    }

    // Main has 10 heroes: the ghost is drawn as whichever one the opponent flies.
    @MainActor @Test func theGhostIsTheOpponentsHeroForEveryHero() throws {
        let sc = scene()
        for hero in Hero.allCases {
            sc.setGhost(hero: hero, name: "Ana")
            #expect(sc.ghostHero == hero)
            let node = try #require(sc.ghostNode)
            #expect(node.texture != nil && node.size == Art.pipSize)
        }
        sc.setGhost(hero: nil, name: "")
        #expect(sc.ghostHero == nil)
    }

    @MainActor @Test func theModelDrawsTheGuestsOwnHeroAsTheGhost() {
        let (m, net, clock) = raceModel()
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)   // host
        let guest = net.remotes[0]
        _ = farEnd(guest)
        net.links[0].connect()
        guest.send(.hello(proto: RaceMessage.protocolVersion, rules: Params.rulesVersion, name: "Tia", hero: "tide"))
        pump(net, to: clock.now)
        m.handle(.flapKey)   // start
        #expect(m.scene.ghostHero == .tide && m.scene.ghostTag?.text == "Tia" && m.scene.hero == .pip)
    }
}
