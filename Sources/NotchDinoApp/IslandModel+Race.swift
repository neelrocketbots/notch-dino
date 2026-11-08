import AppKit
import RaceCore
import RunnerCore

extension IslandModel {
    // MARK: Opening and closing

    /// R on the idle screen, or Race Nearby… in the menu bar. The island opens into the explainer the first time and
    /// the lobby after that. A solo run in progress is set aside.
    public func openRace() {
        if !isOpen { run(.open) }
        guard race == nil else { return }
        game = Runner.newGame(world: soloWorld, seed: seed, best: bestStore.load())
        scene.reset()
        if raceStore.explained { showLobby() } else { race = .explainer }
        publish()
    }

    /// Back to solo: says bye if a match is on, stops listening and browsing, and goes back to this Mac's own map,
    /// world and a fresh run.
    public func closeRace() {
        if let s = session, !s.isOver { raceInput(.leave(.left)) }
        network.stopBrowsing()
        link?.close()
        link = nil
        session = nil
        joinAttempt = nil
        raceTimer?.invalidate()
        raceTimer = nil
        race = nil
        raceHUD = nil
        raceNotice = nil
        scene.setGhost(hero: nil, name: "")
        scene.fit(worldWidth: nil)
        scene.apply(hero: hero, map: map)
        game = Runner.newGame(world: soloWorld, seed: seed, best: bestStore.load())
        scene.reset()
        publish()
    }

    /// ⌘Q or Quit: tell the other Mac before going. Returns false when no race link is connected (nothing to say);
    /// otherwise sends the bye and calls `sent` once it has gone out. If it never does, their heartbeat notices
    /// within 5 s.
    public func prepareToQuit(then sent: @escaping @MainActor () -> Void) -> Bool {
        guard let s = session, !s.isOver, let l = link else { return false }
        raceInput(.leave(.quit))
        l.afterSending(sent)
        return true
    }

    public func setPlayerName(_ name: String) {
        raceStore.save(name: name)
        playerName = raceStore.name()
    }

    // MARK: Keys

    func handleRace(_ event: IslandEvent) {
        guard let screen = race else { return }
        guard isOpen else {
            // Folded: only reopening; the race (or its pause) is shown as it was.
            if event == .clickNotch || event == .hotKey { run(.open) }
            return
        }
        guard let action = RaceKeys.action(screen, event: event) else { return }
        perform(action)
    }

    func perform(_ action: RaceAction) {
        switch action {
        case .explainerContinue:
            raceStore.setExplained()
            showLobby()
        case .openPrivacySettings:
            onOpenPrivacy?()
        case .choose(let delta):
            guard case .lobby(let hosts, let selection) = race else { return }
            race = .lobby(hosts: hosts, selection: min(hosts.count, max(0, selection + delta)))
        case .pick:
            guard case .lobby(let hosts, let selection) = race else { return }
            if selection < hosts.count { join(hosts[selection]) } else { hostRace() }
        case .askName:
            onAskName?()
        case .start:
            raceInput(.startPressed)
        case .flap:
            var events: [GameEvent] = []
            Runner.flap(&game, events: &events)
            scene.consume(events, state: game)
            if events.contains(.flapped) { raceInput(.flapped(step: game.step)) }
        case .pause:
            raceInput(.pausePressed)
        case .resume:
            raceInput(.resumePressed)
        case .rematch:
            raceInput(.rematchPressed)
        case .leave:
            leaveRace()
        case .backToSolo:
            closeRace()
        case .backToLobby:
            showLobby()
        case .fold:
            run(.fold)
            if session?.inRace == true {
                raceInput(.tick(step: game.step, phase: game.phase))
                raceInput(.folded)
            }
            if case .match(.over, _) = race { closeRace() }
            if case .unreachable = race { closeRace() }
        }
        publish()
    }

    /// Esc on a race panel. Mid-match it ends the match for both and shows "You left the race"; anywhere else it
    /// goes straight back to solo.
    func leaveRace() {
        let midMatch: Bool = {
            guard let s = session, !s.isOver else { return false }
            if case .result = s.stage { return true }
            return s.inRace
        }()
        if midMatch { raceInput(.leave(.left)) } else { closeRace() }
    }

    // MARK: Lobby

    func showLobby() {
        race = .lobby(hosts: [], selection: 0)
        network.browse(onHosts: { [weak self] hosts in self?.hostsFound(hosts) },
                       onDenied: { [weak self] in self?.race = .denied })
    }

    func hostsFound(_ hosts: [RaceHost]) {
        guard case .lobby(_, let selection) = race else { return }
        race = .lobby(hosts: hosts, selection: min(selection, hosts.count))
    }

