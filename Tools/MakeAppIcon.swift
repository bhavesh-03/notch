// Draws the Notch app icon and writes every size the asset catalog needs.
//
// Usage (from the repository root):
//   swiftc Tools/MakeAppIcon.swift -o /tmp/MakeAppIcon && /tmp/MakeAppIcon Notch/Resources/Assets.xcassets/AppIcon.appiconset
//
// Each size is drawn from the vector code at its own pixel size, so small icons stay crisp.

import AppKit

/// Draws the icon on a 1024-unit canvas, following Apple's macOS template: an 824-unit
/// rounded-square body centred on the canvas, with a soft drop shadow.
///
/// "Midnight island": a graphite tile with a warm glow, and the notch opened up the way the app
/// opens it, showing a timer ring and music bars. At the smallest sizes (16 and 32 px) the details
/// are drawn bolder and fewer, so they still read.
func drawIcon(in ctx: CGContext, scale: CGFloat) {
    let pixels = 1024 * scale
    let small = pixels <= 32
    // Shadow blur and offset are in device pixels (the CTM doesn't scale them), so scale them by hand.
    func shadow(_ dy: CGFloat, _ blur: CGFloat) -> (CGSize, CGFloat) { (CGSize(width: 0, height: dy * scale), blur * scale) }
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let corner: CGFloat = 185.4
    let bodyPath = CGPath(roundedRect: body, cornerWidth: corner, cornerHeight: corner, transform: nil)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha])!
    }

    // Drop shadow under the body
    ctx.saveGState()
    let (o1, b1) = shadow(-12, 28); ctx.setShadow(offset: o1, blur: b1, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath); ctx.setFillColor(color(0x000000)); ctx.fillPath()
    ctx.restoreGState()

    // Graphite body, with the accent's warm glow spilling from under the island
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    let graphite = CGGradient(colorsSpace: space, colors: [color(0x2A2D36), color(0x0B0C10)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(graphite, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [color(0xF59E4A, 0.55), color(0xE0567A, 0.25), color(0xE0567A, 0)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0, endCenter: CGPoint(x: 512, y: 560), endRadius: 430, options: [])

    // The island: flush with the top edge, square top corners, round bottom ones. Drawn inside the
    // body's clip, so its top corners never poke past the body's rounded ones.
    let island = CGRect(x: 170, y: 924 - 420, width: 684, height: 420)
    let r: CGFloat = 150
    let islandPath = CGMutablePath()
    islandPath.move(to: CGPoint(x: island.minX, y: island.maxY))
    islandPath.addLine(to: CGPoint(x: island.maxX, y: island.maxY))
    islandPath.addLine(to: CGPoint(x: island.maxX, y: island.minY + r))
    islandPath.addArc(tangent1End: CGPoint(x: island.maxX, y: island.minY), tangent2End: CGPoint(x: island.maxX - r, y: island.minY), radius: r)
    islandPath.addLine(to: CGPoint(x: island.minX + r, y: island.minY))
    islandPath.addArc(tangent1End: CGPoint(x: island.minX, y: island.minY), tangent2End: CGPoint(x: island.minX, y: island.minY + r), radius: r)
    islandPath.closeSubpath()
    ctx.saveGState()
    let (o2, b2) = shadow(-14, 40); ctx.setShadow(offset: o2, blur: b2, color: color(0x000000, 0.6))
    ctx.addPath(islandPath); ctx.setFillColor(color(0x000000)); ctx.fillPath()
    ctx.restoreGState()
    ctx.restoreGState()

    // Left: a timer ring, two-thirds run, in the accent
    let ringCentre = CGPoint(x: 352, y: 660)
    let ringWidth: CGFloat = small ? 40 : 26
    ctx.setLineCap(.round)
    ctx.setStrokeColor(color(0xFFFFFF, 0.14)); ctx.setLineWidth(ringWidth)
    ctx.addArc(center: ringCentre, radius: 78, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
    ctx.setStrokeColor(color(0xF59E4A)); ctx.setLineWidth(ringWidth)
    ctx.addArc(center: ringCentre, radius: 78, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.35, clockwise: true); ctx.strokePath()

    // Right: music bars (three bold ones when small)
    let bars: [CGFloat] = small ? [90, 150, 110] : [70, 130, 96, 150, 84]
    let barGap: CGFloat = small ? 72 : 52
    let barWidth: CGFloat = small ? 44 : 30
    let firstBar = 700 - barGap * CGFloat(bars.count - 1) / 2
    ctx.setStrokeColor(color(0xFFFFFF)); ctx.setLineWidth(barWidth)
    for (i, height) in bars.enumerated() {
        let x = firstBar + CGFloat(i) * barGap
        ctx.move(to: CGPoint(x: x, y: 660 - height / 2)); ctx.addLine(to: CGPoint(x: x, y: 660 + height / 2)); ctx.strokePath()
    }

    // A glass rim: light catching the top edge, fainter at the bottom
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 3, dy: 3), cornerWidth: corner - 3, cornerHeight: corner - 3, transform: nil))
    ctx.setLineWidth(6)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let rim = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.35), color(0xFFFFFF, 0), color(0xFFFFFF, 0.14)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()
}

func render(pixels: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    cg.interpolationQuality = .high
    cg.setShouldAntialias(true)
    cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: cg, scale: CGFloat(pixels) / 1024)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

guard CommandLine.arguments.count > 1 else {
    print("usage: MakeAppIcon <output folder>")
    exit(1)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    render(pixels: pixels, to: out.appendingPathComponent("icon_\(pixels).png"))
}
