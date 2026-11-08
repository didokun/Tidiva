import SwiftUI
import SwiftData

enum Routine: String, CaseIterable, Identifiable {
    case arrival, pause, guests, sunday
    var id: Self { self }
    var name: String {
        switch self {
        case .arrival: "After-work reset"
        case .pause: "Work-from-home break"
        case .guests: "Guests are coming"
        case .sunday: "Sunday reset"
        }
    }
    var intent: String {
        switch self {
        case .arrival: "Settle in with one easy zone."
        case .pause: "A quiet break near your workspace."
        case .guests: "Start with the spaces your guests will see."
        case .sunday: "Work through your home one floor at a time."
        }
    }
}

struct HomeRhythm: DynamicProperty {
    @AppStorage("tidiva.weeklySessions") var sessions = 7
    @AppStorage("tidiva.weeklyLoads") var loads = 1
    // A single stored title from earlier versions is also a valid list of one.
    @AppStorage("tidiva.goal") private var goalList = "Keep things tidy"
    var goals: [String] { goalList.split(separator: "|").map(String.init) }
    func toggleGoal(_ goal: String) {
        goalList = (goals.contains(goal) ? goals.filter { $0 != goal } : goals + [goal]).joined(separator: "|")
    }
    func focus(on date: Date) -> String? {
        guard !goals.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 1
        return goals[(day - 1) % goals.count]
    }
    @AppStorage("tidiva.work") var work = "Office"
    @AppStorage("tidiva.remoteDays") var remoteDays = 0
    @AppStorage("tidiva.floors") var floors = 1
    @AppStorage("tidiva.roomLevels") var levels = ""
    @AppStorage("tidiva.rooms") var roomList = "Kitchen,Living room,Bedroom,Entryway"
    @AppStorage("tidiva.workspace") var workspace = "Office"
    @AppStorage("tidiva.favorite") var favorite = ""
    @AppStorage("tidiva.priorityRoom") var priority = "Kitchen"
    var rooms: [Room] {
        let keys = (try? JSONDecoder().decode([String].self, from: Data(roomList.utf8))) ?? roomList.components(separatedBy: ",")
        return keys.compactMap(Room.init(rawValue:))
    }
    func saveRooms(_ rooms: [Room]) {
        if let data = try? JSONEncoder().encode(rooms.map(\.rawValue)) { roomList = String(decoding: data, as: UTF8.self) }
    }
    func label(_ room: Room) -> String {
        floors > 1 ? room.displayName + " · " + String(localized: "Floor \(floor(room))") : room.displayName
    }
    func floor(_ room: Room) -> Int {
        if let level = room.level { return level }
        let pair = levels.split(separator: "|").first { $0.hasPrefix(room.rawValue + "=") }
        return min(floors, max(1, Int(pair?.split(separator: "=").last ?? "1") ?? 1))
    }
    func setFloor(_ room: Room, _ value: Int) {
        var entries = levels.split(separator: "|").map(String.init).filter { !$0.hasPrefix(room.rawValue + "=") }
        entries.append("\(room.rawValue)=\(value)")
        levels = entries.joined(separator: "|")
    }
    func reason(for routine: Routine) -> String {
        if favorite == routine.rawValue { return String(localized: "Your favorite routine") }
        switch routine {
        case .sunday: return String(localized: "Your weekly reset")
        case .guests: return String(localized: "Getting ready for company")
        case .arrival: return String(localized: "One zone at a time") + " · " + (Room(rawValue: priority).map(label) ?? priority)
        case .pause: return String(localized: "Work-from-home day") + " · " + (Room(rawValue: workspace).map(label) ?? workspace)
        }
    }
    func recommendation(on date: Date) -> Routine {
        if let chosen = Routine(rawValue: favorite) { return chosen }
        let day = Calendar.current.component(.weekday, from: date)
        if focus(on: date) == "Be ready for guests" { return .guests }
        if day == 1 { return .sunday }
        if work == "Remote" || (work == "Hybrid" && remoteDays & (1 << day) != 0) { return .pause }
        return .arrival
    }
}

struct RoutineTask: Identifiable {
    let room: Room
    let title: String
    let minutes: Int
    let existing: Reset?
    var id: String { room.rawValue + "|" + title }
}

enum RoutineBuilder {
    static func tasks(_ routine: Routine, rhythm: HomeRhythm, budget: Int, history: [Reset], date: Date) -> [RoutineTask] {
        let focusRooms: [Room]
        switch rhythm.focus(on: date) {
        case "Stay on top of laundry" where rhythm.loads > 0: focusRooms = [.laundry, .bedroom]
        case "Keep the kitchen ready": focusRooms = [.kitchen]
        case "Freshen up the bathroom": focusRooms = [.bathroom]
        case "Wind down in a tidy bedroom": focusRooms = [.bedroom]
        default: focusRooms = []
        }
        let preferred: [Room]
        switch routine {
        case .arrival: preferred = focusRooms + [Room(rawValue: rhythm.priority) ?? .kitchen, .entry, .kitchen]
        case .pause: preferred = [Room(rawValue: rhythm.workspace) ?? .office] + focusRooms + [.office]
        case .guests: preferred = [.entry, .bathroom, .living, .kitchen]
        case .sunday: preferred = focusRooms
        }
        let ranked = preferred.flatMap { candidate in
            rhythm.rooms.filter { $0 == candidate } + rhythm.rooms.filter { candidate.kind != nil && $0.kind == candidate.kind }
        }
        var rooms = (ranked + rhythm.rooms).reduce(into: [Room]()) { result, room in
            if rhythm.rooms.contains(room), !result.contains(room) { result.append(room) }
        }
        if routine == .pause, let first = rooms.first { rooms = rooms.filter { rhythm.floor($0) == rhythm.floor(first) } }
        if routine == .sunday {
            rooms.sort { left, right in
                if rhythm.floor(left) != rhythm.floor(right) { return rhythm.floor(left) < rhythm.floor(right) }
                let last = { (room: Room) in history.filter { $0.roomName == room.rawValue }.compactMap(\.completed).max() ?? .distantPast }
                return last(left) < last(right)
            }
        }
        var remaining = budget
        var result: [RoutineTask] = []
        for room in rooms {
            for (i, title) in room.ideas.enumerated() {
                let matches = history.filter { $0.roomName == room.rawValue && $0.title == title }
                let cutoff = Calendar.current.date(byAdding: .day, value: i == 2 ? -6 : 1 - max(1, 7 / max(1, room.kind == .laundry ? rhythm.loads : rhythm.sessions)), to: Calendar.current.startOfDay(for: date)) ?? date
                if matches.contains(where: { ($0.completed ?? .distantPast) >= cutoff }) { continue }
                if Calendar.current.component(.weekday, from: date) != 1 && matches.contains(where: { $0.sundayOnly }) { continue }
                let pending = matches.first { $0.completed == nil && $0.scheduled <= date }
                let minutes = pending?.minutes ?? [2,3,5][i]
                guard minutes <= remaining else { continue }
                result.append(RoutineTask(room: room, title: title, minutes: minutes, existing: pending))
                remaining -= minutes
                if routine == .guests { break }
            }
            if routine == .arrival && !result.isEmpty { break }
        }
        return result
    }
}
