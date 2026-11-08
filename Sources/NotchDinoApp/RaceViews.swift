import NotchKit
import RaceCore
import RunnerCore
import SwiftUI

/// The words on the race panels, kept out of the views so they can be tested.
enum RaceCopy {
    static let explainerTitle = "Race on your network"
    static func explainer(name: String) -> String {
        "Notch Dino will look for Macs nearby. Nothing leaves your local network, and it stops listening as soon as "
            + "you leave the race. Nearby players will see your name, \(name). macOS will ask once."
    }
    static let deniedTitle = "Racing needs Local Network access"
    static let deniedBody = "Turn on Notch Dino in System Settings › Privacy & Security › Local Network, then come back."
    static func waitingTitle(_ role: RaceRole) -> String { role == .host ? "Waiting for a player…" : "Joining…" }
    static func readyTitle(_ role: RaceRole, opponent: String) -> String {
        role == .host ? "\(opponent) joined" : "Waiting for \(opponent) to start"
    }
    static func pausedTitle(byMe: Bool, opponent: String) -> String { byMe ? "Paused" : "\(opponent) paused" }
    static func pausedBody(byMe: Bool, opponent: String, pausesLeft: Int) -> String {
        guard byMe else { return "Only \(opponent) can resume." }
        return pausesLeft == 1 ? "1 pause left in this race." : "\(pausesLeft) pauses left in this race."
    }
    static func outcome(_ o: RaceOutcome, opponent: String) -> String {
        switch o {
        case .win: "You win"
        case .lose: "\(opponent) wins"
        case .tie: "Tie"
        }
    }
    static func endTitle(_ e: RaceEnd, opponent: String?) -> String {
        switch e {
        case .opponentLeft: opponent.map { "\($0) left the race" } ?? "The race closed"
        case .youLeft: "You left the race"
        case .versionMismatch: "Update Notch Dino to race"
        case .desync: "Couldn't keep the race in sync"
        case .full: "That race is full"
        }
    }
    static func endBody(_ e: RaceEnd) -> String {
        switch e {
        case .versionMismatch: "The other Mac runs a different version. Both need the same one."
        case .full: "Someone else joined first. Pick another race, or host your own."
        case .opponentLeft, .youLeft, .desync: "The match is over. Nothing is saved from it."
        }
    }
    static func unreachableTitle(_ host: String) -> String { RaceText.unreachable(host) }
    static func unreachableBody(_ host: String) -> String {
        "\(host)'s race didn't answer. It may have closed, or the Mac is out of range."
    }
    static func mapName(_ raw: String?) -> String { raw.flatMap(MapTheme.init(rawValue:))?.name ?? "Their map" }
    static func lobbyDetail(_ host: RaceHost) -> String { "\(mapName(host.map)) · waiting" }
}

/// Which host rows the lobby shows: at most `size`, keeping the selection in view. "Host a race" is always shown.
enum LobbyWindow {
    static func range(count: Int, selection: Int, size: Int = 3) -> Range<Int> {
        guard count > size else { return 0..<count }
        let start = min(max(0, selection - 1), count - size)
        return start..<(start + size)
    }
}

extension Ink {
    static let amber = Color(.sRGB, red: 1, green: 0.71, blue: 0.278)
    static let onAmber = Color(.sRGB, red: 0.165, green: 0.086, blue: 0.024)
}

struct Hint: Hashable {
    let key: String
    let action: String
    init(_ key: String, _ action: String) { self.key = key; self.action = action }
}

/// A key cap: a small rounded glass cap with a 1 pt light border, sized to its text so it never truncates.
struct KeyCap: View {
    let key: String
    var fontSize: CGFloat = 11
    var weight: Font.Weight = .semibold
    var height: CGFloat = 20
    var fill = 0.08
    var inset: CGFloat = 7
    var body: some View {
        Text(key).font(.system(size: fontSize, weight: weight)).foregroundStyle(Ink.text)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, inset).frame(height: height)
            .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(fill)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.35), lineWidth: 1))
    }
}

