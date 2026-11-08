import AppKit
import NotchKit
import Observation
import RunnerCore

@MainActor @Observable public final class IslandModel: NotchHandleDriver, RunnerSceneDriver {
    // Observed by SwiftUI.
    public private(set) var geometry: NotchGeometry
    public private(set) var isOpen = false
    public private(set) var isFloating = false
    public private(set) var isMoving = false
    public private(set) var phase: Phase = .idle
    public private(set) var hud: HUD = .empty
    public private(set) var hero: Hero
    public private(set) var map: MapTheme

    // Not observed: change every frame.
    @ObservationIgnored public var game: GameState
    @ObservationIgnored let scene: RunnerScene
    @ObservationIgnored public weak var panel: IslandPanel?
    @ObservationIgnored public private(set) var display: NotchDisplay?

    @ObservationIgnored private let bestStore: BestScoreStore
    @ObservationIgnored private let layoutStore: LayoutStore
    @ObservationIgnored private let lookStore: LookStore
    @ObservationIgnored private var prefs: NotchLayoutPrefs
    @ObservationIgnored private var base: NotchGeometry
    @ObservationIgnored private var seed: UInt64
    @ObservationIgnored private var moveStart: (pointer: CGPoint, frame: CGRect)?
    @ObservationIgnored private var resizeStart: (pointer: CGPoint, height: Double)?
    @ObservationIgnored private var moveStartedDocked = false
    @ObservationIgnored var isResizing: Bool { resizeStart != nil }

    public init(display: NotchDisplay?, best: BestScoreStore, layout: LayoutStore, looks: LookStore = LookStore(), seed: UInt64) {
        self.display = display
        self.bestStore = best
        self.layoutStore = layout
        self.lookStore = looks
        self.hero = looks.hero()
        self.map = looks.map()
        self.prefs = layout.load()
        self.seed = seed
        let g = Self.makeGeometry(display)
        self.base = g
        self.geometry = g
        let field = Self.fieldSize(g)
        self.game = Runner.newGame(world: World.forField(width: field.width, height: field.height), seed: seed, best: best.load())
        self.scene = RunnerScene(islandSize: g.expandedSize, band: g.notch.height, hero: looks.hero(), map: looks.map())
        scene.isPaused = true
        scene.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        scene.driver = self
        if let id = display?.id, let h = prefs.heights[id] { applySavedHeight(h) }
        publish()
    }

    // MARK: Geometry

    static func makeGeometry(_ d: NotchDisplay?) -> NotchGeometry {
        NotchGeometry.make(notch: d?.notch, builtInNotchWidth: 0, menuBarHeight: d?.menuBarHeight ?? 24)
    }

    static func fieldSize(_ g: NotchGeometry) -> CGSize {
        CGSize(width: g.expandedSize.width - 2 * NotchGeometry.bodyInset,
               height: g.expandedSize.height - g.notch.height - NotchGeometry.bodyTop - NotchGeometry.bodyBottom)
    }

    /// The panel: NotchKit's docked panel, or the island plus a margin on every side when floating.
    public var panelSize: CGSize {
        isFloating ? CGSize(width: geometry.expandedSize.width + 2 * NotchFloat.margin,
                            height: geometry.expandedSize.height + 2 * NotchFloat.margin)
                   : geometry.panelSize
    }

    /// The open island's frame inside the panel (top-left points).
    public var islandFrame: CGRect {
        isFloating ? CGRect(origin: CGPoint(x: NotchFloat.margin, y: NotchFloat.margin), size: geometry.expandedSize)
                   : geometry.islandRect(size: geometry.expandedSize)
    }

    /// What takes the mouse: the open island, or only the notch while folded.
    public var hitRect: CGRect { isOpen ? islandFrame : geometry.hoverTarget }

    // MARK: Look

    /// Picks who flies and where. Art only: the run in progress carries on.
    public func choose(hero: Hero) {
        self.hero = hero
        lookStore.save(hero: hero)
        scene.apply(hero: hero, map: map)
    }

    public func choose(map: MapTheme) {
        self.map = map
        lookStore.save(map: map)
        scene.apply(hero: hero, map: map)
    }

    // MARK: Commands

    public func handle(_ event: IslandEvent) {
        let result = IslandLogic.reduce(isOpen: isOpen, phase: game.phase, event: event)
        for command in result.commands { run(command) }
    }

