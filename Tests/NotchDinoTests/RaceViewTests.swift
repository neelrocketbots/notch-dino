import AppKit
import Foundation
import RaceCore
import RunnerCore
import SwiftUI
import Testing
@testable import NotchDinoApp

@Suite struct RaceViewTests {
    @Test func endCards() {
        #expect(RaceCopy.endTitle(.opponentLeft, opponent: "Ana") == "Ana left the race")
        #expect(RaceCopy.endTitle(.opponentLeft, opponent: nil) == "The race closed")
        #expect(RaceCopy.endTitle(.youLeft, opponent: "Ana") == "You left the race")
        #expect(RaceCopy.endTitle(.versionMismatch, opponent: nil) == "Update Notch Dino to race")
        #expect(RaceCopy.endTitle(.desync, opponent: "Ana") == "Couldn't keep the race in sync")
        #expect(RaceCopy.endTitle(.full, opponent: nil) == "That race is full")
        #expect(RaceCopy.endBody(.desync) == "The match is over. Nothing is saved from it.")
        #expect(RaceCopy.endBody(.versionMismatch) == "The other Mac runs a different version. Both need the same one.")
    }

    @Test func lobbyAndMatchWords() {
        #expect(RaceCopy.explainer(name: "Neel").contains("Nearby players will see your name, Neel."))
        #expect(RaceCopy.deniedTitle == "Racing needs Local Network access")
        #expect(RaceCopy.waitingTitle(.host) == "Waiting for a player…")
        #expect(RaceCopy.readyTitle(.host, opponent: "Ana") == "Ana joined")
        #expect(RaceCopy.readyTitle(.guest, opponent: "Ana") == "Waiting for Ana to start")
        #expect(RaceCopy.pausedTitle(byMe: true, opponent: "Ana") == "Paused")
        #expect(RaceCopy.pausedTitle(byMe: false, opponent: "Ana") == "Ana paused")
        #expect(RaceCopy.pausedBody(byMe: true, opponent: "Ana", pausesLeft: 1) == "1 pause left in this race.")
        #expect(RaceCopy.pausedBody(byMe: false, opponent: "Ana", pausesLeft: 2) == "Only Ana can resume.")
        #expect(RaceCopy.outcome(.win, opponent: "Ana") == "You win")
        #expect(RaceCopy.outcome(.lose, opponent: "Ana") == "Ana wins" && RaceCopy.outcome(.tie, opponent: "Ana") == "Tie")
        #expect(RaceCopy.unreachableTitle("Ana") == "Couldn't reach Ana")
        #expect(RaceCopy.unreachableBody("Ana") == "Ana's race didn't answer. It may have closed, or the Mac is out of range.")
        let ana = RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")
        #expect(RaceCopy.lobbyDetail(ana) == "\(MapTheme.glacier.name) · waiting")
        #expect(RaceCopy.mapName("lava9") == "Their map")
    }

    @Test func theLobbyKeepsTheSelectionInView() {
        #expect(LobbyWindow.range(count: 0, selection: 0) == 0..<0)
        #expect(LobbyWindow.range(count: 2, selection: 0) == 0..<2)
        #expect(LobbyWindow.range(count: 5, selection: 0) == 0..<3)
        #expect(LobbyWindow.range(count: 5, selection: 3) == 2..<5)
        #expect(LobbyWindow.range(count: 5, selection: 5) == 2..<5)   // the "Host a race" row
    }

    /// The key row's height when laid out at a card's inner width: 20 pt is one row, more is two rows.
    @MainActor private func keyRowHeight(_ keys: [Hint], in width: CGFloat) -> CGFloat {
        let view = NSHostingView(rootView: KeyRow(keys: keys).frame(width: width))
        view.frame = CGRect(x: 0, y: 0, width: width, height: 200)
        view.layoutSubtreeIfNeeded()
        return view.fittingSize.height
    }

    @MainActor @Test func keyHintsFitTheirCardsWithoutShrinking() {
        let inset = RacePanel<EmptyView>.padding.leading + RacePanel<EmptyView>.padding.trailing
        // The lobby's four hints fit on one row of its card in a 421-pt field (a 185-pt notch's island).
        let lobby = [Hint("↑↓", "Choose"), Hint("space", "Host"), Hint("N", "Name"), Hint("esc", "Leave")]
        #expect(keyRowHeight(lobby, in: RacePanel<EmptyView>.maxWidth(field: 421) - inset) == 20)
        // Squeezed, they take two rows rather than truncating or wrapping.
        let squeezed = keyRowHeight(lobby, in: 200)
        #expect(squeezed > 20 && squeezed <= 46)
        // Every 270-pt card's hints fit on one row.
        let standard = RacePanel<EmptyView>.standardWidth - inset
        for keys in [[Hint("space", "Open Settings"), Hint("esc", "Leave")], [Hint("space", "Back to lobby"), Hint("esc", "Fold")],
                     [Hint("space", "Back to solo"), Hint("esc", "Fold")], [Hint("space", "Continue"), Hint("esc", "Not now")],
                     [Hint("space", "Waiting…"), Hint("esc", "Leave")], [Hint("P", "Resume"), Hint("esc", "Leave")]] {
            #expect(keyRowHeight(keys, in: standard) == 20, "\(keys)")
        }
    }

