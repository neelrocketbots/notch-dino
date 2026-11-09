import Foundation
import NotchKit
import RaceCore
import RunnerCore
import Testing
@testable import NotchDinoApp

@MainActor final class TestClock { var now = 0.0 }
@MainActor final class Inbox { var messages: [RaceMessage] = [] }

/// A model on a loopback network and a test clock. `explained` skips the first-time explainer.
@MainActor func raceModel(defaults: UserDefaults = freshDefaults(), explained: Bool = true)
    -> (model: IslandModel, net: LoopbackRaceNetwork, clock: TestClock) {
    let store = RaceStore(defaults: defaults, fullName: { "Neel Singh" })
    if explained { store.setExplained() }
    let net = LoopbackRaceNetwork()
    let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 185, height: 32),
                               isMain: true, isBuiltIn: true, menuBarHeight: 32)
    let m = IslandModel(display: display, best: BestScoreStore(defaults: defaults), layout: LayoutStore(defaults: defaults),
                        looks: LookStore(defaults: defaults), race: store, network: net, seed: 1)
    let clock = TestClock()
    m.clock = { clock.now }
    return (m, net, clock)
}

/// Delivers everything due on every link, both ways, a few rounds (a reply goes out on the next round).
@MainActor func pump(_ net: LoopbackRaceNetwork, to t: Double) {
    for _ in 0..<3 { for l in net.links + net.remotes { l.pump(to: t) } }
}

/// The far end of a link, played by the test: it records what it receives and answers pings, as a real Mac would.
@MainActor func farEnd(_ link: LoopbackRaceLink) -> Inbox {
    let inbox = Inbox()
    link.onMessage = { [unowned link] m in
        inbox.messages.append(m)
        if case .ping(let t) = m { link.send(.pong(t: t)) }
    }
    return inbox
}

/// Opens the island and hosts a race (nobody else is nearby, so the only row is "Host a race"); a guest played by
/// the test joins.
@MainActor func hostedRace(defaults: UserDefaults = freshDefaults())
    -> (model: IslandModel, net: LoopbackRaceNetwork, clock: TestClock, guest: LoopbackRaceLink, inbox: Inbox) {
    let (m, net, clock) = raceModel(defaults: defaults)
    m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)
    let guest = net.remotes[0]
    let inbox = farEnd(guest)
    net.links[0].connect()
    guest.send(.hello(proto: RaceMessage.protocolVersion, rules: Params.rulesVersion, name: "Ana", hero: "moss"))
    pump(net, to: 0)
    return (m, net, clock, guest, inbox)
}

/// Runs the scene at 60 fps for `seconds`, moving the clock and the links with it.
@MainActor func play(_ m: IslandModel, _ net: LoopbackRaceNetwork, _ clock: TestClock, seconds: Double) {
    let end = clock.now + seconds
    while clock.now < end {
        clock.now += 1.0 / 60
        pump(net, to: clock.now)
        _ = m.sceneTick(elapsed: 1.0 / 60)
    }
}

/// Hosted, started and flying.
@MainActor func racing(defaults: UserDefaults = freshDefaults())
    -> (model: IslandModel, net: LoopbackRaceNetwork, clock: TestClock, guest: LoopbackRaceLink, inbox: Inbox) {
    let r = hostedRace(defaults: defaults)
    r.model.handle(.flapKey)          // Space: start
    play(r.model, r.net, r.clock, seconds: 2.3)
    return r
}

@Suite struct RaceModelTests {
    @MainActor @Test func rOnIdleOpensTheExplainerOnceThenTheLobby() {
        let d = freshDefaults()
        let (m, net, _) = raceModel(defaults: d, explained: false)
        m.handle(.hotKey); m.handle(.raceKey)
        #expect(m.race == .explainer && !net.isBrowsing && m.panel == nil)
        m.handle(.flapKey)
        #expect(m.race == .lobby(hosts: [], selection: 0) && net.isBrowsing)
        m.handle(.escape)
        #expect(m.race == nil && !net.isBrowsing)
        let (again, _, _) = raceModel(defaults: d, explained: false)
        again.handle(.hotKey); again.handle(.raceKey)
        #expect(again.race == .lobby(hosts: [], selection: 0))
    }