/// A key cap and its action. Both keep their natural width: a cap never truncates and a label never wraps.
struct KeyHint: View {
    let hint: Hint
    var body: some View {
        HStack(spacing: 6) {
            KeyCap(key: hint.key)
            Text(hint.action).font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.text)
                .lineLimit(1).fixedSize()
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// A panel's key hints: one centred row, or two centred rows when one doesn't fit. The text never shrinks.
struct KeyRow: View {
    let keys: [Hint]
    static let spacing: CGFloat = 14
    var body: some View {
        ViewThatFits(in: .horizontal) {
            Self.row(keys)
            VStack(spacing: 6) {
                let half = (keys.count + 1) / 2
                Self.row(Array(keys.prefix(half)))
                Self.row(Array(keys.dropFirst(half)))
            }
        }
    }
    private static func row(_ keys: [Hint]) -> some View {
        HStack(spacing: spacing) { ForEach(keys, id: \.self) { KeyHint(hint: $0) } }.fixedSize()
    }
}

/// The field dimmed, with a glass card: the content, then the keys. A standard card is 270 pt wide; a fitting card
/// (the lobby) grows to what its content and keys need, up to the field's width less `sideMargin` each side.
struct RacePanel<Content: View>: View {
    enum Width { case standard, fitting }
    static var standardWidth: CGFloat { 270 }
    static var sideMargin: CGFloat { 20 }
    static var padding: EdgeInsets { EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16) }
    /// The widest a fitting card may be in a field this wide.
    static func maxWidth(field: CGFloat) -> CGFloat { max(standardWidth, field - 2 * sideMargin) }

    let keys: [Hint]
    let width: Width
    let content: Content
    init(keys: [Hint], width: Width = .standard, @ViewBuilder content: () -> Content) {
        self.keys = keys
        self.width = width
        self.content = content()
    }
    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
            switch width {
            case .standard:
                card.frame(width: Self.standardWidth).modifier(PanelGlass())
            case .fitting:
                GeometryReader { proxy in
                    let most = Self.maxWidth(field: proxy.size.width)
                    ViewThatFits(in: .horizontal) {
                        card.frame(minWidth: Self.standardWidth).fixedSize(horizontal: true, vertical: false)
                        card.frame(width: most)
                    }
                    .modifier(PanelGlass())
                    .frame(width: most)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .allowsHitTesting(false)
    }
    private var card: some View {
        VStack(spacing: 6) {
            content
            KeyRow(keys: keys).padding(.top, 4)
        }
        .padding(Self.padding)
    }
}

extension EnvironmentValues {
    /// Draw the mockup's flat stand-in for Liquid Glass, for snapshots: `ImageRenderer` can't draw glass.
    @Entry var glassStandIn = false
}

/// A race panel's 18-pt glass card.
struct PanelGlass: ViewModifier {
    @Environment(\.glassStandIn) private var standIn
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        if standIn {
            content.background(shape.fill(Color(.sRGB, red: 0.157, green: 0.161, blue: 0.18, opacity: 0.62)))
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

struct PanelTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 17, weight: .semibold)).foregroundStyle(Ink.text).multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }
}

struct PanelBody: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct HeroSprite: View {
    let hero: Hero
    var pose: PipPose = .wingUp
    var size = CGSize(width: 52, height: 44)
    var body: some View {
        Image(decorative: Art.pip(pose, hero: hero), scale: Art.scale).resizable().interpolation(.high)
            .aspectRatio(contentMode: .fit).frame(width: size.width, height: size.height)
    }
}

struct DuoSlot {
    var hero: Hero?
    var label: String
    var score: Int? = nil
    var faded = false
    var pose: PipPose = .wingUp
}

