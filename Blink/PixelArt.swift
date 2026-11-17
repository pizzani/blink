import AppKit

/// Shared helpers for the menu bar pixel art. One pixel is half a point,
/// i.e. one physical pixel on Retina.
enum PixelArt {
    static let width = 46
    static let height = 40
    static let pixelSize: CGFloat = 0.5

    static let frameInterval: TimeInterval = 0.15

    struct Pixel: Hashable {
        let x: Int
        let y: Int
    }

    /// Pixels for the `#` characters of `art`, with its top-left corner at `origin`.
    static func pixels(of art: [String], at origin: Pixel = Pixel(x: 0, y: 0)) -> Set<Pixel> {
        var pixels = Set<Pixel>()
        for (row, line) in art.enumerated() {
            for (column, char) in line.enumerated() where char == "#" {
                pixels.insert(Pixel(x: origin.x + column, y: origin.y + row))
            }
        }
        return pixels
    }

    /// A template image (adapts to light and dark menu bars); pixels outside the canvas are dropped.
    static func image(_ pixels: Set<Pixel>) -> NSImage {
        let size = NSSize(width: CGFloat(width) * pixelSize, height: CGFloat(height) * pixelSize)
        let image = NSImage(size: size, flipped: true) { _ in
            NSColor.black.setFill()
            for pixel in pixels where (0..<width).contains(pixel.x) && (0..<height).contains(pixel.y) {
                NSRect(
                    x: CGFloat(pixel.x) * pixelSize, y: CGFloat(pixel.y) * pixelSize,
                    width: pixelSize, height: pixelSize
                ).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The full menu bar loop: a few written scrolls, then the bird runs past.
@MainActor
enum MenuBarAnimation {
    private static let scrollsPerBird = 3

    static let frames: [NSImage] =
        Array(repeating: PixelWriting.frames, count: scrollsPerBird).flatMap { $0 } + PixelBird.frames
}
