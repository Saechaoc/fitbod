//
//  StartSlot.swift
//  fitbod
//
//  The one rule for which slot a workout start credits (RM-006, O-2). Today's
//  hero, the session sheet, session detail and Program's starts all ask here,
//  so starting the same session by any route moves the rotation the same way.
//
//  Pure: it reads only the models handed to it and fetches nothing. A caller
//  that needs the rotation resolver's answer, which does fetch, resolves first
//  and passes the result in.
//

import Foundation

enum StartSlot {

    /// What Today leads with when no block runs: a session, and the slot its start credits.
    struct Suggestion: Equatable {
        let session: SessionTemplate
        /// Nil for a session in no live routine, which starts unslotted.
        let slot: SplitSessionSlot?
    }

    static func hasExercises(_ session: SessionTemplate?) -> Bool {
        !(session?.exercises ?? []).isEmpty
    }

    /// The counted workouts started today, newest first: what T-DONE lists,
    /// and what moves a weekly block's NEXT on to the next training day.
    /// The day is checked first, so only today's workouts have their sets read.
    static func doneToday(_ finished: [Session], now: Date, calendar: Calendar) -> [Session] {
        SessionSetActions.countedWorkouts(finished.filter { calendar.isDate($0.startedAt, inSameDayAs: now) })
            .sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - NEXT

    /// NEXT in an active block. Rotation: the resolver's next slot. Weekly:
    /// today's slot while today trains and no counted workout started today,
    /// otherwise the next training day's slot. Nil when nothing is next.
    static func next(
        in block: Block, resolution: TodayResolution, finished: [Session], now: Date, calendar: Calendar
    ) -> SplitSessionSlot? {
        if case .session(let slot) = resolution,
           block.schedulingMode == .rotation || doneToday(finished, now: now, calendar: calendar).isEmpty {
            return slot
        }
        return TodayResolver.nextTrainingDay(block: block, after: now, calendar: calendar)?.slot
    }

    /// NEXT in a routine no block runs: the first slot at or after the anchor
    /// whose session has exercises, so NEXT never names an empty session. The
    /// anchor is the slot after the newest counted workout slotted in this
    /// routine, wrapping, or the first slot when there is none. Open, empty,
    /// unslotted and other-routine workouts, and those whose slot was deleted,
    /// do not move it. Nil when no session in the routine has exercises.
    static func next(in routine: Split, finished: [Session]) -> SplitSessionSlot? {
        next(in: routine, after: lastSlotted(in: routine, finished: finished))
    }

    private static func next(in routine: Split, after workout: Session?) -> SplitSessionSlot? {
        let slots = ordered(routine)
        let anchor = workout.flatMap { workout in slots.firstIndex { $0.id == workout.slot?.id } }.map { $0 + 1 } ?? 0
        return cycle(slots, from: anchor).first { hasExercises($0.sessionTemplate) }
    }

    /// The newest counted workout whose slot is in `routine`. Sorted before
    /// the empty check, so only the newest candidates have their sets read.
    private static func lastSlotted(in routine: Split, finished: [Session]) -> Session? {
        finished
            .filter { $0.completedAt != nil && $0.slot?.split?.id == routine.id }
            .sorted { $0.startedAt > $1.startedAt }
            .first { !SessionSetActions.isEmptyWorkout($0) }
    }

    // MARK: - The slot a start credits

    /// The slot a start of `session` credits in `routine`: NEXT when NEXT holds
    /// the session, else its first slot after NEXT, wrapping, so a session
    /// slotted twice never moves the rotation backwards. With no NEXT, its
    /// first slot. Nil when the routine does not hold the session.
    static func slot(for session: SessionTemplate, in routine: Split, next: SplitSessionSlot?) -> SplitSessionSlot? {
        let slots = ordered(routine)
        let from = next.flatMap { next in slots.firstIndex { $0.id == next.id } } ?? 0
        return cycle(slots, from: from).first { $0.sessionTemplate?.id == session.id }
    }

    /// The sessions a start at `slot` moves the rotation past this cycle: those
    /// in the slots from NEXT up to `slot`, each named once. Empty when `slot`
    /// is NEXT. Only a rotation block and a routine with no block skip; a
    /// weekly block maps days to slots and moves nothing.
    static func skipped(startingAt slot: SplitSessionSlot, next: SplitSessionSlot?) -> [SessionTemplate] {
        guard let next, let routine = slot.split else { return [] }
        let slots = ordered(routine)
        guard let from = slots.firstIndex(where: { $0.id == next.id }),
              let to = slots.firstIndex(where: { $0.id == slot.id }) else { return [] }
        var seen = Set<UUID>()
        return cycle(slots, from: from)
            .prefix((to - from + slots.count) % slots.count)
            .compactMap(\.sessionTemplate)
            .filter { seen.insert($0.id).inserted }
    }

    // MARK: - Today's suggestion with no block

    /// The session Today leads with when no block runs. The live routine
    /// holding the newest counted slotted workout gives its NEXT; when no
    /// routine has one, the routine holding the most recently updated session
    /// with exercises does. A routine with no NEXT is passed over. With no
    /// such routine, the most recently updated session with exercises that
    /// sits in no live routine, which starts unslotted. Name, then id, break ties.
    static func suggestion(liveRoutines: [Split], sessions: [SessionTemplate], finished: [Session]) -> Suggestion? {
        let leads = liveRoutines.compactMap { routine -> (slot: SplitSessionSlot, trained: Date, edited: Date, name: String, id: String)? in
            let last = lastSlotted(in: routine, finished: finished)
            guard let next = next(in: routine, after: last) else { return nil }
            let edited = ordered(routine).compactMap(\.sessionTemplate).filter { hasExercises($0) }.map(\.updatedAt).max()
            return (next, last?.startedAt ?? .distantPast, edited ?? .distantPast, routine.name, routine.id.uuidString)
        }
        // The dates swap sides, so the newest workout, then the newest edit, sorts first.
        let lead = leads.min { ($1.trained, $1.edited, $0.name, $0.id) < ($0.trained, $0.edited, $1.name, $1.id) }
        if let lead, let session = lead.slot.sessionTemplate {
            return Suggestion(session: session, slot: lead.slot)
        }
        let slotted = Set(liveRoutines.flatMap { ordered($0).compactMap { $0.sessionTemplate?.id } })
        return sessions
            .filter { !slotted.contains($0.id) && hasExercises($0) }
            .min { ($1.updatedAt, $0.name, $0.id.uuidString) < ($0.updatedAt, $1.name, $1.id.uuidString) }
            .map { Suggestion(session: $0, slot: nil) }
    }

    // MARK: - Slot order

    private static func ordered(_ routine: Split) -> [SplitSessionSlot] {
        (routine.slots ?? []).sorted { $0.position < $1.position }
    }

    /// Every slot once, starting at index `start` and wrapping.
    private static func cycle(_ slots: [SplitSessionSlot], from start: Int) -> [SplitSessionSlot] {
        slots.indices.map { slots[(start + $0) % slots.count] }
    }
}
