//
//  SplitDetailViewTests.swift
//  fitbodTests
//
//  Phase 09-01 Task 2 — TDD suite for SplitDetailView slot CRUD + reindex-on-write.
//
//  REQ: SPEC-9-TESTS — slot contiguity invariant after add / remove / reorder.
//  Threat T-09-01 (Tampering): reindex-on-write renumbers positions 0..<n in one
//  ctx.save(); a dup position would silently merge rows.
//  Threat T-09-03 (Tampering): remove slot never deletes the SessionTemplate (.deny rule).
//
//  Test suite:
//    1. reorderKeepsPositionsContiguous — move slots, assert 0..<n
//    2. addSlotAppendsContiguously     — add slot, assert 0..<n
//    3. removeSlotDeletesSlotNotTemplateAndReindexes — remove middle slot; template survives
//    4. splitDetailViewPinsCopy        — source-introspection copy pins
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SplitDetailView", .serialized)
struct SplitDetailViewTests {

    // MARK: - In-memory context

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Helpers

    /// Build a Split with `count` slots, each linked to a freshly-created SessionTemplate.
    /// Insert everything into `ctx` before assigning relationships (project convention).
    private func makeSplitWithSlots(count: Int, in ctx: ModelContext) -> (Split, [SplitSessionSlot]) {
        let split = Split()
        split.name = "Test Split"
        ctx.insert(split)

        var slots: [SplitSessionSlot] = []
        for i in 0..<count {
            let template = SessionTemplate()
            template.name = "Session \(i + 1)"
            ctx.insert(template)

            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.split = split
            slot.sessionTemplate = template
            slot.position = i
            slots.append(slot)
        }
        try? ctx.save()
        return (split, slots)
    }

    // MARK: - Test 1: Reorder keeps positions contiguous

    @Test("reorder keeps positions contiguous 0..<n")
    func reorderKeepsPositionsContiguous() throws {
        let ctx = try makeContext()
        let (split, _) = makeSplitWithSlots(count: 4, in: ctx)

        // Simulate moving slot at index 0 to index 3
        var slots = (split.slots ?? []).sorted { $0.position < $1.position }
        let movedSlot = slots.remove(at: 0)
        slots.append(movedSlot)   // move to end

        // Apply the same reindex logic as SplitDetailView.commitMove
        reindexSlots(slots)
        try? ctx.save()

        // Fetch persisted state
        let reloaded = (split.slots ?? []).sorted { $0.position < $1.position }
        let positions = reloaded.map { $0.position }

        // Positions must be exactly [0, 1, 2, 3]
        #expect(positions == [0, 1, 2, 3])
        // The slot originally at index 0 should now be at position 3
        #expect(reloaded.last?.id == movedSlot.id)
    }

    // MARK: - Test 2: Add slot appends contiguously

    @Test("add slot appends at end; positions remain 0..<n")
    func addSlotAppendsContiguously() throws {
        let ctx = try makeContext()
        let (split, _) = makeSplitWithSlots(count: 3, in: ctx)

        // Simulate addSlot logic: insert + assign + reindex
        let newTemplate = SessionTemplate()
        newTemplate.name = "New Session"
        ctx.insert(newTemplate)

        let newSlot = SplitSessionSlot()
        ctx.insert(newSlot)
        newSlot.split = split
        newSlot.sessionTemplate = newTemplate
        // Mirror the production addSlot fix (CR-02): sentinel position, then pin the new
        // slot to the end of the sort so it appends regardless of SwiftData's
        // relationship-count timing or position collisions.
        newSlot.position = 0  // sentinel — reindexSlots assigns the real value
        let newSlotID = newSlot.id

        let allSlots = (split.slots ?? []).sorted { a, b in
            if a.id == newSlotID { return false }   // new slot sorts last (append)
            if b.id == newSlotID { return true }
            return a.position < b.position
        }
        reindexSlots(allSlots)
        try? ctx.save()

        let reloaded = (split.slots ?? []).sorted { $0.position < $1.position }
        let positions = reloaded.map { $0.position }

        // 4 slots total: positions [0, 1, 2, 3] — contiguous, no gaps or duplicates
        #expect(positions == [0, 1, 2, 3])
        #expect(positions == Array(0..<reloaded.count), "positions must be contiguous 0..<n after add")
        #expect(reloaded.count == 4)
        // New slot is at the end (append semantics held)
        #expect(reloaded.last?.sessionTemplate?.name == "New Session")
    }

    // MARK: - Test 3: Remove slot — slot gone, template survives, reindex correct

    @Test("remove middle slot: slot deleted, SessionTemplate survives, positions reindexed")
    func removeSlotDeletesSlotNotTemplateAndReindexes() throws {
        let ctx = try makeContext()
        let (split, originalSlots) = makeSplitWithSlots(count: 4, in: ctx)

        // Capture the middle slot's template ID before removal
        let slotsOrdered = originalSlots.sorted { $0.position < $1.position }
        let middleSlot = slotsOrdered[1]   // position 1 (second slot)
        let templateID = middleSlot.sessionTemplate?.id

        // Simulate removeSlot logic (same as SplitDetailView.removeSlot)
        ctx.delete(middleSlot)
        let remaining = (split.slots ?? [])
            .filter { $0.id != middleSlot.id }
            .sorted { $0.position < $1.position }
        reindexSlots(remaining)
        try? ctx.save()

        // 1. Slot is gone from split.slots
        let remainingSlots = (split.slots ?? []).sorted { $0.position < $1.position }
        #expect(remainingSlots.count == 3)
        #expect(!remainingSlots.contains { $0.id == middleSlot.id })

        // 2. SessionTemplate still exists in the store (not hard-deleted)
        if let tid = templateID {
            let fetchedTemplates = try ctx.fetch(
                FetchDescriptor<SessionTemplate>(
                    predicate: #Predicate<SessionTemplate> { $0.id == tid }
                )
            )
            #expect(!fetchedTemplates.isEmpty, "SessionTemplate must survive slot removal (.deny rule)")
        }

        // 3. Positions are contiguous 0..<3
        let positions = remainingSlots.map { $0.position }
        #expect(positions == [0, 1, 2])
    }

    // MARK: - Test 4: Source-introspection copy pins

    private func splitDetailViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // fitbodTests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Periodization")
            .appendingPathComponent("SplitDetailView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("SplitDetailView.swift contains verbatim copy strings")
    func splitDetailViewPinsCopy() throws {
        let source = try splitDetailViewSource()

        // Verbatim copy pins per UI-SPEC Copywriting Contract + task behavior block
        #expect(source.contains("\"Sessions\""), "Must contain verbatim 'Sessions' section head")
        #expect(source.contains("\"+ ADD SESSION\""), "Must contain verbatim '+ ADD SESSION'")
        #expect(source.contains("\"Used in\""), "Must contain verbatim 'Used in' section head")
        #expect(source.contains("\"Not linked to any active block.\""), "Must contain empty-usage copy")
        #expect(source.contains("\"ARCHIVE\""), "Must contain verbatim 'ARCHIVE' action label")
        #expect(source.contains("\"Cannot Archive Routine\""), "Must contain deny alert title")
        #expect(source.contains("\"Remove Session?\""), "Must contain remove confirmation title")
        #expect(source.contains("\"Remove Session\""), "Must contain remove confirmation destructive button")
        // Title uses string interpolation: "Routine · \(split.name)" — check the prefix literal
        #expect(source.contains("\"Routine · \\("), "Must contain verbatim screen title prefix")
    }
}
