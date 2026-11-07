import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockPosition")
struct BlockPositionTests {
    /// Friday, Oct 30, 2026, noon UTC.
    private let now = Date(timeIntervalSinceReferenceDate: 815_054_400)

    /// An active four-week block (accumulation 2, intensification 1, deload 1).
    private func activeBlock(startedDaysAgo days: Int, phases: Bool = true, in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = "Spring Block"
        block.isActive = true
        block.startDate = now.addingTimeInterval(-Double(days) * 86_400)
        guard phases else { return block }
        let plan: [(BlockPhaseKind, Int)] = [(.accumulation, 2), (.intensification, 1), (.deload, 1)]
        for (index, (kind, weeks)) in plan.enumerated() {
            let phase = BlockPhase()
            context.insert(phase)
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = kind.rawValue
            phase.weeks = weeks
        }
        return block
    }

    @Test("inside its plan the label names the week and phase", arguments: [
        (3, "Week 1 of 4 · Accumulation", "Week 1 of 4, Accumulation"),
        (15, "Week 3 of 4 · Intensification", "Week 3 of 4, Intensification"),
        (27, "Week 4 of 4 · Deload", "Week 4 of 4, Deload"),
    ])
    func insideItsPlan(daysAgo: Int, line: String, spoken: String) throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let label = BlockPosition.label(activeBlock(startedDaysAgo: daysAgo, in: context), on: now)
        #expect(label.line == line)
        #expect(label.spoken == spoken)
    }

    @Test("past its plan the label reads PLAN COMPLETE", arguments: [28, 35])
    func pastItsPlan(daysAgo: Int) throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let label = BlockPosition.label(activeBlock(startedDaysAgo: daysAgo, in: context), on: now)
        #expect(label.line == "PLAN COMPLETE")
        #expect(label.spoken == "Plan complete")
    }

    @Test("a block without phases reads PLAN COMPLETE")
    func aBlockWithoutPhasesReadsPlanComplete() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let label = BlockPosition.label(activeBlock(startedDaysAgo: 3, phases: false, in: context), on: now)
        #expect(label.line == "PLAN COMPLETE")
    }
}
