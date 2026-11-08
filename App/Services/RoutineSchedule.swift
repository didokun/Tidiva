import Foundation
import SwiftUI

enum RoutineSchedule {
    // Calendar weekdays are 1 (Sunday) through 7 (Saturday).
    static let officeWeek = (2...6).reduce(0) { $0 | (1 << $1) }

    static func dates(minutes: [Int], workdays: Int, budget: Int, occupied: [Date: Int],
                      start: Date = .now, calendar: Calendar = .current) -> [Date] {
        guard workdays & 254 != 254 else { return [] }
        var loads = occupied
        var week = calendar.startOfDay(for: start)
        var days: [Date] = []
        var result: [Date] = []
        for duration in minutes {
            while true {
                if days.isEmpty {
                    days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week) }
                        .filter { workdays & (1 << calendar.component(.weekday, from: $0)) == 0 }
                }
                let candidates = days.filter { day in
                    let used = loads[day, default: 0]
                    return used == 0 || used + duration <= max(1, budget)
                }
                if let day = candidates.min(by: { loads[$0, default: 0] < loads[$1, default: 0] }) {
                    result.append(day)
                    loads[day, default: 0] += duration
                    break
                }
                guard let next = calendar.date(byAdding: .day, value: 7, to: week) else { return [] }
                week = next
                days = []
            }
        }
        return result
    }
}

struct WorkSchedule: DynamicProperty {
    @AppStorage("tidiva.work") private var work = "Office"
    @AppStorage("tidiva.remoteDays") private var legacySelectedDays = 0
    @AppStorage("tidiva.hybridOfficeDays") private var explicitOfficeDays: Int?
    @AppStorage("tidiva.workdays") private var overrideDays: Int?

    var profile: String {
        get { work }
        nonmutating set {
            guard newValue != work else { return }
            work = newValue
            useProfile()
        }
    }

    var profileHint: LocalizedStringKey {
        switch work {
        case "Hybrid": return "Your office days are preselected."
        case "Remote": return "Working from home keeps every day available. Select any days you want to keep free."
        case "Variable": return "Your workweek varies. Select the days to leave out of this schedule."
        default: return "Office work defaults to Monday through Friday. Adjust the days to match your week."
        }
    }

    var officeDays: Int {
        get { explicitOfficeDays ?? legacySelectedDays }
        nonmutating set {
            guard newValue != officeDays else { return }
            useProfile()
            explicitOfficeDays = newValue
        }
    }
    var avoided: Int {
        get {
            if let overrideDays { return overrideDays }
            switch work {
            case "Hybrid": return officeDays
            case "Remote", "Variable": return 0
            default: return RoutineSchedule.officeWeek
            }
        }
        nonmutating set { overrideDays = newValue }
    }
    var hasOverride: Bool { overrideDays != nil }
    func useProfile() { overrideDays = nil }
}

struct WorkdayPicker: View {
    private var schedule = WorkSchedule()
    var body: some View {
        Section("Workdays to avoid") {
            if !schedule.hasOverride { Text(schedule.profileHint).font(.subheadline).foregroundStyle(.secondary) }
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (Calendar.current.firstWeekday - 1 + offset) % 7 + 1
                let bit = 1 << weekday
                Toggle(Calendar.current.weekdaySymbols[weekday - 1], isOn: Binding {
                    schedule.avoided & bit != 0
                } set: { active in
                    schedule.avoided = active ? schedule.avoided | bit : schedule.avoided & ~bit
                })
            }
            if schedule.hasOverride { Button("Use days from my work profile") { schedule.useProfile() } }
            if schedule.avoided & 254 == 254 { Text("Leave at least one day available.").foregroundStyle(.secondary) }
        }
    }
}
