import Foundation

/// The one answer to "what is Today showing", resolved from what Today already reads.
/// Precedence: resume, done, ready, fix, attach, rest, today, pick, first
/// (docs/design-map/redesign/hierarchy.md, the Today state table).
enum TodayState: Equatable {
    case resume(Session)                 // the open workout with the newest startedAt
    case done([Session])                 // today's counted finished workouts, newest first
    case ready(Block)                    // no active block; the first ready block (O-6)
    case fix(Fix)
    case attach(Block)                   // active block whose routine is nil
    case rest(Block)
    case today(Block, SplitSessionSlot)  // the scheduled slot, whose session has exercises
    case pick(StartSlot.Suggestion)      // no block; the session to lead with and the slot its start credits
    case first

    enum Fix: Equatable {
        case routineHasNoSessions(Split)
        case routineHasNoExercises(Split)
        case sessionHasNoExercises(SessionTemplate)
    }

    /// `sessions` is every non-archived SessionTemplate; a template that no live routine's
    /// slot holds counts as a standalone session.
    static func resolve(
        openWorkouts: [Session],
        activeBlock: Block?,
        resolution: TodayResolution,
        finishedWorkouts: [Session],
        readyBlocks: [Block],
        liveRoutines: [Split],
        sessions: [SessionTemplate],
        now: Date,
        calendar: Calendar
    ) -> TodayState {
        if let open = openWorkouts.max(by: { $0.startedAt < $1.startedAt }) { return .resume(open) }

        let doneToday = StartSlot.doneToday(finishedWorkouts, now: now, calendar: calendar)
        if !doneToday.isEmpty { return .done(doneToday) }

        if let block = activeBlock {
            guard let routine = block.split else { return .attach(block) }
            switch resolution {
            case .emptySplit:
                return .fix(.routineHasNoSessions(routine))
            case .noBlock:
                return .attach(block) // the resolver returns this only when the block has no routine
            case .restDay:
                return .rest(block)
            case .session(let slot):
                guard let template = slot.sessionTemplate else { return .fix(.routineHasNoSessions(routine)) }
                return StartSlot.hasExercises(template) ? .today(block, slot) : .fix(.sessionHasNoExercises(template))
            }
        }

        // Program's ready slab leads with the same block (O-6).
        if let ready = readyBlocks.min(by: ProgramBlocks.readyOrder) { return .ready(ready) }

        if let suggestion = StartSlot.suggestion(liveRoutines: liveRoutines, sessions: sessions, finished: finishedWorkouts) {
            return .pick(suggestion)
        }

        let repairRoutine = liveRoutines.min { a, b in
            let aEdited = (a.slots ?? []).compactMap { $0.sessionTemplate?.updatedAt }.max() ?? .distantPast
            let bEdited = (b.slots ?? []).compactMap { $0.sessionTemplate?.updatedAt }.max() ?? .distantPast
            return (bEdited, b.createdAt, a.name, a.id.uuidString) < (aEdited, a.createdAt, b.name, b.id.uuidString)
        }
        if let routine = repairRoutine {
            return (routine.slots ?? []).isEmpty ? .fix(.routineHasNoSessions(routine)) : .fix(.routineHasNoExercises(routine))
        }
        return .first
    }

    /// The one notice row above the hero (hierarchy.md, the notice rows).
    enum Notice: Equatable {
        /// "SUMMER BLOCK FINISHED · REVIEW ›": the last ended block's review is pending (RM-013).
        case review(Block)
        /// "CONSIDER A DELOAD · 3 SIGNALS ›".
        case deload(DeloadAdvisory)
    }

    /// None while a workout is open. A pending review, which
    /// `BlockReviewStatistics.pendingReviewBlocks` gives only without an
    /// active block, outranks the deload advisory, which never shows in a
    /// deload phase.
    static func notice(
        state: TodayState, pendingReview: Block?, advisory: DeloadAdvisory?, phase: BlockPhaseKind?
    ) -> Notice? {
        if case .resume = state { return nil }
        if let pendingReview { return .review(pendingReview) }
        guard let advisory, phase != .deload else { return nil }
        return .deload(advisory)
    }
}
