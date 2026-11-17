import AppKit

/// Pixel-art menu bar animation: a hand with a pen writing lines on a parchment scroll.
/// Frames are built from the ASCII art below (see `PixelArt` for the pixel grid).
@MainActor
enum PixelWriting {
    private typealias Pixel = PixelArt.Pixel

    /// Rows of empty space above the scroll, so the pen has room on the first line.
    private static let scrollTop = 1

    /// Parchment scroll: curl at the top left, slanted S-shaped sheet, roll at the bottom.
    private static let scroll = [
        "...########################.....",
        "..#.....#..................##...",
        ".#......#...................##..",
        "#.......#....................##.",
        "#.....###.....................#.",
        "#....#...#....................#.",
        "#....#...#....................#.",
        ".#...#...#....................#.",
        ".#...#...#....................#.",
        "..#######.....................#.",
        "........#.....................#.",
        "........#.....................#.",
        "........#.....................#.",
        "........#....................#..",
        "........#....................#..",
        ".......#.....................#..",
        ".......#....................#...",
        ".......#....................#...",
        "......#....................#....",
        "......#....................#....",
        ".....#....................#.....",
        ".....#....................#.....",
        "....#.....................#.....",
        "....#....................#......",
        "...#.....................#......",
        "...#....................#.......",
        "...#....................#.......",
        "..#.....................#.......",
        "..#....................#........",
        "..#....................#........",
        ".#.....................#........",
        ".#....####################......",
        ".#..##..#.................##....",
        ".#..#...#..................#....",
        ".#..#...#..................#....",
        ".#..#####..................#....",
        ".#......#..................#....",
        "..#.....#..................#....",
        "...#########################....",
    ]

    /// Text lines in scroll coordinates: row, first and last column. They start further
    /// left as they go down, following the slant of the sheet.
    private static let lines = [(row: 8, from: 13, to: 26), (row: 14, from: 12, to: 25), (row: 20, from: 10, to: 22), (row: 25, from: 8, to: 20)]

    /// Columns left blank between words, per line.
    private static let wordBreaks: [Set<Int>] = [[18], [16, 21], [15], [13, 17]]

    /// Hand holding a pen. `H` hand, `P` pen, `T` pen tip, which sits on the writing position.
    /// Everything around the hand and pen is cleared so they stand out over the scroll.
    private static let pen = [
        "................PP",
        "..............PPPP",
        "............PPPP..",
        "..........PPPP....",
        ".......HHHPP......",
        ".....HHHHHHH......",
        "....PHHHHHHH......",
        "...PPHHHHHHH......",
        "..PP.H.HHH........",
        "TP....H...........",
    ]

    /// Blank pause before writing, and how long the finished scroll stays up.
    private static let startFrames = 3
    private static let holdFrames = 8

    static let frames: [NSImage] = makeFrames()

    private static func makeFrames() -> [NSImage] {
        let total = lines.reduce(0) { $0 + $1.to - $1.from + 1 }
        let progress = Array(repeating: 0, count: startFrames) + Array(1...total) + Array(repeating: total, count: holdFrames)
        return progress.enumerated().map { index, written in
            frame(written: written, bob: written < total ? index % 2 : 0)
        }
    }

    /// Where the pen tip is after `written` columns, in icon coordinates.
    private static func tip(written: Int) -> Pixel {
        var remaining = written
        for line in lines {
            let length = line.to - line.from + 1
            if remaining <= length {
                return Pixel(x: line.from + max(remaining, 1), y: line.row + scrollTop)
            }
            remaining -= length
        }
        let last = lines[lines.count - 1]
        return Pixel(x: last.to + 2, y: last.row + scrollTop)
    }

    /// The first `written` columns of text are inked; the pen lifts by `bob` pixels, like it's forming letters.
    private static func frame(written: Int, bob: Int) -> NSImage {
        var pixels = PixelArt.pixels(of: scroll, at: Pixel(x: 0, y: scrollTop))

        var ink = Set<Pixel>()
        var remaining = written
        for (line, breaks) in zip(lines, wordBreaks) {
            for x in line.from...line.to where remaining > 0 {
                if !breaks.contains(x) { ink.insert(Pixel(x: x, y: line.row + scrollTop)) }
                remaining -= 1
            }
        }
        pixels.formUnion(ink)

        let tip = tip(written: written)
        var penPixels = Set<Pixel>()
        let tipRow = pen.count - 1
        for (row, line) in pen.enumerated() {
            for (column, char) in line.enumerated() where char != "." {
                penPixels.insert(Pixel(x: tip.x + column, y: tip.y - bob - (tipRow - row)))
            }
        }
        for pixel in penPixels {
            for dx in -1...1 {
                for dy in -1...1 {
                    pixels.remove(Pixel(x: pixel.x + dx, y: pixel.y + dy))
                }
            }
        }
        // Keep the freshly written ink right behind the nib.
        pixels.formUnion(ink.filter { $0.y == tip.y && $0.x < tip.x })
        pixels.formUnion(penPixels)

        return PixelArt.image(pixels)
    }
}
