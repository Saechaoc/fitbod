import Foundation

/// The one form of a block's week and phase, read by Today, Block overview and Program.
@MainActor
enum BlockPosition {
    /// ("Week 2 of 4 · Accumulation", "Week 2 of 4, Accumulation"), or
    /// ("PLAN COMPLETE", "Plan complete") past the plan or with no phases.
    /// A block that has not started reads as week 1.
    static func label(_ block: Block, on date: Date) -> (line: String, spoken: String) {
        let totalWeeks = MesocycleWeekPage.totalWeeks(of: block)
        guard totalWeeks > 0,
              case .week(let weekIndex) = PlanWeek.of(block, on: date) ?? .week(0)
        else {
            return (PlanWeek.completeLabel, "Plan complete")
        }
        let kind = PeriodizationEngine.weekContext(for: block, weekIndex: weekIndex, on: date)?.phaseKind.rawValue
        let phase = (kind ?? "Accumulation").capitalized
        return (
            "Week \(weekIndex + 1) of \(totalWeeks) · \(phase)",
            "Week \(weekIndex + 1) of \(totalWeeks), \(phase)"
        )
    }
}
