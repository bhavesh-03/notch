// Draws the Notch app icon and writes every size the asset catalog needs.
//
// Usage (from the repository root):
//   swiftc Tools/MakeAppIcon.swift -o /tmp/MakeAppIcon && /tmp/MakeAppIcon Notch/Resources/Assets.xcassets/AppIcon.appiconset
//
// Each size is drawn from the vector code at its own pixel size, so small icons stay crisp.

import AppKit

/// Draws the icon on a 1024-unit canvas, following Apple's macOS template:
/// an 824-unit rounded-square body centred on the canvas, with a soft drop shadow.
func drawIcon(in ctx: CGContext, scale: CGFloat) {
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

    // Sunset "screen" gradient (top of canvas is maxY in Core Graphics)
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    let sky = CGGradient(colorsSpace: space, colors: [color(0x2B1B5A), color(0x7A2E8E), color(0xE0567A), color(0xF7A85C)] as CFArray, locations: [0, 0.38, 0.72, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Soft glow behind the notch
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 760), startRadius: 0, endCenter: CGPoint(x: 512, y: 760), endRadius: 420, options: [])

    // The notch: flush with the top edge, square top corners, rounded bottom corners
    let notch = CGRect(x: 192, y: 924 - 250, width: 640, height: 250)
    let r: CGFloat = 96
    let notchPath = CGMutablePath()
    notchPath.move(to: CGPoint(x: notch.minX, y: notch.maxY))
    notchPath.addLine(to: CGPoint(x: notch.maxX, y: notch.maxY))
    notchPath.addLine(to: CGPoint(x: notch.maxX, y: notch.minY + r))
    notchPath.addArc(tangent1End: CGPoint(x: notch.maxX, y: notch.minY), tangent2End: CGPoint(x: notch.maxX - r, y: notch.minY), radius: r)
    notchPath.addLine(to: CGPoint(x: notch.minX + r, y: notch.minY))
    notchPath.addArc(tangent1End: CGPoint(x: notch.minX, y: notch.minY), tangent2End: CGPoint(x: notch.minX, y: notch.minY + r), radius: r)
    notchPath.closeSubpath()
    ctx.saveGState()
    let (o2, b2) = shadow(-10, 30); ctx.setShadow(offset: o2, blur: b2, color: color(0x000000, 0.45))
    ctx.addPath(notchPath); ctx.setFillColor(color(0x050506)); ctx.fillPath()
    ctx.restoreGState()

    // Camera lens, centred near the top of the notch
    ctx.setFillColor(color(0x1C1E26)); ctx.fillEllipse(in: CGRect(x: 512 - 30, y: 924 - 88, width: 60, height: 60))
    ctx.setFillColor(color(0x2E3B63)); ctx.fillEllipse(in: CGRect(x: 512 - 13, y: 924 - 71, width: 26, height: 26))

    // Left ear: a green battery
    let battery = CGRect(x: 262, y: notch.minY + 70, width: 118, height: 62)
    ctx.setStrokeColor(color(0xFFFFFF, 0.9)); ctx.setLineWidth(9)
    ctx.addPath(CGPath(roundedRect: battery, cornerWidth: 18, cornerHeight: 18, transform: nil)); ctx.strokePath()
    ctx.setFillColor(color(0xFFFFFF, 0.9))
    ctx.addPath(CGPath(roundedRect: CGRect(x: battery.maxX + 8, y: battery.midY - 14, width: 11, height: 28), cornerWidth: 5, cornerHeight: 5, transform: nil)); ctx.fillPath()
    ctx.setFillColor(color(0x34D058))
    ctx.addPath(CGPath(roundedRect: battery.insetBy(dx: 15, dy: 15).divided(atDistance: (battery.width - 30) * 0.8, from: .minXEdge).slice, cornerWidth: 7, cornerHeight: 7, transform: nil)); ctx.fillPath()

    // Right ear: sound bars
    let heights: [CGFloat] = [46, 84, 62, 100, 54]
    for (i, h) in heights.enumerated() {
        let x = 632 + CGFloat(i) * 26
        ctx.setFillColor(color(0xFFFFFF, 0.92))
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: battery.midY - h / 2, width: 14, height: h), cornerWidth: 7, cornerHeight: 7, transform: nil)); ctx.fillPath()
    }
    ctx.restoreGState()

    // Subtle top highlight on the body edge
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.setStrokeColor(color(0xFFFFFF, 0.10)); ctx.setLineWidth(3); ctx.strokePath()
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
