import AppKit

/// An original pixel-art running bird in a chunky outlined style: big head and beak,
/// swept-back crest, wing raised at the back. It sprints across the menu bar icon from left to right.
@MainActor
enum PixelBird {
    /// Run cycle: full stride, then legs passing (body bobs down a pixel).
    private static let poses = [
        [
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
            ".......#..#.......",
            "......#....#......",
            "....##......##....",
            "..................",
        ],
        [
            "..................",
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
            "..................",
        ],
    ]

    /// Each art character is drawn as a `scale`×`scale` block, i.e. one point.
    private static let scale = 2

    /// Pixels the bird moves per frame.
    private static let speed = 4

    static let frames: [NSImage] = {
        let spriteWidth = poses[0][0].count * scale
        let top = PixelArt.height - poses[0].count * scale
        return stride(from: -spriteWidth, through: PixelArt.width, by: speed).enumerated().map { step, x in
            let pose = poses[step % poses.count]
            return PixelArt.image(PixelArt.pixels(of: pose, at: PixelArt.Pixel(x: x, y: top), scale: scale))
        }
    }()
}
