import AppKit
import Observation

@MainActor
@Observable
final class ReminderScheduler {
    static let intervalOptions = [5, 10, 15, 20, 30, 45, 60]

    private static let intervalKey = "intervalMinutes"
    private static let pausedKey = "isPaused"

    var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Self.intervalKey)
            reschedule()
        }
    }

    var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: Self.pausedKey)
            reschedule()
        }
    }

    private let panel = ReminderPanel()
    private var timer: Timer?

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        intervalMinutes = stored > 0 ? stored : 20
        isPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
    }

    func start() {
        // The screen was off while asleep, so start a fresh interval on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reschedule() }
        }
        reschedule()
    }

    func reschedule() {
        timer?.invalidate()
        timer = nil
        guard !isPaused else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.show() }
        }
    }

    func sendTest() {
        panel.show()
    }
}
