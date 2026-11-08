import Foundation
import RaceCore

public enum RaceLinkFailure: Equatable, Sendable { case denied, lost }
public enum RaceLinkState: Equatable, Sendable { case connecting, ready, failed(RaceLinkFailure) }

/// One connection to one other Mac. Messages and state changes arrive on the main actor, in order. `close()` lets
/// anything already sent go out first.
@MainActor public protocol RaceLink: AnyObject {
    var onMessage: (@MainActor (RaceMessage) -> Void)? { get set }
    var onState: (@MainActor (RaceLinkState) -> Void)? { get set }
    func send(_ message: RaceMessage)
    func close()
}

/// A race someone nearby is hosting, read from their Bonjour TXT record.
public struct RaceHost: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var hero: String
    public var map: String
    public init(id: String, name: String, hero: String, map: String) {
        self.id = id; self.name = name; self.hero = hero; self.map = map
    }
}

/// Finds races and opens links. Nothing listens or browses until the player asks to race.
@MainActor public protocol RaceNetwork: AnyObject {
    /// Reports the hosts nearby whenever the list changes, or that Local Network access is turned off.
    func browse(onHosts: @escaping @MainActor ([RaceHost]) -> Void, onDenied: @escaping @MainActor () -> Void)
    func stopBrowsing()
    /// Advertises a race on `map` and waits for one guest.
    func host(as me: RacePlayer, map: String) -> RaceLink
    /// Connects to a host from the last browse; nil if it has gone.
    func join(_ host: RaceHost) -> RaceLink?
}