    @MainActor @Test func notNowOnTheExplainerIsBackToSolo() {
        let (m, net, _) = raceModel(explained: false)
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.escape)
        #expect(m.race == nil && !net.isBrowsing && net.links.isEmpty)
    }

    @MainActor @Test func rDoesNothingMidRun() {
        let (m, net, _) = raceModel()
        m.handle(.hotKey); m.handle(.flapKey)
        m.handle(.raceKey)
        #expect(m.race == nil && !net.isBrowsing)
    }

    @MainActor @Test func raceNearbyFromTheMenuOpensTheIslandIntoTheLobby() {
        let (m, net, _) = raceModel()
        m.openRace()
        #expect(m.isOpen && m.race == .lobby(hosts: [], selection: 0) && net.isBrowsing)
    }

    @MainActor @Test func theLobbyListsHostsAndJoinsTheChosenOne() {
        let (m, net, _) = raceModel()
        net.hosts = [RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier"),
                     RaceHost(id: "b", name: "Sam", hero: "nova", map: "grove")]
        m.handle(.hotKey); m.handle(.raceKey)
        #expect(m.race == .lobby(hosts: net.hosts, selection: 0))
        m.handle(.downKey); m.handle(.downKey); m.handle(.downKey)
        #expect(m.race == .lobby(hosts: net.hosts, selection: 2))   // "Host a race"
        m.handle(.upKey)
        #expect(m.race == .lobby(hosts: net.hosts, selection: 1))
        m.handle(.flapKey)
        #expect(m.race == .match(.waiting, .guest) && net.joined == [net.hosts[1]] && !net.isBrowsing)
    }

    @MainActor @Test func nInTheLobbyAsksForANameAndTheNameIsCleaned() {
        let (m, _, _) = raceModel()
        var asked = 0
        m.onAskName = { asked += 1 }
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.nameKey)
        #expect(asked == 1)
        m.setPlayerName("  Neelakantan Singh ")
        #expect(m.playerName == "Neelakantan")
    }

    @MainActor @Test func deniedLocalNetworkShowsHowToTurnItOn() {
        let (m, net, _) = raceModel()
        net.denied = true
        var opened = 0
        m.onOpenPrivacy = { opened += 1 }
        m.handle(.hotKey); m.handle(.raceKey)
        #expect(m.race == .denied)
        m.handle(.flapKey)
        #expect(opened == 1)
        m.handle(.escape)
        #expect(m.race == nil)
    }

    @MainActor @Test func aLinkDeniedWhileHostingShowsTheDeniedScreen() {
        let (m, net, _) = raceModel()
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)
        net.links[0].onState?(.failed(.denied))
        #expect(m.race == .denied && m.session == nil)
    }

    @MainActor @Test func hostingAGuestThenStartingAndRacing() {
        let (m, net, clock, _, inbox) = hostedRace()
        #expect(m.race == .match(.ready, .host) && m.session?.opponent?.name == "Ana")
        #expect(inbox.messages.contains(.welcome(name: "Neel", hero: "pip", map: "volcano", width: m.soloWorld.width)))
        m.handle(.flapKey)
        #expect(m.race == .match(.countdown, .host) && m.game.phase == .countdown(remaining: Params.countdownSteps))
        pump(net, to: clock.now)
        #expect(inbox.messages.contains { if case .start = $0 { true } else { false } })
        play(m, net, clock, seconds: 2.2)
        #expect(m.race == .match(.racing, .host) && m.game.phase == .running)
        #expect(m.raceHUD?.opponentName == "Ana" && m.raceHUD?.opponentHero == .moss)
        m.handle(.flapKey)
        pump(net, to: clock.now)
        #expect(inbox.messages.contains(.flap(step: m.game.step)))
    }

    @MainActor @Test func frameGapDuringARaceBecomesARacePause() {
        let (m, net, clock, _, inbox) = racing()
        let step = m.game.step
        _ = m.sceneTick(elapsed: 0.3)
        #expect(m.game.phase == .paused && m.session?.stage == .paused(byMe: true))
        pump(net, to: clock.now)
        #expect(inbox.messages.contains(.pause(atStep: step)))
    }

    @MainActor @Test func pPausesTheRaceInPlaceAndPResumesIt() {
        let (m, net, clock, _, inbox) = racing()
        m.handle(.pauseKey)
        #expect(m.isOpen && m.race == .match(.paused(byMe: true), .host))
        play(m, net, clock, seconds: 0.3)
        #expect(m.game.phase == .paused)
        m.handle(.pauseKey)
        #expect(m.race == .match(.countdown, .host))
        pump(net, to: clock.now)
        #expect(inbox.messages.contains(.resume(inMs: 2_100)))
    }

    @MainActor @Test func theOtherPlayersPauseFreezesUsAndOnlyTheyResume() {
        let (m, net, clock, guest, _) = racing()
        guest.send(.pause(atStep: m.game.step + Params.pauseLeadSteps))
        pump(net, to: clock.now)
        #expect(m.race == .match(.paused(byMe: false), .host))
        m.handle(.pauseKey); m.handle(.flapKey)
        #expect(m.race == .match(.paused(byMe: false), .host))
        play(m, net, clock, seconds: 0.3)
        #expect(m.game.phase == .paused)
    }

    @MainActor @Test func escWhileFlyingFoldsAndPausesThenEscOnThePanelLeaves() {
        let (m, net, clock, _, inbox) = racing()
        m.handle(.escape)
        #expect(!m.isOpen && m.race == .match(.paused(byMe: true), .host) && m.game.phase == .paused)
        m.handle(.hotKey)
        #expect(m.isOpen && m.race == .match(.paused(byMe: true), .host))
        m.handle(.escape)
        pump(net, to: clock.now)
        #expect(m.race == .match(.over(.youLeft), .host) && inbox.messages.contains(.bye(.left)))
        m.handle(.flapKey)   // Back to solo
        #expect(m.race == nil && m.session == nil && m.game.phase == .idle)
    }

    @MainActor @Test func theHeartbeatKeepsGoingWhileFolded() {
        let (m, net, clock, _, inbox) = racing()
        m.handle(.escape)
        let before = inbox.messages.filter { if case .ping = $0 { true } else { false } }.count
        clock.now += 1.5
        m.raceInput(.tick(step: m.game.step, phase: m.game.phase))   // what the race timer does while folded
        pump(net, to: clock.now)
        #expect(inbox.messages.filter { if case .ping = $0 { true } else { false } }.count > before)
    }

    @MainActor @Test func raceScoresNeverTouchTheSoloBest() {
        let d = freshDefaults()
        let (m, net, clock, _, inbox) = racing(defaults: d)
        m.game.score = 40
        m.game.pipY = Params.ground
        _ = m.sceneTick(elapsed: 1.0 / 60)
        #expect(m.game.phase == .crashed && BestScoreStore(defaults: d).load() == 0)
        pump(net, to: clock.now)
        #expect(inbox.messages.contains(.crashed(step: m.game.crashStep!, score: 40)))
    }

    @MainActor @Test func aDisplayChangeEndsTheMatch() {
        let (m, net, clock, _, inbox) = racing()
        m.rehome(displays: [m.display!])
        pump(net, to: clock.now)
        #expect(m.race == nil && m.session == nil && inbox.messages.contains(.bye(.left)))
    }

    @MainActor @Test func quittingSaysByeAndReportsWhenItHasGoneOut() {
        let (m, net, clock, _, inbox) = hostedRace()
        var gone = false
        let saying = m.prepareToQuit(then: { gone = true })
        #expect(saying && !gone)
        pump(net, to: clock.now)
        #expect(inbox.messages.contains(.bye(.quit)) && gone)
    }

    @MainActor @Test func quittingWithNoRaceHasNothingToSend() {
        let (m, _, _) = raceModel()
        var gone = false
        let solo = m.prepareToQuit(then: { gone = true })
        m.handle(.hotKey); m.handle(.raceKey)
        let lobby = m.prepareToQuit(then: { gone = true })
        #expect(!solo && m.race != nil && !lobby && !gone)
    }

    @MainActor @Test func theOpponentLeavingShowsTheLeftCard() {
        let (m, net, clock, guest, _) = racing()
        guest.send(.bye(.left))
        pump(net, to: clock.now)
        #expect(m.race == .match(.over(.opponentLeft), .host))
    }

    @MainActor @Test func aGuestRacesTheHostsMapAndWorldWithoutChangingItsOwn() {
        let d = freshDefaults()
        let (m, net, clock) = raceModel(defaults: d)
        net.hosts = [RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")]
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)
        let host = net.remotes[0]
        let inbox = farEnd(host)
        net.links[0].connect()
        pump(net, to: clock.now)
        #expect(inbox.messages.first == .hello(proto: 1, rules: Params.rulesVersion, name: "Neel", hero: "pip"))
        host.send(.welcome(name: "Ana", hero: "moss", map: "glacier", width: 400))
        pump(net, to: clock.now)
        #expect(m.race == .match(.ready, .guest) && m.scene.map == .glacier)
        #expect(m.map == .volcano && LookStore(defaults: d).map() == .volcano)
        host.send(.start(seed: 77, inMs: 2_100))
        pump(net, to: clock.now)
        #expect(m.game.world.width == 400 && m.race == .match(.countdown, .guest))
        m.closeRace()
        #expect(m.scene.map == .volcano && m.game.world == m.soloWorld && m.race == nil)
    }

    // MARK: Ruling 1: a guest's connect timeout

    /// Lobby with Ana listed, then Space joins her.
    @MainActor private func joining() -> (model: IslandModel, net: LoopbackRaceNetwork, clock: TestClock) {
        let (m, net, clock) = raceModel()
        net.hosts = [RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")]
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)
        return (m, net, clock)
    }

    @MainActor @Test func aJoinThatIsNotConnectedIn5SecondsCouldNotReachTheHost() {
        let (m, net, clock) = joining()
        #expect(m.race == .match(.waiting, .guest))
        clock.now = RaceTimeouts.connect - 0.01
        m.raceInput(.tick(step: m.game.step, phase: m.game.phase))
        #expect(m.race == .match(.waiting, .guest) && m.session != nil)
        clock.now = RaceTimeouts.connect
        m.raceInput(.tick(step: m.game.step, phase: m.game.phase))
        #expect(m.race == .unreachable(host: "Ana") && m.session == nil && net.links[0].isClosed)
        #expect(net.links[0].sent.isEmpty)          // never connected: no bye
        #expect(m.isOpen)
    }

    @MainActor @Test func theConnectTimeoutAlsoRunsOnTheSceneTick() {
        let (m, _, clock) = joining()
        clock.now = 5
        _ = m.sceneTick(elapsed: 1.0 / 60)
        #expect(m.race == .unreachable(host: "Ana"))
    }

    @MainActor @Test func spaceOnCouldNotReachGoesBackToTheLobby() {
        let (m, net, clock) = joining()
        clock.now = 5
        m.raceInput(.tick(step: 0, phase: .idle))
        net.hosts = [RaceHost(id: "b", name: "Sam", hero: "nova", map: "grove")]
        m.handle(.flapKey)
        #expect(m.race == .lobby(hosts: net.hosts, selection: 0) && net.isBrowsing && m.isOpen)
        // The timeout is gone with the attempt: a later tick doesn't bring the card back.
        clock.now = 20
        _ = m.sceneTick(elapsed: 1.0 / 60)
        #expect(m.race == .lobby(hosts: net.hosts, selection: 0))
    }

    @MainActor @Test func escOnCouldNotReachFoldsBackToSolo() {
        let (m, net, clock) = joining()
        clock.now = 5
        m.raceInput(.tick(step: 0, phase: .idle))
        m.handle(.escape)
        #expect(!m.isOpen && m.race == nil && !net.isBrowsing && m.game.phase == .idle)
    }

    @MainActor @Test func aJoinThatConnectsInTimeIsNotTimedOut() {
        let (m, net, clock) = joining()
        let host = net.remotes[0]
        _ = farEnd(host)
        clock.now = 4
        net.links[0].connect()
        host.send(.welcome(name: "Ana", hero: "moss", map: "glacier", width: 400))
        pump(net, to: clock.now)
        clock.now = 6
        pump(net, to: clock.now)
        m.raceInput(.tick(step: m.game.step, phase: m.game.phase))
        #expect(m.race == .match(.ready, .guest))
    }

    @MainActor @Test func aLinkLostBeforeItConnectedCouldNotReachTheHost() {
        let (m, net, _) = joining()
        net.links[0].onState?(.failed(.lost))
        #expect(m.race == .unreachable(host: "Ana") && m.session == nil)
    }

    @MainActor @Test func theConnectTimeoutIsOnlyForGuests() {
        let (m, net, clock) = raceModel()
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)   // host, nobody joins
        clock.now = 60
        m.raceInput(.tick(step: 0, phase: .idle))
        #expect(m.race == .match(.waiting, .host) && !net.links[0].isClosed)
    }

    @MainActor @Test func aConnectTimeoutWhileFoldedShowsOnReopening() {
        let (m, _, clock) = joining()
        m.handle(.hotKey)
        #expect(!m.isOpen && m.race == .match(.waiting, .guest))   // folding keeps a waiting race open
        clock.now = 5
        m.raceInput(.tick(step: 0, phase: .idle))                   // the race timer
        m.handle(.hotKey)
        #expect(m.isOpen && m.race == .unreachable(host: "Ana"))
    }
}
