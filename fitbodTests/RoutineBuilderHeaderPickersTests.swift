//
//  RoutineBuilderHeaderPickersTests.swift
//  fitbodTests
//
//  Phase 3.1 plan 04 regression suite for the new session-level Intent
//  + Progression header pickers in `RoutineBuilderView`, the persistence
//  round-trip on the `RoutineDraft` save path, and the relocated
//  `snapshotHash()` dirty-check helper.
//
//  Six `@Test` functions in order:
//
//    1. `RoutineDraft` defaults to `.strength` + `.double` on
//       new-routine init (no-routine path).
//    2. `RoutineDraft.init(routine:)` round-trips intent +
//       progressionKind from an existing `Routine` (edit-mode path).
//    3. `RoutineDraft.save(into:context:)` writes intent +
//       progressionKind onto the underlying `Routine` row
//       (`routine.intentRaw` + `routine.progressionKindRaw`).
//    4. Intent picker copy verbatim per UI-SPEC § Header pickers §
//       Verification anchors — anchors all 5 option strings + the row
//       label + the accessibility hint via `#filePath` ascent.
//    5. Progression picker copy verbatim per UI-SPEC — anchors all 4
//       option strings + the row label + the accessibility hint.
//    6. Mutating `draft.intent` or `draft.progressionKind` makes
//       `draft.snapshotHash()` return a different value — locks the
//       Phase 3.1 dirty-check behavior change (the relocated
//       `snapshotHash()` on `RoutineDraft` is testable now that it's
//       `internal` access). Plan 04 WARNING 1 fix from a prior
//       revision: the test compiles because Plan 04 Task 1 relocated
//       `snapshotHash()` from RoutineBuilderView (private) to
//       RoutineDraft (internal).
//
//  Test framework: Swift Testing (`@Test` / `#expect`). `@MainActor`
//  on tests that touch `ModelContext` per the FilterStatePredicateTests
//  / ExerciseHistoryIntentSplitTests precedent. Source-anchor copy
//  tests (Tests 4 + 5) follow the `ExerciseHistoryViewCopyTests` shape
//  — read the source file from disk via `#filePath` ascent and
//  `#expect` on `contains(...)` rather than instantiating the view.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("RoutineBuilderHeaderPickers")
struct RoutineBuilderHeaderPickersTests {

    // MARK: - Helpers

    /// Fresh in-memory V4 ModelContext over `Schema(SchemaV5.models)` +
    /// FitbodSchemaMigrationPlan — mirrors SchemaV4MigrationTests +
    /// ExerciseHistoryIntentSplitTests fixture pattern.
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - 1. Defaults on new-routine init

    @Test("RoutineDraft defaults to .strength + .double on new-routine init")
    @MainActor
    func newDraftDefaults() {
        let draft = RoutineDraft()
        #expect(draft.intent == .strength)
        #expect(draft.progressionKind == .double)
    }

    // MARK: - 2. init(routine:) round-trip (edit mode)

    @Test("RoutineDraft init(routine:) round-trips intent + progressionKind from an existing Routine")
    @MainActor
    func initFromRoutineRoundTrip() throws {
        let ctx = try makeContext()

        let routine = Routine()
        routine.name = "Edit-Mode Fixture"
        routine.intentRaw = "hypertrophy"
        routine.progressionKindRaw = "rpe"
        ctx.insert(routine)
        try ctx.save()

        let draft = RoutineDraft(routine: routine)
        #expect(draft.intent == .hypertrophy)
        #expect(draft.progressionKind == .rpe)
    }

    // MARK: - 3. save(into:context:) writes intent + progressionKind

    @Test("RoutineDraft.save(into:) writes intent + progressionKind to the Routine")
    @MainActor
    func savePersistsHeaderPickerFields() throws {
        let ctx = try makeContext()

        // Seed an Exercise so the draft's lone RoutineExerciseDraft is
        // non-empty (isValid requires ≥1 exercise) — name + canonicalName
        // + the equipment/mechanic raw strings keep the row hermetic.
        let bench = Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
        try ctx.save()

        // Build a fresh draft with both pickers MUTATED away from the
        // default values so the assertion exercises a real write.
        // Phase 4 requires block/hybrid progression to be inside a
        // resolved block, so this fixture links the routine to one.
        let block = Block()
        block.name = "Peak Block"
        ctx.insert(block)

        let draft = RoutineDraft()
        draft.name = "Header Picker Save Test"
        draft.blockID = block.id
        draft.intent = .power
        draft.progressionKind = .hybrid
        let exDraft = RoutineExerciseDraft()
        exDraft.exercise = bench
        draft.exercises = [exDraft]

        // Save into a fresh Routine row.
        let routine = Routine()
        ctx.insert(routine)
        draft.save(into: routine, context: ctx)
        try ctx.save()

        // Re-fetch from the store.
        let routines = try ctx.fetch(FetchDescriptor<Routine>())
        let saved = try #require(routines.first)
        #expect(saved.intentRaw == "power")
        #expect(saved.progressionKindRaw == "hybrid")
        #expect(saved.block?.id == block.id)
        // Computed accessor sanity-check.
        #expect(saved.intent == .power)
        #expect(saved.progressionKind == .hybrid)
    }

