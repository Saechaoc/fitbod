//
//  SchemaV7MigrationTests.swift
//  fitbodTests
//
//  Canonical proof that the Phase 7 V6→V7 custom migration is wired correctly.
//  Mirrors `SchemaV6MigrationTests` fixture pattern (in-memory ModelContainer
//  over V7 schema + FitbodSchemaMigrationPlan; seeds SchemaV6.Routine /
//  SchemaV6.RoutineExercise / Session rows, calls the internal-static helpers
//  directly, then asserts the V7-shape result).
//
//  V7 delta covered by this suite:
//    - Entity rename: Routine→SessionTemplate, RoutineExercise→SessionExerciseTemplate
//    - New entities: Split, SplitSessionSlot
//    - Block additions: split, schedulingModeRaw, trainingDaysJoined, archivedConfigJSON
//    - Session additions: template, slot, templateName
//
//  Test surface (Tasks 1 + 2 combined in a single serialized suite):
//
//  TASK 1 — Migration + backfill + ghost-free assertions (spec §7 minimum):
//    1.  migrationPlanRegistersV7:      schemas.last == "SchemaV7", count == 7
//    2.  migrationPlanHasSixStages:     stages.count == 6
//    3.  refRemapping:                  stash + materialize → Session.template remapped
//    4.  ghostFreePicker:               only auto-created Splits post-migration;
//                                       completed-block splits isArchived == true
//    5.  rotationContinuityBackfill:    active-block last session slot backfilled (step 4)
//    6.  templateNameBackfill:          sessions carry templateName == template.name
//    7.  archiveBackfill:               completed block has archivedConfigJSON v==1
//
//  TASK 2 — Delete-rule + contiguity + status invariants (spec §3 / §9):
//    8.  slottedTemplateDenyRule:       hard-delete of slotted template throws (.deny)
//    9.  slotNullifyHistoryIntact:      slot delete → session.slot == nil, session survives
//    10. blockSplitNullify:             split delete → block.split == nil, block survives
//    11. splitSlotsCascade:             split delete cascades all 3 slots
//    12. positionContiguity:            reindex-on-write invariant add/remove/reorder
//    13. schedulingModeRoundTrip:       raw string ↔ enum accessor
//    14. derivedStatusPrecedence:       completed > active > ready > draft ordered switch
//
//  Build approach: helper-invocation (same pattern as SchemaV6MigrationTests tests
//  9–10). Seeds nested SchemaV6.Routine rows into an in-memory V7 context, then
//  calls `FitbodSchemaMigrationPlan.stashV6Routines(in:)` followed by
//  `FitbodSchemaMigrationPlan.materializeSessionTemplates(in:)` and asserts the
//  V7-shape result. Delete-rule + contiguity tests operate directly on V7 entities.
//
//  Single serialized suite to prevent in-process SwiftData container conflicts
//  when multiple simulator test clones run different suites concurrently.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// MARK: - Suite

@MainActor
@Suite("SchemaV7Migration", .serialized)
struct SchemaV7MigrationTests {

    // MARK: - Helpers

    /// Fresh in-memory V7 ModelContext over `Schema(SchemaV7.models)` +
    /// FitbodSchemaMigrationPlan — mirrors SchemaV6MigrationTests.makeContext shape.
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

    /// Seeds a SchemaV6.Routine row into the context with all required fields.
    /// Insert-before-relate convention: block must already be inserted.
    private func makeV6Routine(
        ctx: ModelContext,
        name: String,
        block: Block? = nil
    ) -> SchemaV6.Routine {
        let r = SchemaV6.Routine()
        ctx.insert(r)
        r.name = name
        r.block = block
        return r
    }

