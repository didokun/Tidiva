import SwiftUI
import SwiftData

enum RoutineDraftMode: Hashable, Identifiable {
    case custom, template(Routine), edit
    var id: Self { self }
}

private struct DraftTask: Identifiable {
    let id = UUID()
    let room: Room
    let title: String
    var minutes: Int
    let existing: Reset?
    var taskIcon: String? = nil
    var taskNotes: String? = nil
    var selected: Bool
}

struct RoutineComposer: View {
    let mode: RoutineDraftMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Reset.scheduled) private var history: [Reset]
    @AppStorage("tidiva.dailyMinutes") private var budget = 15
    private var rhythm = HomeRhythm()
    @State private var draft: [DraftTask] = []
    private enum Page: Hashable {
        case floor(Int), room(Room), review
    }
    @State private var excludedRooms = Set<Room>()
    @State private var pageIndex = 0
    @State private var addingTo: Room?
    @State private var taskIcon = "sparkles"
    @State private var taskNotes = ""
    @State private var taskName = ""
    @State private var taskMinutes = 5
    @State private var stage: Int?
    @State private var confirmExit = false
    @State private var failed = false
    init(mode: RoutineDraftMode) { self.mode = mode }
    private var chosen: [DraftTask] { draft.filter { $0.selected && !excludedRooms.contains($0.room) } }
    private let phases: [LocalizedStringKey] = [
        "Collecting selected tasks", "Grouping tasks by floor", "Building room checklists",
        "Adding up cleaning time", "Comparing with your daily target", "Saving your routine"
    ]
    private var finished: Bool { stage == phases.count }

    var body: some View {
        NavigationStack {
            if let stage {
                preparation(stage)
                    .task { if stage == 0 { await save() } }
            } else {
                let page = pages[min(pageIndex, pages.count - 1)]
                List {
                    switch page {
                    case .floor(let floor):
                        Section {
                            ForEach(rooms(on: floor)) { room in
                                let included = !excludedRooms.contains(room)
                                Button {
                                    if included { excludedRooms.insert(room) }
                                    else { excludedRooms.remove(room) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: room.symbol).font(.title2).frame(width: 42, height: 48)
                                        Text(room.displayName).font(.headline)
                                        Spacer()
                                        Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                            .font(.title2).foregroundStyle(Theme.leaf)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityAddTraits(included ? .isSelected : [])

                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Floor \(floor)").font(.title2.bold())
                                Text("Choose the rooms to include.").font(.subheadline)
                            }.textCase(nil)
                        }
                    case .room(let room):
                        Section {
                            ForEach($draft) { $item in
                                if item.room == room {
                                    taskCard($item)
                                }
                            }
                            Button {
                                taskName = ""
                                taskIcon = "sparkles"
                                taskNotes = ""
                                taskMinutes = 5
                                addingTo = room
                            } label: { Label("Add my own task", systemImage: "plus.circle.fill") }
                        } header: { Label(rhythm.label(room), systemImage: room.symbol) }
                    case .review:
                        if chosen.isEmpty { Text("No tasks selected") }
                        ForEach(orderedRooms) { room in
                            let tasks = chosen.filter { $0.room == room }
                            if !tasks.isEmpty {
                                Section(rhythm.label(room)) {
                                    ForEach(tasks) { task in
                                        LabeledContent { Text("\(task.minutes) minutes") } label: { Text(LocalizedStringKey(task.title)) }
                                    }
                                }
                            }
                        }
                    }
                }.id(page).navigationTitle(page == .review ? String(localized: "Review my routine") : title)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Text("\(chosen.count) tasks · \(chosen.reduce(0) { $0 + $1.minutes }) min").font(.subheadline)
                        ProgressView(value: Double(pageIndex + 1), total: Double(pages.count))
                        if page == .review {
                            PrimaryButton(title: mode == .edit ? "Save changes" : "Create my routine") {
                                stage = 0
                            }.disabled(chosen.isEmpty && mode != .edit)
                        } else {
                            PrimaryButton(title: "Continue") { pageIndex += 1 }
                        }
                    }.padding().background(Theme.paper)
                }.toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if pageIndex > 0 { Button("Back") { pageIndex -= 1 } }
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { confirmExit = true } }
                }
            }
        }.tint(Theme.leaf).interactiveDismissDisabled(!finished)
            .alert("Leave this routine?", isPresented: $confirmExit) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard changes", role: .destructive) { dismiss() }
            } message: { Text("Your changes in this editor will be lost.") }
            .onAppear { if draft.isEmpty { prepare() } }
            .sheet(item: $addingTo) { room in
                NavigationStack {
                    Form {
                        Section(rhythm.label(room)) {
                            TaskFields(title: $taskName, icon: $taskIcon, notes: $taskNotes)
                            Stepper("\(taskMinutes) minutes", value: $taskMinutes, in: 1...240)
                        }
                    }.navigationTitle("Add my own task").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { addingTo = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let name = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
                                let notes = taskNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                                if let index = draft.firstIndex(where: { $0.room == room && $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                                    draft[index].selected = true
                                    draft[index].minutes = taskMinutes
                                    draft[index].taskIcon = taskIcon
                                    draft[index].taskNotes = notes
                                } else {
                                    draft.append(DraftTask(room: room, title: name, minutes: taskMinutes, existing: nil, taskIcon: taskIcon, taskNotes: notes, selected: true))
                                }
                                addingTo = nil
                            }.disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }.presentationDetents([.medium, .large])
                    .interactiveDismissDisabled(!taskName.isEmpty || !taskNotes.isEmpty || taskIcon != "sparkles" || taskMinutes != 5)
            }
            .alert("Couldn’t save this plan", isPresented: $failed) { Button("OK") {} }
    }

    private func taskCard(_ binding: Binding<DraftTask>) -> some View {
        let item = binding.wrappedValue
        let guidance = taskGuidance[item.title]
        return VStack(alignment: .leading, spacing: 10) {
            Button { binding.selected.wrappedValue.toggle() } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.taskIcon ?? guidance?.symbol ?? item.room.symbol)
                        .font(.title2).foregroundStyle(Theme.ink)
                        .frame(width: 48, height: 48)
                        .background(Theme.mint, in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(item.title)).font(.title3.bold())
                        if let notes = item.taskNotes, !notes.isEmpty {
                            Text(notes).font(.subheadline).foregroundStyle(.secondary)
                        } else if let guidance, item.taskIcon == nil {
                            Text(guidance.hint).font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text(rhythm.label(item.room)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Label("\(item.minutes) minutes", systemImage: "clock").font(.caption.bold())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Theme.leaf).font(.title2)
                }.padding(16).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityAddTraits(item.selected ? .isSelected : [])
            if item.selected {
                Stepper("\(item.minutes) minutes", value: binding.minutes, in: 1...max(120, item.minutes))
                    .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .background(item.selected ? Theme.mint : Theme.paper, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.leaf.opacity(item.selected ? 0.8 : 0.25)).allowsHitTesting(false) }
        .listRowSeparator(.hidden).listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
    }

    private var title: String {
        switch mode {
        case .template(let template): NSLocalizedString(template.name, comment: "")
        case .custom: String(localized: "Build your routine")
        case .edit: String(localized: "Edit my routine")
        }
    }
    private var orderedRooms: [Room] {
        var seen = Set<Room>()
        return (rhythm.rooms + draft.map(\.room)).filter { seen.insert($0).inserted }
    }
    private func rooms(on floor: Int) -> [Room] {
        orderedRooms.filter { rhythm.floor($0) == floor }
    }
    private var pages: [Page] {
        let levels = Set(orderedRooms.map { rhythm.floor($0) }).sorted()
        return levels.flatMap { level in
            [Page.floor(level)] + rooms(on: level).filter { !excludedRooms.contains($0) }.map(Page.room)
        } + [.review]
    }
    private func prepare() {
        let now = Date.now
        let pending = history.filter { $0.completed == nil && ($0.scheduled <= now || Calendar.current.isDateInToday($0.scheduled)) }
        if mode == .edit {
            draft = pending.compactMap { item in
                guard let room = Room(rawValue: item.roomName) else { return nil }
                return DraftTask(room: room, title: item.title, minutes: item.minutes, existing: item, taskIcon: item.taskIcon, taskNotes: item.taskNotes, selected: true)
            }
        }
        var suggested: [RoutineTask] = []
        if case .template(let routine) = mode {
            suggested = RoutineBuilder.tasks(routine, rhythm: rhythm, budget: budget, history: history, date: now)
        }
        for room in rhythm.rooms {
            for (index, title) in room.ideas.enumerated() {
                if draft.contains(where: { $0.room == room && $0.title == title }) { continue }
                let existing = pending.first { $0.roomName == room.rawValue && $0.title == title }
                let suggestion = suggested.first { $0.room == room && $0.title == title }
                draft.append(DraftTask(room: room, title: title, minutes: existing?.minutes ?? suggestion?.minutes ?? [2,3,5][index], existing: existing, taskIcon: existing?.taskIcon, taskNotes: existing?.taskNotes, selected: suggestion != nil))
            }
        }
    }

    private func preparation(_ current: Int) -> some View {
        let groups = Dictionary(grouping: chosen, by: \.room)
        let levels = Set(groups.keys.map { rhythm.floor($0) }).sorted()
        let total = chosen.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("TidivaMark").resizable().frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(finished ? "Your routine is ready" : "Preparing your routine").font(.title.bold())
            }
            ProgressView(value: Double(current), total: Double(phases.count)).tint(Theme.leaf)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(phases.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 4) {
                                if current == index { ProgressView().tint(Theme.leaf).frame(width: 26, height: 26) }
                                else {
                                    Image(systemName: current > index ? "checkmark.circle.fill" : "circle")
                                        .font(.title2).foregroundStyle(Theme.leaf).frame(width: 26, height: 26)
                                }
                                if index < phases.count - 1 {
                                    Rectangle().fill(Theme.leaf.opacity(0.35)).frame(width: 2)
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(phases[index]).font(.headline)
                                switch index {
                                case 0: Text("\(chosen.count) tasks · \(total) min")
                                case 1:
                                    ForEach(levels, id: \.self) { level in
                                        Text("Floor \(level)") + Text(" · ") + Text(verbatim: rooms(on: level).filter { groups[$0] != nil }.map(\.displayName).joined(separator: ", "))
                                    }
                                case 2:
                                    ForEach(levels, id: \.self) { level in
                                        ForEach(rooms(on: level)) { room in
                                            if let tasks = groups[room] {
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Label(rhythm.label(room), systemImage: room.symbol).font(.subheadline.bold())
                                                    ForEach(tasks) { task in
                                                        HStack {
                                                            Text(LocalizedStringKey(task.title))
                                                            Spacer()
                                                            Text("\(task.minutes) min").monospacedDigit()
                                                        }
                                                    }
                                                }.padding(12).background(Theme.mint, in: RoundedRectangle(cornerRadius: 14))
                                            }
                                        }
                                    }
                                case 3: Text("\(total) minutes")
                                case 4: Text("Planned: \(total) min · Target: \(budget) min")
                                default: Text(finished ? "Routine saved" : "On this device")
                                }
                            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 22)
                        }.opacity(index > current ? 0.65 : 1)
                    }
                }.padding(.vertical, 12)
            }
            if finished { PrimaryButton(title: "View my tasks") { dismiss() } }
        }.padding(20).background(Theme.paper).foregroundStyle(Theme.ink)
    }

    @MainActor private func save() async {
        // Six independently paced steps keep the timeline visible for at least 15 seconds.
        for index in phases.indices {
            do { try await Task.sleep(for: .milliseconds(Int.random(in: 2500...3600))) }
            catch { return }
            if index < phases.count - 1 {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { stage = index + 1 }
            }
        }
        for item in draft {
            if item.selected && !excludedRooms.contains(item.room) {
                if let existing = item.existing {
                    existing.minutes = item.minutes
                    existing.taskIcon = item.taskIcon
                    existing.taskNotes = item.taskNotes
                }
                else { context.insert(Reset(item.title, room: item.room, minutes: item.minutes, taskIcon: item.taskIcon, taskNotes: item.taskNotes)) }
            } else if mode == .edit, let existing = item.existing { context.delete(existing) }
        }
        do {
            try context.save()
            stage = phases.count
        } catch { context.rollback(); stage = nil; failed = true }
    }
}

