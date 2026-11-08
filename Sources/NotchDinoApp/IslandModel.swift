import AppKit
import NotchKit
import Observation
import RaceCore
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
    /// The race screen; nil in solo play.
    public internal(set) var race: RaceScreen?
    public internal(set) var raceHUD: RaceHUD?
    /// "Ana crashed at 9 · pass 9 to win", while it applies.
    public internal(set) var raceNotice: String?
    public internal(set) var playerName: String
    /// This player pressed Space on the result card and is waiting for the other.
    public internal(set) var rematchAsked = false

    // Not observed: change every frame.
    @ObservationIgnored public var game: GameState
    @ObservationIgnored let scene: RunnerScene
    @ObservationIgnored public weak var panel: IslandPanel?
    @ObservationIgnored public private(set) var display: NotchDisplay?
    @ObservationIgnored public internal(set) var session: RaceSession?
    @ObservationIgnored var link: RaceLink?
    @ObservationIgnored let network: RaceNetwork
    @ObservationIgnored let raceStore: RaceStore
    @ObservationIgnored var raceTimer: Timer?
    /// A join in progress: who, and when (on `clock`). Cleared once the link connects (ruling 1).
    @ObservationIgnored var joinAttempt: (host: RaceHost, since: Double)?
    /// Seconds on a monotonic clock; tests replace it.
    @ObservationIgnored var clock: @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime }
    /// N in the lobby: ask for a new player name. Set by the app delegate.
    @ObservationIgnored public var onAskName: (@MainActor () -> Void)?
    /// Opens System Settings at Privacy & Security › Local Network. Set by the app delegate.
    @ObservationIgnored public var onOpenPrivacy: (@MainActor () -> Void)?
    /// The displays a drop can land on; tests replace it.
    @ObservationIgnored var availableDisplays: @MainActor () -> [NotchDisplay] = { NotchScreens.displays() }

    @ObservationIgnored let bestStore: BestScoreStore
    @ObservationIgnored private let layoutStore: LayoutStore
    @ObservationIgnored private let lookStore: LookStore
    @ObservationIgnored private var prefs: NotchLayoutPrefs
    @ObservationIgnored private var base: NotchGeometry
    @ObservationIgnored var seed: UInt64
    @ObservationIgnored private var moveStart: (pointer: CGPoint, frame: CGRect)?
    @ObservationIgnored private var moveStartedDocked = false

    public init(display: NotchDisplay?, best: BestScoreStore, layout: LayoutStore, looks: LookStore = LookStore(),
                race: RaceStore = RaceStore(), network: RaceNetwork? = nil, seed: UInt64) {
        self.display = display
        self.bestStore = best
        self.layoutStore = layout
        self.lookStore = looks
        layout.dropLegacyHeights()
        self.hero = looks.hero()
        self.map = looks.map()
        self.raceStore = race
        self.network = network ?? NWRaceNetwork()
        self.playerName = race.name()
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

    /// The world this island's own field holds: 200 units tall, as wide as the field.
    var soloWorld: World {
        let field = Self.fieldSize(geometry)
        return World.forField(width: field.width, height: field.height)
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
        scene.sync(game)
    }

    public func choose(map: MapTheme) {
        self.map = map
        lookStore.save(map: map)
        scene.apply(hero: hero, map: map)
        scene.sync(game)
    }

    // MARK: Commands

    public func handle(_ event: IslandEvent) {
        if race != nil { handleRace(event); return }
        let result = IslandLogic.reduce(isOpen: isOpen, phase: game.phase, event: event)
        for command in result.commands { run(command) }
    }

    func run(_ command: IslandCommand) {
        switch command {
        case .open:
            if layoutStore.prefersFloating(), let id = display?.id, prefs.origins[id] != nil { floatAtSavedOrigin() }
            isOpen = true
            scene.isPaused = false
            scene.sync(game)
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
            scene.sync(game)
            run(.flap)
        case .openRace:
            openRace()
        }
    }

    // MARK: RunnerSceneDriver

    func sceneTick(elapsed: Double) -> (state: GameState, events: [GameEvent]) {
        let events = Runner.advance(&game, elapsed: elapsed)
        if race != nil { raceTick(events) } else { react(to: events) }
        publish()
        return (game, events)
    }

    func sceneClicked() { handle(.clickField) }

    var sceneGhost: GameState? { session?.ghost?.state }

    private func react(to events: [GameEvent]) {
        for e in events {
            switch e {
            case .milestone(let n): announce("\(n) gates")
            case .newBest(let n): bestStore.save(n); announce("New best, \(n)")
            case .crashed(let n): announce("Crashed at \(n)")
            case .picked(let p): announce(p.label)
            case .flapped, .gatePassed, .hiccup, .melted, .bounced: break
            }
        }
    }

    func announce(_ text: String) {
        guard let panel else { return }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Only touches observed properties when they change, so SwiftUI is not invalidated every frame.
    func publish() {
        if phase != game.phase { phase = game.phase }
        let h = HUD.make(game)
        if h.countdown != hud.countdown, let n = h.countdown { announce("\(n)") }
        if h != hud { hud = h }
    }

    // MARK: Displays

    /// The screen set changed: re-home onto the best display and pause.
    public func rehome(displays: [NotchDisplay]) {
        if race != nil { closeRace() }   // a display change ends the match (spec §6)
        handle(.autoPause)
        clearDrag()
        guard let d = DisplayPicker.pick(displays) else { panel?.orderOut(nil); return }
        isFloating = false
        adopt(d)
        panel?.orderFrontRegardless()
    }

    /// Lays the island out for `d`: its own notch (or NotchKit's virtual one), the default height, the world refitted.
    private func adopt(_ d: NotchDisplay) {
        display = d
        base = Self.makeGeometry(d)
        applyBaseGeometry()
    }

    /// The display under the island's centre (top-left points), if any.
    private func display(under topLeft: CGPoint) -> NotchDisplay? {
        let centre = CGPoint(x: topLeft.x + geometry.expandedSize.width / 2, y: topLeft.y + geometry.expandedSize.height / 2)
        return availableDisplays().first { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height).contains(centre) }
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

    private func clearDrag() { moveStart = nil; isMoving = false }

    private func persistFloatingOrigin(_ topLeft: CGPoint) {
        guard let d = display else { return }
        let clamped = NotchFloat.clamp(CGRect(origin: topLeft, size: geometry.expandedSize), in: d.visibleRect)
        float(topLeft: clamped.origin)
        prefs.origins[d.id] = NotchFloat.origin(of: CGPoint(x: clamped.midX, y: clamped.minY), visible: d.visibleRect,
                                                pillSize: geometry.expandedSize)
        layoutStore.save(prefs)
        layoutStore.setPrefersFloating(true)
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
    var floatingTopLeft: CGPoint {
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
            guard isMoving, var d = display else { moveStart = nil; isMoving = false; return }
            let tl = floatingTopLeft
            if let target = display(under: tl), target.id != d.id {
                // A race stays on its display: the drop snaps back, as a cancel does.
                if race != nil { move(.cancel); return }
                // Another display: the island moves there, laid out for it, and a running game pauses.
                run(.pauseGame)
                adopt(target)
                d = target
            }
            defer { moveStart = nil; isMoving = false }
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

    // MARK: NotchHandleDriver — resize

    /// The island always keeps NotchKit's default height, so no resize handle is shown and this does nothing.
    /// It stays only because `NotchHandleDriver` requires it.
    public func resize(_ input: NotchHandleInput) {}

    /// Lays the island out at the display's default height (`notch.height + NotchGeometry.extraHeight`) and resizes the
    /// world to the new field.
    private func applyBaseGeometry() {
        var g = base
        g.isFloating = isFloating
        geometry = g
        scene.layout(islandSize: g.expandedSize, band: g.notch.height)
        let field = Self.fieldSize(g)
        Runner.resize(&game, world: World.forField(width: field.width, height: field.height))
        scene.sync(game)
        placePanel()
    }
}
