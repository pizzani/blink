// Draws Blink's app icon (the pixel bird on a sky-blue tile) at every macOS size
// and writes the PNGs into the asset catalog.
//
//   swift Tools/make-app-icon.swift Blink/Assets.xcassets/AppIcon.appiconset

import AppKit

/// The standing bird from PixelBird.swift (`poses[1]`), without its empty top and bottom rows.
let bird = [
    "......##..........",
    "....#...######....",
    ".....##.#.....#...",
    ".......#.......#..",
    ".......#....#..##.",
    "##.....#....#..###",
    "#.#....#.......###",
    "#..#....#.....###.",
    ".#..####.....#....",
    ".#............#...",
    ".#..#..........#..",
    ".#...##........#..",
    "..#....##......#..",
    "...#.##.......#...",
    "....#........#....",
    ".....########.....",
    "........#.#.......",
    "........####......",
]

let cloud = [
    "..##......",
    ".####.##..",
    "#########.",
    "##########",
    ".########.",
]

let ink = NSColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1)
let body = NSColor.white
let skyTop = NSColor(red: 0.53, green: 0.80, blue: 0.97, alpha: 1)
let skyBottom = NSColor(red: 0.27, green: 0.56, blue: 0.88, alpha: 1)
let cloudColor = NSColor(white: 1, alpha: 0.55)

/// Cells inside the bird's outline: not ink, and not reachable from the edge of the sprite.
func interior(of art: [String]) -> Set<[Int]> {
    let rows = art.map(Array.init)
    let height = rows.count, width = rows[0].count
    func isInk(_ x: Int, _ y: Int) -> Bool { rows[y][x] == "#" }
    var outside = Set<[Int]>()
    var stack = (0..<width).flatMap { [[$0, 0], [$0, height - 1]] } + (0..<height).flatMap { [[0, $0], [width - 1, $0]] }
    while let cell = stack.popLast() {
        let (x, y) = (cell[0], cell[1])
        guard (0..<width).contains(x), (0..<height).contains(y), !isInk(x, y), !outside.contains(cell) else { continue }
        outside.insert(cell)
        stack += [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]
    }
    var inside = Set<[Int]>()
    for y in 0..<height {
        for x in 0..<width where !isInk(x, y) && !outside.contains([x, y]) {
            inside.insert([x, y])
        }
    }
    return inside
}

/// Draws `art` with each character as a `cell`-sized square, top-left at `origin` (y grows down).
func drawCells(_ art: [String], origin: CGPoint, cell: CGFloat, color: NSColor, canvasHeight: CGFloat, only: Set<[Int]>? = nil) {
    color.setFill()
    for (y, line) in art.enumerated() {
        for (x, char) in line.enumerated() where only.map({ $0.contains([x, y]) }) ?? (char == "#") {
            NSRect(x: origin.x + CGFloat(x) * cell, y: canvasHeight - origin.y - CGFloat(y + 1) * cell, width: cell, height: cell).fill()
        }
    }
}

func renderIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let s = CGFloat(size) / 1024
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .none
    NSGraphicsContext.current = context

    // Rounded-square tile per Apple's macOS icon grid: 824 pt body inside a 1024 pt canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: skyTop, ending: skyBottom)!.draw(in: tilePath, angle: -90)

    // Pixel-sized steps snap to whole device pixels so the art stays crisp.
    let cell = max(1, (30 * s).rounded(.down))
    tilePath.addClip()
    drawCells(cloud, origin: CGPoint(x: 150 * s, y: 160 * s), cell: cell * 0.7, color: cloudColor, canvasHeight: CGFloat(size))
    drawCells(cloud, origin: CGPoint(x: 724 * s, y: 712 * s), cell: cell * 0.6, color: cloudColor, canvasHeight: CGFloat(size))

    let birdWidth = CGFloat(bird[0].count) * cell, birdHeight = CGFloat(bird.count) * cell
    let origin = CGPoint(x: ((CGFloat(size) - birdWidth) / 2).rounded(), y: ((CGFloat(size) - birdHeight) / 2 + 20 * s).rounded())
    drawCells(bird, origin: origin, cell: cell, color: body, canvasHeight: CGFloat(size), only: interior(of: bird))
    drawCells(bird, origin: origin, cell: cell, color: ink, canvasHeight: CGFloat(size))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// Point size and scale for each slot macOS uses.
let slots: [(points: Int, scale: Int)] = [16, 32, 128, 256, 512].flatMap { [($0, 1), ($0, 2)] }
var images: [[String: String]] = []
for slot in slots {
    let name = slot.scale == 1 ? "icon_\(slot.points)x\(slot.points).png" : "icon_\(slot.points)x\(slot.points)@2x.png"
    try renderIcon(size: slot.points * slot.scale).write(to: outputDirectory.appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.points)x\(slot.points)"])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))
print("Wrote \(slots.count) icons to \(outputDirectory.path)")