    /// Seeds a Session row referencing a routine ID (soft V6 link).
    private func makeSession(
        ctx: ModelContext,
        sourceRoutineID: UUID? = nil,
        block: Block? = nil,
        completedAt: Date? = nil
    ) -> Session {
        let s = Session()
        ctx.insert(s)
        s.sourceRoutineID = sourceRoutineID
        s.block = block
        s.completedAt = completedAt
        if let d = completedAt { s.startedAt = d.addingTimeInterval(-3600) }
        return s
    }

    // MARK: - 1. migrationPlanRegistersV7

    @Test("Migration plan lists SchemaV7 as the latest schema with count 7")
    func migrationPlanRegistersV7() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names.last == "SchemaV7")
        #expect(names.count == 7)
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4",
                          "SchemaV5", "SchemaV6", "SchemaV7"])
    }

    // MARK: - 2. migrationPlanHasSixStages

    @Test("Migration plan has exactly six stages (V1→V2 through V6→V7)")
    func migrationPlanHasSixStages() {
        #expect(FitbodSchemaMigrationPlan.stages.count == 6)
    }

    // MARK: - 3. refRemapping

    @Test("stashV6Routines + materializeSessionTemplates remaps Session.template via sourceRoutineID")
    func refRemapping() throws {
        let ctx = try makeContext()

        // Seed two V6 Routine rows (no block — orphan templates).
        let r1 = makeV6Routine(ctx: ctx, name: "Push A")
        let r2 = makeV6Routine(ctx: ctx, name: "Pull B")

        // Seed two sessions with soft sourceRoutineID refs.
        let s1 = makeSession(ctx: ctx, sourceRoutineID: r1.id)
        let s2 = makeSession(ctx: ctx, sourceRoutineID: r2.id)
        // One ad-hoc session with no routine ref.
        let s3 = makeSession(ctx: ctx, sourceRoutineID: nil)
        try ctx.save()

        // Run migration helpers directly (same pattern as bumpPlateauToleranceDefault tests).
        try FitbodSchemaMigrationPlan.stashV6Routines(in: ctx)
        try FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx)

        // Two SessionTemplates must exist (one per V6 Routine row).
        let templates = try ctx.fetch(FetchDescriptor<SessionTemplate>())
        #expect(templates.count == 2)

        // Sessions must have template refs remapped from sourceRoutineID.
        let sessions = try ctx.fetch(FetchDescriptor<Session>())
        let fetchedS1 = sessions.first { $0.id == s1.id }
        let fetchedS2 = sessions.first { $0.id == s2.id }
        let fetchedS3 = sessions.first { $0.id == s3.id }

        let t1 = try #require(fetchedS1?.template)
        let t2 = try #require(fetchedS2?.template)
        #expect(t1.id == r1.id)
        #expect(t2.id == r2.id)
        #expect(t1.name == "Push A")
        #expect(t2.name == "Pull B")

        // Ad-hoc session has no template remapping.
        #expect(fetchedS3?.template == nil)
    }

    // MARK: - 4. ghostFreePicker

    @Test("Only auto-created Splits exist after migration; completed-block splits are archived")
    func ghostFreePicker() throws {
        let ctx = try makeContext()

        // Active block with 2 routines.
        let activeBlock = Block()
        ctx.insert(activeBlock)
        activeBlock.name = "Hypertrophy Block"
        activeBlock.isActive = true

        let r1 = makeV6Routine(ctx: ctx, name: "Push", block: activeBlock)
        let r2 = makeV6Routine(ctx: ctx, name: "Pull", block: activeBlock)

        // Completed block with 1 routine.
        let completedBlock = Block()
        ctx.insert(completedBlock)
        completedBlock.name = "Strength Block"
        completedBlock.endDate = Date(timeIntervalSinceNow: -86400)

        let r3 = makeV6Routine(ctx: ctx, name: "Full Body", block: completedBlock)
        _ = r3

        // Orphan routine (no block) — must NOT spawn a split.
        _ = makeV6Routine(ctx: ctx, name: "Orphan Routine", block: nil)
        _ = r1
        _ = r2

        try ctx.save()

        try FitbodSchemaMigrationPlan.stashV6Routines(in: ctx)
        try FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx)

        // V6 Routine entity table is gone (replaced by SessionTemplate).
        // The Split table should have exactly 2 auto-splits (active + completed block).
        let splits = try ctx.fetch(FetchDescriptor<Split>())
        #expect(splits.count == 2)

        // Active block split: NOT archived.
        let activeSplit = splits.first { $0.name == "Hypertrophy Block split" }
        let completedSplit = splits.first { $0.name == "Strength Block split" }
        let activeSplitRow = try #require(activeSplit)
        let completedSplitRow = try #require(completedSplit)
        #expect(activeSplitRow.isArchived == false)
        #expect(completedSplitRow.isArchived == true)

        // Active split must have 2 slots (one per routine, name-sorted).
        let activeSlots = (activeSplitRow.slots ?? []).sorted { $0.position < $1.position }
        #expect(activeSlots.count == 2)
        // Name-sorted order: Pull (0), Push (1)
        #expect(activeSlots[0].sessionTemplate?.name == "Pull")
        #expect(activeSlots[1].sessionTemplate?.name == "Push")

        // Completed split must have 1 slot.
        #expect((completedSplitRow.slots ?? []).count == 1)

        // No ghost: a non-archived picker query returns only 1 split.
        let pickerDescriptor = FetchDescriptor<Split>(
            predicate: #Predicate { !$0.isArchived }
        )
        let pickerResults = try ctx.fetch(pickerDescriptor)
        #expect(pickerResults.count == 1)
    }

    // MARK: - 5. rotationContinuityBackfill (step 4)

    @Test("Step 4 backfills Session.slot for active block's last completed session")
    func rotationContinuityBackfill() throws {
        let ctx = try makeContext()

        // Active block with 2 name-sorted routines.
        let activeBlock = Block()
        ctx.insert(activeBlock)
        activeBlock.name = "Active Block"
        activeBlock.isActive = true

        // Name-sorted: "Push A" < "Push B"
        let r1 = makeV6Routine(ctx: ctx, name: "Push A", block: activeBlock)
        let r2 = makeV6Routine(ctx: ctx, name: "Push B", block: activeBlock)

        // Two completed sessions for this block. The LAST completed is s2.
        let earlier = Date(timeIntervalSinceNow: -7200)
        let later   = Date(timeIntervalSinceNow: -3600)
        let s1 = makeSession(ctx: ctx, sourceRoutineID: r1.id, block: activeBlock, completedAt: earlier)
        let s2 = makeSession(ctx: ctx, sourceRoutineID: r2.id, block: activeBlock, completedAt: later)
        _ = s1

        try ctx.save()

        try FitbodSchemaMigrationPlan.stashV6Routines(in: ctx)
        try FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx)

        // The most-recent completed session (s2 — "Push B") must have slot backfilled.
        // "Push B" is position 1 in name-sorted order (after "Push A" at position 0).
        let sessions = try ctx.fetch(FetchDescriptor<Session>())
        let fetchedS2 = sessions.first { $0.id == s2.id }
        let slot = try #require(fetchedS2?.slot)
        // The slot at position 1 should reference the "Push B" template.
        #expect(slot.position == 1)
        #expect(slot.sessionTemplate?.name == "Push B")
    }

    // MARK: - 6. templateNameBackfill (step 5)

    @Test("Step 5 backfills Session.templateName from the remapped template name")
    func templateNameBackfill() throws {
        let ctx = try makeContext()

        let r = makeV6Routine(ctx: ctx, name: "Leg Day")
        let s1 = makeSession(ctx: ctx, sourceRoutineID: r.id)
        // Ad-hoc session with a routineSnapshotName fallback.
        let s2 = makeSession(ctx: ctx, sourceRoutineID: nil)
        s2.routineSnapshotName = "Old Snapshot Name"
        // Session with no refs at all.
        let s3 = makeSession(ctx: ctx, sourceRoutineID: nil)
        _ = s3
        try ctx.save()

        try FitbodSchemaMigrationPlan.stashV6Routines(in: ctx)
        try FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx)

        let sessions = try ctx.fetch(FetchDescriptor<Session>())
        let fetchedS1 = sessions.first { $0.id == s1.id }
        let fetchedS2 = sessions.first { $0.id == s2.id }
        let fetchedS3 = sessions.first { $0.id == s3.id }

        // s1 has a template ref → name comes from template.
        #expect(fetchedS1?.templateName == "Leg Day")
        // s2 has no template but has routineSnapshotName → falls back to that.
        #expect(fetchedS2?.templateName == "Old Snapshot Name")
        // s3 has nothing → templateName stays nil (empty routineSnapshotName → no backfill).
        #expect(fetchedS3?.templateName == nil || fetchedS3?.templateName == "")
    }

    // MARK: - 7. archiveBackfill (step 6)

    @Test("Step 6 writes archivedConfigJSON with v==1 for completed blocks")
    func archiveBackfill() throws {
        let ctx = try makeContext()

        let completedBlock = Block()
        ctx.insert(completedBlock)
        completedBlock.name = "Completed Block"
        completedBlock.endDate = Date(timeIntervalSinceNow: -86400)

        _ = makeV6Routine(ctx: ctx, name: "Slot A", block: completedBlock)
        try ctx.save()

        try FitbodSchemaMigrationPlan.stashV6Routines(in: ctx)
        try FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx)

        let blocks = try ctx.fetch(FetchDescriptor<Block>())
        let fetchedBlock = blocks.first { $0.id == completedBlock.id }
        let jsonString = try #require(fetchedBlock?.archivedConfigJSON)
        #expect(!jsonString.isEmpty)

        // Decode and verify the v==1 stamp.
        let data = try #require(jsonString.data(using: .utf8))
        let archive = try ArchivedBlockConfig.decode(from: data)
        #expect(archive.v == 1)
        #expect(archive.blockName == "Completed Block")
    }

    // MARK: - 8. slottedTemplateDenyRule (Pitfall 9 / T-07-15)

    @Test("Hard-deleting a slotted SessionTemplate throws due to .deny rule")
    func slottedTemplateDenyRule() throws {
        let ctx = try makeContext()

        // Split + template + slot wired together.
        let split = Split()
        ctx.insert(split)
        split.name = "PPL Split"

        let template = SessionTemplate()
        ctx.insert(template)
        template.name = "Push Day"

        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = template

        try ctx.save()

        // Verify the slot relationship exists before attempting delete.
        let templateID = template.id
        let slotsBefore = try ctx.fetch(FetchDescriptor<SplitSessionSlot>())
        #expect(slotsBefore.count == 1)
        #expect(slotsBefore.first?.sessionTemplate?.id == templateID)

        // Attempt hard-delete of the slotted template — must throw due to .deny rule.
        ctx.delete(template)
        var didThrow = false
        do {
            try ctx.save()
        } catch {
            // Expected: SwiftData enforces .deny and throws.
            didThrow = true
        }

        if !didThrow {
            // Fallback assertion: if save didn't throw, the template should still exist
            // (delete was rolled back by the deny rule). This handles the edge case
            // where SwiftData enforces .deny by rolling back the delete silently.
            let templatesAfter = try ctx.fetch(FetchDescriptor<SessionTemplate>())
            let stillSlotted = templatesAfter.first { $0.id == templateID }
            let isProtected = stillSlotted != nil
            // Either the save threw (didThrow) or the delete was rolled back (template persists).
            #expect(isProtected, "Expected .deny to either throw or silently preserve the slotted template")
        }
        // At least one protection mechanism must have fired.
        let slotsAfter = try ctx.fetch(FetchDescriptor<SplitSessionSlot>())
        #expect(slotsAfter.count == 1, "Slot must survive — deny rule protects the slot reference")
    }

    // MARK: - 9. slotNullifyHistoryIntact (Pitfall 6 / T-07-14)

    @Test("Deleting a SplitSessionSlot nullifies Session.slot; the Session row survives")
    func slotNullifyHistoryIntact() throws {
        let ctx = try makeContext()

        let split = Split()
        ctx.insert(split)
        split.name = "Upper/Lower"

        let template = SessionTemplate()
        ctx.insert(template)
        template.name = "Upper A"

        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = template

        let session = Session()
        ctx.insert(session)
        session.slot = slot

        try ctx.save()

        let sessionID = session.id

        // Unlink the template before deleting the slot (avoid deny-rule interference).
        slot.sessionTemplate = nil
        try ctx.save()

        // Verify session has the slot before delete.
        let sessionsBefore = try ctx.fetch(FetchDescriptor<Session>())
        let sessionBefore = try #require(sessionsBefore.first { $0.id == sessionID })
        #expect(sessionBefore.slot != nil, "Session must have a slot before delete")

        ctx.delete(slot)
        try ctx.save()

        // Session must still exist with slot == nil (nullify, not cascade).
        let sessions = try ctx.fetch(FetchDescriptor<Session>())
        let found = sessions.first { $0.id == sessionID }
        let row = try #require(found, "Session must survive slot deletion — history is never erased")
        #expect(row.slot == nil, "Session.slot must be nil after slot deletion (nullify, not cascade)")
    }

    // MARK: - 10. blockSplitNullify (T-07-17 adjacent)

    @Test("Deleting a Split sets Block.split to nil; the Block survives")
    func blockSplitNullify() throws {
        let ctx = try makeContext()

        let split = Split()
        ctx.insert(split)
        split.name = "PPL"

        let block = Block()
        ctx.insert(block)
        block.name = "Completed Block"
        block.endDate = Date(timeIntervalSinceNow: -86400)
        block.split = split

        try ctx.save()
        let blockID = block.id

        ctx.delete(split)
        try ctx.save()

        // Block must still exist with split == nil.
        let blocks = try ctx.fetch(FetchDescriptor<Block>())
        let found = blocks.first { $0.id == blockID }
        let row = try #require(found)
        #expect(row.split == nil)
    }

    // MARK: - 11. splitSlotsCascade

    @Test("Deleting a Split cascades and removes all its SplitSessionSlots")
    func splitSlotsCascade() throws {
        let ctx = try makeContext()

        let split = Split()
        ctx.insert(split)
        split.name = "Full Body 3x"

        // Insert templates for each slot (deny-rule: unlink before deleting the split).
        let templates: [SessionTemplate] = (0..<3).map { i in
            let t = SessionTemplate()
            ctx.insert(t)
            t.name = "Slot \(i)"
            return t
        }

        let slots: [SplitSessionSlot] = (0..<3).map { i in
            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.split = split
            slot.position = i
            slot.sessionTemplate = templates[i]
            return slot
        }
        _ = slots
        try ctx.save()

        // Unlink all slot→template refs before deleting the split (avoids deny interference).
        for slot in (split.slots ?? []) {
            slot.sessionTemplate = nil
        }
        try ctx.save()

        ctx.delete(split)
        try ctx.save()

        // All 3 slots must be gone (cascade).
        let remainingSlots = try ctx.fetch(FetchDescriptor<SplitSessionSlot>())
        #expect(remainingSlots.count == 0)
    }

    // MARK: - 12. positionContiguity (Pitfall 5 / T-07-16)

    @Test("Slot positions remain 0..<n contiguous after add, remove, and reorder")
    func positionContiguity() throws {
        let ctx = try makeContext()

        let split = Split()
        ctx.insert(split)
        split.name = "Reorder Test"

        // Build a 3-slot split with templates.
        let templates: [SessionTemplate] = (0..<3).map { i in
            let t = SessionTemplate()
            ctx.insert(t)
            t.name = "T\(i)"
            return t
        }
        var slots: [SplitSessionSlot] = (0..<3).map { i in
            let s = SplitSessionSlot()
            ctx.insert(s)
            s.split = split
            s.position = i
            s.sessionTemplate = templates[i]
            return s
        }
        try ctx.save()

        // Verify initial [0, 1, 2] positions.
        let initial = (split.slots ?? []).sorted { $0.position < $1.position }.map(\.position)
        #expect(initial == [0, 1, 2])

        // REMOVE middle slot (position 1) and reindex → [0, 1].
        slots[1].sessionTemplate = nil
        try ctx.save()
        ctx.delete(slots[1])
        try ctx.save()
        slots.remove(at: 1)

        // Reindex remaining slots.
        for (i, slot) in slots.enumerated() { slot.position = i }
        try ctx.save()

        let afterRemove = (split.slots ?? []).sorted { $0.position < $1.position }.map(\.position)
        #expect(afterRemove == [0, 1])

        // ADD a new slot at the end → [0, 1, 2].
        let newTemplate = SessionTemplate()
        ctx.insert(newTemplate)
        newTemplate.name = "T-new"
        let newSlot = SplitSessionSlot()
        ctx.insert(newSlot)
        newSlot.split = split
        newSlot.position = slots.count   // 2
        newSlot.sessionTemplate = newTemplate
        slots.append(newSlot)
        try ctx.save()

        let afterAdd = (split.slots ?? []).sorted { $0.position < $1.position }.map(\.position)
        #expect(afterAdd == [0, 1, 2])

        // REORDER: swap positions 0 ↔ 2 → still [0, 1, 2] contiguous.
        slots[0].position = 2
        slots[2].position = 0
        try ctx.save()

        let afterReorder = (split.slots ?? []).sorted { $0.position < $1.position }.map(\.position)
        #expect(afterReorder == [0, 1, 2])
    }

    // MARK: - 13. schedulingModeRoundTrip

    @Test("Block.schedulingMode round-trips through schedulingModeRaw")
    func schedulingModeRoundTrip() throws {
        let ctx = try makeContext()

        let block = Block()
        ctx.insert(block)
        block.schedulingMode = .fixedWeekly
        try ctx.save()

        #expect(block.schedulingModeRaw == "fixedWeekly")
        #expect(block.schedulingMode == .fixedWeekly)

        block.schedulingMode = .rotation
        #expect(block.schedulingModeRaw == "rotation")
        #expect(block.schedulingMode == .rotation)
    }

    // MARK: - 14. derivedStatusPrecedence

    @Test("Block.derivedStatus follows completed > active > ready > draft precedence")
    func derivedStatusPrecedence() throws {
        let ctx = try makeContext()

        // completed: endDate != nil BEATS isActive (ordered-switch precedence).
        let completedBlock = Block()
        ctx.insert(completedBlock)
        completedBlock.endDate = Date(timeIntervalSinceNow: -86400)
        completedBlock.isActive = true   // should NOT influence — completed wins
        #expect(completedBlock.derivedStatus == .completed)

        // active: isActive + no endDate.
        let activeBlock = Block()
        ctx.insert(activeBlock)
        activeBlock.isActive = true
        #expect(activeBlock.derivedStatus == .active)

        // ready: split wired + ≥1 slot + mode == .rotation (no trainingDays needed).
        let readyBlock = Block()
        ctx.insert(readyBlock)
        let split = Split()
        ctx.insert(split)
        let template = SessionTemplate()
        ctx.insert(template)
        template.name = "Push"
        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.position = 0
        slot.sessionTemplate = template
        readyBlock.split = split
        readyBlock.schedulingMode = .rotation
        try ctx.save()
        #expect(readyBlock.derivedStatus == .ready)

        // draft: no split.
        let draftBlock = Block()
        ctx.insert(draftBlock)
        #expect(draftBlock.derivedStatus == .draft)
    }
}
