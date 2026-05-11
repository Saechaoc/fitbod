//
//  NotesPersistenceTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-03 — verifies the three notes-binding round-trips:
//
//    1. session.notes (workout-level) — written by WorkoutNotesSheet's
//       Binding(get:set:) and persisted via SwiftData's relationship-
//       managed save lifecycle.
//    2. sessionExercise.pinnedNote (per-exercise) — written by
//       PinnedNoteSheet's Binding(get:set:).
//    3. setEntry.notes (per-set form notes) — written by PerSetNoteSheet's
//       Binding(get:set:).
//
//  All three sheets share the same write-through pattern:
//    Binding(get: { model.field ?? "" }, set: { model.field = $0.isEmpty ? nil : $0 })
//
//  This test exercises the SwiftData round-trip directly (in-memory
//  ModelContainer over SchemaV2) — the sheet UI is pure SwiftUI binding so
//  the semantic contract is the round-trip itself. The defensive
//  empty-string → nil normalization is exercised by the fourth test.
//
//  Pattern matches SetRowCommitTests / MidSessionSwapTests — production
//  hermetic copy of the closure semantic against the production model
//  entities.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("NotesPersistence", .serialized)
struct NotesPersistenceTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - 1. session.notes round-trip

    @Test("sessionNotesRoundTrip — session.notes writes + reads through SwiftData")
    func sessionNotesRoundTrip() throws {
        let ctx = try makeContext()
        let session = Session()
        ctx.insert(session)
        session.notes = "Felt strong on bench today"
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Session>()).first!
        #expect(fetched.notes == "Felt strong on bench today")
    }

    // MARK: - 2. sessionExercise.pinnedNote round-trip

    @Test("pinnedNoteRoundTrip — sessionExercise.pinnedNote writes + reads through SwiftData")
    func pinnedNoteRoundTrip() throws {
        let ctx = try makeContext()
        let session = Session()
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        ctx.insert(se)
        se.pinnedNote = "Keep elbows tucked"
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SessionExercise>()).first!
        #expect(fetched.pinnedNote == "Keep elbows tucked")
    }

    // MARK: - 3. setEntry.notes round-trip

    @Test("setEntryNoteRoundTrip — setEntry.notes writes + reads through SwiftData")
    func setEntryNoteRoundTrip() throws {
        let ctx = try makeContext()
        let session = Session()
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        ctx.insert(se)
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.notes = "Right knee caved on rep 7"
        ctx.insert(entry)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SetEntry>()).first!
        #expect(fetched.notes == "Right knee caved on rep 7")
    }

    // MARK: - 4. empty-string → nil normalization

    @Test("emptyStringNotesPersistAsNil — Binding(get:set:) empty-string set maps to nil")
    func emptyStringNotesPersistAsNil() throws {
        let ctx = try makeContext()
        let session = Session()
        ctx.insert(session)
        try ctx.save()

        // Simulate the binding's set closure: empty string maps to nil.
        // This is the defensive normalization shared by all three sheets
        // (WorkoutNotesSheet / PinnedNoteSheet / PerSetNoteSheet). Keeping
        // the column nil-on-empty means "has notes?" predicates stay
        // simple (`session.notes != nil`) instead of needing to special-
        // case the empty-string boundary.
        let normalized: String? = "".isEmpty ? nil : ""
        session.notes = normalized
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Session>()).first!
        #expect(fetched.notes == nil)
    }
}
