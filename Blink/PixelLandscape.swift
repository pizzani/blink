import SwiftUI

/// Pixel-art view into the distance for the break card: sky with a sun and drifting
/// clouds, a city skyline and trees. Looking far away is the point of the break.
struct PixelLandscape: View {
    private static let columns = 67
    private static let rows = 28
    private static let cell: CGFloat = 4

    /// Row where the ground starts; buildings stand on it.
    private static let horizon = 22

    private static let buildings: [(x: Int, width: Int, height: Int)] = [
        (1, 6, 9), (8, 4, 13), (13, 7, 7), (21, 5, 11), (27, 8, 15),
        (36, 4, 8), (41, 6, 12), (48, 5, 6), (54, 7, 10), (62, 5, 13),
    ]

    /// Trees in front of the buildings: trunk column and canopy radius.
    private static let trees: [(x: Int, radius: Int)] = [(5, 4), (18, 3), (33, 4), (46, 3), (60, 4)]

    private static let cloud = [
        "...###....",
        ".#######..",
        "##########",
        ".########.",
    ]

    /// Starting column and row of each cloud; they drift right and wrap around.
    private static let clouds: [(x: Int, y: Int)] = [(4, 3), (40, 8)]

    private enum Palette {
        static let sky = [Color(hex: 0x4A7BD0), Color(hex: 0x6A9BE0), Color(hex: 0x8DB9EE), Color(hex: 0xB5D6F5)]
        static let sun = Color(hex: 0xFFD55A)
        static let sunCore = Color(hex: 0xFFF1B0)
        static let cloud = Color.white
        static let cloudShade = Color(hex: 0xDCE8F5)
        static let building = Color(hex: 0x7C8AA5)
        static let buildingEdge = Color(hex: 0x66738C)
        static let window = Color(hex: 0xFFE08A)
        static let grass = Color(hex: 0x6DBE5A)
        static let grassDark = Color(hex: 0x55A246)
        static let leaves = Color(hex: 0x3E9B4F)
        static let leavesLight = Color(hex: 0x5DBB63)
        static let trunk = Color(hex: 0x8A5A3B)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Canvas { canvas, _ in
                let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
                Self.draw(in: &canvas, tick: tick)
            }
        }
        .frame(width: CGFloat(Self.columns) * Self.cell, height: CGFloat(Self.rows) * Self.cell)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static func draw(in canvas: inout GraphicsContext, tick: Int) {
        func fill(_ x: Int, _ y: Int, _ width: Int = 1, _ height: Int = 1, _ color: Color) {
            canvas.fill(
                Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: CGFloat(width) * cell, height: CGFloat(height) * cell)),
                with: .color(color)
            )
        }

        // Sky in bands, dithered where they meet.
        let bandHeight = (horizon + Palette.sky.count - 1) / Palette.sky.count
        for y in 0..<horizon {
            let band = min(y / bandHeight, Palette.sky.count - 1)
            fill(0, y, columns, 1, Palette.sky[band])
            if y % bandHeight == bandHeight - 1, band + 1 < Palette.sky.count {
                for x in stride(from: y % 2, to: columns, by: 2) {
                    fill(x, y, 1, 1, Palette.sky[band + 1])
                }
            }
        }

        // Sun.
        let sun = (x: 57, y: 5)
        for dx in -3...3 {
            for dy in -3...3 where dx * dx + dy * dy <= 10 {
                fill(sun.x + dx, sun.y + dy, 1, 1, dx * dx + dy * dy <= 2 ? Palette.sunCore : Palette.sun)
            }
        }

        // Clouds drift one column every other tick and wrap around.
        let cloudWidth = cloud[0].count
        for start in clouds {
            let x = (start.x + tick / 2) % (columns + cloudWidth) - cloudWidth
            for (row, line) in cloud.enumerated() {
                for (column, char) in line.enumerated() where char == "#" {
                    fill(x + column, start.y + row, 1, 1, row == cloud.count - 1 ? Palette.cloudShade : Palette.cloud)
                }
            }
        }

        // Skyline with a few lit windows.
        for (index, building) in buildings.enumerated() {
            let top = horizon - building.height
            fill(building.x, top, building.width, building.height, Palette.building)
            fill(building.x + building.width - 1, top, 1, building.height, Palette.buildingEdge)
            for y in stride(from: top + 1, to: horizon - 1, by: 2) {
                for x in stride(from: building.x + 1, to: building.x + building.width - 1, by: 2)
                where (x * 7 + y * 13 + index) % 3 != 0 {
                    fill(x, y, 1, 1, Palette.window)
                }
            }
        }

        // Ground.
        fill(0, horizon, columns, rows - horizon, Palette.grass)
        fill(0, rows - 2, columns, 2, Palette.grassDark)

        // Trees: round canopy with a lighter top-left, on a short trunk.
        for tree in trees {
            let center = (x: tree.x, y: horizon - tree.radius)
            fill(tree.x, horizon - 1, 1, 3, Palette.trunk)
            let r2 = tree.radius * tree.radius + 1
            for dx in -tree.radius...tree.radius {
                for dy in -tree.radius...tree.radius where dx * dx + dy * dy <= r2 {
                    let light = dx < 0 && dy < 0 && dx * dx + dy * dy >= r2 / 3
                    fill(center.x + dx, center.y + dy, 1, 1, light ? Palette.leavesLight : Palette.leaves)
                }
            }
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    PixelLandscape()
        .padding()
}