    private func run(_ command: IslandCommand) {
        switch command {
        case .open:
            if layoutStore.prefersFloating(), let id = display?.id, prefs.origins[id] != nil { floatAtSavedOrigin() }
            isOpen = true
            scene.isPaused = false
            panel?.allowsKey = true
            panel?.makeKey()
        case .fold:
            clearDrag()
            if isFloating { dock(rememberFloating: true) }
            isOpen = false
            scene.isPaused = true
            panel?.dropKey()
        case .pauseGame:
            Runner.pause(&game)
            publish()
        case .flap:
            var events: [GameEvent] = []
            Runner.flap(&game, events: &events)
            scene.consume(events, state: game)
            publish()
        case .newGameAndFlap:
            seed &+= 1
            game = Runner.newGame(world: game.world, seed: seed, best: game.best)
            scene.reset()
            run(.flap)
        }
    }

    // MARK: RunnerSceneDriver

    func sceneTick(elapsed: Double) -> (state: GameState, events: [GameEvent]) {
        let events = Runner.advance(&game, elapsed: elapsed)
        react(to: events)
        publish()
        return (game, events)
    }

    func sceneClicked() { handle(.clickField) }

    private func react(to events: [GameEvent]) {
        for e in events {
            switch e {
            case .milestone(let n): announce("\(n) gates")
            case .newBest(let n): bestStore.save(n); announce("New best, \(n)")
            case .crashed(let n): announce("Crashed at \(n)")
            case .picked(let p): announce(p.label)
            case .flapped, .gatePassed, .hiccup, .melted: break
            }
        }
    }

    private func announce(_ text: String) {
        guard let panel else { return }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Only touches observed properties when they change, so SwiftUI is not invalidated every frame.
    private func publish() {
        if phase != game.phase { phase = game.phase }
        let h = HUD.make(game)
        if h != hud { hud = h }
    }

    // MARK: Displays

    /// The screen set changed: re-home onto the best display and pause.
    public func rehome(displays: [NotchDisplay]) {
        handle(.autoPause)
        clearDrag()
        guard let d = DisplayPicker.pick(displays) else { panel?.orderOut(nil); return }
        display = d
        base = Self.makeGeometry(d)
        isFloating = false
        applySavedHeight(prefs.heights[d.id] ?? base.expandedSize.height)
        panel?.orderFrontRegardless()
    }

    // MARK: Panel placement (AppKit: bottom-left origin)

    private var screen: NSScreen? {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display?.id }
            ?? NSScreen.main
    }
    private var mainHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    public func placePanel() {
        guard let panel, let screen else { return }
        if isFloating { return }
        let s = panelSize
        panel.setFrame(CGRect(x: screen.frame.midX - s.width / 2, y: screen.frame.maxY - s.height, width: s.width, height: s.height),
                       display: true)
    }

    private func clearDrag() { moveStart = nil; resizeStart = nil; isMoving = false }

    private func persistFloatingOrigin(_ topLeft: CGPoint) {
        guard let d = display else { return }
        let clamped = NotchFloat.clamp(CGRect(origin: topLeft, size: geometry.expandedSize), in: d.visibleRect)
        float(topLeft: clamped.origin)
        prefs.origins[d.id] = NotchFloat.origin(of: CGPoint(x: clamped.midX, y: clamped.minY), visible: d.visibleRect,
                                                pillSize: geometry.expandedSize)
        layoutStore.save(prefs)
        layoutStore.setPrefersFloating(true)
    }

    private func persistHeight() {
        guard let id = display?.id else { return }
        prefs.heights[id] = geometry.expandedSize.height
        layoutStore.save(prefs)
    }

    private func dock(rememberFloating: Bool) {
        isFloating = false
        var g = geometry; g.isFloating = false; geometry = g
        if !rememberFloating { layoutStore.setPrefersFloating(false) }
        placePanel()
    }

    /// Floats with the island's top-left at `topLeft` (global top-left points).
    private func float(topLeft: CGPoint) {
        guard let panel else { return }
        isFloating = true
        var g = geometry; g.isFloating = true; geometry = g
        let s = panelSize
        panel.setFrame(CGRect(x: topLeft.x - NotchFloat.margin, y: mainHeight - topLeft.y + NotchFloat.margin - s.height,
                              width: s.width, height: s.height), display: true)
    }

    private func floatAtSavedOrigin() {
        guard let d = display, let origin = prefs.origins[d.id] else { return }
        let anchor = NotchFloat.anchor(of: origin, visible: d.visibleRect, pillSize: geometry.expandedSize)
        float(topLeft: CGPoint(x: anchor.x - geometry.expandedSize.width / 2, y: anchor.y))
    }

