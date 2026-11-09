import Foundation
import SwiftData
import Testing
@testable import fitbod

/// Each Today seed must land on the state it is named for: the 390pt captures
/// and the redesign slices open Today through these seeds.
@MainActor
@Suite("TodayStatesSeed", .serialized)
struct TodayStatesSeedTests {
    private let calendar = Calendar.current
    /// Noon today, so no test depends on the hour it runs at.
    private var noon: Date { calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600) }

    /// Seeds `seed` into an empty store at `now` and resolves Today from what Today reads.
    private func state(after seed: TodayStatesSeed.State, now: Date) throws -> TodayState {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        for name in TodayStatesSeed.catalogNames {
            ctx.insert(Exercise(name: name, canonicalName: name.lowercased(), equipmentRaw: "barbell", mechanicRaw: "compound"))
        }
        TodayStatesSeed.seed(seed, in: ctx, now: now)

        let blocks = try ctx.fetch(FetchDescriptor<Block>())
        let workouts = try ctx.fetch(FetchDescriptor<Session>())
        let active = blocks.first { $0.isActive }
        return TodayState.resolve(
            openWorkouts: workouts.filter { $0.completedAt == nil },
            activeBlock: active,
            resolution: active.map { TodayResolver.resolve(block: $0, context: ctx, today: now, calendar: calendar) } ?? .noBlock,
            finishedWorkouts: workouts.filter { $0.completedAt != nil },
            readyBlocks: blocks.filter { $0.derivedStatus == .ready },
            liveRoutines: try ctx.fetch(FetchDescriptor<Split>()).filter { !$0.isArchived },
            sessions: try ctx.fetch(FetchDescriptor<SessionTemplate>()).filter { !$0.isArchived },
            now: now, calendar: calendar)
    }

    @Test("each seed reaches its Today state", arguments: TodayStatesSeed.State.allCases)
    func seedReachesItsState(_ seed: TodayStatesSeed.State) throws {
        let state = try state(after: seed, now: noon)
        switch (seed, state) {
        case (.ready, .ready(let block)):
            #expect(block.name == TodayStatesSeed.blockName)
        case (.empty, .fix(.sessionHasNoExercises(let session))):
            #expect(session.name == TodayStatesSeed.emptySessionName)
        case (.done, .done(let workouts)):
            #expect(workouts.map(\.displayName) == ["Pull A", "Push A"])
        case (.pick, .pick(let suggestion)):
            // Push A was trained two days ago, so the routine's NEXT is Pull A.
            #expect(suggestion.session.name == "Pull A")
            #expect(suggestion.slot?.split?.name == TodayStatesSeed.routineName)
        case (.rest, .rest), (.attach, .attach):
            break
        default:
            Issue.record("the \(seed.rawValue) seed gave \(state)")
        }
    }

    @Test("workouts seeded as done today stay on today one minute after midnight")
    func doneTodayHoldsJustAfterMidnight() throws {
        let justAfterMidnight = calendar.startOfDay(for: .now).addingTimeInterval(60)
        guard case .done(let workouts) = try state(after: .done, now: justAfterMidnight) else {
            Issue.record("the done seed did not give T-DONE one minute after midnight")
            return
        }
        #expect(workouts.count == 2)
    }
}
