import SwiftUI
import UserNotifications

struct ReminderOptions: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @AppStorage("tidiva.reminderCount") private var savedCount = 0
    @State private var count = 2
    @State private var busy = false
    @State private var denied = false
    @State private var failed = false
    @AppStorage("tidiva.reminderTimes") private var storedTimes = "540,1140,780"
    @State private var times = [540, 1140, 780]
    // Retain the original notification identifiers when changing their delivery times.
    private let identifiers = ["tidiva.reminder.9", "tidiva.reminder.19", "tidiva.reminder.13"]
    private var previousTimes: [Int] {
        let result = storedTimes.split(separator: ",").compactMap { Int($0) }
        return result.count == 3 && result.allSatisfy { (0..<1440).contains($0) } ? result : [540, 1140, 780]
    }
    private var unchanged: Bool { savedCount == count && times.prefix(count) == previousTimes.prefix(count) }
    private var duplicate: Bool { Set(times.prefix(count)).count < count }


    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A gentle nudge to start a cleaning task. Choose two or three reminders a day.")
            Picker("Daily reminders", selection: $count) {
                Text("2 per day").tag(2)
                Text("3 per day").tag(3)
            }.pickerStyle(.segmented)
            ForEach(0..<count, id: \.self) { slot in
                DatePicker(selection: timeBinding(slot), displayedComponents: .hourAndMinute) {
                    Label("Reminder \(slot + 1)", systemImage: "bell")
                        .font(.headline)
                }.padding(18).frame(maxWidth: .infinity, minHeight: 70)
                    .background(Theme.mint, in: RoundedRectangle(cornerRadius: 20))
            }
            if duplicate { Text("Choose different times for your reminders.").font(.footnote) }
            if denied {
                Button("Allow notifications in Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            } else {
                Button(unchanged ? "Reminders enabled" : savedCount > 0 ? "Save reminder times" : "Enable these reminders") {
                    busy = true
                    Task { await schedule() }
                }.buttonStyle(.borderedProminent).disabled(unchanged || duplicate)
            }
            if savedCount > 0 {
                Button("Turn off reminders") {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                    savedCount = 0
                }
            }
        }.disabled(busy)
        .task { times = previousTimes; count = savedCount == 3 ? 3 : 2; await checkPermission() }
        .onChange(of: phase) { if phase == .active { Task { await checkPermission() } } }
        .alert("Couldn’t schedule reminders", isPresented: $failed) { Button("OK") {} }
    }

    private func timeBinding(_ slot: Int) -> Binding<Date> {
        Binding {
            let minutes = times[slot]
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            times[slot] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    private func checkPermission() async {
        denied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    private func schedule() async {
        defer { busy = false }
        let center = UNUserNotificationCenter.current()
        let previous = await center.pendingNotificationRequests().filter { identifiers.contains($0.identifier) }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { denied = true; return }
            for (slot, minutes) in times.prefix(count).enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Tidiva"
                content.body = NSString.localizedUserNotificationString(forKey: "Ready for a small reset? Open your routine and pick one task.", arguments: nil)
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
                try await center.add(UNNotificationRequest(identifier: identifiers[slot], content: content, trigger: trigger))
            }
            center.removePendingNotificationRequests(withIdentifiers: Array(identifiers.dropFirst(count)))
            storedTimes = times.map(String.init).joined(separator: ",")
            savedCount = count
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            for request in previous { try? await center.add(request) }
            failed = true
        }
    }
}
