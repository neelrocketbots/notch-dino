import NotchKit
import RunnerCore

public enum IslandEvent: Equatable, Sendable { case clickNotch, hotKey, escape, lostKey, autoPause, flapKey, clickField, pauseKey }
public enum IslandCommand: Equatable, Sendable { case open, fold, pauseGame, flap, newGameAndFlap }

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
        case .flapKey, .clickField: return (true, phase == .crashed ? [.newGameAndFlap] : [.flap])
        case .pauseKey:
            switch phase {
            case .running: return (true, [.pauseGame])
            case .paused: return (true, [.flap])
            case .idle, .countdown, .crashed: return (true, [])
            }
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
    public static let space: UInt16 = 49, up: UInt16 = 126, escape: UInt16 = 53, q: UInt16 = 12, p: UInt16 = 35

    public static func action(keyCode: UInt16, modifiers: KeyModifiers, isOpen: Bool) -> KeyAction? {
        guard isOpen else { return nil }
        switch keyCode {
        case space, up:
            // Only a bare press flaps, so the hot-key (control-option-space) never starts a run.
            return modifiers.isDisjoint(with: [.command, .control, .option]) ? .island(.flapKey) : nil
        case escape: return .island(.escape)
        case q: return modifiers.contains(.command) ? .quit : nil
        case p:
            // Same rule as Space: P with control, option or command passes through to the frontmost app.
            return modifiers.isDisjoint(with: [.command, .control, .option]) ? .island(.pauseKey) : nil
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
