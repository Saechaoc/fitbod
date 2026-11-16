//
//  RoutineBlockLinkageTests.swift
//  fitbodTests
//
//  How a session links to a block for its progression (RM-026): only through
//  the program graph, a slot in the active block's routine. The deprecated
//  `SessionTemplate.block` stays stored, and the editor neither reads nor
//  writes it.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineBlockLinkage", .serialized)
struct RoutineBlockLinkageTests {
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// A session with one lift, in a slot of `routine` when one is given.
    private func makeSession(_ name: String, in routine: Split? = nil, context: ModelContext) -> SessionTemplate {
        let exercise = Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        context.insert(exercise)
        let session = SessionTemplate()
        session.name = name
        context.insert(session)
        let lift = SessionExerciseTemplate()
        context.insert(lift)
        lift.sessionTemplate = session
        lift.exercise = exercise
        if let routine {
            let slot = SplitSessionSlot()
            context.insert(slot)
            slot.split = routine
            slot.sessionTemplate = session
        }
        return session
    }

    /// The active block, its routine, and a block that ended on another routine.
    private func makeGraph(in context: ModelContext) throws -> (routine: Split, active: Block, ended: Block) {
        let routine = Split()
        routine.name = "Upper Lower"
        context.insert(routine)
        let active = Block()
        active.name = "Spring Block"
        context.insert(active)
        active.isActive = true
        active.split = routine
        let ended = Block()
        ended.name = "Winter Block"
        context.insert(ended)
        ended.endDate = .now
        try context.save()
        return (routine, active, ended)
    }

    @Test("Eligibility reads the active graph, not the deprecated block")
    func eligibilityReadsTheActiveGraph() throws {
        let context = try makeContext()
        let graph = try makeGraph(in: context)
        let slotted = makeSession("Upper A", in: graph.routine, context: context)
        let linkedOnly = makeSession("Upper B", context: context)
        linkedOnly.block = graph.active
        try context.save()

        #expect(RoutineDraft(routine: slotted).isOnActiveBlock)
        #expect(!RoutineDraft(routine: linkedOnly).isOnActiveBlock)
        // A new session is in no routine until it saves.
        #expect(!RoutineDraft().isOnActiveBlock)
    }

    @Test("A session on the active block saves Block Periodized and Hybrid, and its deprecated block stays")
    func sessionOnTheActiveBlockSavesBlockProgression() throws {
        let context = try makeContext()
        let graph = try makeGraph(in: context)

        for kind in [ProgressionKind.block, .hybrid] {
            let session = makeSession("Upper A", in: graph.routine, context: context)
            session.block = graph.ended
            try context.save()

            let draft = RoutineDraft(routine: session)
            #expect(RoutineDraft.availableProgressionKinds(hasBlock: draft.isOnActiveBlock).contains(kind))
            draft.progressionKind = kind
            try draft.persist(into: session, context: context)

            #expect(session.progressionKind == kind)
            #expect(session.block?.id == graph.ended.id)
        }
    }

    @Test("A session off the active block falls back to Double Progression, and its deprecated block stays")
    func sessionOffTheActiveBlockFallsBackToDouble() throws {
        let context = try makeContext()
        let graph = try makeGraph(in: context)

        for kind in [ProgressionKind.block, .hybrid] {
            let session = makeSession("Upper B", context: context)
            session.block = graph.active
            try context.save()

            let draft = RoutineDraft(routine: session)
            draft.progressionKind = kind
            try draft.persist(into: session, context: context)

            #expect(draft.progressionKind == .double)
            #expect(session.progressionKind == .double)
            #expect(session.block?.id == graph.active.id)
        }
    }

    @Test("A copy of a Block Periodized session joins no routine, so it saves Double Progression and no deprecated block")
    func copyFallsBackToDouble() throws {
        let context = try makeContext()
        let graph = try makeGraph(in: context)
        let session = makeSession("Upper A", in: graph.routine, context: context)
        session.progressionKindRaw = ProgressionKind.block.rawValue
        session.block = graph.ended
        try context.save()

        let copy = try RoutineDuplicator.duplicate(RoutineDraft(routine: session), context: context)

        #expect(copy.progressionKind == .double)
        #expect(copy.block == nil)
        #expect(session.progressionKind == .block)
    }

    @Test("A Block Periodized session opened off the active block shows the fall back as an unsaved change")
    func openingOffTheActiveBlockShowsAnUnsavedChange() throws {
        let context = try makeContext()
        let session = makeSession("Upper B", context: context)
        session.progressionKindRaw = ProgressionKind.block.rawValue
        try context.save()

        let draft = RoutineDraft(routine: session)
        let opened = draft.openingSnapshot()

        #expect(draft.progressionKind == .double)
        #expect(draft.snapshotHash() != opened, "Cancel must ask before it drops the change, and Save must be the lifter's choice")
        #expect(session.progressionKind == .block, "Opening the editor writes nothing")
    }

    @Test("A block that ends while the editor is open makes save fall back to Double Progression")
    func blockEndingWhileEditingFallsBack() throws {
        let context = try makeContext()
        let graph = try makeGraph(in: context)
        let session = makeSession("Upper A", in: graph.routine, context: context)
        try context.save()

        let draft = RoutineDraft(routine: session)
        #expect(draft.isOnActiveBlock)
        draft.progressionKind = .block
        graph.active.isActive = false
        graph.active.endDate = .now
        try draft.persist(into: session, context: context)

        #expect(!draft.isOnActiveBlock)
        #expect(session.progressionKind == .double)
    }
}
