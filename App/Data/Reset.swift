import SwiftData
import Foundation

enum RoomKind: String, CaseIterable, Identifiable {
    case kitchen = "Kitchen", living = "Living room", bedroom = "Bedroom", entry = "Entryway", bathroom = "Bathroom", office = "Office", laundry = "Laundry room"
    case dining = "Dining room", pantry = "Pantry", garage = "Garage", balcony = "Balcony", garden = "Garden", nursery = "Nursery", playroom = "Playroom", closet = "Walk-in closet", basement = "Basement", attic = "Attic", hallway = "Hallway"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .dining: "fork.knife"
        case .pantry: "cabinet"
        case .garage: "car"
        case .balcony: "sun.max"
        case .garden: "leaf"
        case .nursery: "moon.stars"
        case .playroom: "puzzlepiece"
        case .closet: "hanger"
        case .basement: "stairs"
        case .attic: "house"
        case .hallway: "door.left.hand.open"
        case .kitchen: "cup.and.saucer"
        case .living: "sofa"
        case .bedroom: "bed.double"
        case .entry: "door.left.hand.open"
        case .bathroom: "shower"
        case .office: "desktopcomputer"
        case .laundry: "washer"
        }
    }
    var ideas: [String] {
        switch self {
        case .kitchen: ["Clear the counter", "Wipe the sink", "Put away clean dishes"]
        case .living: ["Fold the throws", "Clear the coffee table", "Straighten the cushions"]
        case .bedroom: ["Make the bed", "Clear the nightstand", "Gather the laundry"]
        case .entry: ["Pair up the shoes", "Hang the coats", "Sort the mail"]
        case .bathroom: ["Wipe the bathroom sink", "Put away toiletries", "Replace the hand towels"]
        case .office: ["Clear the desk", "Sort loose papers", "Dust the desk surface"]
        case .laundry: ["Gather the laundry", "Fold clean clothes", "Put away folded clothes"]
        default: ["Put things away", "Clear a surface", "Sweep the floor"]
        }
    }
}

// Legacy tasks store a catalog name. New rooms carry their level and name in the same key.
struct Room: Hashable, Identifiable {
    let rawValue: String
    let name: String
    let level: Int?
    private let customSymbol: String?
    let custom: Bool
    var id: String { rawValue }
    var kind: RoomKind? { custom ? nil : RoomKind(rawValue: name) }
    var symbol: String { customSymbol ?? kind?.symbol ?? "square.grid.2x2" }
    var ideas: [String] { kind?.ideas ?? ["Put things away", "Clear a surface", "Sweep the floor"] }
    var displayName: String { custom ? name : NSLocalizedString(name, comment: "") }
    init?(rawValue: String) {
        self.rawValue = rawValue
        if RoomKind(rawValue: rawValue) != nil {
            name = rawValue
            level = nil
            custom = false
            customSymbol = nil
        } else {
            let parts = rawValue.split(separator: ":", maxSplits: 2)
            guard parts.count == 3, parts[0] == "room" || parts[0] == "custom" || parts[0].hasPrefix("custom/"),
                  let number = Int(parts[1]), number > 0 else { return nil }
            level = number
            name = String(parts[2])
            custom = parts[0] != "room"
            customSymbol = parts[0].hasPrefix("custom/") ? String(parts[0].dropFirst(7)) : nil
        }
    }
    init(name: String, level: Int, custom: Bool, symbol: String? = nil) {
        self.name = name
        self.level = level
        self.custom = custom
        customSymbol = custom ? symbol : nil
        let prefix = customSymbol.map { "custom/" + $0 } ?? (custom ? "custom" : "room")
        rawValue = "\(prefix):\(level):\(name)"
    }
    static var allCases: [Room] { RoomKind.allCases.compactMap { Room(rawValue: $0.rawValue) } }
    static let kitchen = Room(rawValue: RoomKind.kitchen.rawValue)!
    static let living = Room(rawValue: RoomKind.living.rawValue)!
    static let bedroom = Room(rawValue: RoomKind.bedroom.rawValue)!
    static let entry = Room(rawValue: RoomKind.entry.rawValue)!
    static let bathroom = Room(rawValue: RoomKind.bathroom.rawValue)!
    static let office = Room(rawValue: RoomKind.office.rawValue)!
    static let laundry = Room(rawValue: RoomKind.laundry.rawValue)!
}

@Model final class Reset {
    var taskIcon: String?
    var taskNotes: String?
    var title = ""
    var roomName = ""
    var roomLabel: String {
        guard let room = Room(rawValue: roomName) else { return roomName }
        if let level = room.level { return room.displayName + " · " + String(localized: "Floor \(level)") }
        return room.displayName
    }
    var minutes = 5
    var calendarKey: UUID?
    var scheduled = Date.now
    var skippedCount = 0
    var sundayOnly = false
    var completed: Date?
    init(_ title: String, room: Room, minutes: Int, scheduled: Date = .now, taskIcon: String? = nil, taskNotes: String? = nil) {
        self.taskIcon = taskIcon
        self.taskNotes = taskNotes
        self.title = title
        roomName = room.rawValue
        self.minutes = minutes
        self.scheduled = scheduled
    }
    static func seed(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Reset>()) == 0 else { return }
        for room in [Room.kitchen, .living, .entry] {
            context.insert(Reset(room.ideas[0], room: room, minutes: 5))
        }
        try context.save()
    }
}
