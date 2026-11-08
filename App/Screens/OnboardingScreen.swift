import SwiftUI
import SwiftData

private enum SetupStep: Hashable {
    case welcome, cleaning, laundry, goal, minutes, home, floors, level(Int)
    case work, days, workspace, priority, profile, reminders, membership

    var title: String {
        switch self {
        case .welcome: "A home routine that fits your day."
        case .cleaning: "How often do you clean?"
        case .laundry: "How much laundry do you do?"
        case .goal: "What would you like to focus on?"
        case .minutes: "How much time can you spare?"
        case .home: "What kind of home do you live in?"
        case .floors: "How many levels does your home have?"
        case .level(let level): String(localized: "Which rooms are on level \(level)?")
        case .work: "Where do you usually work?"
        case .days: "Which days do you work at the office?"
        case .workspace: "Where do you work at home?"
        case .priority: "Which room comes first?"
        case .profile: "Your profile"
        case .reminders: "Would a reminder help?"
        case .membership: "Choose your plan"
        }
    }
}

struct OnboardingScreen: View {
    @AppStorage("tidiva.dailyMinutes") private var dailyMinutes = 15
    @State private var addingRoom = false
    @AppStorage("tidiva.homeType") private var homeType = "Apartment"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var step = SetupStep.welcome
    @State private var selected: [Room] = []
    @State private var floorCount = 1
    @ObservedObject private var membership = Membership.shared
    private var rhythm = HomeRhythm()
    private var schedule = WorkSchedule()
    let editRooms: Bool
    let finish: () -> Void
    init(editRooms: Bool = false, finish: @escaping () -> Void) {
        self.editRooms = editRooms
        self.finish = finish
        _step = State(initialValue: editRooms ? .floors : .welcome)
    }

