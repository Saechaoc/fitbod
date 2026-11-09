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

        let ready = readyBlocks.min {
            ($0.startDate, $0.name, $0.id.uuidString) < ($1.startDate, $1.name, $1.id.uuidString)
        }
        if let ready { return .ready(ready) }

        if let suggestion = StartSlot.suggestion(liveRoutines: liveRoutines, sessions: sessions, finished: finishedWorkouts) {
            return .pick(suggestion)
        }

        if let routine = liveRoutines.max(by: { $0.createdAt < $1.createdAt }) {
            return (routine.slots ?? []).isEmpty ? .fix(.routineHasNoSessions(routine)) : .fix(.routineHasNoExercises(routine))
        }
        return .first
    }

    /// No notice while a workout is open or in a deload phase.
    static func showsDeloadAdvisory(state: TodayState, phase: BlockPhaseKind?) -> Bool {
        if case .resume = state { return false }
        return phase != .deload
    }
}
