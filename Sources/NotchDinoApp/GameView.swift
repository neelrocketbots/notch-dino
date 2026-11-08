import NotchKit
import RunnerCore
import SpriteKit
import SwiftUI

enum Ink {
    static let text = Color(.sRGB, red: 1, green: 0.957, blue: 0.941)
    static let soft = Color(.sRGB, red: 1, green: 0.886, blue: 0.847, opacity: 0.62)
    static let pip = Color(.sRGB, red: 1, green: 0.353, blue: 0.235)
    static let goodRing = Color(.sRGB, red: 1, green: 0.816, blue: 0.541, opacity: 0.85)
    static let badRing = Color(.sRGB, red: 1, green: 0.353, blue: 0.235, opacity: 0.8)
}

/// The open island's content at full size: the scene, the band's fade, the HUD in the band's ears, and glass overlays.
struct GameView: View {
    let model: IslandModel

    var body: some View {
        let g = model.geometry
        let band = g.notch.height
        let field = CGRect(x: NotchGeometry.bodyInset, y: band + NotchGeometry.bodyTop,
                           width: g.expandedSize.width - 2 * NotchGeometry.bodyInset,
                           height: g.expandedSize.height - band - NotchGeometry.bodyTop - NotchGeometry.bodyBottom)
        ZStack(alignment: .topLeading) {
            SceneHost(scene: model.scene, paused: !model.isOpen)
            BandFade(band: band, height: g.expandedSize.height, map: model.map).allowsHitTesting(false)
            Ears(hud: model.hud, phase: model.phase, notchWidth: model.isFloating ? 0 : g.notch.width, band: band)
                .frame(width: g.expandedSize.width, height: band)
                .allowsHitTesting(false)
            overlay
                .frame(width: field.width, height: field.height)
                .offset(x: field.minX, y: field.minY)
        }
        .frame(width: g.expandedSize.width, height: g.expandedSize.height, alignment: .topLeading)
    }

    @ViewBuilder private var overlay: some View {
        switch model.phase {
        case .idle:
            KeyPrompt(action: "to flap")
                .padding(.horizontal, 6).frame(height: 34)
                .glassEffect(.regular, in: Capsule())
                .offset(x: 50)
                .allowsHitTesting(false)
        case .paused:
            ZStack {
                Color.black.opacity(0.38)
                VStack(spacing: 10) {
                    Text("Paused").font(.system(size: 17, weight: .semibold)).foregroundStyle(Ink.text)
                    KeyPrompt(action: "to resume")
                }
                .frame(width: 210, height: 96)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            }
            .allowsHitTesting(false)
        case .crashed:
            ZStack {
                Color.black.opacity(0.38)
                VStack(spacing: 8) {
                    Text("\(model.hud.score)").font(.system(size: 40, weight: .semibold)).monospacedDigit().foregroundStyle(Ink.text)
                    if model.game.newBest {
                        Text("New best").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(.sRGB, red: 0.165, green: 0.031, blue: 0.02))
                            .padding(.horizontal, 8).frame(height: 18).background(Ink.pip, in: Capsule())
                    }
                    KeyPrompt(action: "to retry").padding(.top, 6)
                }
                .frame(width: 210, height: 140)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            }
            .allowsHitTesting(false)
        case .running:
            EmptyView()
        }
    }
}

/// The black band stays black, then fades into the map's sky through the sky's own hue (`Art.bandFade`).
struct BandFade: View {
    let band: CGFloat
    let height: CGFloat
    let map: MapTheme
    var body: some View {
        let fieldTop = band + NotchGeometry.bodyTop
        let fieldHeight = height - fieldTop - NotchGeometry.bodyBottom
        LinearGradient(stops: Art.bandFade(map: map, band: band, height: height, fieldTop: fieldTop, fieldHeight: fieldHeight).map {
            Gradient.Stop(color: Color(.sRGB, red: $0.r, green: $0.g, blue: $0.b, opacity: $0.alpha), location: $0.location)
        }, startPoint: .top, endPoint: .bottom)
            .frame(height: band + map.palette.fade)
    }
}

struct KeyPrompt: View {
    let action: String
    var body: some View {
        HStack(spacing: 8) {
            Text("space").font(.system(size: 12, weight: .medium)).foregroundStyle(Ink.text)
                .padding(.horizontal, 8).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.35), lineWidth: 1))
            Text(action).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text)
        }
        .padding(.horizontal, 6)
    }
}

/// Best on the left ear; score with effect chips on the right ear.
struct Ears: View {
    let hud: HUD
    let phase: Phase
    let notchWidth: CGFloat
    let band: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("Best \(hud.best)").font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(Ink.soft)
            Spacer(minLength: notchWidth + 16)
            HStack(spacing: 6) {
                ForEach(hud.chips, id: \.pickup) { chip in
                    ZStack {
                        Image(decorative: Art.pickup(chip.pickup), scale: Art.scale).resizable().frame(width: 21, height: 21)
                        if chip.pickup != .ember {
                            Circle().trim(from: 0, to: chip.fraction)
                                .stroke(chip.pickup.isGood ? Ink.goodRing : Ink.badRing, lineWidth: 1.5)
                                .rotationEffect(.degrees(-90)).frame(width: 17, height: 17)
                        }
                    }
                }
                if phase != .idle {
                    Text("\(hud.score)").font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Ink.text)
                }
            }
        }
        .padding(.horizontal, 26)
        .frame(height: band)
    }
}