    private var rooms: [Room] { selected.filter { rhythm.floor($0) <= floorCount } }
    private var steps: [SetupStep] {
        var pages: [SetupStep] = [.welcome, .cleaning, .laundry, .goal, .minutes, .home, .floors]
        pages += (1...floorCount).map(SetupStep.level)
        if editRooms { return [.floors] + (1...floorCount).map(SetupStep.level) }
        pages.append(.work)
        if rhythm.work == "Hybrid" { pages.append(.days) }
        if rhythm.work != "Office" && rooms.count > 1 { pages.append(.workspace) }
        if rooms.count > 1 { pages.append(.priority) }
        return pages + [.profile, .reminders, .membership]
    }
    private var index: Int { steps.firstIndex(of: step) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if index > 0 {
                    Button { move(-1) } label: {
                        Image(systemName: "arrow.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Back")
                }
                mark(36)
                Text("Tidiva").font(.title2.bold())
                Spacer()
                if step != .welcome { Text("\(editRooms ? index + 1 : index) / \(editRooms ? steps.count : steps.count - 1)").font(.subheadline.monospacedDigit()) }
            }
            if step == .membership {
                PremiumOptions(onContinue: save)
            } else {
            if step != .welcome { ProgressView(value: Double(editRooms ? index + 1 : index), total: Double(editRooms ? steps.count : steps.count - 1)).tint(Theme.leaf) }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if step == .welcome {
                        mark(148).frame(maxWidth: .infinity).padding(.vertical, 28)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.8)
                    }
                    Text(LocalizedStringKey(step.title)).font(Theme.headline).accessibilityAddTraits(.isHeader)
                    fields
                }.padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
            }.id(step).scrollDismissesKeyboard(.interactively)
            PrimaryButton(title: step == .welcome ? "Get started" : editRooms && step == steps.last ? "Done" : "Continue") {
                if step == steps.last { save() } else { move(1) }
            }.disabled((step == .level(floorCount) && rooms.isEmpty) || (step == .goal && rhythm.goals.isEmpty))
            }
        }.padding(.horizontal, 16).padding(.vertical, 18).foregroundStyle(Theme.ink).tint(Theme.leaf).background(Theme.paper)
            .onAppear {
                selected = rhythm.rooms
                floorCount = rhythm.floors
                withAnimation(reduceMotion ? nil : .spring(duration: 0.7)) { appeared = true }
            }
    }
    private func mark(_ size: CGFloat) -> some View {
        Image("TidivaMark").resizable().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23)).accessibilityHidden(true)
    }
    @ViewBuilder private var fields: some View {
        switch step {
        case .welcome:
            Text("Tidiva picks small cleaning tasks for your rooms, your schedule and the time you have. Choose a routine and follow it one task at a time.").foregroundStyle(.secondary)
        case .cleaning: wheel("Cleaning sessions per week", "sparkles", Theme.surface, Array(0...21), rhythm.$sessions)
        case .laundry: wheel("Laundry loads per week", "washer.fill", Theme.surface, Array(0...30), rhythm.$loads)
        case .goal:
            Text("Select one or more priorities.").foregroundStyle(.secondary)
            goalCard("Keep things tidy", "Give everyday clutter a place to go.", "sparkles", Theme.surface)
            goalCard("Stay on top of laundry", "Make time to gather, fold and put clothes away.", "washer.fill", Theme.surface)
            goalCard("Be ready for guests", "Focus on the rooms your guests will see.", "person.2.fill", Theme.surface)
            goalCard("Keep the kitchen ready", "Clear the counters and put clean dishes away.", "fork.knife", Theme.surface)
            goalCard("Freshen up the bathroom", "Give the sink and towels regular attention.", "shower.fill", Theme.surface)
            goalCard("Wind down in a tidy bedroom", "Make the bed and clear your nightstand.", "bed.double.fill", Theme.surface)
        case .minutes: wheel("Minutes per routine", "timer", Theme.surface, PlanningRules.sessionMinutes, $dailyMinutes)
        case .home:
            choice("Apartment", "A home in a shared building.", "building.2.fill", Theme.surface, $homeType)
            choice("House", "An individual or attached house.", "house.fill", Theme.surface, $homeType)
            choice("Studio", "Living and sleeping in one space.", "bed.double.fill", Theme.surface, $homeType)
            choice("Other", "A different kind of living space.", "house.and.flag.fill", Theme.surface, $homeType)
        case .priority, .workspace:
            ForEach(rooms) { room in
                let active = (step == .priority ? rhythm.priority : rhythm.workspace) == room.rawValue
                card(room.displayName, floorCount > 1 ? String(localized: "Floor \(rhythm.floor(room))") : "", room.symbol, Theme.surface, active) {
                    if step == .priority { rhythm.priority = room.rawValue } else { rhythm.workspace = room.rawValue }
                }
            }
        case .floors: wheel("Number of levels", "square.3.layers.3d", Theme.surface, Array(1...8), $floorCount)
        case .level(let level):
            let onLevel = selected.filter { rhythm.floor($0) == level }
            ForEach(Room.allCases) { template in
                let chosen = onLevel.first { $0.kind == template.kind }
                card(template.displayName, "", template.symbol, Theme.surface, chosen != nil, multiple: true) {
                    if let chosen { selected.removeAll { $0 == chosen } }
                    else {
                        // Keep the original key when reselecting a previously saved room.
                        let previous = rhythm.rooms.first { $0.kind == template.kind && rhythm.floor($0) == level }
                        selected.append(previous ?? Room(name: template.name, level: level, custom: false))
                    }
                }
            }
            ForEach(onLevel.filter(\.custom)) { room in
                card(room.name, "", room.symbol, Theme.surface, true, multiple: true) { selected.removeAll { $0 == room } }
            }
            Button { addingRoom = true } label: {
                Label("Add a room", systemImage: "plus.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(16)
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.leaf, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Theme.leaf)
            .sheet(isPresented: $addingRoom) {
                NewRoomSheet(existing: onLevel) { name, symbol in
                    selected.append(Room(name: name, level: level, custom: true, symbol: symbol))
                }
            }
        case .work:
            ForEach(["Office","Remote","Hybrid","Variable"], id: \.self) { value in
                choice(value, "", "briefcase.fill", Theme.surface, Binding(get: { schedule.profile }, set: { schedule.profile = $0 }))
            }
        case .days:
            ForEach(1...7, id: \.self) { day in
                card(Calendar.current.weekdaySymbols[day - 1], "", "calendar", Theme.surface, schedule.officeDays & (1 << day) != 0) { schedule.officeDays ^= 1 << day }
            }
        case .profile: ProfileFields()
        case .reminders: ReminderOptions()
        case .membership: EmptyView()
        }
    }
    private func wheel(_ label: String, _ icon: String, _ color: Color, _ values: [Int], _ selection: Binding<Int>) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).padding(.top, 12)
            Text(LocalizedStringKey(label)).font(.headline)
            Picker(LocalizedStringKey(label), selection: selection) {
                ForEach(values, id: \.self) { value in
                    if step == .minutes { Text(PlanningRules.durationLabel(value)).font(.title.bold()).tag(value) }
                    else { Text(value, format: .number).font(.title.bold()).tag(value) }
                }
            }.pickerStyle(.wheel).frame(maxWidth: .infinity)
        }.padding(16).background(color, in: RoundedRectangle(cornerRadius: 28))
    }
    private func goalCard(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        card(title, detail, icon, color, rhythm.goals.contains(title), multiple: true) { rhythm.toggleGoal(title) }
    }
    private func choice(_ title: String, _ detail: String, _ icon: String, _ color: Color, _ binding: Binding<String>) -> some View {
        card(title, detail, icon, color, binding.wrappedValue == title) { binding.wrappedValue = title }
    }
    private func card(_ title: String, _ detail: String, _ icon: String, _ color: Color, _ active: Bool, multiple: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.headline)
                    if !detail.isEmpty { Text(LocalizedStringKey(detail)).font(.subheadline) }
                }
                Spacer()
                Image(systemName: multiple ? (active ? "checkmark.square.fill" : "square") : (active ? "checkmark.circle.fill" : "circle")).foregroundStyle(Theme.leaf)
            }.padding(16).background(color, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(active ? Theme.leaf : .clear, lineWidth: 2).allowsHitTesting(false) }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
    }
    private func move(_ delta: Int) {
        if delta > 0 && step == .level(floorCount), let first = rooms.first {
            if !rooms.contains(where: { $0.rawValue == rhythm.workspace }) { rhythm.workspace = first.rawValue }
            if !rooms.contains(where: { $0.rawValue == rhythm.priority }) { rhythm.priority = first.rawValue }
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = steps[index + delta] }
    }
    private func save() {
        let configured = rooms
        rhythm.floors = floorCount
        rhythm.saveRooms(configured)
        if let first = configured.first {
            if !configured.contains(where: { $0.rawValue == rhythm.priority }) { rhythm.priority = first.rawValue }
            if !configured.contains(where: { $0.rawValue == rhythm.workspace }) { rhythm.workspace = first.rawValue }
        }
        finish()
    }
}

