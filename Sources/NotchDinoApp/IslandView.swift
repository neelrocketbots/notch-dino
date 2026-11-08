import NotchKit
import SwiftUI

/// The island's outline at an expansion, animatable so open and fold spring the shape itself (NotchKit invariant 5:
/// the content is laid out at full size and only the clip animates).
struct IslandClip: Shape {
    var expansion: Double
    let notch: CGSize
    let expanded: CGSize
    let floating: Bool

    var animatableData: Double {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if floating { return NotchPillShape(cornerRadius: NotchFloat.cornerRadius).path(in: rect) }
        let e = max(0, min(1.04, expansion))
        let w = notch.width + (expanded.width - notch.width) * e
        let h = notch.height + (expanded.height - notch.height) * e
        let r = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: h)
        return NotchShape(shoulder: NotchGeometry.shoulder(expansion: min(1, e)),
                          bottomRadius: NotchGeometry.cornerRadius(expansion: min(1, e))).path(in: r)
    }
}

public struct IslandView: View {
    let model: IslandModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gripHover = false

    public init(model: IslandModel) { self.model = model }

    public var body: some View {
        let g = model.geometry
        let e: Double = model.isOpen ? 1 : 0
        let frame = model.islandFrame
        let clip = IslandClip(expansion: e, notch: g.notch, expanded: g.expandedSize, floating: model.isFloating)
        let currentHeight = g.notch.height + (g.expandedSize.height - g.notch.height) * e

        ZStack(alignment: .topLeading) {
            ZStack(alignment: .top) {
                NotchBackdrop(shape: AnyShape(clip), rendering: .material, height: currentHeight,
                              expandedHeight: g.notch.height + NotchGeometry.extraHeight, floating: model.isFloating)
                    .modifier(NotchFloatShadow(on: model.isFloating))
                content(g: g)
                    .clipShape(clip)
                if !model.isOpen {
                    Color.clear
                        .frame(width: g.notch.width, height: g.notch.height)
                        .contentShape(Rectangle())
                        .onTapGesture { model.handle(.clickNotch) }
                }
            }
            .frame(width: g.expandedSize.width, height: g.expandedSize.height, alignment: .top)
            .offset(x: frame.minX, y: frame.minY)
        }
        .frame(width: model.panelSize.width, height: model.panelSize.height, alignment: .topLeading)
        .animation(reduceMotion ? nil : NotchDockMotion.snapSpring(), value: model.isOpen)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private func content(g: NotchGeometry) -> some View {
        ZStack(alignment: .top) {
            GameView(model: model)
            VStack(spacing: 0) {
                ZStack {
                    NotchMoveArea(driver: model)
                    if model.isFloating {
                        NotchGripDots(lit: gripHover || model.isMoving)
                            .frame(width: NotchGrip.hitSize.width, height: NotchGrip.hitSize.height)
                            .contentShape(Rectangle())
                            .onHover { gripHover = $0 }
                            .notchMoveGesture(model)
                            .notchMoveGripAccessibility(model)
                    }
                }
                .frame(height: g.notch.height)
                Spacer(minLength: 0)
            }
        }
        .frame(width: g.expandedSize.width, height: g.expandedSize.height)
    }
}