private let taskGuidance: [String: (symbol: String, hint: LocalizedStringKey)] = [
    "Clear the counter": ("square.grid.2x2", "Leave only the appliances you use daily."),
    "Wipe the sink": ("drop", "Rinse the basin and wipe around the tap."),
    "Put away clean dishes": ("fork.knife", "Empty the drying rack or dishwasher."),
    "Fold the throws": ("rectangle.compress.vertical", "Fold each blanket over the arm of the sofa."),
    "Clear the coffee table": ("cup.and.saucer", "Take mugs to the kitchen and put magazines away."),
    "Straighten the cushions": ("sofa", "Fluff the cushions and arrange them on the seats."),
    "Make the bed": ("bed.double", "Pull up the duvet and straighten the pillows."),
    "Clear the nightstand": ("moon", "Leave room for your lamp and bedtime essentials."),
    "Gather the laundry": ("basket", "Bring loose clothes to the laundry basket."),
    "Pair up the shoes": ("shoeprints.fill", "Match each pair and clear the doorway."),
    "Hang the coats": ("hanger", "Move jackets from chairs to their hooks."),
    "Sort the mail": ("envelope", "Keep letters to handle together and recycle the rest."),
    "Wipe the bathroom sink": ("drop", "Wipe soap marks from the basin and tap."),
    "Put away toiletries": ("cabinet", "Return bottles and brushes to their usual spot."),
    "Replace the hand towels": ("arrow.triangle.2.circlepath", "Hang fresh towels and put used ones in the wash."),
    "Clear the desk": ("desktopcomputer", "Leave space for your next work session."),
    "Sort loose papers": ("doc.on.doc", "File what you need and recycle old drafts."),
    "Dust the desk surface": ("sparkles", "Lift small items and wipe underneath."),
    "Fold clean clothes": ("tshirt", "Make one pile per person or drawer."),
    "Put away folded clothes": ("cabinet", "Carry each pile to its drawer or shelf."),
    "Put things away": ("tray", "Return loose items to their usual places."),
    "Clear a surface": ("square", "Pick one shelf or tabletop and clear it."),
    "Sweep the floor": ("sparkles", "Start at the edges and sweep toward the door."),
]
