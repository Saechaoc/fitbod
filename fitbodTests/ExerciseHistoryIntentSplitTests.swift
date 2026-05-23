//
//  ExerciseHistoryIntentSplitTests.swift
//  fitbodTests
//
//  Six test functions covering the intent-split predicate that
//  drives `ExerciseHistoryView`'s inner `FilteredHistoryList` query.
//  The list-view itself is SwiftUI composition — these tests pin the
//  data layer that the view binds to.
//
//  Closes the data-layer half of:
//    - **ROUTINE-08** (same routine recurring with different intent
//      maintains separate per-intent histories) — proven by
//      `strengthFilterReturnsMondayOnly` / `hypertrophyFilterReturnsThursdayOnly`.
//    - **SESS-10** (per-exercise history with intent split) — proven
//      by the predicate-scoping tests (`differentExerciseReturnsEmpty`)
//      plus the visible-rows filter pin
//      (`incompleteSetsExcludedFromVisibleSets`).
//
//  The query under test mirrors `FilteredHistoryList.init`'s `Query`
//  predicate exactly — same local-let captures (RESEARCH §6 Pitfall 1
//  workaround for the SwiftData related-entity ID compare footgun on
//  iOS 17/18) — so a passing test here matches what the view sees at
//  render time.
//
//  Container/test pattern matches `PreviousMatchingIntentTests` (plan
//  01-01) verbatim: `@MainActor` + `.serialized` over an in-memory
//  `ModelContainer` constructed with `Schema(SchemaV4.models)` +
//  `FitbodSchemaMigrationPlan`.
//
//  Phase 3.1 (PIVOT-02 / PIVOT-05 / D-13 / D-15): intent moved from
//  SessionExercise.intentRaw to Session.intentRaw. The view's predicate
//  drops the intent compare from the #Predicate body and re-adds it as a
//  Swift post-filter on `se.session?.intentRaw == targetIntent`
//  (Pitfall 1 workaround for multi-level optional chain inside
//  #Predicate). The intent-split semantics survive the field move
//  because the two fixture sessions still carry different session-level
//  intents.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ExerciseHistoryIntentSplit", .serialized)
struct ExerciseHistoryIntentSplitTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Builds a fixture with the same exercise (Bench Press) logged on
    /// Monday at strength intent AND on Thursday at hypertrophy intent.
    ///
    /// The intent-split contract: querying for strength returns Monday
    /// only; hypertrophy returns Thursday only; "All" returns both.
    /// This fixture IS ROUTINE-08's canonical scenario.
    private func makeMondayAndThursdayFixture(ctx: ModelContext) throws -> Exercise {
        let bench = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound
        )
        ctx.insert(bench)

        // Monday — strength session (intent on Session per PIVOT-02).
        let monday = Session()
        monday.startedAt = Date(timeIntervalSince1970: 1_000_000)
        monday.completedAt = monday.startedAt.addingTimeInterval(45 * 60)
        monday.routineSnapshotName = "Push Day A — Strength"
        monday.intentRaw = Intent.strength.rawValue
        ctx.insert(monday)
        let mondaySE = SessionExercise()
        mondaySE.session = monday
        mondaySE.exercise = bench
        ctx.insert(mondaySE)
        let mondaySet = SetEntry()
        mondaySet.sessionExercise = mondaySE
        mondaySet.weight = 185
        mondaySet.reps = 5
        mondaySet.rpe = 8.0
        mondaySet.isComplete = true
        ctx.insert(mondaySet)

        // Thursday — hypertrophy session (intent on Session per PIVOT-02).
        let thursday = Session()
        thursday.startedAt = Date(timeIntervalSince1970: 1_300_000)
        thursday.completedAt = thursday.startedAt.addingTimeInterval(60 * 60)
        thursday.routineSnapshotName = "Push Day A — Hypertrophy"
        thursday.intentRaw = Intent.hypertrophy.rawValue
        ctx.insert(thursday)
        let thursdaySE = SessionExercise()
        thursdaySE.session = thursday
        thursdaySE.exercise = bench
        ctx.insert(thursdaySE)
        let thursdaySet = SetEntry()
        thursdaySet.sessionExercise = thursdaySE
        thursdaySet.weight = 155
        thursdaySet.reps = 10
        thursdaySet.rpe = 7.5
        thursdaySet.isComplete = true
        ctx.insert(thursdaySet)

        try ctx.save()
        return bench
    }

    /// Mirrors `FilteredHistoryList.init`'s predicate exactly (post-Plan-07
    /// shape). Returns matching `SessionExercise` rows in descending
    /// session-startedAt order.
    ///
    /// Phase 3.1 (PIVOT-05 / D-13 / D-15): the predicate filters on
    /// exerciseID only — the intent gate moves to a Swift post-filter
    /// on `se.session?.intentRaw == targetIntent` because multi-level
    /// optional chains aren't allowed inside #Predicate (Pitfall 1).
    /// RESEARCH §6 local-let captures still apply for the exerciseID.
    private func fetchHistory(
        ctx: ModelContext,
        exercise: Exercise,
        intent: Intent?
    ) throws -> [SessionExercise] {
        let targetID = exercise.id
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in
                se.exercise?.id == targetID
            },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        let all = try ctx.fetch(descriptor)
        if let intent {
            let targetIntent = intent.rawValue
            return all.filter { $0.session?.intentRaw == targetIntent }
        }
        return all
    }

    // MARK: - 1. "All" returns both intents

    @Test("allFilterReturnsBoth — nil intent ⇒ both Monday + Thursday visible")
    func allFilterReturnsBoth() throws {
        let ctx = try makeContext()
        let bench = try makeMondayAndThursdayFixture(ctx: ctx)
        let results = try fetchHistory(ctx: ctx, exercise: bench, intent: nil)
        #expect(results.count == 2)
    }

    // MARK: - 2. ROUTINE-08 — strength filter scopes to strength only

    @Test("strengthFilterReturnsMondayOnly — ROUTINE-08 separates strength stream")
    func strengthFilterReturnsMondayOnly() throws {
        let ctx = try makeContext()
        let bench = try makeMondayAndThursdayFixture(ctx: ctx)
        let results = try fetchHistory(ctx: ctx, exercise: bench, intent: .strength)
        #expect(results.count == 1)
        // Phase 3.1: intent lives on the parent Session now.
        #expect(results.first?.session?.intentRaw == Intent.strength.rawValue)
        #expect(results.first?.session?.routineSnapshotName == "Push Day A — Strength")
    }

    // MARK: - 3. ROUTINE-08 — hypertrophy filter scopes to hypertrophy only

    @Test("hypertrophyFilterReturnsThursdayOnly — ROUTINE-08 separates hypertrophy stream")
    func hypertrophyFilterReturnsThursdayOnly() throws {
        let ctx = try makeContext()
        let bench = try makeMondayAndThursdayFixture(ctx: ctx)
        let results = try fetchHistory(ctx: ctx, exercise: bench, intent: .hypertrophy)
        #expect(results.count == 1)
        // Phase 3.1: intent lives on the parent Session now.
        #expect(results.first?.session?.intentRaw == Intent.hypertrophy.rawValue)
        #expect(results.first?.session?.routineSnapshotName == "Push Day A — Hypertrophy")
    }

    // MARK: - 4. Filter with no matching data ⇒ empty result

    @Test("powerFilterReturnsEmpty — no power sessions logged ⇒ empty result")
    func powerFilterReturnsEmpty() throws {
        let ctx = try makeContext()
        let bench = try makeMondayAndThursdayFixture(ctx: ctx)
        let results = try fetchHistory(ctx: ctx, exercise: bench, intent: .power)
        #expect(results.isEmpty)
    }

    // MARK: - 5. Predicate scopes by exerciseID — different exercise returns empty

    @Test("differentExerciseReturnsEmpty — predicate isolates per-exercise history")
    func differentExerciseReturnsEmpty() throws {
        let ctx = try makeContext()
        _ = try makeMondayAndThursdayFixture(ctx: ctx)
        let squat = Exercise.previewSample(
            name: "Squat",
            equipment: .barbell,
            mechanic: .compound
        )
        ctx.insert(squat)
        try ctx.save()
        let results = try fetchHistory(ctx: ctx, exercise: squat, intent: nil)
        #expect(results.isEmpty)
    }

    // MARK: - 6. Visible-rows filter — incomplete sets excluded

    @Test("incompleteSetsExcludedFromVisibleSets — view-layer filter pin")
    func incompleteSetsExcludedFromVisibleSets() throws {
        let ctx = try makeContext()
        let bench = try makeMondayAndThursdayFixture(ctx: ctx)
        // Add a planned-but-not-completed set on Monday's SE — the
        // FilteredHistoryList view applies `.filter { $0.isComplete }`
        // at render time, so the SE itself still matches the predicate
        // but the planned row should NOT appear among visible rows.
        let mondaySEs = try fetchHistory(ctx: ctx, exercise: bench, intent: .strength)
        let mondaySE = mondaySEs.first!
        let planned = SetEntry()
        planned.sessionExercise = mondaySE
        planned.weight = 200
        planned.reps = 0
        planned.isComplete = false
        ctx.insert(planned)
        try ctx.save()

        // The fetch returns the SE; the view filters .filter { $0.isComplete }
        // — verify here at the predicate-output level that the planned
        // set is present in the relationship but the visible-set count
        // excludes it.
        #expect(mondaySE.sets?.count == 2)            // 1 logged + 1 planned
        let completedOnly = (mondaySE.sets ?? []).filter { $0.isComplete }
        #expect(completedOnly.count == 1)
        #expect(completedOnly.first?.weight == 185)   // the logged set wins
    }
}
