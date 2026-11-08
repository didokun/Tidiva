import SwiftUI
import SwiftData

extension Routine {
    var symbol: String {
        switch self {
        case .arrival: "house.fill"
        case .pause: "cup.and.saucer.fill"
        case .guests: "person.2.fill"
        case .sunday: "sun.max.fill"
        }
    }
    var surface: Color {
        switch self {
        case .arrival: Theme.surface
        case .pause: Theme.surface
        case .guests: Theme.surface
        case .sunday: Theme.surface
        }
    }
}

struct RoutineDetail: View {
    let routine: Routine
    let date: Date
    @Query(sort: \Reset.scheduled) private var history: [Reset]
    @Environment(\.modelContext) private var context
    @AppStorage("tidiva.dailyMinutes") private var usualMinutes = 15
    private var rhythm = HomeRhythm()
    @State private var overrideMinutes: Int?
    @State private var session: RunningRoutine?
    @State private var failed = false
    init(routine: Routine, date: Date) {
        self.routine = routine
        self.date = date
    }
    private struct RunningRoutine: Identifiable { let id = UUID(); let items: [Reset] }
    var body: some View {
        let budget = overrideMinutes ?? usualMinutes
        let steps = RoutineBuilder.tasks(routine, rhythm: rhythm, budget: budget, history: history, date: date)
        VStack(alignment: .leading, spacing: 16) {
            Label(LocalizedStringKey(routine.name), systemImage: routine.symbol)
                .font(.title2.bold()).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(routine.surface)
            VStack(alignment: .leading, spacing: 14) {
                Text(LocalizedStringKey(routine.intent)).font(.body)
                Picker("Available time", selection: Binding { budget } set: { overrideMinutes = $0 }) {
                    ForEach(PlanningRules.sessionMinutes, id: \.self) { Text(PlanningRules.durationLabel($0)).tag($0) }
                }.pickerStyle(.menu)
                ForEach(steps) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey(item.title)).font(.headline)
                            Text(item.room.displayName + (rhythm.floors > 1 ? " · " + String(localized: "Floor \(rhythm.floor(item.room))") : "")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(item.minutes) min").font(.subheadline.monospacedDigit())
                    }
                    Divider()
                }
                if steps.isEmpty {
                    Text("Nothing due for this routine within your time limit. Try another routine or check back tomorrow.").foregroundStyle(.secondary)
                } else {
                    PrimaryButton(title: String(localized: "Start · \(steps.reduce(0) { $0 + $1.minutes }) min"), symbol: "play.fill") {
                        let items = steps.map { task in
                            if let existing = task.existing { return existing }
                            let reset = Reset(task.title, room: task.room, minutes: task.minutes)
                            context.insert(reset)
                            return reset
                        }
                        do { try context.save(); session = RunningRoutine(items: items) }
                        catch { context.rollback(); failed = true }
                    }
                }
                Button {
                    rhythm.favorite = rhythm.favorite == routine.rawValue ? "" : routine.rawValue
                } label: {
                    Label(rhythm.favorite == routine.rawValue ? "Remove favorite" : "Make my favorite", systemImage: rhythm.favorite == routine.rawValue ? "heart.fill" : "heart")
                }
            }.padding([.horizontal,.bottom], 18)
        }.background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .sheet(item: $session) { SessionScreen(items: $0.items) }
            .alert("Couldn’t start this routine", isPresented: $failed) { Button("OK") {} }
    }
}
