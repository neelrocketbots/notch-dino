import NotchKit
import RunnerCore

public enum IslandEvent: Equatable, Sendable { case clickNotch, hotKey, escape, lostKey, autoPause, flapKey, clickField }
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
        }
    }

    public static func resizeAllowed(_ phase: Phase) -> Bool { phase == .idle || phase == .paused }
}

public enum KeyAction: Equatable, Sendable { case island(IslandEvent), quit }

/// Keys the open island consumes. While folded nothing is consumed, so typing reaches the frontmost app.
public enum KeyRouter {
    public static let space: UInt16 = 49, up: UInt16 = 126, escape: UInt16 = 53, q: UInt16 = 12

    public static func action(keyCode: UInt16, command: Bool, isOpen: Bool) -> KeyAction? {
        guard isOpen else { return nil }
        switch keyCode {
        case space, up: return command ? nil : .island(.flapKey)
        case escape: return .island(.escape)
        case q: return command ? .quit : nil
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
