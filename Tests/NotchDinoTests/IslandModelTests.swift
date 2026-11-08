import Foundation
import NotchKit
import RunnerCore
import Testing
@testable import NotchDinoApp

@MainActor fileprivate func makeModel(best: Int = 0, defaults: UserDefaults? = nil) -> IslandModel {
    let d = defaults ?? UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    BestScoreStore(defaults: d).save(best)
    let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 185, height: 32),
                               isMain: true, isBuiltIn: true, menuBarHeight: 32)
    return IslandModel(display: display, best: BestScoreStore(defaults: d), layout: LayoutStore(defaults: d), looks: LookStore(defaults: d), seed: 1)
}

@MainActor @Test func opensFoldsAndPauses() {
    let m = makeModel()
    m.handle(.hotKey); #expect(m.isOpen && !m.scene.isPaused)
    m.handle(.flapKey); #expect(m.game.phase == .running && m.phase == .running)
    m.handle(.escape); #expect(!m.isOpen && m.game.phase == .paused && m.scene.isPaused)
}

@MainActor @Test func tickAdvancesAndPublishesHUD() {
    let m = makeModel(best: 7)
    m.handle(.hotKey); m.handle(.flapKey)
    _ = m.sceneTick(elapsed: 1.0 / 60)
    #expect(m.game.time > 0 && m.hud.best == 7)
}

@MainActor @Test func crashSavesNewBest() {
    let m = makeModel(best: 1)
    m.handle(.hotKey); m.handle(.flapKey)
    m.game.score = 5; m.game.pipY = Params.ground; m.game.nextGateX = 1e6
    _ = m.sceneTick(elapsed: 1.0 / 60)
    #expect(m.phase == .crashed)
    #expect(m.hud.best == 5)
}

@MainActor @Test func retryStartsAFreshRun() {
    let m = makeModel()
    m.handle(.hotKey); m.handle(.flapKey)
    m.game.pipY = Params.ground; m.game.nextGateX = 1e6
    _ = m.sceneTick(elapsed: 1.0 / 60)
    m.handle(.flapKey)
    #expect(m.game.phase == .running && m.game.score == 0 && m.game.gates.isEmpty)
}

@MainActor @Test func hitRectIsTheNotchWhenFoldedAndTheIslandWhenOpen() {
    let m = makeModel()
    #expect(m.hitRect == m.geometry.hoverTarget)
    m.handle(.clickNotch)
    #expect(m.hitRect == m.islandFrame && m.islandFrame.size == m.geometry.expandedSize)
}

@MainActor @Test func resetAndStepPersistHeight() {
    let d = UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    let m = makeModel(defaults: d)
    m.resize(.step(1))
    #expect(LayoutStore(defaults: d).load().heights[1] == Double(m.geometry.expandedSize.height))
    m.resize(.step(1))
    m.resize(.reset)
    #expect(LayoutStore(defaults: d).load().heights[1] == Double(m.geometry.expandedSize.height))
}

@MainActor @Test func resizeEndClearsStateEvenWhenRunning() {
    let m = makeModel()
    m.resize(.began(CGPoint(x: 0, y: 100)))
    #expect(m.isResizing)
    m.handle(.hotKey); m.handle(.flapKey)
    m.resize(.ended)
    #expect(!m.isResizing)
    m.resize(.began(CGPoint(x: 0, y: 100)))
    #expect(!m.isResizing)
}

@MainActor @Test func foldMidDragClearsMoving() {
    let m = makeModel()
    m.panel = IslandPanel(size: m.panelSize)
    m.handle(.hotKey)
    m.move(.began(.zero)); m.move(.changed(CGPoint(x: 20, y: 0)))
    #expect(m.isMoving && m.isFloating)
    m.handle(.escape)
    #expect(!m.isMoving && !m.isFloating)
}

@MainActor @Test func cancelAfterMorphRedocks() {
    let m = makeModel()
    m.panel = IslandPanel(size: m.panelSize)
    m.handle(.hotKey)
    m.move(.began(.zero)); m.move(.changed(CGPoint(x: 20, y: 0)))
    #expect(m.isFloating)
    m.move(.cancel)
    #expect(!m.isFloating && !m.isMoving)
}

/// The test display is 982 pt tall with no Dock inset, so the tallest island is 982 − 80 (Dock clearance) = 902.
@MainActor @Test(arguments: [5.0, 50_000.0])
func savedHeightIsClampedToTheDisplayOnLaunch(saved: Double) {
    let d = UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    LayoutStore(defaults: d).save(NotchLayoutPrefs(heights: [1: saved]))
    let m = makeModel(defaults: d)
    let h = Double(m.geometry.expandedSize.height)
    #expect(h >= NotchGeometry.idleHeight && h <= 902)
    #expect(m.game.world.width > 0 && m.game.world.width.isFinite)
}

@MainActor @Test(arguments: [5.0, 50_000.0])
func savedHeightIsClampedToTheDisplayOnRehome(saved: Double) {
    let d = UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    LayoutStore(defaults: d).save(NotchLayoutPrefs(heights: [1: saved]))
    let m = makeModel(defaults: d)
    m.rehome(displays: [m.display!])
    let h = Double(m.geometry.expandedSize.height)
    #expect(h >= NotchGeometry.idleHeight && h <= 902)
    #expect(m.game.world.width > 0 && m.game.world.width.isFinite)
}

@MainActor @Test func openingSyncsTheSceneBeforeAnyUpdateTick() {
    let m = makeModel()
    m.handle(.hotKey)
    let expected = m.scene.scenePoint(x: m.game.world.pipX, y: m.game.pipY)
    #expect(m.scene.ashIsHidden)
    #expect(m.scene.overlaysAreHidden)
    #expect(abs(m.scene.pipNode.position.x - expected.x) < 0.01 && abs(m.scene.pipNode.position.y - expected.y) < 0.01)
}