    /// Hosts on this Mac's map and world.
    func hostRace() {
        let me = RacePlayer(name: playerName, hero: hero.rawValue)
        session = RaceSession(hostingAs: me, map: map.rawValue, world: soloWorld, seed: .random(in: .min ... .max))
        joinAttempt = nil
        attach(network.host(as: me, map: map.rawValue))
        publishRace()
    }

    func join(_ host: RaceHost) {
        guard let link = network.join(host) else { return }
        session = RaceSession(joiningAs: RacePlayer(name: playerName, hero: hero.rawValue), seed: .random(in: .min ... .max))
        joinAttempt = (host, clock())
        attach(link)
        publishRace()
    }

    /// Wires the link and a 4-a-second tick, so the heartbeat and the pause limit keep running while folded (the
    /// scene doesn't tick then).
    func attach(_ link: RaceLink) {
        self.link = link
        link.onMessage = { [weak self] message in self?.raceInput(.received(message)) }
        link.onState = { [weak self] state in self?.linkChanged(state) }
        raceTimer?.invalidate()
        raceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.raceInput(.tick(step: self.game.step, phase: self.game.phase))
            }
        }
    }

    func linkChanged(_ state: RaceLinkState) {
        switch state {
        case .connecting:
            break
        case .ready:
            joinAttempt = nil
            raceInput(.connected)
        case .failed(.lost):
            // A guest whose link never connected couldn't reach the host; once connected, it's the opponent leaving.
            if let attempt = joinAttempt { couldNotReach(attempt.host) } else { raceInput(.disconnected) }
        case .failed(.denied):
            link = nil
            session = nil
            joinAttempt = nil
            raceTimer?.invalidate()
            raceTimer = nil
            race = .denied
        }
    }

    // MARK: Connect timeout (ruling 1)

    /// A join whose link hasn't connected within `RaceTimeouts.connect` ends on "Couldn't reach <host>". Checked on
    /// every race input, so the scene tick (open) and the race timer (folded) both catch it.
    func connectTimedOut() -> Bool {
        guard let attempt = joinAttempt, clock() - attempt.since >= RaceTimeouts.connect - 1e-9 else { return false }
        couldNotReach(attempt.host)
        return true
    }

    /// Ends a join that never connected. Nothing was said to the host, so there's no bye.
    func couldNotReach(_ host: RaceHost) {
        joinAttempt = nil
        link?.close()
        link = nil
        session = nil
        raceTimer?.invalidate()
        raceTimer = nil
        raceHUD = nil
        raceNotice = nil
        race = .unreachable(host: host.name)
        publish()
    }

    // MARK: Session I/O

    /// Feeds the session, applies its game commands to the run, and sends, announces or closes the rest.
    func raceInput(_ input: RaceInput) {
        if connectTimedOut() { return }
        guard var s = session else { return }
        let commands = s.handle(input, now: clock())
        session = s
        let started = commands.contains { if case .startGame = $0 { true } else { false } }
        for command in RacePlay.apply(commands, to: &game, world: s.world ?? game.world) {
            switch command {
            case .send(let message):
                link?.send(message)
            case .notice(.opponentCrashed(let score)):
                let notice = "\(s.opponent?.name ?? "They") crashed at \(score) · pass \(score) to win"
                raceNotice = notice
                announce(notice)
            case .close:
                link?.close()
                link = nil
                raceTimer?.invalidate()
                raceTimer = nil
            case .startGame, .freeze, .resume:
                break
            }
        }
        if started {
            scene.reset()
            raceNotice = nil
            scene.fit(worldWidth: s.world?.width)
            scene.setGhost(hero: Hero(rawValue: s.opponent?.hero ?? "") ?? .pip, name: s.opponent?.name ?? "")
        }
        // The host's map, for the scene only: the player's own choice is untouched.
        if let theme = s.map.flatMap(MapTheme.init(rawValue:)) { scene.apply(hero: hero, map: theme) }
        publishRace()
        publish()
    }

    /// Every frame of a race.
    func raceTick(_ events: [GameEvent]) {
        guard session != nil else { return }
        if events.contains(where: { if case .crashed = $0 { true } else { false } }), let step = game.crashStep {
            raceInput(.crashed(step: step, score: game.score))
            announce("Crashed at \(game.score)")
        }
        raceInput(.tick(step: game.step, phase: game.phase))
        // A stalled frame (over 0.25 s) paused the run on this Mac only: make it a race pause on both.
        if game.phase == .paused, let stage = session?.stage, stage == .racing || stage == .countdown {
            raceInput(.folded)
        }
    }

    func publishRace() {
        guard let s = session else { return }
        let screen = RaceScreen.match(s.stage, s.role)
        if race != screen { race = screen }
        if rematchAsked != s.rematchMine { rematchAsked = s.rematchMine }
        let h = RaceHUD.make(session: s, game: game)
        if h != raceHUD { raceHUD = h }
    }
}
