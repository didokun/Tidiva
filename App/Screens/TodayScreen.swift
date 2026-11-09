import SwiftUI
import SwiftData

struct ResetRow: View {
    @Environment(\.modelContext) private var context
    let item: Reset
    @State private var failed = false
    var body: some View {
        Button {
            item.completed = item.completed == nil ? .now : nil
            do { try context.save() } catch { context.rollback(); failed = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.completed == nil ? "circle" : "checkmark.circle.fill")
                    .font(.title2).foregroundStyle(Theme.leaf)
                if let icon = item.taskIcon { Image(systemName: icon).foregroundStyle(Theme.leaf) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(item.title)).font(.headline).strikethrough(item.completed != nil)
                    if let notes = item.taskNotes, !notes.isEmpty { Text(notes).font(.subheadline) }
                    Text(item.roomLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text("\(item.minutes)m").font(.caption.bold()).padding(7).background(Theme.surface, in: Capsule())
            }.padding(13).background(Theme.paper, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityValue(item.completed == nil ? "Incomplete" : "Completed")
        .alert("Couldn’t save this change", isPresented: $failed) { Button("OK") {} }
    }
}

struct TodayScreen: View {
    @Query(sort: \Reset.scheduled) private var resets: [Reset]
    @State private var composer: RoutineDraftMode?
    @State private var adding = false
    @State private var session = false
    @State private var sessionItems: [Reset] = []
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { clock in
            let today = resets.filter {
                Calendar.current.isDate($0.scheduled, inSameDayAs: clock.date) ||
                ($0.completed.map { Calendar.current.isDate($0, inSameDayAs: clock.date) } ?? false)
            }
            let pending = today.filter { $0.completed == nil }
            let done = today.count - pending.count
            let week = Calendar.current.dateInterval(of: .weekOfYear, for: clock.date)
            let weekly = resets.filter { week?.contains($0.scheduled) == true }
            let hour = Calendar.current.component(.hour, from: clock.date)
            let greeting = hour < 5 || hour >= 18 ? "Good evening!" : hour < 12 ? "Good morning!" : "Good afternoon!"

            Page(title: greeting + " 👋") {
                if resets.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Image("TidivaMark").resizable().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Build your routine").font(.title.bold())
                        Text("Pick the tasks you want to do, room by room.").foregroundStyle(.secondary)
                        PrimaryButton(title: "Create my routine", symbol: "plus") { composer = .custom }
                    }.panel()
                    Text("Start from a template").font(.title3.bold())
                    ForEach(Routine.allCases) { routine in
                        Button { composer = .template(routine) } label: {
                            HStack {
                                Image(systemName: routine.symbol).frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(routine.name)).font(.headline)
                                    Text(LocalizedStringKey(routine.intent)).font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }.panel().contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                } else {
                Text("Ready for today’s reset?").foregroundStyle(.secondary)
                HStack {
                    FocusRing(title: "This week", icon: "calendar", count: weekly.filter { $0.completed != nil }.count, total: weekly.count, color: Theme.leaf)
                    FocusRing(title: "Today", icon: "sun.max.fill", count: done, total: today.count, color: Theme.leaf)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today’s focus").font(.title3.bold())
                        Spacer()
                        if resets.contains(where: { $0.completed == nil }) {
                            Button { composer = .edit } label: {
                                Image(systemName: "square.and.pencil").font(.title3)
                                    .frame(width: 44, height: 44)
                            }.accessibilityLabel("Edit my routine")
                        }
                        Button { adding = true } label: {
                            Label("New", systemImage: "plus").font(.subheadline.bold()).padding(10)
                                .foregroundStyle(Theme.ivory).background(Theme.pine, in: Capsule())
                        }
                    }
                    if today.isEmpty { Text("No tasks scheduled today.").foregroundStyle(.secondary) }
                    ForEach(today) { ResetRow(item: $0) }
                    if !pending.isEmpty {
                        Button("Start my task list") { sessionItems = pending; session = true }.font(.subheadline.bold())
                    }
                }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                NavigationLink { TaskCalendarScreen() } label: { Label("Task calendar", systemImage: "calendar") }
                PrimaryButton(title: "Create my routine", symbol: "plus") { composer = .custom }
                }
            }
        }.browsingAdvertising()
            .sheet(isPresented: $adding) { AddTaskScreen() }
            .sheet(item: $composer) { RoutineComposer(mode: $0) }
            .sheet(isPresented: $session) { SessionScreen(items: sessionItems) }
    }


}

