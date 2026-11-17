import SwiftUI

/// Shown on the break card once the break is over, in place of the scenery: the bird
/// stands on the floor tapping its foot, waiting for the user to click Continue.
/// Same size and one-color chunky pixel style as `PixelLandscape`.
struct PixelWaitingBird: View {
    private static let columns = 67
    private static let rows = 28
    private static let cell: CGFloat = 4

    /// Row of the floor line the bird stands on.
    private static let floor = 25

    var body: some View {
        TimelineView(.periodic(from: .now, by: PixelArt.frameInterval)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / PixelArt.frameInterval)
            let poses = PixelBird.waitingPoses
            let pose = poses[tick % poses.count]
            let (cell, columns, floor) = (Self.cell, Self.columns, Self.floor)
            Canvas { canvas, _ in
                var path = Path()
                func fill(_ x: Int, _ y: Int, width: Int = 1) {
                    path.addRect(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: CGFloat(width) * cell, height: cell))
                }
                // The sprite's feet sit on its second-to-last row; put them right on the floor.
                let left = (columns - pose[0].count) / 2
                let top = floor - (pose.count - 1)
                for (row, line) in pose.enumerated() {
                    for (column, char) in line.enumerated() where char == "#" {
                        fill(left + column, top + row)
                    }
                }
                fill(0, floor, width: columns)
                canvas.fill(path, with: .color(.primary))
            }
        }
        .frame(width: CGFloat(Self.columns) * Self.cell, height: CGFloat(Self.rows) * Self.cell)
    }
}

#Preview {
    PixelWaitingBird()
        .padding()
}
