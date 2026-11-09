import SwiftUI
import SwiftData

struct PlannerScreen: View {
    @Environment(\.modelContext) private var context
    private var roomProfile = HomeRhythm()
    @State private var room = Room.kitchen
    @State private var minutes = 10
    @State private var plan: Plan?
    @State private var busy = false
    @State private var added = false
    @State private var failed = false
    var body: some View {
        Page(title: "Routine library") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142))], spacing: 12) {
            ForEach(Routine.allCases) { routine in
                NavigationLink {
                    ScrollView { RoutineDetail(routine: routine, date: .now).padding() }.background(Theme.paper)
                        .browsingAdvertising()
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Image(systemName: routine.symbol).font(.title2).padding(.bottom, 8)
                        Text(LocalizedStringKey(routine.name)).font(.headline)
                        Text(LocalizedStringKey(routine.intent)).font(.caption)
                    }.padding(16).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .background(routine.surface, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
            }
            Text("Build a room plan").font(.title2.bold())
            VStack(alignment: .leading, spacing: 20) {
                Picker("Room", selection: $room) {
                    ForEach(roomProfile.rooms) { Text(roomProfile.label($0)).tag($0) }
                }.pickerStyle(.menu).onAppear { if !roomProfile.rooms.contains(room), let first = roomProfile.rooms.first { room = first } }
                Text("Time available").font(.headline)
                Picker("Time available", selection: $minutes) {
                    ForEach(PlanningRules.sessionMinutes, id: \.self) { Text(PlanningRules.durationLabel($0)).tag($0) }
                }.pickerStyle(.menu)
            }.panel().disabled(busy)
            Button {
                busy = true
                added = false
                plan = nil
                Task { plan = await Planner.generate(room: room, minutes: minutes); busy = false }
            } label: {
                Label(busy ? "Planning…" : "Build my plan", systemImage: "sparkles").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.leaf).disabled(busy)
            if let plan {
                Text("Your \(plan.totalMinutes)-minute routine").font(.title3.bold())
                Text(LocalizedStringKey(plan.source)).font(.caption).foregroundStyle(.secondary)
                ForEach(plan.titles, id: \.self) { Text(LocalizedStringKey($0)).panel() }
                Button(added ? "Added to Today" : "Add to Today") {
                    for title in plan.titles { context.insert(Reset(title, room: room, minutes: 5)) }
                    do { try context.save(); added = true } catch { context.rollback(); failed = true }
                }.buttonStyle(.bordered).disabled(added)
            }
        }.browsingAdvertising()
        .onChange(of: room) { plan = nil }.onChange(of: minutes) { plan = nil }
        .alert("Couldn’t save this plan", isPresented: $failed) { Button("OK") {} }
    }
}
