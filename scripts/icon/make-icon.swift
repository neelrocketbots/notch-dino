// Draws Notch Dino's app icon: a Liquid Glass dragon egg, cracked open at the top, with Pip peeking out.
// Pip comes from the game's own art (scripts/icon/pip.png, rendered from Art.drawPip at 24x).
// Run scripts/make-icon.sh to regenerate scripts/icon/AppIcon.icns.
import AppKit
import CoreImage
let cs = CGColorSpaceCreateDeviceRGB()
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(red: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a) }
func grad(_ c: [CGColor], _ l: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: cs, colors: c as CFArray, locations: l)! }
func ctx(_ n: Int) -> CGContext { CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)! }
func eggPath() -> CGPath {
  let p = CGMutablePath(); let cx: CGFloat = 512, b: CGFloat = 215, t: CGFloat = 790, w: CGFloat = 225
  p.move(to: CGPoint(x: cx, y: b))
  p.addCurve(to: CGPoint(x: cx - w, y: 415), control1: CGPoint(x: cx - 140, y: b), control2: CGPoint(x: cx - w, y: 290))
  p.addCurve(to: CGPoint(x: cx, y: t), control1: CGPoint(x: cx - w, y: 610), control2: CGPoint(x: cx - 118, y: t))
  p.addCurve(to: CGPoint(x: cx + w, y: 415), control1: CGPoint(x: cx + 118, y: t), control2: CGPoint(x: cx + w, y: 610))
  p.addCurve(to: CGPoint(x: cx, y: b), control1: CGPoint(x: cx + w, y: 290), control2: CGPoint(x: cx + 140, y: b))
  p.closeSubpath(); return p
}
let rimPts: [(CGFloat, CGFloat)] = [(270, 600), (318, 640), (352, 612), (398, 662), (436, 630), (474, 676), (516, 640), (556, 684), (594, 646), (632, 690), (668, 650), (712, 672), (760, 618)]
func belowRim() -> CGPath {
  let p = CGMutablePath(); p.move(to: CGPoint(x: 200, y: 0)); p.addLine(to: CGPoint(x: 200, y: 600))
  for q in rimPts { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
  p.addLine(to: CGPoint(x: 830, y: 600)); p.addLine(to: CGPoint(x: 830, y: 0)); p.closeSubpath(); return p
}
func rimLine() -> CGPath { let p = CGMutablePath(); p.move(to: CGPoint(x: rimPts[0].0, y: rimPts[0].1)); for q in rimPts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }; return p }
func crackLine() -> CGPath {
  let p = CGMutablePath(); let pts: [(CGFloat, CGFloat)] = [(474, 676), (460, 616), (488, 572), (462, 520), (480, 470)]
  p.move(to: CGPoint(x: pts[0].0, y: pts[0].1)); for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
  p.move(to: CGPoint(x: 488, y: 572)); p.addLine(to: CGPoint(x: 524, y: 548)); p.addLine(to: CGPoint(x: 532, y: 512)); return p
}
let pipImg: CGImage = { let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil)!; return CGImageSourceCreateImageAtIndex(src, 0, nil)! }()
let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
func background(dark: Bool) -> CGImage {
  let c = ctx(1024)
  if dark {
    c.drawLinearGradient(grad([rgb(0x0B0709), rgb(0x2A0F10), rgb(0x4A1A14)], [0, 0.6, 1]), start: CGPoint(x: 300, y: 100), end: CGPoint(x: 724, y: 924), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    for (x, y, r, col, a) in [(512.0, 380.0, 360.0, UInt32(0xFF5A3C), 0.55), (300.0, 760.0, 260.0, UInt32(0xFF9A4C), 0.20), (760.0, 260.0, 240.0, UInt32(0xC8321E), 0.35)] {
      let p = CGPoint(x: x, y: y); c.drawRadialGradient(grad([rgb(col, a), rgb(col, 0)], [0, 1]), startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: []) }
  } else {
    c.drawLinearGradient(grad([rgb(0x7A1622), rgb(0xD8402C), rgb(0xFF8A4A)], [0, 0.55, 1]), start: CGPoint(x: 724, y: 100), end: CGPoint(x: 300, y: 924), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    for (x, y, r, col, a) in [(300.0, 760.0, 320.0, UInt32(0xFFC07A), 0.55), (780.0, 300.0, 300.0, UInt32(0x5A0E2A), 0.45), (560.0, 520.0, 260.0, UInt32(0xFF6A3C), 0.35)] {
      let p = CGPoint(x: x, y: y); c.drawRadialGradient(grad([rgb(col, a), rgb(col, 0)], [0, 1]), startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: []) }
  }
  return c.makeImage()!
}
func blurred(_ img: CGImage, _ r: Double) -> CGImage {
  let ci = CIImage(cgImage: img).clampedToExtent().applyingGaussianBlur(sigma: r).cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))
  return CIContext().createCGImage(ci, from: ci.extent)!
}
func render(_ px: Int, dark: Bool) -> CGImage {
  let bg = background(dark: dark), frost = blurred(bg, 38)
  let c = ctx(1024)
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: rgb(0, 0.40)); c.addPath(tile); c.setFillColor(rgb(0x2A0F10)); c.fillPath(); c.restoreGState()
  c.saveGState(); c.addPath(tile); c.clip(); c.draw(bg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
  let egg = eggPath()
  // soft contact shadow + ember light spill under the egg
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -26), blur: 50, color: rgb(0x1A0508, 0.55)); c.addPath(egg); c.setFillColor(rgb(0, 0.01)); c.fillPath(); c.restoreGState()
  // hatchling: inside the egg and rising above the broken rim
  c.saveGState()
  let pipClip = egg.intersection(belowRim()).union(CGPath(rect: CGRect(x: 398, y: 600, width: 312, height: 118), transform: nil)).union(CGPath(rect: CGRect(x: 372, y: 718, width: 338, height: 202), transform: nil))
  c.addPath(pipClip); c.clip()
  let k: CGFloat = 0.57
  c.draw(pipImg, in: CGRect(x: 540 - 912 * k, y: 700 - (1056 - 443) * k, width: 1248 * k, height: 1056 * k))
  // warm underglow on the hatchling from the ember inside
  c.setBlendMode(.screen)
  let ug = CGPoint(x: 520, y: 600)
  c.drawRadialGradient(grad([rgb(0xFFB547, 0.45), rgb(0xFF7A3C, 0)], [0, 1]), startCenter: ug, startRadius: 0, endCenter: ug, endRadius: 200, options: [])
  c.setBlendMode(.normal)
  c.restoreGState()
  // glass body (front shell, below the broken rim): frosted backdrop, brightened
  c.saveGState(); c.addPath(egg); c.clip(); c.addPath(belowRim()); c.clip()
  c.setAlpha(0.88); c.draw(frost, in: CGRect(x: 0, y: 0, width: 1024, height: 1024)); c.setAlpha(1)
  c.drawLinearGradient(grad([rgb(0xFFFFFF, dark ? 0.10 : 0.16), rgb(0xFFFFFF, dark ? 0.22 : 0.34)], [0, 1]), start: CGPoint(x: 0, y: 215), end: CGPoint(x: 0, y: 790), options: [])
  // pointy glass scales: shingled rows, upper rows overlap lower ones
  var row = 0
  for y in stride(from: CGFloat(170), through: 830, by: 44) {
    let r: CGFloat = 30, off: CGFloat = row % 2 == 0 ? 0 : r
    for x in stride(from: CGFloat(250) + off, through: 790, by: 2 * r) {
      let sp = CGMutablePath()
      sp.move(to: CGPoint(x: x - r, y: y))
      sp.addCurve(to: CGPoint(x: x, y: y - 1.45 * r), control1: CGPoint(x: x - r, y: y - 0.75 * r), control2: CGPoint(x: x - 0.35 * r, y: y - 1.2 * r))
      sp.addCurve(to: CGPoint(x: x + r, y: y), control1: CGPoint(x: x + 0.35 * r, y: y - 1.2 * r), control2: CGPoint(x: x + r, y: y - 0.75 * r))
      sp.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x, y: y + 0.35 * r))
      sp.closeSubpath()
      c.saveGState(); c.addPath(sp); c.clip()
      c.drawLinearGradient(grad([rgb(0xFFFFFF, dark ? 0.10 : 0.14), rgb(0x2A0610, dark ? 0.30 : 0.20)], [0, 1]),
                           start: CGPoint(x: 0, y: y + 0.3 * r), end: CGPoint(x: 0, y: y - 1.45 * r), options: [])
      c.restoreGState()
      // edge light on the two flanks, brighter on the upper-left flank
      let edge = CGMutablePath()
      edge.move(to: CGPoint(x: x - r, y: y))
      edge.addCurve(to: CGPoint(x: x, y: y - 1.45 * r), control1: CGPoint(x: x - r, y: y - 0.75 * r), control2: CGPoint(x: x - 0.35 * r, y: y - 1.2 * r))
      c.addPath(edge); c.setLineWidth(2); c.setStrokeColor(rgb(0xFFFFFF, dark ? 0.22 : 0.28)); c.strokePath()
      let edge2 = CGMutablePath()
      edge2.move(to: CGPoint(x: x, y: y - 1.45 * r))
      edge2.addCurve(to: CGPoint(x: x + r, y: y), control1: CGPoint(x: x + 0.35 * r, y: y - 1.2 * r), control2: CGPoint(x: x + r, y: y - 0.75 * r))
      c.addPath(edge2); c.setLineWidth(2); c.setStrokeColor(rgb(0xFFFFFF, 0.08)); c.strokePath()
    }
    row += 1
  }
  // ember core glowing inside
  let core = CGPoint(x: 512, y: 400)
  c.setBlendMode(.screen)
  c.drawRadialGradient(grad([rgb(0xFFF6DC, 1.0), rgb(0xFFC25A, 0.85), rgb(0xFF6A3C, 0.40), rgb(0xFF5A3C, 0)], [0, 0.2, 0.55, 1]), startCenter: core, startRadius: 0, endCenter: core, endRadius: 260, options: [])
  c.setBlendMode(.normal)
  // inner edge darkening for thickness
  // soft inner edge: blurred dark stroke for glass thickness (no hard ring)
  c.saveGState(); c.setShadow(offset: .zero, blur: 40, color: rgb(0x2A0610, dark ? 0.55 : 0.35))
  c.addPath(CGPath(rect: CGRect(x: -200, y: -200, width: 1424, height: 1424), transform: nil)); c.addPath(egg); c.setFillColor(rgb(0x2A0610, 1)); c.fillPath(using: .evenOdd); c.restoreGState()
  // transmitted light pooling at the bottom inside the glass
  c.saveGState(); c.translateBy(x: 512, y: 260); c.scaleBy(x: 1, y: 0.35)
  c.drawRadialGradient(grad([rgb(0xFFD08A, 0.55), rgb(0xFFD08A, 0)], [0, 1]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 190, options: [])
  c.restoreGState()
  // specular highlight top-left
  c.saveGState(); c.translateBy(x: 430, y: 660); c.rotate(by: 0.55); c.scaleBy(x: 1, y: 0.55)
  c.drawRadialGradient(grad([rgb(0xFFFFFF, 0.75), rgb(0xFFFFFF, 0)], [0, 1]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 110, options: [])
  c.restoreGState()
  c.restoreGState()
  // broken rim: warm light from inside, bright glass edge
  c.saveGState(); c.addPath(egg); c.clip()
  c.saveGState(); c.setShadow(offset: .zero, blur: 24, color: rgb(0xFFC25A, 0.9)); c.addPath(rimLine()); c.setLineWidth(10); c.setLineJoin(.round); c.setStrokeColor(rgb(0xFF9A4C, 0.7)); c.strokePath(); c.restoreGState()
  c.addPath(rimLine()); c.setLineWidth(3.5); c.setLineJoin(.miter); c.setStrokeColor(rgb(0xFFF4DC, 0.95)); c.strokePath()
  c.saveGState(); c.setShadow(offset: .zero, blur: 18, color: rgb(0xFFC25A, 0.9)); c.addPath(crackLine()); c.setLineWidth(7); c.setStrokeColor(rgb(0xFF9A4C, 0.6)); c.strokePath(); c.restoreGState()
  c.addPath(crackLine()); c.setLineWidth(3); c.setStrokeColor(rgb(0xFFF4DC, 0.95)); c.strokePath()
  c.restoreGState()
  // tile glass sheen
  c.drawLinearGradient(grad([rgb(0xFFFFFF, 0), rgb(0xFFFFFF, 0.10)], [0, 1]), start: CGPoint(x: 0, y: 560), end: CGPoint(x: 0, y: 924), options: [])
  c.restoreGState()
  c.saveGState(); c.addPath(tile); c.setLineWidth(3); c.replacePathWithStrokedPath(); c.clip()
  c.drawLinearGradient(grad([rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0.08)], [0, 1]), start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: []); c.restoreGState()
  let full = c.makeImage()!
  if px == 1024 { return full }
  let s = ctx(px); s.interpolationQuality = .high; s.draw(full, in: CGRect(x: 0, y: 0, width: px, height: px)); return s.makeImage()!
}
// usage: swift make-icon.swift <pip.png> <out.iconset>
let out = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  for (scale, suffix) in [(1, ""), (2, "@2x")] {
    let img = render(base * scale, dark: true)
    try! NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
      .write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)\(suffix).png"))
  }
}
