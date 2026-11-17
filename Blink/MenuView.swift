import SwiftUI

struct MenuView: View {
    @Bindable var scheduler: ReminderScheduler

    var body: some View {
        if !scheduler.isAuthorized {
            Button("Notifications are off — Open Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
            Divider()
        }

        Picker("Remind every", selection: $scheduler.intervalMinutes) {
            ForEach(ReminderScheduler.intervalOptions, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }

        Button(scheduler.isPaused ? "Resume reminders" : "Pause reminders") {
            scheduler.isPaused.toggle()
        }

        Button("Send test reminder") {
            scheduler.sendTest()
        }

        Divider()

        Button("Quit Blink") {
            scheduler.stop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
