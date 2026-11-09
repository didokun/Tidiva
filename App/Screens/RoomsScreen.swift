import SwiftUI
import SwiftData

struct RoomsScreen: View {
    @Query(sort: \Reset.scheduled) private var resets: [Reset]
    private var rhythm = HomeRhythm()
    @State private var adding = false
    @State private var editing = false
    private var visibleRooms: [Room] {
        var result = rhythm.rooms
        for item in resets {
            if let room = Room(rawValue: item.roomName), !result.contains(room) { result.append(room) }
        }
        return result
    }
    var body: some View {
        NavigationStack {
            Page(title: "My Home") {
                Button("Edit rooms by level") { editing = true }
                ForEach(1...max(rhythm.floors, visibleRooms.map(rhythm.floor).max() ?? 1), id: \.self) { level in
                Text("Floor \(level)").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(visibleRooms.filter { rhythm.floor($0) == level }) { room in
                    let items = resets.filter { $0.roomName == room.rawValue }
                    NavigationLink {
                        Page(title: room.displayName) {
                            if items.isEmpty { Text("Add a reset for this room in Routines.").panel() }
                            ForEach(items) { ResetRow(item: $0) }
                        }.browsingAdvertising()
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: room.symbol).font(.title2)
                            Text(room.displayName).font(.headline)
                            Text("\(items.filter { $0.completed == nil }.count) remaining").font(.subheadline)
                            if rhythm.floors > 1 { Text("Floor \(rhythm.floor(room))").font(.caption) }
                        }.padding(18).frame(maxWidth: .infinity, minHeight: 135, alignment: .leading)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                }
                }
            }.browsingAdvertising()
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add a task") } }
        }.sheet(isPresented: $editing) { OnboardingScreen(editRooms: true) { editing = false } }
        .sheet(isPresented: $adding) { AddTaskScreen() }
    }
}
