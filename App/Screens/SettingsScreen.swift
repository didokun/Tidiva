import SwiftUI
import SwiftData
import UserNotifications

struct SettingsScreen: View {
    let restart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tidiva.dailyMinutes") private var minutes = 15
    private var rhythm = HomeRhythm()
    @State private var setup = false
    @State private var editRooms = false

    init(restart: @escaping () -> Void) { self.restart = restart }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    link("Your profile", "person.crop.circle") {
                        Form { ProfileFields().listRowBackground(Color.clear) }
                    }
                    link("My Home", "house") {
                        Form {
                            ForEach(1...max(1, rhythm.floors), id: \.self) { level in
                                Section(String(localized: "Floor \(level)")) {
                                    ForEach(rhythm.rooms.filter { rhythm.floor($0) == level }) { room in
                                        Text(room.displayName)
                                    }
                                }
                            }
                            Button("Edit rooms by level") { editRooms = true }
                        }
                    }
                    link("Your routine", "checklist") {
                        Form {
                            Picker("Daily time", selection: $minutes) {
                                ForEach(PlanningRules.sessionMinutes, id: \.self) {
                                    Text(PlanningRules.durationLabel($0)).tag($0)
                                }
                            }
                            Button("Review my setup") { setup = true }
                        }
                    }
                    link("Daily reminders", "bell") {
                        Form { ReminderOptions() }
                    }
                }
                Section {
                    link("Subscription", "star.circle") {
                        PremiumOptions().padding(.horizontal)
                    }
                    link("Data and privacy", "hand.raised") {
                        Form {
                            Section { Text("Your tasks are saved locally. No account is required.") }
                            AdvertisingPrivacyOptions()
                            NavigationLink("Reset Tidiva") { FactoryResetScreen(restart: restart) }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Theme.leaf)
        .sheet(isPresented: $setup) { OnboardingScreen { setup = false } }
        .sheet(isPresented: $editRooms) { OnboardingScreen(editRooms: true) { editRooms = false } }
    }

    private func link<Content: View>(_ title: LocalizedStringKey, _ icon: String,
                                     @ViewBuilder destination: @escaping () -> Content) -> some View {
        NavigationLink {
            destination().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(Theme.pine)
                    .frame(width: 38, height: 38).background(Theme.mint, in: RoundedRectangle(cornerRadius: 12))
                Text(title).font(.headline)
            }.padding(.vertical, 3)
        }
    }
}

private struct FactoryResetScreen: View {
    let restart: () -> Void
    @Environment(\.modelContext) private var context
    @State private var confirming = false
    @State private var failed = false

    var body: some View {
        Form {
            Section {
                Label("Start fresh", systemImage: "arrow.counterclockwise").font(.title2.bold())
                Text("This erases your profile, rooms, routines, task history and reminders on this device. You’ll return to the welcome screen.")
                Text("Your App Store subscription is managed separately.").font(.footnote)
            }
            Button("Erase all local data", role: .destructive) { confirming = true }
        }
        .navigationTitle("Reset Tidiva")
        .alert("Erase all local data?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Erase and restart", role: .destructive, action: reset)
        } message: { Text("This action is permanent.") }
        .alert("Couldn’t erase your data", isPresented: $failed) { Button("OK") {} }
    }

    private func reset() {
        do {
            for item in try context.fetch(FetchDescriptor<Reset>()) { context.delete(item) }
            try context.save()
        } catch {
            context.rollback()
            failed = true
            return
        }
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("tidiva.") && key != "tidiva.onboardingComplete" {
            defaults.removeObject(forKey: key)
        }
        restart()
    }
}
