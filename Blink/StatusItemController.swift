import AppKit
import Observation

/// Menu bar icon and its menu. Built with AppKit rather than SwiftUI's MenuBarExtra
/// because an NSMenu can update item titles while it is open, so the countdown stays live.
@MainActor
final class StatusItemController: NSObject {
    private let scheduler: ReminderScheduler
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let statusMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem()
    private var intervalMenuItems: [NSMenuItem] = []
    private var breakMenuItems: [NSMenuItem] = []

    private var animationTimer: Timer?
    private var animationFrame = 0
    private var animation: Animation?

    private enum Animation {
        /// Countdown running: the hand writes scrolls, with the bird running by now and then.
        case writing
        /// Break: only the bird, running past again and again.
        case bird
        /// Reminders paused: the bird stands around, looks down at the desk and naps.
        case idle

        @MainActor var frames: [NSImage] {
            switch self {
            case .writing: MenuBarAnimation.frames
            case .bird: PixelBird.frames
            case .idle: PixelBird.idleFrames
            }
        }
    }

    init(scheduler: ReminderScheduler) {
        self.scheduler = scheduler
        super.init()

        // Fixed-width digits so the icon doesn't shift as the countdown ticks.
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.menu = makeMenu()
        observe()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        intervalMenuItems = addChoiceMenu(
            to: menu, title: String(localized: "Remind every"), options: ReminderScheduler.intervalOptions, action: #selector(selectInterval(_:))
        )
        breakMenuItems = addChoiceMenu(
            to: menu, title: String(localized: "Break length"), options: ReminderScheduler.breakOptions, action: #selector(selectBreak(_:))
        )

        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        menu.addItem(pauseMenuItem)

        let showItem = NSMenuItem(title: String(localized: "Show reminder now"), action: #selector(showReminder), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Blink"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    /// Adds a submenu with one item per duration (in seconds, stored in each item's tag) and returns the items.
    private func addChoiceMenu(to menu: NSMenu, title: String, options: [Int], action: Selector) -> [NSMenuItem] {
        let submenu = NSMenu()
        let items = options.map { seconds in
            let item = NSMenuItem(title: Self.durationTitle(seconds), action: action, keyEquivalent: "")
            item.target = self
            item.tag = seconds
            submenu.addItem(item)
            return item
        }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
        return items
    }

    /// Re-renders whenever a scheduler property read in `render()` changes.
    private func observe() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            // onChange fires before the new value is stored, so render on the next main-actor turn.
            Task { @MainActor in self?.observe() }
        }
    }

    private func render() {
        if let button = statusItem.button {
            button.title = scheduler.countdownText.map { " \($0)" } ?? ""
        }
        // The hand writes while the countdown runs, the bird runs during a break, the bird
        // idles while paused, and a static eye shows when the countdown is otherwise stopped.
        if scheduler.isOnBreak {
            startAnimation(.bird)
        } else if scheduler.countdownText != nil {
            startAnimation(.writing)
        } else if scheduler.isPaused {
            startAnimation(.idle)
        } else {
            stopAnimation()
            let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Blink")
            image?.isTemplate = true
            statusItem.button?.image = image
        }

        statusMenuItem.title = scheduler.statusText
        pauseMenuItem.title = scheduler.isPaused ? String(localized: "Resume reminders") : String(localized: "Pause reminders")
        for item in intervalMenuItems {
            item.state = item.tag == scheduler.intervalSeconds ? .on : .off
        }
        for item in breakMenuItems {
            item.state = item.tag == scheduler.breakSeconds ? .on : .off
        }
    }

    private func startAnimation(_ animation: Animation) {
        guard animation != self.animation else { return }
        stopAnimation()
        self.animation = animation
        animationFrame = 0
        statusItem.button?.image = animation.frames[0]
        // .common mode keeps it animating while the menu is open.
        let timer = Timer(timeInterval: PixelArt.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceAnimation() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animation = nil
    }

    private func advanceAnimation() {
        guard let frames = animation?.frames else { return }
        animationFrame = (animationFrame + 1) % frames.count
        statusItem.button?.image = frames[animationFrame]
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        scheduler.intervalSeconds = sender.tag
    }

    @objc private func selectBreak(_ sender: NSMenuItem) {
        scheduler.breakSeconds = sender.tag
    }

    @objc private func togglePause() {
        scheduler.isPaused.toggle()
    }

    @objc private func showReminder() {
        scheduler.sendTest()
    }

    private static func durationTitle(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min"
    }
}
