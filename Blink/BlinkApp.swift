import SwiftUI

@main
struct BlinkApp: App {
    @State private var scheduler = ReminderScheduler()

    init() {
        scheduler.start()
    }

    var body: some Scene {
        MenuBarExtra("Blink", systemImage: scheduler.isPaused ? "eye.slash" : "eye") {
            MenuView(scheduler: scheduler)
        }
        .menuBarExtraStyle(.menu)
    }
}