    // MARK: - 4. Intent picker copy verbatim per UI-SPEC

    @Test("Intent picker copy verbatim per UI-SPEC § Header pickers § Verification anchors")
    func intentPickerCopy() throws {
        let source = try readRoutineBuilderViewSource()

        // UI-SPEC § Header pickers row label + the 5 option strings.
        #expect(source.contains("\"Intent\""))
        #expect(source.contains("\"Strength\""))
        #expect(source.contains("\"Hypertrophy\""))
        #expect(source.contains("\"Power\""))
        #expect(source.contains("\"Endurance\""))
        #expect(source.contains("\"Technique\""))

        // Accessibility hint verbatim per UI-SPEC § Copywriting Contract.
        #expect(source.contains(
            "\"Sets the training goal for the whole session.\""
        ))

        // Tag bindings prove the picker case order matches Intent.allCases.
        #expect(source.contains(".tag(Intent.strength)"))
        #expect(source.contains(".tag(Intent.hypertrophy)"))
        #expect(source.contains(".tag(Intent.power)"))
        #expect(source.contains(".tag(Intent.endurance)"))
        #expect(source.contains(".tag(Intent.technique)"))
    }

    // MARK: - 5. Progression picker copy verbatim per UI-SPEC

    @Test("Progression picker copy verbatim per UI-SPEC § Header pickers § Verification anchors")
    func progressionPickerCopy() throws {
        let source = try readRoutineBuilderViewSource()

        // Row label + the 4 option strings.
        #expect(source.contains("\"Progression\""))
        #expect(source.contains("\"RPE Autoregulation\""))
        #expect(source.contains("\"Double Progression\""))
        #expect(source.contains("\"Block Periodized\""))
        #expect(source.contains("\"Hybrid\""))

        // Accessibility hint verbatim per UI-SPEC § Copywriting Contract.
        #expect(source.contains(
            "\"Sets the weight-progression strategy used for every exercise in this routine.\""
        ))

        // Phase 4 filters the actual picker entries through
        // `availableProgressionKinds`, so Block + Hybrid are only
        // offered after a routine has a block.
        #expect(source.contains("ForEach(availableProgressionKinds"))
        #expect(source.contains("RoutineDraft.availableProgressionKinds(hasBlock: draft.blockID != nil)"))
        #expect(source.contains("\"Add routine to a block to use these.\""))
    }

    // MARK: - 6. snapshotHash dirty-check (Phase 3.1 expansion)

    /// Plan 04 WARNING 1 fix — `snapshotHash()` relocated from
    /// `RoutineBuilderView` (private) to `RoutineDraft` (internal) so
    /// the unit-test target can call it via `@testable import fitbod`.
    /// The Phase 3.1 expansion of the hash inputs INCLUDES the two new
    /// picker rawValues (`intent.rawValue` + `progressionKind.rawValue`)
    /// so a header-picker change arms the Cancel-discard prompt. This
    /// test locks that behavior: a future edit that accidentally drops
    /// either component from the hash will fail one of the `#expect`
    /// calls below.
    @Test("mutating intent or progression makes snapshotHash return a different value")
    @MainActor
    func snapshotHashRespondsToPickerMutations() {
        let draft = RoutineDraft()
        let initialHash = draft.snapshotHash()

        draft.intent = .hypertrophy
        #expect(draft.snapshotHash() != initialHash)

        let afterIntent = draft.snapshotHash()
        draft.progressionKind = .rpe
        #expect(draft.snapshotHash() != afterIntent)
    }

    // MARK: - Source-file reader (Tests 4 + 5)

    /// Ascend from this test file at
    /// `fitbodTests/RoutineBuilderHeaderPickersTests.swift` to the repo
    /// root, descend into `fitbod/Routines/`, and read
    /// `RoutineBuilderView.swift`. Same `#filePath` ascent pattern as
    /// `ExerciseHistoryViewCopyTests.verbatimCopy()` +
    /// `RoutineBuilderCopyTests.verbatimCopy()`.
    private func readRoutineBuilderViewSource() throws -> String {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Routines")
        return try String(
            contentsOf: base.appendingPathComponent("RoutineBuilderView.swift"),
            encoding: .utf8
        )
    }
}
