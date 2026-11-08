import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
expect(PlanningRules.taskCount(minutes: 15, available: 3) == 3, "15-minute plan")
expect(PlanningRules.taskCount(minutes: 30, available: 3) == 3, "Do not invent tasks")
expect(PlanningRules.taskCount(minutes: -5, available: 3) == 0, "Reject negative time")
expect(PlanningRules.taskCount(minutes: 4, available: 3) == 0, "Do not exceed time budget")
expect(PlanningRules.fittingIndices(durations: [12, 5, 3], budget: 8) == [1, 2], "Skip long task and fit shorter tasks")
expect(PlanningRules.fittingIndices(durations: [5, 5, 5], budget: 10) == [0, 1], "Respect session budget")
expect(PlanningRules.fittingIndices(durations: [0, -1, 5], budget: 5) == [2], "Exclude invalid durations")
expect(PlanningRules.fittingIndices(durations: [5], budget: 0).isEmpty, "Empty budget")
print("8 planning checks passed")
