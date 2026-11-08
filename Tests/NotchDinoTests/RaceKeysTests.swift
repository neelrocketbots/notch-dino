import Foundation
import RaceCore
import RunnerCore
import Testing
@testable import NotchDinoApp

private let ana = RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")

@Suite struct RaceKeysTests {
    @Test func newKeysAreRoutedOnlyWhileOpen() {
        #expect(KeyRouter.action(keyCode: 15, modifiers: [], isOpen: true) == .island(.raceKey))
        #expect(KeyRouter.action(keyCode: 45, modifiers: [], isOpen: true) == .island(.nameKey))
        #expect(KeyRouter.action(keyCode: 126, modifiers: [], isOpen: true) == .island(.upKey))
        #expect(KeyRouter.action(keyCode: 125, modifiers: [], isOpen: true) == .island(.downKey))
        #expect(KeyRouter.action(keyCode: 15, modifiers: .command, isOpen: true) == nil)
        for code: UInt16 in [15, 45, 125, 126] { #expect(KeyRouter.action(keyCode: code, modifiers: [], isOpen: false) == nil) }
    }

    @Test func soloMeaningOfTheNewKeys() {
        #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: .upKey) == (true, [.flap]))
        #expect(IslandLogic.reduce(isOpen: true, phase: .crashed, event: .upKey) == (true, [.newGameAndFlap]))
        #expect(IslandLogic.reduce(isOpen: true, phase: .idle, event: .raceKey) == (true, [.openRace]))
        #expect(IslandLogic.reduce(isOpen: true, phase: .running, event: .raceKey) == (true, []))
        #expect(IslandLogic.reduce(isOpen: true, phase: .idle, event: .nameKey) == (true, []))
        #expect(IslandLogic.reduce(isOpen: true, phase: .idle, event: .downKey) == (true, []))
        #expect(IslandLogic.reduce(isOpen: false, phase: .idle, event: .raceKey) == (false, []))
    }

    @Test func foldEventsFoldEveryRaceScreen() {
        let screens: [RaceScreen] = [.explainer, .denied, .lobby(hosts: [], selection: 0), .match(.racing, .host),
                                     .match(.result(.win), .guest), .match(.over(.desync), .host)]
        for screen in screens {
            for e in [IslandEvent.hotKey, .lostKey, .autoPause] { #expect(RaceKeys.action(screen, event: e) == .fold) }
            #expect(RaceKeys.action(screen, event: .clickNotch) == nil)
        }
    }

    @Test func explainerDeniedAndLobbyKeys() {
        #expect(RaceKeys.action(.explainer, event: .flapKey) == .explainerContinue)
        #expect(RaceKeys.action(.explainer, event: .escape) == .leave)
        #expect(RaceKeys.action(.denied, event: .flapKey) == .openPrivacySettings)
        #expect(RaceKeys.action(.denied, event: .escape) == .leave)
        let lobby = RaceScreen.lobby(hosts: [ana], selection: 0)
        #expect(RaceKeys.action(lobby, event: .upKey) == .choose(delta: -1))
        #expect(RaceKeys.action(lobby, event: .downKey) == .choose(delta: 1))
        #expect(RaceKeys.action(lobby, event: .flapKey) == .pick)
        #expect(RaceKeys.action(lobby, event: .nameKey) == .askName)
        #expect(RaceKeys.action(lobby, event: .escape) == .leave)
        #expect(RaceKeys.action(lobby, event: .pauseKey) == nil)
    }

    @Test func onlyTheHostStarts() {
        #expect(RaceKeys.action(.match(.ready, .host), event: .flapKey) == .start)
        #expect(RaceKeys.action(.match(.ready, .guest), event: .flapKey) == nil)
        #expect(RaceKeys.action(.match(.ready, .guest), event: .escape) == .leave)
        #expect(RaceKeys.action(.match(.waiting, .host), event: .escape) == .leave)
        #expect(RaceKeys.action(.match(.waiting, .host), event: .flapKey) == nil)
    }

    @Test func countdownIgnoresKeysButEscFolds() {
        for e in [IslandEvent.flapKey, .upKey, .pauseKey, .clickField] {
            #expect(RaceKeys.action(.match(.countdown, .guest), event: e) == nil)
        }
        #expect(RaceKeys.action(.match(.countdown, .guest), event: .escape) == .fold)
    }

    @Test func racingKeys() {
        for e in [IslandEvent.flapKey, .upKey, .clickField] { #expect(RaceKeys.action(.match(.racing, .host), event: e) == .flap) }
        #expect(RaceKeys.action(.match(.racing, .host), event: .pauseKey) == .pause)
        #expect(RaceKeys.action(.match(.racing, .host), event: .escape) == .fold)
        #expect(RaceKeys.action(.match(.racing, .host), event: .raceKey) == nil)
    }

    @Test func onlyThePauserResumesAndEscLeaves() {
        #expect(RaceKeys.action(.match(.paused(byMe: true), .host), event: .pauseKey) == .resume)
        #expect(RaceKeys.action(.match(.paused(byMe: true), .host), event: .flapKey) == .resume)
        #expect(RaceKeys.action(.match(.paused(byMe: true), .host), event: .escape) == .leave)
        #expect(RaceKeys.action(.match(.paused(byMe: false), .host), event: .pauseKey) == nil)
        #expect(RaceKeys.action(.match(.paused(byMe: false), .host), event: .flapKey) == nil)
        #expect(RaceKeys.action(.match(.paused(byMe: false), .host), event: .escape) == .leave)
    }

    @Test func resultAndOverKeys() {
        #expect(RaceKeys.action(.match(.result(.lose), .guest), event: .flapKey) == .rematch)
        #expect(RaceKeys.action(.match(.result(.lose), .guest), event: .escape) == .leave)
        #expect(RaceKeys.action(.match(.over(.opponentLeft), .guest), event: .flapKey) == .backToSolo)
        #expect(RaceKeys.action(.match(.over(.opponentLeft), .guest), event: .escape) == .fold)
    }

    @Test func raceHUDShowsBothScoresAndThePlace() {
        var host = RaceSession(hostingAs: RacePlayer(name: "Neel", hero: "pip"), map: "volcano", world: World(width: 351), seed: 1)
        _ = host.handle(.connected, now: 0)
        _ = host.handle(.received(.hello(proto: 1, rules: Params.rulesVersion, name: "Ana", hero: "moss")), now: 0)
        var game = Runner.newGame(world: World(width: 351), seed: 0, best: 0)
        #expect(RaceHUD.make(session: host, game: game) == RaceHUD(opponentName: "Ana", opponentHero: .moss, opponentScore: 0, score: 0, place: nil))
        _ = host.handle(.startPressed, now: 0)
        game.score = 3
        #expect(RaceHUD.make(session: host, game: game)?.place == "1st")
        let unknown = RaceSession(hostingAs: RacePlayer(name: "N", hero: "pip"), map: "volcano", world: World(width: 351), seed: 1)
        #expect(RaceHUD.make(session: unknown, game: game) == nil)
    }

    @Test func raceStoreNameAndExplainer() {
        let d = freshDefaults()
        let s = RaceStore(defaults: d, fullName: { "Neel Singh" })
        #expect(s.name() == "Neel" && !s.explained)
        s.save(name: " Bartholomew-Jones\n")
        #expect(s.name() == "Bartholomew-" && d.string(forKey: RaceStore.nameKey) == "Bartholomew-")
        s.setExplained()
        #expect(s.explained)
        #expect(RaceStore(defaults: freshDefaults(), fullName: { "" }).name() == "Player")
    }

    // Adaptation: main's KeyRouter takes modifiers. The new keys follow Space's rule: control, option or command
    // passes the key through to the frontmost app; Shift doesn't.
    @Test func modifiedNewKeysPassThroughLikeSpace() {
        let combos: [KeyModifiers] = [.control, .option, .command, [.control, .option]]
        for code: UInt16 in [15, 45, 125, 126] {
            for m in combos { #expect(KeyRouter.action(keyCode: code, modifiers: m, isOpen: true) == nil) }
        }
        #expect(KeyRouter.action(keyCode: 15, modifiers: .shift, isOpen: true) == .island(.raceKey))
        #expect(KeyRouter.action(keyCode: 125, modifiers: .shift, isOpen: true) == .island(.downKey))
    }

    // Ruling 1: a join that never connected ends on "Couldn't reach <host>"; Space goes back to the lobby, Esc folds.
    @Test func couldNotReachKeys() {
        let screen = RaceScreen.unreachable(host: "Ana")
        #expect(RaceKeys.action(screen, event: .flapKey) == .backToLobby)
        #expect(RaceKeys.action(screen, event: .escape) == .fold)
        for e in [IslandEvent.hotKey, .lostKey, .autoPause] { #expect(RaceKeys.action(screen, event: e) == .fold) }
        for e in [IslandEvent.upKey, .downKey, .pauseKey, .raceKey, .nameKey, .clickField, .clickNotch] {
            #expect(RaceKeys.action(screen, event: e) == nil)
        }
        #expect(RaceText.unreachable("Ana") == "Couldn't reach Ana")
    }
}
