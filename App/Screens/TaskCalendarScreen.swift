import SwiftUI
import SwiftData
import EventKit

struct TaskCalendarScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reset.scheduled) private var tasks: [Reset]
    @State private var day = Date.now
    @State private var syncing = false
    @State private var message: LocalizedStringKey?
    @State private var confirmingRemoval = false
    private let linksKey = "tidiva.calendarEvents"
    @State private var store = EKEventStore()

    var body: some View {
        List {
            DatePicker("Scheduled day", selection: $day, displayedComponents: .date)
                .datePickerStyle(.graphical)
            Section(day.formatted(date: .complete, time: .omitted)) {
                let selected = tasks.filter { Calendar.current.isDate($0.scheduled, inSameDayAs: day) }
                if selected.isEmpty { Text("No tasks on this date.").foregroundStyle(.secondary) }
                ForEach(selected) { ResetRow(item: $0) }
            }
            Section("Scheduled days") {
                let grouped = Dictionary(grouping: tasks.filter { $0.completed == nil }) { Calendar.current.startOfDay(for: $0.scheduled) }
                ForEach(grouped.keys.sorted(), id: \.self) { date in
                    Button { day = date } label: {
                        HStack {
                            Text(date, format: .dateTime.weekday(.abbreviated).day().month())
                            Spacer()
                            let items = grouped[date] ?? []
                            Text("\(items.count) tasks · \(items.reduce(0) { $0 + $1.minutes }) min").font(.caption)
                        }
                    }
                }
            }
            Section {
                Button {
                    syncing = true
                    Task { await syncCalendar() }
                } label: { Label("Sync to Apple Calendar", systemImage: "arrow.triangle.2.circlepath") }
                    .disabled(syncing)
                if UserDefaults.standard.dictionary(forKey: linksKey)?.isEmpty == false {
                    Button(role: .destructive) { confirmingRemoval = true } label: {
                        Label("Remove Tidiva events", systemImage: "calendar.badge.minus")
                    }.disabled(syncing)
                }
                if let message { Text(message).font(.footnote) }
            } footer: { Text("Send scheduled tasks as all-day events. Sync again after changing your plan.") }
        }.navigationTitle("Task calendar")
        .alert("Remove Tidiva events from Apple Calendar?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove events", role: .destructive) {
                syncing = true
                Task { await removeCalendarEvents() }
            }
        } message: { Text("This removes previously synced events. Your tasks stay in Tidiva.") }
    }

    private func removeLinkedEvents(_ links: inout [String: String], keeping ids: Set<String>) throws {
        for (id, eventID) in links where !ids.contains(id) {
            if let event = store.event(withIdentifier: eventID), event.url?.absoluteString == "tidiva://task/" + id {
                try store.remove(event, span: .thisEvent)
            }
            links.removeValue(forKey: id)
            UserDefaults.standard.set(links, forKey: linksKey)
        }
    }

    @MainActor private func removeCalendarEvents() async {
        defer { syncing = false }
        do {
            guard try await store.requestFullAccessToEvents() else {
                message = "Allow calendar access in iPhone Settings to remove events."
                return
            }
            var links = UserDefaults.standard.dictionary(forKey: linksKey) as? [String: String] ?? [:]
            try removeLinkedEvents(&links, keeping: [])
            message = "Tidiva events removed from Apple Calendar."
        } catch { message = "Couldn’t remove all events. Try again." }
    }

    @MainActor private func syncCalendar() async {
        defer { syncing = false }
        do {
            guard try await store.requestFullAccessToEvents() else {
                message = "Allow calendar access in iPhone Settings to sync."
                return
            }
            let defaults = UserDefaults.standard
            var links = defaults.dictionary(forKey: linksKey) as? [String: String] ?? [:]
            let start = Calendar.current.startOfDay(for: .now)
            let upcoming = tasks.filter { $0.scheduled >= start && $0.completed == nil }
            for task in upcoming where task.calendarKey == nil { task.calendarKey = UUID() }
            try context.save()
            let localKeys = Set(tasks.compactMap { $0.calendarKey?.uuidString })
            try removeLinkedEvents(&links, keeping: localKeys)
            for task in upcoming {
                guard let id = task.calendarKey?.uuidString else { continue }
                let url = URL(string: "tidiva://task/" + id)
                let linked = links[id].flatMap { store.event(withIdentifier: $0) }
                let event: EKEvent
                if let linked, linked.url == url { event = linked }
                else {
                    guard let calendar = store.defaultCalendarForNewEvents else {
                        message = "No writable Apple calendar is available."
                        return
                    }
                    event = EKEvent(eventStore: store)
                    event.calendar = calendar
                }
                event.url = url
                event.title = "Tidiva · " + NSLocalizedString(task.title, comment: "")
                event.notes = [task.roomLabel, PlanningRules.durationLabel(task.minutes), task.taskNotes].compactMap { $0 }.joined(separator: "\n")
                event.isAllDay = true
                event.startDate = Calendar.current.startOfDay(for: task.scheduled)
                event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate)
                try store.save(event, span: .thisEvent)
                links[id] = event.eventIdentifier
                defaults.set(links, forKey: linksKey)
            }
            message = "Apple Calendar is up to date."
        } catch { message = "Calendar sync failed. Try again." }
    }
}
