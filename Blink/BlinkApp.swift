import SwiftUI

@main
struct BlinkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // The UI is an AppKit status item (see StatusItemController); SwiftUI needs at least one scene.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scheduler = ReminderScheduler()
        scheduler.start()
        statusItemController = StatusItemController(scheduler: scheduler)
    }
}
