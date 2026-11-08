import Foundation
import RaceCore
import RunnerCore

/// An in-memory pair of links for tests, on a clock the test moves with `pump(to:)`. Every message goes through the
/// real framing and JSON. Each is delayed by a seeded random amount within `delay`. Each side delivers in the order
/// it sent, as TCP does, so the jitter only reorders deliveries across the two directions. Closing delivers what was
/// already sent, then tells the other end the link was lost.
@MainActor public final class LoopbackRaceLink: RaceLink {
    public var onMessage: (@MainActor (RaceMessage) -> Void)?
    public var onState: (@MainActor (RaceLinkState) -> Void)?
    public private(set) var isClosed = false
    /// Every message this end sent.
    public private(set) var sent: [RaceMessage] = []

    private enum Packet { case bytes(Data), fin }
    private weak var peer: LoopbackRaceLink?
    private let delay: ClosedRange<Double>
    private var rng: SeededRandom
    private var now = 0.0
    private var outbox: [(at: Double, packet: Packet)] = []
    private var reader = FrameReader()
    private var sentWaiters: [@MainActor () -> Void] = []

    private init(delay: ClosedRange<Double>, seed: UInt64) {
        self.delay = delay
        rng = SeededRandom(seed: seed)
    }

    /// Two connected ends. Hold both: each refers to the other weakly.
    public static func pair(delay: ClosedRange<Double> = 0...0, seed: UInt64 = 1) -> (LoopbackRaceLink, LoopbackRaceLink) {
        let a = LoopbackRaceLink(delay: delay, seed: seed)
        let b = LoopbackRaceLink(delay: delay, seed: seed &+ 1)
        a.peer = b
        b.peer = a
        return (a, b)
    }

    /// Both ends become ready, as when a TCP connection is established.
    public func connect() {
        onState?(.ready)
        peer?.onState?(.ready)
    }

    public func send(_ message: RaceMessage) {
        guard !isClosed else { return }
        sent.append(message)
        enqueue(.bytes(RaceFrame.encode(message)))
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        enqueue(.fin)
    }

    /// Called once the outbox is empty: everything sent so far has been handed to the other end.
    public func afterSending(_ done: @escaping @MainActor () -> Void) {
        if outbox.isEmpty { done() } else { sentWaiters.append(done) }
    }

    /// Moves this end's clock to `time` and hands the other end everything due.
    public func pump(to time: Double) {
        now = time
        while let first = outbox.first, first.at <= time {
            outbox.removeFirst()
            switch first.packet {
            case .bytes(let data): peer?.receive(data)
            case .fin: peer?.peerClosed()
            }
        }
        if outbox.isEmpty, !sentWaiters.isEmpty {
            let waiters = sentWaiters
            sentWaiters = []
            for w in waiters { w() }
        }
    }

    private func enqueue(_ packet: Packet) {
        let jitter = delay.lowerBound + rng.unit() * (delay.upperBound - delay.lowerBound)
        outbox.append((max(outbox.last?.at ?? 0, now + jitter), packet))
    }

    private func receive(_ data: Data) {
        guard !isClosed else { return }
        do {
            for frame in try reader.append(data) where !isClosed {
                if let m = RaceMessage(json: frame) { onMessage?(m) }
            }
        } catch {
            isClosed = true
            onState?(.failed(.lost))
        }
    }

    private func peerClosed() {
        guard !isClosed else { return }
        isClosed = true
        onState?(.failed(.lost))
    }
}

/// A `RaceNetwork` made of loopback links, for tests. `links` are this Mac's ends, `remotes` the far ends a test
/// plays the other Mac through.
@MainActor public final class LoopbackRaceNetwork: RaceNetwork {
    public var hosts: [RaceHost] = []
    public var denied = false
    public private(set) var isBrowsing = false
    public private(set) var joined: [RaceHost] = []
    public private(set) var hostedMaps: [String] = []
    public private(set) var links: [LoopbackRaceLink] = []
    public private(set) var remotes: [LoopbackRaceLink] = []

    public init() {}

    public func browse(onHosts: @escaping @MainActor ([RaceHost]) -> Void, onDenied: @escaping @MainActor () -> Void) {
        isBrowsing = true
        if denied { onDenied() } else { onHosts(hosts) }
    }

    public func stopBrowsing() { isBrowsing = false }

    public func host(as me: RacePlayer, map: String) -> RaceLink {
        isBrowsing = false
        hostedMaps.append(map)
        return makeLink()
    }

    public func join(_ host: RaceHost) -> RaceLink? {
        isBrowsing = false
        joined.append(host)
        return makeLink()
    }

    private func makeLink() -> RaceLink {
        let (mine, theirs) = LoopbackRaceLink.pair()
        links.append(mine)
        remotes.append(theirs)
        return mine
    }
}
