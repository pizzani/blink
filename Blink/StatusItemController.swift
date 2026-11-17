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

    private var animationTimer: Timer?
    private var animationFrame = 0

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

        let intervalMenu = NSMenu()
        intervalMenuItems = ReminderScheduler.intervalOptions.map { seconds in
            let item = NSMenuItem(title: Self.intervalTitle(seconds), action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            intervalMenu.addItem(item)
            return item
        }
        let intervalItem = NSMenuItem(title: "Remind every", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        menu.addItem(pauseMenuItem)

        let showItem = NSMenuItem(title: "Show reminder now", action: #selector(showReminder), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Blink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
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
        // The hand writes while the countdown runs; a static eye shows when it's stopped.
        if scheduler.countdownText != nil {
            startAnimation()
        } else {
            stopAnimation()
            let image = NSImage(systemSymbolName: scheduler.isPaused ? "eye.slash" : "eye", accessibilityDescription: "Blink")
            image?.isTemplate = true
            statusItem.button?.image = image
        }

        statusMenuItem.title = scheduler.statusText
        pauseMenuItem.title = scheduler.isPaused ? "Resume reminders" : "Pause reminders"
        for item in intervalMenuItems {
            item.state = item.tag == scheduler.intervalSeconds ? .on : .off
        }
    }

    private func startAnimation() {
        guard animationTimer == nil else { return }
        animationFrame = 0
        statusItem.button?.image = MenuBarAnimation.frames[0]
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
    }

    private func advanceAnimation() {
        animationFrame = (animationFrame + 1) % MenuBarAnimation.frames.count
        statusItem.button?.image = MenuBarAnimation.frames[animationFrame]
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        scheduler.intervalSeconds = sender.tag
    }

    @objc private func togglePause() {
        scheduler.isPaused.toggle()
    }

    @objc private func showReminder() {
        scheduler.sendTest()
    }

    private static func intervalTitle(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min"
    }
}
