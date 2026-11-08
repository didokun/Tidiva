import Foundation
import FoundationModels

struct Plan {
    let titles: [String]
    let source: String
    var totalMinutes: Int { titles.count * 5 }
}

enum Planner {
    static func generate(room: Room, minutes: Int) async -> Plan {
        let count = PlanningRules.taskCount(minutes: minutes, available: room.ideas.count)
        guard count > 0 else { return Plan(titles: [], source: "Offline routine") }
        if #available(iOS 26, *), SystemLanguageModel.default.availability == .available {
            do {
                // The model selects only reviewed actions; free-form cleaning instructions are never saved.
                let session = LanguageModelSession(instructions: "Select only exact task titles from the supplied list. Return one exact title per line, without numbering or commentary.")
                let response = try await session.respond(to: "Choose exactly \(count) distinct tasks for the \(room.displayName) from this list: \(room.ideas.joined(separator: "; ")).")
                try Task.checkCancellation()
                let lines = response.content.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if lines.count == count, Set(lines).count == count, lines.allSatisfy({ room.ideas.contains($0) }) {
                    return Plan(titles: lines, source: "On-device AI selection")
                }
            } catch { /* Fall back to reviewed actions when on-device generation is unavailable. */ }
        }
        return Plan(titles: Array(room.ideas.prefix(count)), source: "Offline routine")
    }
}
