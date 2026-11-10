// WorkoutStarter.swift
// fitbod
//
// One entry point for "start this session" (Today's hero and session
// lists, session detail). Wraps SessionFactory.start and turns its errors
// into an outcome each caller can present, so no surface swallows a failed
// start.

import Foundation
import SwiftData

public enum WorkoutStartOutcome {
    /// A new in-progress session was created and saved.
    case started(Session)
    /// Another workout is already in progress; resume it instead.
    case alreadyInProgress(Session)
    /// The template has no exercises.
    case emptyTemplate
    /// Saving failed; the message is user-presentable.
    case failed(String)
}

@MainActor
public enum WorkoutStarter {

    /// Starts `template` from `routine`: the routine it was listed in or
    /// opened from, or nil for a session shown outside any routine.
    /// `StartSlot` works the slot out here, at the tap, so every route
    /// credits the same one and a slot removed since the screen opened is
    /// never credited (RM-006, O-2, D-19). The session is still attributed
    /// to the active block, so block volume and history stay complete.
    public static func start(
        _ template: SessionTemplate,
        in routine: Split?,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WorkoutStartOutcome {
        if let active = inProgressSession(in: context) {
            return .alreadyInProgress(active)
        }
        let block = activeBlock(in: context)
        do {
            let session = try SessionFactory.start(
                template: template,
                slot: slot(for: template, startedFrom: routine, block: block, context: context, now: now, calendar: calendar),
                activeBlock: block,
                on: now,
                calendar: calendar,
                context: context
            )
            return .started(session)
        } catch SessionFactoryError.routineHasNoExercises {
            return .emptyTemplate
        } catch SessionFactoryError.activeSessionAlreadyExists {
            if let active = inProgressSession(in: context) {
                return .alreadyInProgress(active)
            }
            return .failed("Another workout is already in progress.")
        } catch {
            return .failed("The new workout couldn't be saved. Try again.")
        }
    }

    /// The slot a start of `template` from `routine` credits, read from the
    /// store as it is now and decided by `StartSlot`.
    private static func slot(
        for template: SessionTemplate, startedFrom routine: Split?, block: Block?,
        context: ModelContext, now: Date, calendar: Calendar
    ) -> SplitSessionSlot? {
        guard let routine else { return nil }
        let finished = (try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt != nil }))) ?? []
        return StartSlot.slot(
            for: template, startedFrom: routine, block: block,
            resolution: block.map { TodayResolver.resolve(block: $0, context: context, today: now, calendar: calendar) } ?? .noBlock,
            finished: finished, now: now, calendar: calendar)
    }

    public static func inProgressSession(in context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// The block with `isActive == true`, if any. `isActive` is the single
    /// exclusivity flag (see CLAUDE.md entity map).
    private static func activeBlock(in context: ModelContext) -> Block? {
        var descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.isActive })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Most recent completed session started from `template`.
    public static func lastCompletedSession(of template: SessionTemplate, in context: ModelContext) -> Session? {
        let templateID: UUID? = template.id
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.sourceRoutineID == templateID && $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
