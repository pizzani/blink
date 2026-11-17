import SwiftUI

struct MenuView: View {
    @Bindable var scheduler: ReminderScheduler

    var body: some View {
        Picker("Remind every", selection: $scheduler.intervalMinutes) {
            ForEach(ReminderScheduler.intervalOptions, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }

        Button(scheduler.isPaused ? "Resume reminders" : "Pause reminders") {
            scheduler.isPaused.toggle()
        }

        Button("Show reminder now") {
            scheduler.sendTest()
        }

        Divider()

        Button("Quit Blink") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
