//
//  BlockDraft.swift
//  fitbod
//
//  Ephemeral editor state for BlockBuilderView. The draft is the only
//  Phase 4 writer that enforces the one-active-block invariant.
//

import Foundation
import SwiftData

@Observable
@MainActor
public final class BlockDraft {
    public var id: UUID? = nil
    public var name: String = ""
    public var startDate: Date = .now
    public var isActive: Bool = false
    public var daysPerWeek: Int = 4
    public var phases: [BlockPhaseDraft] = []

    public init() {}

    public static func newBlock() -> BlockDraft {
        let draft = BlockDraft()
        draft.isActive = true
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
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !phases.isEmpty
    }

    public var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    public var computedEndDate: Date {
        startDate.addingTimeInterval(Double(totalWeeks * 7) * 86_400)
    }

    public func save(into context: ModelContext) throws {
        try context.transaction {
            if isActive {
                let myID = id
                let descriptor = FetchDescriptor<Block>(
                    predicate: #Predicate<Block> { $0.isActive == true }
                )
                let activeBlocks = try context.fetch(descriptor)
                for block in activeBlocks where block.id != myID {
                    block.isActive = false
                }
            }

            let block: Block
            if let existingID = id {
                let targetID = existingID
                let descriptor = FetchDescriptor<Block>(
                    predicate: #Predicate<Block> { $0.id == targetID }
                )
                if let existing = try context.fetch(descriptor).first {
                    block = existing
                } else {
                    let inserted = Block()
                    context.insert(inserted)
                    block = inserted
                }
            } else {
                let inserted = Block()
                context.insert(inserted)
                block = inserted
                id = inserted.id
            }

            block.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            block.startDate = startDate
            block.endDate = computedEndDate
            block.isActive = isActive

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
}
