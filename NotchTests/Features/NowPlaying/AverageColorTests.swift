import AppKit
import Testing
@testable import Notch

@MainActor
struct AverageColorTests {
    private func image(_ fill: @escaping (NSRect) -> Void) -> NSImage {
        NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            fill(rect)
            return true
        }
    }

    private func components(_ color: NSColor?) -> (r: Double, g: Double, b: Double)? {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
    }

    @Test func aSolidImageAveragesToItsColor() throws {
        let c = try #require(components(image { NSColor.red.setFill(); $0.fill() }.averageColor))
        #expect(c.r > 0.9 && c.g < 0.1 && c.b < 0.1)
    }

    @Test func halfAndHalfAveragesToTheMix() throws {
        let c = try #require(components(image { rect in
            NSColor.red.setFill(); NSRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
            NSColor.blue.setFill(); NSRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height).fill()
        }.averageColor))
        #expect(abs(c.r - 0.5) < 0.1 && abs(c.b - 0.5) < 0.1 && c.g < 0.1)
    }

    @Test func transparentAreasDarkenTowardsBlack() throws {
        let c = try #require(components(image { rect in
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
        }.averageColor))
        #expect(abs(c.r - 0.5) < 0.1 && abs(c.g - 0.5) < 0.1)
    }
}