    /// The floating island's top-left in global top-left points.
    private var floatingTopLeft: CGPoint {
        guard let panel else { return .zero }
        return CGPoint(x: panel.frame.minX + NotchFloat.margin, y: mainHeight - (panel.frame.maxY - NotchFloat.margin))
    }

    // MARK: NotchHandleDriver — move

    public func move(_ input: NotchHandleInput) {
        guard let panel, isOpen else { return }
        switch input {
        case .began(let p):
            moveStart = (p, panel.frame)
            moveStartedDocked = !isFloating
        case .changed(let p):
            guard let start = moveStart else { return }
            let dx = p.x - start.pointer.x, dy = p.y - start.pointer.y
            if !isMoving {
                guard hypot(dx, dy) >= NotchFloat.dragThreshold else { return }
                isMoving = true
                if !isFloating {
                    let island = NotchHitRect.screenRect(of: islandFrame, inPanel: panel.frame)
                    float(topLeft: CGPoint(x: island.minX, y: mainHeight - island.maxY))
                    moveStart = (start.pointer, panel.frame)
                }
            }
            guard let s = moveStart else { return }
            panel.setFrameOrigin(CGPoint(x: s.frame.minX + dx, y: s.frame.minY + dy))
        case .ended:
            defer { moveStart = nil; isMoving = false }
            guard isMoving, let d = display else { return }
            let tl = floatingTopLeft
            if NotchFloat.touchesDock(proposedTop: tl.y, left: tl.x, right: tl.x + geometry.expandedSize.width,
                                      display: d, notchWidth: geometry.notch.width) {
                dock(rememberFloating: false)
            } else {
                persistFloatingOrigin(tl)
            }
        case .cancel:
            if let s = moveStart {
                if moveStartedDocked && isFloating { dock(rememberFloating: true) } else { panel.setFrame(s.frame, display: true) }
            }
            moveStart = nil; isMoving = false
        case .reset:
            dock(rememberFloating: false)
        case .corner(let corner):
            guard let d = display else { return }
            let a = NotchFloat.anchor(corner: corner, size: geometry.expandedSize, visible: d.visibleRect)
            persistFloatingOrigin(CGPoint(x: a.x - geometry.expandedSize.width / 2, y: a.y))
        case .step:
            break
        }
    }

    // MARK: NotchHandleDriver — resize (idle or paused only)

    private var minHeight: Double { NotchGeometry.idleHeight }
    private var maxHeight: Double {
        guard let d = display else { return base.expandedSize.height }
        let top = isFloating ? Double(floatingTopLeft.y) : d.y
        return NotchResize.maxHeight(top: top, display: d, min: minHeight)
    }

    public func resize(_ input: NotchHandleInput) {
        switch input {
        case .ended, .cancel:
            let dragging = resizeStart != nil
            resizeStart = nil
            if dragging {
                applyHeight(NotchResize.settled(geometry.expandedSize.height, min: minHeight, max: maxHeight))
                persistHeight()
            }
            return
        default: break
        }
        guard IslandLogic.resizeAllowed(game.phase) else { return }
        switch input {
        case .began(let p): resizeStart = (p, geometry.expandedSize.height)
        case .changed(let p):
            guard let s = resizeStart else { return }
            applyHeight(NotchResize.live(proposed: s.height + (s.pointer.y - p.y), min: minHeight, max: maxHeight,
                                         reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
        case .reset: applyHeight(base.notch.height + NotchGeometry.extraHeight); persistHeight()
        case .step(let dir):
            applyHeight(NotchResize.stepped(geometry.expandedSize.height, by: dir, min: minHeight, max: maxHeight))
            persistHeight()
        case .ended, .cancel, .corner: break
        }
    }

    /// A height from settings (or the default) may come from a taller display or a hand edit: keep it within this one.
    private func applySavedHeight(_ height: Double) {
        applyHeight(NotchResize.settled(height, min: minHeight, max: maxHeight))
    }

    private func applyHeight(_ height: Double) {
        let h = height.rounded()
        var g = base
        g.expandedSize.height = h
        g.panelSize = base.panelSize(growth: h - base.expandedSize.height)
        g.isFloating = isFloating
        let topLeft = isFloating ? floatingTopLeft : nil
        geometry = g
        scene.layout(islandSize: g.expandedSize, band: g.notch.height)
        let field = Self.fieldSize(g)
        Runner.resize(&game, world: World.forField(width: field.width, height: field.height))
        if let topLeft { float(topLeft: topLeft) } else { placePanel() }
    }
}
