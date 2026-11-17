import AppKit
import SwiftUI

/// Always-on-top card shown in the top-right corner. It never takes focus,
/// so it doesn't interrupt typing.
@MainActor
final class ReminderPanel {
    private var panel: NSPanel?

    /// Called once each time the card goes away, however it was closed.
    var onClose: (() -> Void)?

    func show(seconds: Int) {
        guard panel == nil else { return }

        let hosting = NSHostingView(rootView: ReminderCard(seconds: seconds) { [weak self] in
            self?.close()
        })
        let size = hosting.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.setFrameOrigin(Self.topRightOrigin(for: size))

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; panel.animator().alphaValue = 1 }
        NSSound(named: "tweet")?.play()

        self.panel = panel
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        onClose?()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private static func topRightOrigin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        let margin: CGFloat = 16
        return NSPoint(x: frame.maxX - size.width - margin, y: frame.maxY - size.height - margin)
    }
}

private struct ReminderCard: View {
    let seconds: Int
    let onFinish: () -> Void

    @State private var remaining: Int

    init(seconds: Int, onFinish: @escaping () -> Void) {
        self.seconds = seconds
        self.onFinish = onFinish
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelLandscape()

            HStack(spacing: 10) {
                Image(systemName: "eye")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time to blink")
                        .font(.headline)
                    Text("Look at something ~6 m (20 ft) away.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(seconds - remaining), total: Double(seconds))
                .animation(.linear(duration: 1), value: remaining)

            HStack {
                Text(remaining >= 60 ? String(format: "%d:%02d", remaining / 60, remaining % 60) : "\(remaining) s")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Skip", action: onFinish)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            onFinish()
        }
    }
}