/// Two heroes side by side; an empty dashed slot while waiting for a player.
struct Duo: View {
    let left: DuoSlot
    let right: DuoSlot
    var body: some View {
        HStack(spacing: 22) { slot(left); slot(right) }.padding(.vertical, 4)
    }
    @ViewBuilder private func slot(_ s: DuoSlot) -> some View {
        VStack(spacing: 2) {
            if let hero = s.hero {
                HeroSprite(hero: hero, pose: s.pose)
            } else {
                RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(0.3)).frame(width: 52, height: 44)
            }
            if let score = s.score {
                Text("\(score)").font(.system(size: 28, weight: .semibold)).monospacedDigit().foregroundStyle(Ink.text)
            }
            Text(s.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(s.hero == nil ? Ink.soft : Ink.text)
        }
        .opacity(s.faded ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// A lobby row: a host's hero, name and map, or (hero nil) "Host a race".
struct LobbyRow: View {
    let hero: Hero?
    let name: String
    let detail: String
    let selected: Bool
    var body: some View {
        HStack(spacing: 8) {
            if let hero {
                HeroSprite(hero: hero, size: CGSize(width: 26, height: 22))
            } else {
                Text("＋").font(.system(size: 15)).foregroundStyle(Ink.amber).frame(width: 26, height: 22)
            }
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text).lineLimit(1)
            Spacer(minLength: 6)
            Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(Ink.soft).lineLimit(1)
        }
        .padding(.horizontal, 8).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(selected ? 0.12 : 0)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(selected ? 0.14 : 0), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RaceToast: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.text).lineLimit(1)
            .padding(.horizontal, 12).frame(height: 26)
            .glassEffect(.regular, in: Capsule())
    }
}

struct ResultBadge: View {
    let text: String
    let win: Bool
    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold)).foregroundStyle(win ? Ink.onAmber : Ink.text)
            .padding(.horizontal, 7).frame(height: 18)
            .background(win ? Ink.amber : .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Everything shown over the field while racing.
struct RaceOverlay: View {
    let model: IslandModel
    let screen: RaceScreen

    private var opponent: String { model.session?.opponent?.name ?? "" }
    private var opponentHero: Hero { model.raceHUD?.opponentHero ?? .pip }

    var body: some View {
        switch screen {
        case .explainer:
            RacePanel(keys: [Hint("space", "Continue"), Hint("esc", "Not now")]) {
                PanelTitle(RaceCopy.explainerTitle)
                PanelBody(RaceCopy.explainer(name: model.playerName))
            }
        case .denied:
            RacePanel(keys: [Hint("space", "Open Settings"), Hint("esc", "Leave")]) {
                PanelTitle(RaceCopy.deniedTitle)
                PanelBody(RaceCopy.deniedBody)
            }
        case .lobby(let hosts, let selection):
            RacePanel(keys: [Hint("↑↓", "Choose"), Hint("space", selection < hosts.count ? "Join" : "Host"),
                             Hint("N", "Name"), Hint("esc", "Leave")], width: .fitting) {
                PanelTitle("Nearby")
                VStack(spacing: 4) {
                    if hosts.isEmpty {
                        Text("Looking for races nearby…").font(.system(size: 12)).foregroundStyle(Ink.soft).frame(height: 30)
                    }
                    ForEach(Array(LobbyWindow.range(count: hosts.count, selection: selection)), id: \.self) { i in
                        LobbyRow(hero: Hero(rawValue: hosts[i].hero) ?? .pip, name: hosts[i].name,
                                 detail: RaceCopy.lobbyDetail(hosts[i]), selected: i == selection)
                    }
                    LobbyRow(hero: nil, name: "Host a race", detail: model.map.name, selected: selection == hosts.count)
                }
                .padding(.vertical, 4)
            }
        case .unreachable(let host):
            RacePanel(keys: [Hint("space", "Back to lobby"), Hint("esc", "Fold")]) {
                PanelTitle(RaceCopy.unreachableTitle(host))
                PanelBody(RaceCopy.unreachableBody(host))
            }
        case .match(let stage, let role):
            match(stage, role)
        }
    }

    @ViewBuilder private func match(_ stage: RaceStage, _ role: RaceRole) -> some View {
        switch stage {
        case .waiting:
            RacePanel(keys: [Hint("esc", "Cancel")]) {
                PanelTitle(RaceCopy.waitingTitle(role))
                if role == .host {
                    Duo(left: DuoSlot(hero: model.hero, label: "You"), right: DuoSlot(hero: nil, label: "—"))
                    PanelBody("Map: \(model.map.name). Anyone nearby can see this race.")
                }
            }
        case .ready:
            RacePanel(keys: role == .host ? [Hint("space", "Start"), Hint("esc", "Cancel")] : [Hint("esc", "Leave")]) {
                PanelTitle(RaceCopy.readyTitle(role, opponent: opponent))
                Duo(left: DuoSlot(hero: model.hero, label: "You"), right: DuoSlot(hero: opponentHero, label: opponent))
                PanelBody("\(RaceCopy.mapName(model.session?.map)) · same course for both of you")
            }
        case .countdown:
            CountdownBadge(number: model.hud.countdown ?? 3)
        case .racing:
            if let notice = model.raceNotice {
                RaceToast(text: notice)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }
        case .paused(let byMe):
            RacePanel(keys: byMe ? [Hint("P", "Resume"), Hint("esc", "Leave")] : [Hint("esc", "Leave")]) {
                PanelTitle(RaceCopy.pausedTitle(byMe: byMe, opponent: opponent))
                PanelBody(RaceCopy.pausedBody(byMe: byMe, opponent: opponent, pausesLeft: model.session?.pausesLeft ?? 0))
            }
        case .result(let outcome):
            RacePanel(keys: [Hint("space", model.rematchAsked ? "Waiting…" : "Rematch"), Hint("esc", "Leave")]) {
                ResultBadge(text: RaceCopy.outcome(outcome, opponent: opponent), win: outcome == .win)
                Duo(left: DuoSlot(hero: model.hero, label: "You", score: model.session?.myCrash?.score,
                                  faded: outcome == .lose, pose: outcome == .lose ? .crash : .wingUp),
                    right: DuoSlot(hero: opponentHero, label: opponent, score: model.session?.theirCrash?.score,
                                   faded: outcome == .win, pose: outcome == .win ? .crash : .wingUp))
            }
        case .over(let end):
            RacePanel(keys: [Hint("space", "Back to solo"), Hint("esc", "Fold")]) {
                PanelTitle(RaceCopy.endTitle(end, opponent: model.session?.opponent?.name))
                PanelBody(RaceCopy.endBody(end))
            }
        }
    }
}

/// The band's ears in a race. Lobby: "Race nearby" or "Your race", and a "local only" pill. Racing: the opponent's
/// dot, name and score on the left; your place and score on the right.
struct RaceEars: View {
    let screen: RaceScreen
    let hud: RaceHUD?
    let notchWidth: CGFloat
    let band: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            left
            Spacer(minLength: notchWidth + 16)
            right
        }
        .padding(.horizontal, 26)
        .frame(height: band)
        .accessibilityElement(children: .combine)
    }

    private var lobbyTitle: String? { Self.lobbyTitle(screen, hud: hud) }

    /// The left ear's words when the band shows the lobby ("local only" on the right), or nil when it shows the
    /// opponent's name and score. An end card before the opponent is known (a version mismatch, a full race) shows
    /// the lobby band rather than empty ears.
    static func lobbyTitle(_ screen: RaceScreen, hud: RaceHUD?) -> String? {
        switch screen {
        case .explainer, .denied, .lobby, .unreachable: "Race nearby"
        case .match(.waiting, .host), .match(.ready, .host): "Your race"
        case .match(.waiting, .guest), .match(.ready, .guest): "Race nearby"
        case .match(.over, _): hud == nil ? "Race nearby" : nil
        case .match: nil
        }
    }

    @ViewBuilder private var left: some View {
        if let title = lobbyTitle {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Ink.soft)
        } else if let hud {
            HStack(spacing: 6) {
                Circle().fill(Color(cgColor: Art.rgb(hud.opponentHero.palette.body))).frame(width: 7, height: 7)
                Text(hud.place == nil ? hud.opponentName : "\(hud.opponentName) \(hud.opponentScore)")
            }
            .font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(Ink.soft)
        }
    }

    @ViewBuilder private var right: some View {
        if lobbyTitle != nil {
            Text("local only").font(.system(size: 11)).foregroundStyle(Ink.soft)
                .padding(.horizontal, 8).frame(height: 18)
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        } else if let hud {
            HStack(spacing: 8) {
                if let place = hud.place {
                    Text(place).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6).frame(height: 18)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                Text(hud.place == nil ? "You" : "\(hud.score)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(Ink.text)
        }
    }
}
