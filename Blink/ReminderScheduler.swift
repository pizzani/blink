import AppKit
import Observation

@MainActor
@Observable
final class ReminderScheduler {
    /// Reminder intervals in seconds. The 30 s option only exists in Debug builds, for testing.
    #if DEBUG
    static let intervalOptions = [30, 5 * 60, 10 * 60, 15 * 60, 20 * 60, 30 * 60, 45 * 60, 60 * 60]
    #else
    static let intervalOptions = [5 * 60, 10 * 60, 15 * 60, 20 * 60, 30 * 60, 45 * 60, 60 * 60]
    #endif

    /// How long the reminder card stays up, in seconds.
    static let breakOptions = [20, 30, 60, 2 * 60, 5 * 60, 10 * 60]

    /// No keyboard/mouse input for this long counts as a break away from the screen.
    private static let idleThreshold: TimeInterval = 5 * 60
    private static let idleCheckInterval: TimeInterval = 15

    private static let intervalKey = "intervalSeconds"
    private static let pausedKey = "isPaused"
    private static let breakKey = "breakSeconds"
    private static let pauseWhenAwayKey = "pauseWhenAway"

    var intervalSeconds: Int {
        didSet {
            UserDefaults.standard.set(intervalSeconds, forKey: Self.intervalKey)
            reschedule()
        }
    }

    var breakSeconds: Int {
        didSet { UserDefaults.standard.set(breakSeconds, forKey: Self.breakKey) }
    }

    var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: Self.pausedKey)
            reschedule()
        }
    }

    /// When off, time without input on this Mac still counts (e.g. working on another machine).
    var pauseWhenAway: Bool {
        didSet {
            UserDefaults.standard.set(pauseWhenAway, forKey: Self.pauseWhenAwayKey)
            checkIdle()
        }
    }

    /// Time left until the next reminder, shown next to the menu bar icon.
    /// `nil` while the countdown is stopped (break, paused, locked or idle).
    private(set) var countdownText: String?

    /// True while the reminder card is up. The countdown waits and restarts once it closes.
    private(set) var isOnBreak = false

    /// First line of the menu: the exact time left, or why the countdown is stopped.
    private(set) var statusText = ""

    private var isLocked = false
    private var isIdle = false

    private let panel = ReminderPanel()
    private var timer: Timer?
    private var idleTimer: Timer?
    private var countdownTimer: Timer?
    private var activity: NSObjectProtocol?

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        intervalSeconds = Self.intervalOptions.contains(stored) ? stored : 20 * 60
        isPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
        let storedBreak = UserDefaults.standard.integer(forKey: Self.breakKey)
        breakSeconds = Self.breakOptions.contains(storedBreak) ? storedBreak : 5 * 60
        pauseWhenAway = UserDefaults.standard.object(forKey: Self.pauseWhenAwayKey) as? Bool ?? true
        panel.onClose = { [weak self] in self?.endBreak() }
    }

    func start() {
        // Menu bar apps have no visible window, so App Nap would otherwise delay the timers.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Eye-break reminders must fire on time"
        )

        // The screen was off while asleep, so the eyes already rested: on wake, end any
        // break in progress (closing the card ends it) and start a fresh interval.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.close()
                self?.reschedule()
            }
        }

        // Stop counting while the screen is locked, and start fresh on unlock.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(true) }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setLocked(false) }
        }

        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.idleCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
        idleTimer?.tolerance = 5

        // .common mode keeps the countdown ticking while the menu is open.
        let countdownTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCountdown() }
        }
        countdownTimer.tolerance = 0.2
        RunLoop.main.add(countdownTimer, forMode: .common)
        self.countdownTimer = countdownTimer

        reschedule()
    }

    func reschedule() {
        defer { updateCountdown() }
        timer?.invalidate()
        timer = nil
        guard !isOnBreak, !isPaused, !isLocked, !isIdle else { return }
        let timer = Timer(timeInterval: TimeInterval(intervalSeconds), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.startBreak() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sendTest() {
        startBreak()
    }

    private func startBreak() {
        guard !isOnBreak else { return }
        isOnBreak = true
        reschedule()
        panel.show(seconds: breakSeconds)
    }

    /// Called when the card closes: its countdown ended, Skip was clicked, or the screen locked.
    private func endBreak() {
        isOnBreak = false
        reschedule()
    }

    /// The menu bar shows minutes while a minute or more is left, then seconds; the
    /// menu shows mm:ss. Only assigns on change, so the menu bar redraws at most
    /// once per displayed unit.
    private func updateCountdown() {
        var text: String?
        let status: String
        if let timer, timer.isValid {
            let remaining = max(0, Int(timer.fireDate.timeIntervalSinceNow.rounded(.up)))
            text = remaining >= 60 ? "\((remaining + 59) / 60)m" : "\(remaining)s"
            let time = String(format: "%d:%02d", remaining / 60, remaining % 60)
            status = String(localized: "Next reminder in \(time)")
        } else if isOnBreak {
            status = String(localized: "Time to blink — look away")
        } else if isPaused {
            status = String(localized: "Reminders paused")
        } else if isIdle {
            status = String(localized: "Away — restarts when you're back")
        } else {
            status = String(localized: "Screen locked")
        }
        if text != countdownText { countdownText = text }
        if status != statusText { statusText = status }
    }

    private func setLocked(_ locked: Bool) {
        isLocked = locked
        if locked { panel.close() }
        reschedule()
    }

    /// After a long stretch without input the eyes already had a break, so the
    /// interval stops while away and restarts from zero once the user is back.
    private func checkIdle() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
        let away = pauseWhenAway && idleSeconds >= Self.idleThreshold

        if away != isIdle {
            isIdle = away
            reschedule()
        }
    }
}
