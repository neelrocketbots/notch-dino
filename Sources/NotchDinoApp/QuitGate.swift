import Foundation

/// Decides how ⌘Q or Quit ends the app. With no race open it quits at once. Mid-race it says bye first and quits
/// once the bye has gone out, or after `timeout`, whichever comes first, so the other Mac hears "left the race"
/// instead of waiting 5 s for the heartbeat.
@MainActor public enum QuitGate {
    public enum Decision: Equatable, Sendable { case now, later }

    /// The longest a quit waits for the bye.
    public static let timeout = 0.3

    /// - Parameters:
    ///   - sendBye: sends the bye and calls its argument once it has gone out; returns false when no race link is
    ///     connected, so there is nothing to send.
    ///   - after: runs a closure after a delay in seconds.
    ///   - reply: told `true` exactly once, when the app may quit. Never called for `.now`.
    public static func begin(sendBye: (@escaping @MainActor () -> Void) -> Bool,
                             after: (Double, @escaping @MainActor () -> Void) -> Void,
                             reply: @escaping @MainActor (Bool) -> Void) -> Decision {
        let once = Once()
        let finish: @MainActor () -> Void = { if once.fire() { reply(true) } }
        guard sendBye(finish) else { return .now }
        after(timeout, finish)
        return .later
    }

    @MainActor private final class Once {
        private var fired = false
        func fire() -> Bool {
            defer { fired = true }
            return !fired
        }
    }
}
