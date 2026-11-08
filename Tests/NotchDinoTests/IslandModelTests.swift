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
    m.handle(.flapKey); #expect(m.game.phase == .countdown(remaining: Params.countdownSteps) && m.phase == m.game.phase)
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
    m.handle(.hotKey); m.handle(.flapKey); m.game.phase = .running
    m.game.score = 5; m.game.pipY = Params.ground; m.game.nextGateX = 1e6
    _ = m.sceneTick(elapsed: 1.0 / 60)
    #expect(m.phase == .crashed)
    #expect(m.hud.best == 5)
}

@MainActor @Test func retryStartsAFreshRun() {
    let m = makeModel()
    m.handle(.hotKey); m.handle(.flapKey); m.game.phase = .running
    m.game.pipY = Params.ground; m.game.nextGateX = 1e6
    _ = m.sceneTick(elapsed: 1.0 / 60)
    m.handle(.flapKey)
    #expect(m.game.phase == .countdown(remaining: Params.countdownSteps) && m.game.score == 0 && m.game.gates.isEmpty)
}

@MainActor @Test func hitRectIsTheNotchWhenFoldedAndTheIslandWhenOpen() {
    let m = makeModel()
    #expect(m.hitRect == m.geometry.hoverTarget)
    m.handle(.clickNotch)
    #expect(m.hitRect == m.islandFrame && m.islandFrame.size == m.geometry.expandedSize)
}

@MainActor @Test func opensAtTheDefaultHeight() {
    let m = makeModel()
    m.handle(.hotKey)
    #expect(m.panel == nil && m.isOpen)
    #expect(Double(m.geometry.expandedSize.height) == 32 + NotchGeometry.extraHeight)
    let field = IslandModel.fieldSize(m.geometry)
    #expect(m.game.world == World.forField(width: field.width, height: field.height))
}

@MainActor @Test func leftoverSavedHeightIsIgnoredAndRemoved() {
    let d = UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    d.set(["1": 600.0], forKey: LayoutStore.legacyHeightsKey)
    let m = makeModel(defaults: d)
    #expect(Double(m.geometry.expandedSize.height) == 32 + NotchGeometry.extraHeight)
    #expect(d.object(forKey: LayoutStore.legacyHeightsKey) == nil)
    m.rehome(displays: [m.display!])
    #expect(Double(m.geometry.expandedSize.height) == 32 + NotchGeometry.extraHeight)
}

@MainActor @Test func rehomeAppliesTheNewDisplaysDefaultHeight() {
    let m = makeModel()
    let other = NotchDisplay(id: 2, x: 0, y: 0, width: 1728, height: 1117, notch: Notch(width: 200, height: 38),
                             isMain: true, isBuiltIn: true, menuBarHeight: 38)
    m.rehome(displays: [other])
    #expect(m.display?.id == 2)
    #expect(Double(m.geometry.expandedSize.height) == 38 + NotchGeometry.extraHeight)
    #expect(m.geometry == IslandModel.makeGeometry(other))
    let field = IslandModel.fieldSize(m.geometry)
    #expect(m.game.world == World.forField(width: field.width, height: field.height))
}

@MainActor @Test func foldMidDragClearsMoving() {
    let m = makeModel()
    let panel = IslandPanel(size: m.panelSize)
    m.panel = panel
    m.handle(.hotKey)
    m.move(.began(.zero)); m.move(.changed(CGPoint(x: 20, y: 0)))
    #expect(m.isMoving && m.isFloating)
    m.handle(.escape)
    #expect(!m.isMoving && !m.isFloating)
}

@MainActor @Test func cancelAfterMorphRedocks() {
    let m = makeModel()
    let panel = IslandPanel(size: m.panelSize)
    m.panel = panel
    m.handle(.hotKey)
    m.move(.began(.zero)); m.move(.changed(CGPoint(x: 20, y: 0)))
    #expect(m.isFloating)
    m.move(.cancel)
    #expect(!m.isFloating && !m.isMoving)
}

/// The VoiceOver float (a corner) and dock actions: floating saves the origin and keeps the default height.
@MainActor @Test func floatsToACornerAndDocksBack() {
    let d = UserDefaults(suiteName: "notchDino.model.\(UUID().uuidString)")!
    let m = makeModel(defaults: d)
    let panel = IslandPanel(size: m.panelSize)
    m.panel = panel
    m.handle(.hotKey)
    m.move(.corner(.bottomRight))
    #expect(m.isFloating && m.geometry.isFloating)
    #expect(LayoutStore(defaults: d).prefersFloating())
    #expect(LayoutStore(defaults: d).load().origins[1] != nil)
    #expect(Double(m.geometry.expandedSize.height) == 32 + NotchGeometry.extraHeight)
    #expect(d.object(forKey: LayoutStore.legacyHeightsKey) == nil)
    m.move(.reset)
    #expect(!m.isFloating && !m.geometry.isFloating)
    #expect(!LayoutStore(defaults: d).prefersFloating())
    #expect(Double(m.geometry.expandedSize.height) == 32 + NotchGeometry.extraHeight)
}

@MainActor @Test func openingSyncsTheSceneBeforeAnyUpdateTick() {
    let m = makeModel()
    m.handle(.hotKey)
    let expected = m.scene.scenePoint(x: m.game.world.pipX, y: m.game.pipY)
    #expect(m.scene.ashIsHidden)
    #expect(m.scene.overlaysAreHidden)
    #expect(abs(m.scene.pipNode.position.x - expected.x) < 0.01 && abs(m.scene.pipNode.position.y - expected.y) < 0.01)
}
