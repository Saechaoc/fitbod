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
        try seeded(seed, now: now).state
    }

    /// An empty store with the catalog rows the seeds use, after `seed`,
    /// then the pending review when `review` is set.
    private func store(after seed: TodayStatesSeed.State?, review: Bool = false, now: Date) throws -> ModelContext {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        for id in TodayStatesSeed.catalogIDs {
            ctx.insert(Exercise(externalID: id, name: id, canonicalName: id.lowercased(), equipmentRaw: "barbell", mechanicRaw: "compound"))
        }
        if let seed { TodayStatesSeed.seed(seed, in: ctx, now: now) }
        if review { TodayStatesSeed.seedPendingReview(in: ctx, now: now) }
        return ctx
    }

    /// Seeds `seed`, then the pending review when `review` is set, and
    /// resolves Today's state and the review its notice offers.
    private func seeded(
        _ seed: TodayStatesSeed.State?, review: Bool = false, now: Date
    ) throws -> (state: TodayState, pendingReview: Block?) {
        let ctx = try store(after: seed, review: review, now: now)
        let blocks = try ctx.fetch(FetchDescriptor<Block>())
        let workouts = try ctx.fetch(FetchDescriptor<Session>())
        let active = blocks.first { $0.isActive }
        let state = TodayState.resolve(
            openWorkouts: workouts.filter { $0.completedAt == nil },
            activeBlock: active,
            resolution: active.map { TodayResolver.resolve(block: $0, context: ctx, today: now, calendar: calendar) } ?? .noBlock,
            finishedWorkouts: workouts.filter { $0.completedAt != nil },
            readyBlocks: blocks.filter { $0.derivedStatus == .ready },
            liveRoutines: try ctx.fetch(FetchDescriptor<Split>()).filter { !$0.isArchived },
            sessions: try ctx.fetch(FetchDescriptor<SessionTemplate>()).filter { !$0.isArchived },
            now: now, calendar: calendar)
        return (state, try BlockReviewStatistics.pendingReviewBlocks(context: ctx, now: now).first)
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
        case (.doneWeekly, .done(let workouts)):
            #expect(workouts.count == 1)
            #expect(workouts.first?.block?.schedulingMode == .fixedWeekly)
        case (.weekly, .today(let block, _)):
            #expect(block.schedulingMode == .fixedWeekly)
        case (.pick, .pick(let suggestion)):
            // Push A was trained two days ago, so the routine's NEXT is Pull A.
            #expect(suggestion.session.name == "Pull A")
            #expect(suggestion.slot?.split?.name == TodayStatesSeed.routineName)
        case (.fix, .fix(.routineHasNoExercises(let routine))):
            #expect(routine.name == TodayStatesSeed.routineName)
        case (.rest, .rest), (.attach, .attach):
            break
        default:
            Issue.record("the \(seed.rawValue) seed gave \(state)")
        }
    }

    /// The captures of the review notice (RM-013) open each state it shows on.
    @Test("the review flag leaves a review pending on the state it is seeded with",
          arguments: [TodayStatesSeed.State.done, .ready, .pick, .fix, nil])
    func reviewFlagLeavesAReviewPending(_ seed: TodayStatesSeed.State?) throws {
        let (state, pending) = try seeded(seed, review: true, now: noon)
        let review = try #require(pending, "the review flag left no review pending")
        #expect(TodayState.notice(state: state, pendingReview: review, advisory: nil, phase: nil) == .review(review))
        switch (seed, state) {
        case (.done, .done):
            #expect(review.name == TodayStatesSeed.blockName, "the done seed's block ends")
        case (.ready, .ready), (.pick, .pick), (.fix, .fix(.routineHasNoExercises)), (nil, .first):
            #expect(review.name == TodayStatesSeed.endedBlockName)
        default:
            Issue.record("the \(seed?.rawValue ?? "review") seed gave \(state)")
        }
    }

    /// The training days sort to the locale's week order, so on some weekdays
    /// today's session is not the routine's first.
    @Test("the weekly done seed finishes the session the block schedules today, on every weekday")
    func weeklyDoneSeedTrainsTodaysSession() throws {
        for offset in 0..<7 {
            let now = noon.addingTimeInterval(Double(offset) * 86_400)
            guard case .done(let workouts) = try state(after: .doneWeekly, now: now),
                  let block = workouts.first?.block,
                  case .session(let today) = TodayResolver.resolveFixedWeekly(block: block, today: now, calendar: calendar)
            else {
                Issue.record("day +\(offset): no T-DONE on a day the block trains")
                continue
            }
            #expect(workouts.map(\.slot) == [today], "day +\(offset)")
        }
    }

    /// Program's This week shows only this week, so the weekly seed's
    /// workouts stay in it on every launch weekday, before today.
    @Test("the weekly seed logs only in this week before today, and nothing on the week's first day",
          arguments: 0..<7)
    func weeklySeedStaysInThisWeek(_ offset: Int) throws {
        let now = noon.addingTimeInterval(Double(offset) * 86_400)
        let ctx = try store(after: .weekly, now: now)
        let weekStart = ThisWeek.weekStart(try ctx.fetch(FetchDescriptor<UserSettings>()), now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let workouts = try ctx.fetch(FetchDescriptor<Session>())

        #expect(workouts.allSatisfy { $0.startedAt >= weekStart && $0.startedAt < today })
        #expect(workouts.isEmpty == (weekStart == today))
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
