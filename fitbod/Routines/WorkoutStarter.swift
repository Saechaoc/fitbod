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

    /// Starts `template` as an ad-hoc workout (no rotation slot). When a
    /// block is active the session is still attributed to it so block
    /// volume and history stay complete.
    public static func start(
        _ template: SessionTemplate,
        slot: SplitSessionSlot? = nil,
        context: ModelContext,
        now: Date = .now
    ) -> WorkoutStartOutcome {
        if let active = inProgressSession(in: context) {
            return .alreadyInProgress(active)
        }
        do {
            let session = try SessionFactory.start(
                template: template,
                slot: slot,
                activeBlock: activeBlock(in: context),
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
            return .failed(error.localizedDescription)
        }
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
