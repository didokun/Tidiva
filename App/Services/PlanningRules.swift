import Foundation

enum PlanningRules {
    static let sessionMinutes = [5, 10, 15, 20, 30, 45, 60, 75, 90, 105, 120]

    static func durationLabel(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func taskCount(minutes: Int, available: Int) -> Int {
        max(0, min(minutes / 5, available))
    }

    static func fittingIndices(durations: [Int], budget: Int) -> [Int] {
        var remaining = max(0, budget)
        return durations.indices.filter { index in
            let duration = durations[index]
            guard duration > 0, duration <= remaining else { return false }
            remaining -= duration
            return true
        }
    }
}
