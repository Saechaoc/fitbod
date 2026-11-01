//
//  BlockDraft.swift
//  fitbod
//
//  Ephemeral editor state for BlockBuilderView. Saving a draft never
//  starts, ends or deactivates a block; BlockLifecycleService does, and
//  keeps at most one block active. A saved block also takes a new routine
//  only through BlockLifecycleService, which refuses an active block.
//

import Foundation
import SwiftData

@Observable
@MainActor
public final class BlockDraft {
    public var id: UUID? = nil
    public var name: String = ""
    public var startDate: Date = .now
    /// The edited block's active state when the draft opened. `save(into:)`
    /// never writes it back.
    public var isActive: Bool = false
    public var daysPerWeek: Int = 4
    public var phases: [BlockPhaseDraft] = []

    // V7 program-graph fields — wired by the Phase 9 split band.
    // save(into:) writes split directly only onto a new block; a saved block
    // changes routine through BlockLifecycleService.attachSplit / swapSplit,
    // which refuse an active block (T67).
    public var split: Split? = nil
    public var schedulingMode: SchedulingMode = .rotation
    // trainingDays written ONLY via TrainingDaysWriter.sort at save time (T-09-14).
    public var trainingDays: [Int] = []

    public init() {}

    public static func newBlock() -> BlockDraft {
        let draft = BlockDraft()
        draft.daysPerWeek = 4
        draft.phases = [
            BlockPhaseDraft(
                kind: .accumulation,
                weeks: 2,
                volumeMultiplier: 1.2,
                intensityMultiplier: 0.70
            ),
            BlockPhaseDraft(
                kind: .intensification,
                weeks: 2,
                volumeMultiplier: 1.0,
                intensityMultiplier: 0.85
            ),
            BlockPhaseDraft(
                kind: .deload,
                weeks: 1,
                volumeMultiplier: 0.5,
                intensityMultiplier: 0.60
            ),
        ]
        return draft
    }

    public convenience init(template: BlockTemplate) {
        self.init()
        self.name = template.name
        self.phases = template.phases.map { phase in
            BlockPhaseDraft(
                kind: phase.kind,
                weeks: phase.weeks,
                volumeMultiplier: phase.volumeMultiplier,
                intensityMultiplier: phase.intensityMultiplier
            )
        }
    }

    public convenience init(block: Block) {
        self.init()
        self.id = block.id
        self.name = block.name
        self.startDate = block.startDate
        self.isActive = block.isActive
        self.phases = (block.phases ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { BlockPhaseDraft(phase: $0) }
        // V7 round-trip — preserve scheduling config when editing an existing block.
        self.split = block.split
        self.schedulingMode = block.schedulingMode
        self.trainingDays = block.trainingDays
    }

    /// SAVE DRAFT needs only a name (decision 3).
    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Today's save rule, which EDIT BLOCK's SAVE CHANGES keeps: a name and
    /// at least one phase.
    public var isValid: Bool {
        hasName && !phases.isEmpty
    }

    /// The first piece the block would lack once saved, by `Block`'s one
    /// readiness rule, or nil when SAVE AS READY would save a ready block.
    public var missingPiece: BlockMissingPiece? {
        Block.firstMissingPiece(
            name: name,
            phaseCount: phases.count,
            sessionCount: split.map { $0.slots?.count ?? 0 },
            schedulingMode: schedulingMode,
            trainingDayCount: trainingDays.count
        )
    }

    public var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    /// The midnight after the plan's last day, counted the way
    /// `PeriodizationEngine` counts block days.
    public var computedEndDate: Date {
        PeriodizationEngine.startOfDay(totalWeeks * 7, from: startDate)
    }

    public func save(into context: ModelContext) throws {
        let existing = try savedBlock(in: context)
        // A saved block takes a new routine only through the lifecycle service,
        // which refuses an active block. It runs before any other write, so a
        // refused save leaves the block as it was (T67).
        if let existing, let split, existing.split?.id != split.id {
            if existing.split == nil {
                try BlockLifecycleService.attachSplit(split, to: existing, context: context)
            } else {
                try BlockLifecycleService.swapSplit(split, on: existing, context: context)
            }
        }

        try context.transaction {
            let block: Block
            if let existing {
                block = existing
            } else {
                let inserted = Block()
                context.insert(inserted)
                block = inserted
                if id == nil {
                    id = inserted.id
                }
            }

            block.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            block.startDate = startDate
            // endDate is the completion freeze marker (spec §3/§4) — written ONLY by
            // BlockLifecycleService.end when the block is ended. The builder is pre-
            // activation (draft/ready context) so block.endDate MUST stay nil here.
            // Preserving any pre-existing endDate (e.g. re-editing a completed block)
            // is intentional — we do not clear it. computedEndDate stays available for
            // display purposes (projected total weeks) but is never persisted by the builder.
            // isActive is never written here either: an edited block keeps its stored
            // state (SAVE CHANGES on the active block keeps it active), a new block stays
            // inactive, and no other block is touched. Only BlockLifecycleService starts
            // or ends a block (T65).

            // V7 program-graph fields. Only a new block, never active, takes the
            // draft's routine directly; a saved block's routine changed above,
            // through BlockLifecycleService.
            if existing == nil {
                block.split = split
            }
            block.schedulingMode = schedulingMode
            // trainingDays written ONLY via TrainingDaysWriter.sort to ensure sort-at-write
            // invariant (T-09-14 / SPEC-8-TRAININGDAYS).
            block.trainingDays = TrainingDaysWriter.sort(weekdays: trainingDays)

            for oldPhase in block.phases ?? [] {
                context.delete(oldPhase)
            }

            block.phases = phases.enumerated().map { index, draft in
                let phase = BlockPhase()
                phase.block = block
                phase.orderIndex = index
                phase.nameRaw = draft.kind.rawValue
                phase.weeks = draft.weeks
                phase.volumeMultiplier = draft.volumeMultiplier
                phase.intensityMultiplier = draft.intensityMultiplier
                context.insert(phase)
                draft.id = phase.id
                return phase
            }

            try context.save()
        }
    }

    /// The saved block this draft edits, or nil for a new block.
    private func savedBlock(in context: ModelContext) throws -> Block? {
        guard let targetID = id else { return nil }
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.id == targetID }
        )
        return try context.fetch(descriptor).first
    }
}

// MARK: - Unsaved edits

extension BlockDraft {
    /// Value copy of every field the builder edits. The builder takes one
    /// when it opens and compares it with the live `snapshot()` to tell
    /// whether the draft holds unsaved edits.
    public func snapshot() -> Snapshot {
        Snapshot(
            name: name,
            daysPerWeek: daysPerWeek,
            phases: phases.map {
                Snapshot.Phase(
                    kind: $0.kind,
                    weeks: $0.weeks,
                    volumeMultiplier: $0.volumeMultiplier,
                    intensityMultiplier: $0.intensityMultiplier
                )
            },
            splitID: split?.id,
            schedulingMode: schedulingMode,
            // Toggling a day off and on again reorders the array, not the selection.
            trainingDays: trainingDays.sorted()
        )
    }

    public struct Snapshot: Equatable, Sendable {
        public struct Phase: Equatable, Sendable {
            public let kind: BlockPhaseKind
            public let weeks: Int
            public let volumeMultiplier: Double
            public let intensityMultiplier: Double
        }

        public let name: String
        public let daysPerWeek: Int
        public let phases: [Phase]
        public let splitID: UUID?
        public let schedulingMode: SchedulingMode
        public let trainingDays: [Int]
    }
}
