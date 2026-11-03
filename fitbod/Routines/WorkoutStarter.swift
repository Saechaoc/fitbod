// WorkoutStarter.swift
// fitbod
//
// One entry point for "start this session" outside the block resolver
// (session detail, Today's session list). Wraps SessionFactory.start and
// turns its errors into an outcome each caller can present, so no surface
// swallows a failed start.

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

    /// Starts `template`. Given no slot, a session in the active block's
    /// routine takes its slot there, so a session started from anywhere
    /// counts as that day of the block and the rotation moves on from it
    /// (D-19). The session is still attributed to the active block, so
    /// block volume and history stay complete.
    public static func start(
        _ template: SessionTemplate,
        slot: SplitSessionSlot? = nil,
        context: ModelContext,
        now: Date = .now
    ) -> WorkoutStartOutcome {
        if let active = inProgressSession(in: context) {
            return .alreadyInProgress(active)
        }
        let block = activeBlock(in: context)
        do {
            let session = try SessionFactory.start(
                template: template,
                slot: slot ?? Self.slot(for: template, in: block, context: context),
                activeBlock: block,
                on: now,
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

    /// Starts an empty workout: no session behind it, exercises added in
    /// the logger. It belongs to the active block, for its volume, and
    /// takes no slot, so the rotation stays where it is.
    public static func startEmpty(context: ModelContext, now: Date = .now) -> WorkoutStartOutcome {
        if let active = inProgressSession(in: context) {
            return .alreadyInProgress(active)
        }
        let session = Session()
        context.insert(session)
        session.startedAt = now
        session.block = activeBlock(in: context)
        do {
            try SessionSetActions.saveOrRollBack(context)
        } catch {
            return .failed("The new workout couldn't be saved. Try again.")
        }
        return .started(session)
    }

    /// The slot `template` fills in `block`'s routine: today's scheduled
    /// slot when it holds this session, else the session's first slot.
    /// Nil when the session is not in the routine.
    static func slot(for template: SessionTemplate, in block: Block?, context: ModelContext) -> SplitSessionSlot? {
        guard let block else { return nil }
        let slots = (block.split?.slots ?? [])
            .filter { $0.sessionTemplate?.id == template.id }
            .sorted { $0.position < $1.position }
        guard !slots.isEmpty else { return nil }
        if case .session(let scheduled) = TodayResolver.resolve(block: block, context: context),
           slots.contains(where: { $0.id == scheduled.id }) {
            return scheduled
        }
        return slots.first
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
