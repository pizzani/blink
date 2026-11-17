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

        let hosting = NSHostingView(rootView: ReminderCard(
            seconds: seconds,
            onDismiss: { [weak self] in self?.close() },
            // The break ran its full length: chirp so the user knows they can look back. The card
            // stays up (counting the extra time) until they click Continue.
            onTimeUp: { Self.playTweet() }
        ))
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
        Self.playTweet()

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

    private static func playTweet() {
        NSSound(named: "tweet")?.play()
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
    /// Skip during the break, or Continue once it's over.
    let onDismiss: () -> Void
    let onTimeUp: () -> Void

    @State private var remaining: Int

    /// Seconds past the intended break length; `nil` while the break is still running.
    @State private var overtime: Int?

    init(seconds: Int, onDismiss: @escaping () -> Void, onTimeUp: @escaping () -> Void) {
        self.seconds = seconds
        self.onDismiss = onDismiss
        self.onTimeUp = onTimeUp
        _remaining = State(initialValue: seconds)
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Look into the distance during the break; once it's over, the bird waits for the user.
            if overtime == nil {
                PixelLandscape()
            } else {
                PixelWaitingBird()
            }

            HStack(spacing: 10) {
                Image(systemName: "eye")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    if overtime == nil {
                        Text("Time to blink")
                            .font(.headline)
                        Text("Look at something ~6 m (20 ft) away.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Break's over")
                            .font(.headline)
                        Text("Click Continue to start the next interval.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: Double(seconds - remaining), total: Double(seconds))
                .animation(.linear(duration: 1), value: remaining)

            HStack {
                if let overtime {
                    Text("\(Self.clock(overtime)) over")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Continue", action: onDismiss)
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                } else {
                    Text(remaining >= 60 ? Self.clock(remaining) : "\(remaining) s")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Skip", action: onDismiss)
                        .controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .task {
            // Both loops stop when the card closes (Skip, Continue, lock, wake), so time-up
            // only fires for a full break.
            while remaining > 0 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                remaining -= 1
            }
            onTimeUp()
            overtime = 0
            while true {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                overtime? += 1
            }
        }
    }
}
