import Foundation
import RaceCore
import RunnerCore

/// What the island shows while racing. Nil on the model means solo play.
public enum RaceScreen: Equatable, Sendable {
    /// First time only: what racing does, before macOS asks for Local Network access.
    case explainer
    /// Local Network access is off.
    case denied
    /// Races nearby; `selection == hosts.count` is the "Host a race" row.
    case lobby(hosts: [RaceHost], selection: Int)
    case match(RaceStage, RaceRole)
    /// A join that never connected within `RaceTimeouts.connect` (or whose link failed first): "Couldn't reach <host>".
    /// Space goes back to the lobby; Esc folds and goes back to solo.
    case unreachable(host: String)
}

/// Limits the app keeps on top of the session's own.
public enum RaceTimeouts {
    /// Seconds a joined link may take to connect before the attempt ends.
    public static let connect = 5.0
}

/// Copy the model decides on; the views show it.
public enum RaceText {
    /// The end card for a join that never connected.
    public static func unreachable(_ host: String) -> String { "Couldn't reach \(host)" }
}

public enum RaceAction: Equatable, Sendable {
    case explainerContinue, openPrivacySettings, choose(delta: Int), pick, askName
    case start, flap, pause, resume, rematch, leave, backToSolo, fold
    /// Space on "Couldn't reach <host>".
    case backToLobby
}

/// What a key or click does on each race screen (spec §3, §6). Esc while flying folds (which pauses the race); Esc on
/// a race panel is Leave.
public enum RaceKeys {
    public static func action(_ screen: RaceScreen, event: IslandEvent) -> RaceAction? {
        switch event {
        case .hotKey, .lostKey, .autoPause: return .fold
        case .clickNotch: return nil
        default: break
        }
        switch screen {
        case .explainer:
            return event == .flapKey ? .explainerContinue : event == .escape ? .leave : nil
        case .denied:
            return event == .flapKey ? .openPrivacySettings : event == .escape ? .leave : nil
        case .lobby:
            switch event {
            case .upKey: return .choose(delta: -1)
            case .downKey: return .choose(delta: 1)
            case .flapKey: return .pick
            case .nameKey: return .askName
            case .escape: return .leave
            default: return nil
            }
        case .unreachable:
            return event == .flapKey ? .backToLobby : event == .escape ? .fold : nil
        case .match(let stage, let role):
            switch stage {
            case .waiting:
                return event == .escape ? .leave : nil
            case .ready:
                if event == .escape { return .leave }
                return event == .flapKey && role == .host ? .start : nil
            case .countdown:
                return event == .escape ? .fold : nil
            case .racing:
                switch event {
                case .flapKey, .upKey, .clickField: return .flap
                case .pauseKey: return .pause
                case .escape: return .fold
                default: return nil
                }
            case .paused(let byMe):
                if event == .escape { return .leave }
                return byMe && (event == .pauseKey || event == .flapKey) ? .resume : nil
            case .result:
                return event == .flapKey ? .rematch : event == .escape ? .leave : nil
            case .over:
                return event == .flapKey ? .backToSolo : event == .escape ? .fold : nil
            }
        }
    }
}

/// What the band's ears show in a race: the opponent on the left, you and your place on the right.
public struct RaceHUD: Equatable, Sendable {
    public var opponentName: String
    public var opponentHero: Hero
    public var opponentScore: Int
    public var score: Int
    /// "1st", "2nd" or "tied"; nil before anyone has scored.
    public var place: String?

    public static func make(session: RaceSession, game: GameState) -> RaceHUD? {
        guard let o = session.opponent else { return nil }
        let racing = session.ghost != nil
        let theirs = session.theirCrash?.score ?? session.ghost?.state.score ?? 0
        let mine = racing ? game.score : 0
        let place: String? = !racing || (mine == 0 && theirs == 0) ? nil
            : mine > theirs ? "1st" : mine < theirs ? "2nd" : "tied"
        return RaceHUD(opponentName: o.name, opponentHero: Hero(rawValue: o.hero) ?? .pip,
                       opponentScore: theirs, score: mine, place: place)
    }
}
