import NotchKit
import RunnerCore

public enum IslandEvent: Equatable, Sendable {
    case clickNotch, hotKey, escape, lostKey, autoPause, flapKey, clickField, pauseKey
    case raceKey, nameKey, upKey, downKey
}
public enum IslandCommand: Equatable, Sendable { case open, fold, pauseGame, flap, newGameAndFlap, openRace }

/// The island's policy as a pure function: what an event does, given whether the island is open and the game's phase.
public enum IslandLogic {
    public static func reduce(isOpen: Bool, phase: Phase, event: IslandEvent) -> (isOpen: Bool, commands: [IslandCommand]) {
        guard isOpen else {
            switch event {
            case .clickNotch, .hotKey: return (true, [.open])
            default: return (false, [])
            }
        }
        switch event {
        case .hotKey, .escape, .lostKey, .autoPause: return (false, [.pauseGame, .fold])
        case .clickNotch: return (true, [])
        case .flapKey, .clickField, .upKey: return (true, phase == .crashed ? [.newGameAndFlap] : [.flap])
        case .pauseKey:
            switch phase {
            case .running: return (true, [.pauseGame])
            case .paused: return (true, [.flap])
            case .idle, .countdown, .crashed: return (true, [])
            }
        case .raceKey: return (true, phase == .idle ? [.openRace] : [])
        case .nameKey, .downKey: return (true, [])
        }
    }
}

public enum KeyAction: Equatable, Sendable { case island(IslandEvent), quit }

/// The modifiers the key router cares about (Shift and Caps Lock are deliberately absent from decisions).
public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)
}

/// Keys the open island consumes. While folded nothing is consumed, so typing reaches the frontmost app.
public enum KeyRouter {
    public static let space: UInt16 = 49, up: UInt16 = 126, down: UInt16 = 125, escape: UInt16 = 53, q: UInt16 = 12
    public static let p: UInt16 = 35, r: UInt16 = 15, n: UInt16 = 45

    public static func action(keyCode: UInt16, modifiers: KeyModifiers, isOpen: Bool) -> KeyAction? {
        guard isOpen else { return nil }
        // Only a bare (or shifted) press counts, so the hot-key (control-option-space) never starts a run, and P, R, N
        // and the arrows with control, option or command pass through to the frontmost app.
        let bare = modifiers.isDisjoint(with: [.command, .control, .option])
        switch keyCode {
        case space: return bare ? .island(.flapKey) : nil
        case up: return bare ? .island(.upKey) : nil
        case down: return bare ? .island(.downKey) : nil
        case escape: return .island(.escape)
        case q: return modifiers.contains(.command) ? .quit : nil
        case p: return bare ? .island(.pauseKey) : nil
        case r: return bare ? .island(.raceKey) : nil
        case n: return bare ? .island(.nameKey) : nil
        default: return nil
        }
    }
}

/// Where the island lives: the built-in notched display, else the main display, else any.
public enum DisplayPicker {
    public static func pick(_ displays: [NotchDisplay]) -> NotchDisplay? {
        displays.first { $0.isBuiltIn && $0.kind == .notch } ?? displays.first { $0.isMain } ?? displays.first
    }
}
