import AppKit
import Foundation
import NotchKit
import RunnerCore
import Testing
@testable import NotchDinoApp

/// The built-in display, with its notch, and an external one to its right with no notch.
private let builtIn = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 185, height: 32),
                                   isMain: true, isBuiltIn: true, menuBarHeight: 32)
private let external = NotchDisplay(id: 2, x: 1512, y: 0, width: 2560, height: 1440, notch: nil,
                                    isMain: false, menuBarHeight: 30)

/// An open island on the built-in display, with a panel (held here: the model keeps it weakly) and both displays.
@MainActor private func openOnBuiltIn(defaults d: UserDefaults = freshDefaults()) -> (model: IslandModel, panel: IslandPanel) {
    let m = IslandModel(display: builtIn, best: BestScoreStore(defaults: d), layout: LayoutStore(defaults: d),
                        looks: LookStore(defaults: d), seed: 1)
    let panel = IslandPanel(size: m.panelSize)
    m.panel = panel
    m.availableDisplays = { [builtIn, external] }
    m.handle(.hotKey)
    return (m, panel)
}

/// Drags the island so its top-left lands at `topLeft` (global top-left points), then drops it.
@MainActor private func drag(_ m: IslandModel, toTopLeft topLeft: CGPoint) {
    m.move(.began(.zero))
    m.move(.changed(CGPoint(x: 10, y: 0)))   // past the threshold: the island floats where it was
    let start = m.floatingTopLeft
    // Pointer points are AppKit's (y up); top-left points grow downward.
    m.move(.changed(CGPoint(x: 10 + topLeft.x - start.x, y: -(topLeft.y - start.y))))
    m.move(.ended)
}

private func near(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 0.5 && abs(a.y - b.y) < 0.5 }

@MainActor @Suite struct IslandMoveTests {
    @Test func dropOnAnotherDisplayMovesTheIslandThere() {
        let d = freshDefaults()
        let (m, panel) = openOnBuiltIn(defaults: d)
        m.game.phase = .running
        let target = CGPoint(x: 2400, y: 500)
        drag(m, toTopLeft: target)
        #expect(m.display?.id == 2)
        #expect(m.isFloating && m.geometry.isFloating && !m.isMoving)
        var expected = IslandModel.makeGeometry(external); expected.isFloating = true
        #expect(m.geometry == expected)
        #expect(Double(m.geometry.expandedSize.height) == 30 + NotchGeometry.extraHeight)
        let field = IslandModel.fieldSize(m.geometry)
        #expect(m.game.world == World.forField(width: field.width, height: field.height))
        #expect(m.game.phase == .paused)
        let prefs = LayoutStore(defaults: d).load()
        #expect(prefs.origins[2] != nil && prefs.origins[1] == nil)
        #expect(LayoutStore(defaults: d).prefersFloating())
        #expect(near(m.floatingTopLeft, target))
        #expect(external.visibleRect.contains(CGRect(origin: m.floatingTopLeft, size: m.geometry.expandedSize)))
        #expect(panel.frame.width == m.panelSize.width)
    }

    @Test func dropOnAnotherDisplayIsClampedIntoItsVisibleRect() {
        let d = freshDefaults()
        let (m, _) = openOnBuiltIn(defaults: d)
        // Centre on the external display, right edge past it.
        drag(m, toTopLeft: CGPoint(x: 1512 + 2560 - 300, y: 600))
        #expect(m.display?.id == 2)
        #expect(external.visibleRect.contains(CGRect(origin: m.floatingTopLeft, size: m.geometry.expandedSize)))
        #expect(LayoutStore(defaults: d).load().origins[2] != nil)
    }

    @Test func dropOnTheSameDisplayFloatsThereAsBefore() {
        let d = freshDefaults()
        let (m, _) = openOnBuiltIn(defaults: d)
        m.game.phase = .running
        let geometry = m.geometry, world = m.game.world
        let target = CGPoint(x: 300, y: 400)
        drag(m, toTopLeft: target)
        #expect(m.display?.id == 1)
        var expected = geometry; expected.isFloating = true
        #expect(m.geometry == expected)
        #expect(m.game.world == world)
        #expect(m.game.phase == .running)
        let prefs = LayoutStore(defaults: d).load()
        #expect(prefs.origins[1] != nil && prefs.origins[2] == nil)
        #expect(near(m.floatingTopLeft, target))
    }

    @Test func dropNearAnotherDisplaysTopCentreDocksThere() {
        let d = freshDefaults()
        let (m, _) = openOnBuiltIn(defaults: d)
        let width = IslandModel.makeGeometry(external).expandedSize.width
        drag(m, toTopLeft: CGPoint(x: external.x + (external.width - width) / 2, y: external.y + 10))
        #expect(m.display?.id == 2)
        #expect(!m.isFloating && !m.geometry.isFloating)
        #expect(m.geometry == IslandModel.makeGeometry(external))
        #expect(!LayoutStore(defaults: d).prefersFloating())
        #expect(LayoutStore(defaults: d).load().origins.isEmpty)
    }

    @Test func duringARaceADropOnAnotherDisplaySnapsBack() {
        let d = freshDefaults()
        let (m, _, _, _, _) = hostedRace(defaults: d)
        let panel = IslandPanel(size: m.panelSize)
        m.panel = panel
        m.availableDisplays = { [builtIn, external] }
        m.placePanel()
        let before = panel.frame, geometry = m.geometry, race = m.race
        #expect(race != nil && m.session != nil)
        drag(m, toTopLeft: CGPoint(x: 2400, y: 500))
        #expect(m.display?.id == 1)
        #expect(m.geometry == geometry)
        #expect(!m.isFloating && !m.isMoving)
        #expect(panel.frame == before)
        #expect(m.race == race && m.session != nil)
        #expect(LayoutStore(defaults: d).load().origins.isEmpty)
    }

    @Test func duringARaceADropOnTheSameDisplayStillFloats() {
        let d = freshDefaults()
        let (m, _, _, _, _) = hostedRace(defaults: d)
        let panel = IslandPanel(size: m.panelSize)
        m.panel = panel
        m.availableDisplays = { [builtIn, external] }
        drag(m, toTopLeft: CGPoint(x: 300, y: 400))
        #expect(m.display?.id == 1 && m.isFloating && m.race != nil)
        #expect(LayoutStore(defaults: d).load().origins[1] != nil)
    }

    @Test func foldThenOpenReopensOnTheNewDisplay() {
        let (m, _) = openOnBuiltIn()
        let target = CGPoint(x: 2400, y: 500)
        drag(m, toTopLeft: target)
        m.handle(.escape)
        #expect(!m.isOpen && !m.isFloating && m.display?.id == 2)
        m.handle(.hotKey)
        #expect(m.isOpen && m.isFloating && m.display?.id == 2)
        #expect(near(m.floatingTopLeft, target))
    }

    @Test func dockedOnTheNewDisplayReopensDockedThere() {
        let (m, _) = openOnBuiltIn()
        let width = IslandModel.makeGeometry(external).expandedSize.width
        drag(m, toTopLeft: CGPoint(x: external.x + (external.width - width) / 2, y: 0))
        m.handle(.escape); m.handle(.hotKey)
        #expect(m.isOpen && !m.isFloating && m.display?.id == 2)
        #expect(m.geometry == IslandModel.makeGeometry(external))
    }
}