struct AddTaskScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var scheduledDay = Date.now
    @State private var title = ""
    @State private var icon = "sparkles"
    @State private var notes = ""
    private var roomProfile = HomeRhythm()
    @State private var room = Room.kitchen
    @State private var minutes = 5
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TaskFields(title: $title, icon: $icon, notes: $notes)
                    Picker("Room", selection: $room) { ForEach(roomProfile.rooms) { Text(roomProfile.label($0)).tag($0) } }.onAppear { if !roomProfile.rooms.contains(room), let first = roomProfile.rooms.first { room = first } }
                    DatePicker("Scheduled day", selection: $scheduledDay, displayedComponents: .date)
                    Stepper("\(minutes) minutes", value: $minutes, in: 1...60)
                }
            }.navigationTitle("Add a task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            context.insert(Reset(title.trimmingCharacters(in: .whitespacesAndNewlines), room: room, minutes: minutes, scheduled: Calendar.current.startOfDay(for: scheduledDay), taskIcon: icon, taskNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines)))
                            do { try context.save(); dismiss() } catch { context.rollback(); failed = true }
                        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.alert("Couldn’t save this task", isPresented: $failed) { Button("OK") {} }
        }.tint(Theme.leaf)
    }
}

struct SessionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let items: [Reset]
    @State private var index = 0
    @StateObject private var advertising = SessionAdvertising()
    @ObservedObject private var membership = Membership.shared
    @State private var showPremium = false
    @State private var finished = 0
    @State private var suggestSunday = false
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Page(title: index < items.count ? "One small step." : "Time to breathe.") {
                if index < items.count {
                    let item = items[index]
                    Text("TASK \(index + 1) OF \(items.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.leaf)
                    ProgressView(value: Double(index), total: Double(items.count)).tint(Theme.leaf)
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: item.taskIcon ?? Room(rawValue: item.roomName)?.symbol ?? "house").font(.system(size: 58, weight: .light)).foregroundStyle(Theme.leaf)
                        Text(LocalizedStringKey(item.title)).font(Theme.headline)
                        if let notes = item.taskNotes, !notes.isEmpty { Text(notes) }
                        Label("\(item.roomLabel) · about \(item.minutes) min", systemImage: "clock").foregroundStyle(.secondary)
                    }.padding(.vertical, 30)
                    PrimaryButton(title: "Done, next step", symbol: "checkmark") {
                        item.completed = .now
                        do { try context.save(); finished += 1; index += 1 } catch { context.rollback(); failed = true }
                    }
                    Button("Skip for now") {
                        item.skippedCount += 1
                        do {
                            try context.save()
                            if item.skippedCount >= 2 && !item.sundayOnly && Calendar.current.component(.weekday, from: .now) != 1 { suggestSunday = true }
                            else { index += 1 }
                        } catch { context.rollback(); failed = true }
                    }.confirmationDialog("Save this task for Sunday resets?", isPresented: $suggestSunday) {
                        Button("Save for Sundays") {
                            item.sundayOnly = true
                            do { try context.save(); index += 1 } catch { context.rollback(); failed = true }
                        }
                        Button("Keep current routine", role: .cancel) { index += 1 }
                    }.frame(maxWidth: .infinity).padding(12)
                } else {
                    Image(systemName: "checkmark.seal").font(.system(size: 72, weight: .light)).foregroundStyle(Theme.leaf).padding(.vertical, 24)
                    Text(items.isEmpty ? String(localized: "No tasks fit this time window. Try a longer reset or add a shorter task.") : String(localized: "You completed \(finished) tasks. Every little bit makes home feel better.")).font(.title3)
                    if membership.premium == false {
                        Button("Go ad-free with Premium") { showPremium = true }
                    }
                    PrimaryButton(title: "Back to my day", symbol: "sun.max") { dismiss() }
                }
            }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.tint(Theme.leaf).interactiveDismissDisabled(index < items.count)
            .task { await advertising.preload() }
            .onChange(of: index) { _, next in
                if next == items.count && finished > 0 { advertising.showAtCompletion() }
            }
            .sheet(isPresented: $showPremium) { PremiumOptions().padding() }
            .alert("Couldn’t save your progress", isPresented: $failed) { Button("Try again", role: .cancel) {} }
    }
}

private struct FocusRing: View {
    let title: String
    let icon: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        let fraction = total == 0 ? 0 : Double(count) / Double(total)
        VStack(spacing: 9) {
            ZStack {
                Circle().stroke(color.opacity(0.17), lineWidth: 6)
                Circle().trim(from: 0, to: fraction).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(fraction, format: .percent.precision(.fractionLength(0))).font(.title3.bold())
                }
            }.frame(width: 88, height: 88)
            Text(LocalizedStringKey(title)).font(.headline)
            Text("\(count) of \(total) tasks").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}
