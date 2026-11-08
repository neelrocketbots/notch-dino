import CoreGraphics
import Foundation

enum Palette {
    // Hero and map colours live in Looks.swift.
    static let eye: UInt32 = 0x1A0605
    static let text: UInt32 = 0xFFF4F0
}

enum Art {
    static let scale: CGFloat = 2
    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Draws in points with a top-left origin (like an HTML canvas), at `scale` pixels per point.
    static func image(_ size: CGSize, scale: CGFloat = Art.scale, _ draw: (CGContext) -> Void) -> CGImage {
        let w = max(1, Int((size.width * scale).rounded(.up))), h = max(1, Int((size.height * scale).rounded(.up)))
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        draw(ctx)
        return ctx.makeImage()!
    }

    static func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }
    static func white(_ a: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
    static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    static func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
        CGGradient(colorsSpace: srgb, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
    }

    static func linear(_ ctx: CGContext, clip path: CGPath, _ stops: [(CGFloat, CGColor)], from: CGPoint, to: CGPoint) {
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        ctx.drawLinearGradient(gradient(stops), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    static func radial(_ ctx: CGContext, at c: CGPoint, radius: CGFloat, _ stops: [(CGFloat, CGColor)]) {
        ctx.drawRadialGradient(gradient(stops), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
        ctx.addPath(path); ctx.setFillColor(color); ctx.fillPath()
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, width: CGFloat) {
        ctx.addPath(path); ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.strokePath()
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ angle: CGFloat = 0) -> CGPath {
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle)
        return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: &t)
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath { ellipse(c, r, r) }

    static func polygon(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p
    }

    /// An arc as a polyline (avoids CoreGraphics' clockwise flag flipping under the top-left transform).
    static func arc(_ c: CGPoint, _ r: CGFloat, from a0: CGFloat, to a1: CGFloat, steps: Int = 16) -> CGPath {
        let p = CGMutablePath()
        for i in 0...steps {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    /// Draws `body` translated and rotated, then restores.
    static func at(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, rotate a: CGFloat = 0, _ body: () -> Void) {
        ctx.saveGState(); ctx.translateBy(x: x, y: y); ctx.rotate(by: a); body(); ctx.restoreGState()
    }
}

extension CGPoint { init(_ x: CGFloat, _ y: CGFloat) { self.init(x: x, y: y) } }
