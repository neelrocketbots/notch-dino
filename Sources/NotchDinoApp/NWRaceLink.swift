import Foundation
import Network
import RaceCore

/// The Bonjour service a race is advertised as. The same type is in Info.plist's NSBonjourServices.
public enum RaceBonjour {
    public static let type = "_notchdino._tcp"

    public static func txt(name: String, hero: String, map: String) -> [String: String] {
        ["name": name, "hero": hero, "map": map, "proto": "\(RaceMessage.protocolVersion)"]
    }

    /// A lobby row from a TXT record; nil when it isn't a race. A host on another protocol is still listed, so
    /// joining it shows "Update Notch Dino to race".
    public static func host(id: String, txt: [String: String]) -> RaceHost? {
        guard let name = txt["name"], let hero = txt["hero"], let map = txt["map"],
              RaceName.isToken(hero), RaceName.isToken(map) else { return nil }
        return RaceHost(id: id, name: RaceName.clean(name), hero: hero, map: map)
    }

    /// TCP, over infrastructure Wi-Fi or Ethernet, or peer-to-peer Wi-Fi with no router.
    public static func parameters() -> NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = true
        return p
    }

    /// Local Network access is off: Bonjour reports kDNSServiceErr_PolicyDenied (−65570).
    public static func isDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == -65570 }
        return false
    }

    /// What a listener state means for a host. A wait that isn't a Local Network denial (no network yet, Wi-Fi
    /// switching) is transient: the listener starts by itself when it can, so hosting carries on (nil). A denial
    /// ends hosting with the denied screen; any other failure, as a lost link.
    public static func listenerFailure(_ state: NWListener.State) -> RaceLinkFailure? {
        switch state {
        case .waiting(let error): isDenied(error) ? .denied : nil
        case .failed(let error): isDenied(error) ? .denied : .lost
        case .setup, .ready, .cancelled: nil
        @unknown default: nil
        }
    }
}

/// One race connection over Network.framework. All callbacks run on the main queue.
@MainActor public final class NWRaceLink: RaceLink {
    public var onMessage: (@MainActor (RaceMessage) -> Void)?
    public var onState: (@MainActor (RaceLinkState) -> Void)?
    private var listener: NWListener?
    private var connection: NWConnection?
    private var reader = FrameReader()
    private var closed = false

    /// Host: advertise this race and accept one guest.
    public init(hosting me: RacePlayer, map: String) {
        do {
            let l = try NWListener(using: RaceBonjour.parameters())
            l.service = NWListener.Service(name: me.name, type: RaceBonjour.type, domain: nil,
                                           txtRecord: NWTXTRecord(RaceBonjour.txt(name: me.name, hero: me.hero, map: map)))
            l.stateUpdateHandler = { [weak self] state in MainActor.assumeIsolated { self?.listenerChanged(state) } }
            l.newConnectionHandler = { [weak self] c in MainActor.assumeIsolated { self?.accept(c) } }
            listener = l
            l.start(queue: .main)
        } catch {
            Task { @MainActor [weak self] in self?.fail(.lost) }
        }
    }

    /// Guest: connect to a host found by `NWRaceNetwork`.
    public init(joining endpoint: NWEndpoint) {
        use(NWConnection(to: endpoint, using: RaceBonjour.parameters()))
    }

    public func send(_ message: RaceMessage) {
        guard !closed else { return }
        connection?.send(content: RaceFrame.encode(message), completion: .idempotent)
    }

    /// Stops advertising, lets anything already sent go out, then closes.
    public func close() {
        guard !closed else { return }
        closed = true
        listener?.cancel()
        listener = nil
        guard let c = connection else { return }
        connection = nil
        c.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in c.cancel() })
    }

    private func listenerChanged(_ state: NWListener.State) {
        if let failure = RaceBonjour.listenerFailure(state) { fail(failure) }
    }

    private func accept(_ c: NWConnection) {
        guard connection == nil, !closed else { refuseFull(c); return }
        listener?.service = nil   // full: stop advertising
        use(c)
    }

    /// A second guest: tell it the race is full and hang up.
    private func refuseFull(_ c: NWConnection) {
        c.start(queue: .main)
        c.send(content: RaceFrame.encode(.refuse(.full)), completion: .contentProcessed { _ in c.cancel() })
    }

    private func use(_ c: NWConnection) {
        connection = c
        c.stateUpdateHandler = { [weak self] state in MainActor.assumeIsolated { self?.connectionChanged(state) } }
        c.start(queue: .main)
        receive()
    }

    private func connectionChanged(_ state: NWConnection.State) {
        switch state {
        case .ready: onState?(.ready)
        case .waiting(let error): if RaceBonjour.isDenied(error) { fail(.denied) }
        case .failed: fail(.lost)
        case .cancelled: fail(.lost)
        case .setup, .preparing: break
        @unknown default: break
        }
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                if let data, !data.isEmpty { self.deliver(data) }
                if self.closed { return }
                if isComplete || error != nil { self.fail(.lost) } else { self.receive() }
            }
        }
    }

    private func deliver(_ data: Data) {
        do {
            for frame in try reader.append(data) where !closed {
                if let m = RaceMessage(json: frame) { onMessage?(m) }
            }
        } catch {
            fail(.lost)   // a frame over 1 KB: hang up
        }
    }

    private func fail(_ failure: RaceLinkFailure) {
        guard !closed else { return }
        closed = true
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
        onState?(.failed(failure))
    }
}

/// Bonjour browsing plus host and guest links. Creates nothing until `browse` or `host` is called.
@MainActor public final class NWRaceNetwork: RaceNetwork {
    private var browser: NWBrowser?
    private var endpoints: [String: NWEndpoint] = [:]
    private var onHosts: (@MainActor ([RaceHost]) -> Void)?
    private var onDenied: (@MainActor () -> Void)?

    public init() {}

    public func browse(onHosts: @escaping @MainActor ([RaceHost]) -> Void, onDenied: @escaping @MainActor () -> Void) {
        stopBrowsing()
        self.onHosts = onHosts
        self.onDenied = onDenied
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: RaceBonjour.type, domain: nil), using: RaceBonjour.parameters())
        b.browseResultsChangedHandler = { [weak self] results, _ in MainActor.assumeIsolated { self?.found(results) } }
        b.stateUpdateHandler = { [weak self] state in MainActor.assumeIsolated { self?.browserChanged(state) } }
        browser = b
        b.start(queue: .main)
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        onHosts = nil
        onDenied = nil
    }

    public func host(as me: RacePlayer, map: String) -> RaceLink {
        stopBrowsing()
        return NWRaceLink(hosting: me, map: map)
    }

    public func join(_ host: RaceHost) -> RaceLink? {
        guard let endpoint = endpoints[host.id] else { return nil }
        stopBrowsing()
        return NWRaceLink(joining: endpoint)
    }

    private func found(_ results: Set<NWBrowser.Result>) {
        var hosts: [RaceHost] = []
        var seen: [String: NWEndpoint] = [:]
        for r in results {
            guard case .bonjour(let record) = r.metadata else { continue }
            let id = "\(r.endpoint)"
            guard let host = RaceBonjour.host(id: id, txt: record.dictionary) else { continue }
            hosts.append(host)
            seen[id] = r.endpoint
        }
        endpoints = seen
        onHosts?(hosts.sorted { ($0.name, $0.id) < ($1.name, $1.id) })
    }

    private func browserChanged(_ state: NWBrowser.State) {
        switch state {
        case .waiting(let error), .failed(let error): if RaceBonjour.isDenied(error) { onDenied?() }
        default: break
        }
    }
}
