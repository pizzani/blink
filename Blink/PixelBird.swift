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

    // MARK: Idle (reminders paused): standing in the menu bar, looking down at the desk,
    // glancing around and dozing off.

    /// Looking down at the desk: pupil low, beak tipped down.
    private static let lookingDown = [
        "..................",
        "......##..........",
        "....#...######....",
        ".....##.#.....#...",
        ".......#.......#..",
        ".......#..........",
        "##.....#....#..##.",
        "#.#....#....#..###",
        "#..#....#.....####",
        ".#..####.....#.##.",
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
    ]

    /// Eye closed for a blink.
    private static let blinking = [
        "..................",
        "......##..........",
        "....#...######....",
        ".....##.#.....#...",
        ".......#.......#..",
        ".......#.......##.",
        "##.....#....##.###",
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
    ]

    /// Asleep: eye shut, beak tipped down.
    private static let asleep = [
        "..................",
        "......##..........",
        "....#...######....",
        ".....##.#.....#...",
        ".......#.......#..",
        ".......#..........",
        "##.....#.......##.",
        "#.#....#...###.###",
        "#..#....#.....####",
        ".#..####.....#.##.",
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
    ]

    /// Sleeping "z"s rising from the bird, drawn in fine half-point pixels in the top-right corner.
    private static let sleepZs: [(art: [String], origin: PixelArt.Pixel)] = [
        (["###", ".#.", "###"], PixelArt.Pixel(x: 37, y: 8)),
        (["####", "..#.", ".#..", "####"], PixelArt.Pixel(x: 39, y: 4)),
        (["#####", "...#.", "..#..", ".#...", "#####"], PixelArt.Pixel(x: 41, y: 0)),
    ]

    // MARK: Waiting (break over): standing on the floor, tapping a foot until the user comes back.

    /// Waiting poses, one per animation tick: tap-tap-tap, a pause, a blink.
    static let waitingPoses: [[String]] = {
        let standing = poses[1]
        // Front foot lifted and kicked forward; the back foot stays down.
        var footUp = standing
        footUp[17] = "........#..##....."
        footUp[18] = "........##........"
        // Foot back on the floor, with a little tap mark beside it.
        var tap = standing
        tap[17] = "........#.#...#..."
        tap[18] = "........####.#...."
        var sequence: [[String]] = []
        for _ in 0..<3 {
            sequence += [footUp, footUp, tap, standing]
        }
        sequence += Array(repeating: standing, count: 6) + [blinking] + Array(repeating: standing, count: 3)
        return sequence
    }()

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

    /// Idle loop while reminders are paused: look down, blink, glance back, then a nap. About 18 s.
    static let idleFrames: [NSImage] = {
        let standing = poses[1]
        let turned = lookingDown.map { String($0.reversed()) }
        var sequence: [(pose: [String], zs: Int)] = []
        func hold(_ pose: [String], _ frames: Int) {
            sequence += Array(repeating: (pose, 0), count: frames)
        }
        hold(lookingDown, 14)
        hold(blinking, 1)
        hold(lookingDown, 10)
        hold(standing, 6)
        hold(turned, 12)
        hold(standing, 4)
        hold(blinking, 1)
        hold(lookingDown, 12)
        for _ in 0..<5 {
            for zs in 1...sleepZs.count {
                sequence += Array(repeating: (asleep, zs), count: 4)
            }
        }
        hold(blinking, 1)

        return sequence.map { pose, zs in
            var pixels = PixelArt.pixels(of: pose, scale: scale)
            for z in sleepZs.prefix(zs) {
                pixels.formUnion(PixelArt.pixels(of: z.art, at: z.origin))
            }
            return PixelArt.image(pixels)
        }
    }()
}
