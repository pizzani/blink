import SwiftUI

/// Pixel-art view into the distance for the break card: a sun and drifting clouds,
/// a city skyline and trees. Looking far away is the point of the break.
///
/// Drawn like the menu bar icons: one color (the primary text color, so it adapts to
/// light and dark) on chunky pixels. Shapes are painted back to front into a grid of
/// layers; solid shapes keep a one-pixel gap around them so they stand out from what's behind.
struct PixelLandscape: View {
    private static let columns = 67
    private static let rows = 28
    private static let cell: CGFloat = 4

    /// Row where the ground starts; buildings stand on it.
    private static let horizon = 22

    private static let buildings: [(x: Int, width: Int, height: Int)] = [
        (1, 6, 9), (8, 4, 13), (13, 7, 7), (21, 5, 11), (27, 8, 15),
        (41, 6, 12), (48, 5, 6), (54, 7, 10), (62, 5, 13),
    ]

    /// Trees in front of the buildings: trunk column and canopy radius.
    private static let trees: [(x: Int, radius: Int)] = [(12, 2), (37, 2), (51, 2)]

    private static let sun = (x: 58, y: 4, radius: 3)

    private static let cloud = [
        "..##......",
        ".####.##..",
        "#########.",
        "##########",
        ".########.",
    ]

    /// Starting column and row of each cloud; they drift right and wrap around.
    private static let clouds: [(x: Int, y: Int)] = [(4, 1), (34, 3)]

    private enum Style {
        /// Only the edge is drawn.
        case outline
        /// Filled, with an optional pattern of holes (windows, leaves).
        case solid(holes: (Int, Int) -> Bool)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Canvas { canvas, _ in
                let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
                var path = Path()
                for (index, inked) in Self.ink(tick: tick).enumerated() where inked {
                    path.addRect(CGRect(
                        x: CGFloat(index % Self.columns) * Self.cell, y: CGFloat(index / Self.columns) * Self.cell,
                        width: Self.cell, height: Self.cell
                    ))
                }
                canvas.fill(path, with: .color(.primary))
            }
        }
        .frame(width: CGFloat(Self.columns) * Self.cell, height: CGFloat(Self.rows) * Self.cell)
    }

    /// Which cells are inked for this tick (row-major).
    private static func ink(tick: Int) -> [Bool] {
        // Layer per cell, painted back to front; 0 is the empty sky. styles[layer] says how to draw it.
        var layers = [Int](repeating: 0, count: columns * rows)
        var styles: [Style] = [.outline]
        func paint(_ style: Style, _ isInside: (Int, Int) -> Bool) {
            let layer = styles.count
            styles.append(style)
            for y in 0..<rows {
                for x in 0..<columns where isInside(x, y) {
                    layers[y * columns + x] = layer
                }
            }
        }

        paint(.outline) { x, y in
            let dx = x - sun.x, dy = y - sun.y
            return dx * dx + dy * dy <= sun.radius * sun.radius + 1
        }

        // Clouds drift one column every other tick and wrap around.
        let cloudWidth = cloud[0].count
        let cloudRows = cloud.map(Array.init)
        for start in clouds {
            let left = (start.x + tick / 2) % (columns + cloudWidth) - cloudWidth
            paint(.outline) { x, y in
                let column = x - left, row = y - start.y
                return cloudRows.indices.contains(row) && (0..<cloudWidth).contains(column) && cloudRows[row][column] == "#"
            }
        }

        // Buildings: solid, with a grid of windows of which some are dark.
        for (index, building) in buildings.enumerated() {
            let top = horizon - building.height
            let windows: (Int, Int) -> Bool = { x, y in
                let column = x - building.x, row = y - top
                return column % 2 == 1 && column < building.width - 1 && row % 2 == 1 && row < building.height - 1
                    && (x * 7 + y * 13 + index) % 3 != 0
            }
            paint(.solid(holes: windows)) { x, y in
                (building.x..<building.x + building.width).contains(x) && (top..<horizon).contains(y)
            }
        }

        paint(.outline) { _, y in y >= horizon }

        // Trees: solid round canopy on a one-pixel trunk.
        for tree in trees {
            let centerY = horizon - tree.radius - 2
            paint(.solid(holes: { _, _ in false })) { x, y in
                let dx = x - tree.x, dy = y - centerY
                return dx * dx + dy * dy <= tree.radius * tree.radius + 1 || (x == tree.x && (centerY...horizon).contains(y))
            }
        }

        func layer(_ x: Int, _ y: Int) -> Int? {
            (0..<columns).contains(x) && (0..<rows).contains(y) ? layers[y * columns + x] : nil
        }

        var ink = [Bool](repeating: false, count: columns * rows)
        for y in 0..<rows {
            for x in 0..<columns {
                let current = layers[y * columns + x]
                guard current > 0 else { continue }

                // Leave a gap where a solid shape in front touches this one.
                let nearSolidInFront = (-1...1).contains { dx in
                    (-1...1).contains { dy in
                        guard let other = layer(x + dx, y + dy), other > current else { return false }
                        if case .solid = styles[other] { return true }
                        return false
                    }
                }
                if nearSolidInFront { continue }

                switch styles[current] {
                case .outline:
                    ink[y * columns + x] = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { nx, ny in
                        (layer(nx, ny) ?? current) < current
                    }
                case .solid(let holes):
                    ink[y * columns + x] = !holes(x, y)
                }
            }
        }

        // A few tufts of grass.
        for x in stride(from: 3, to: columns, by: 7) {
            let y = horizon + 2 + (x * 5) % 4
            if y < rows { ink[y * columns + x] = true }
        }

        return ink
    }
}

#Preview {
    PixelLandscape()
        .padding()
}