    @MainActor @Test func everyRaceScreenRenders() {
        let (m, _, _, _, _) = racing()
        let ana = RaceHost(id: "a", name: "Ana", hero: "moss", map: "glacier")
        let screens: [RaceScreen] = [
            .explainer, .denied, .lobby(hosts: [], selection: 0), .lobby(hosts: [ana, ana, ana, ana], selection: 2),
            .match(.waiting, .host), .match(.waiting, .guest), .match(.ready, .host), .match(.ready, .guest),
            .match(.countdown, .host), .match(.racing, .host), .match(.paused(byMe: true), .host),
            .match(.paused(byMe: false), .guest), .match(.result(.win), .host), .match(.result(.tie), .guest),
            .match(.over(.desync), .host), .match(.over(.versionMismatch), .guest), .match(.over(.opponentLeft), .host),
            .match(.over(.youLeft), .guest), .match(.over(.full), .guest), .unreachable(host: "Ana"),
        ]
        for screen in screens {
            let overlay = NSHostingView(rootView: RaceOverlay(model: m, screen: screen).frame(width: 421, height: 240))
            overlay.frame = CGRect(x: 0, y: 0, width: 421, height: 240)
            overlay.layoutSubtreeIfNeeded()
            let ears = NSHostingView(rootView: RaceEars(screen: screen, hud: m.raceHUD, notchWidth: 185, band: 32))
            ears.frame = CGRect(x: 0, y: 0, width: 445, height: 32)
            ears.layoutSubtreeIfNeeded()
            #expect(overlay.fittingSize.width > 0 && ears.fittingSize.height > 0, "\(screen)")
        }
    }

    @MainActor @Test func anEndCardWithNoKnownOpponentShowsTheLobbyBand() {
        let (m, net, _) = raceModel()
        m.handle(.hotKey); m.handle(.raceKey); m.handle(.flapKey)   // host
        let guest = net.remotes[0]
        net.links[0].connect()
        guest.send(.hello(proto: RaceMessage.protocolVersion + 1, rules: Params.rulesVersion, name: "Ana", hero: "moss"))
        pump(net, to: 0)
        #expect(m.race == .match(.over(.versionMismatch), .host) && m.raceHUD == nil)
        #expect(RaceEars.lobbyTitle(.match(.over(.versionMismatch), .host), hud: nil) == "Race nearby")
        #expect(RaceEars.lobbyTitle(.match(.over(.full), .guest), hud: nil) == "Race nearby")
        #expect(RaceEars.lobbyTitle(.match(.over(.versionMismatch), .guest), hud: nil) == "Race nearby")
        // Once the opponent is known, the band keeps their name and score.
        let (r, _, _, _, _) = racing()
        #expect(RaceEars.lobbyTitle(.match(.over(.opponentLeft), .host), hud: r.raceHUD) == nil && r.raceHUD != nil)
        #expect(RaceEars.lobbyTitle(.match(.waiting, .host), hud: nil) == "Your race")
        #expect(RaceEars.lobbyTitle(.lobby(hosts: [], selection: 0), hud: nil) == "Race nearby")
    }

    @MainActor @Test func theResultCardShowsTheRematchRequest() throws {
        let (m, net, clock, guest, inbox) = racing()
        guard case .start(let seed, _) = inbox.messages.first(where: { if case .start = $0 { true } else { false } }) else {
            Issue.record("no start"); return
        }
        var fall = Ghost(seed: seed, world: try #require(m.session?.world))
        fall.advance(to: 2_000)
        guest.send(.crashed(step: fall.state.crashStep!, score: fall.state.score))
        m.game.pipY = Params.ground
        _ = m.sceneTick(elapsed: 1.0 / 60)
        pump(net, to: clock.now)
        guard case .match(.result, .host) = m.race else { Issue.record("no result: \(String(describing: m.race))"); return }
        #expect(!m.rematchAsked)
        m.handle(.flapKey)
        #expect(m.rematchAsked)
    }
}
