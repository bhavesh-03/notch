import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

extension NSImage {
    /// The true mean color of every pixel, composited over black so transparent corners darken it
    /// slightly (which suits a tint behind it on the black notch).
    ///
    /// Core Image's area-average filter is used because drawing an image into a single pixel only
    /// samples part of it, which skews the result.
    var averageColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let image = CIImage(cgImage: cgImage)
        let extent = image.extent
        let onBlack = image.composited(over: CIImage(color: .black).cropped(to: extent))

        let filter = CIFilter.areaAverage()
        filter.inputImage = onBlack
        filter.extent = extent
        guard let output = filter.outputImage else { return nil }

        // Convert everything to sRGB first (icons and drawings may be Display P3), then average there.
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: sRGB])
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: sRGB)

        return NSColor(srgbRed: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }
}
