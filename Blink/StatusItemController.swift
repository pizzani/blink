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
            let image = NSImage(systemSymbolName: scheduler.isPaused ? "eye.slash" : "eye", accessibilityDescription: "Blink")
            image?.isTemplate = true
            button.image = image
            button.title = scheduler.countdownText.map { " \($0)" } ?? ""
        }

        statusMenuItem.title = scheduler.statusText
        pauseMenuItem.title = scheduler.isPaused ? "Resume reminders" : "Pause reminders"
        for item in intervalMenuItems {
            item.state = item.tag == scheduler.intervalSeconds ? .on : .off
        }
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
