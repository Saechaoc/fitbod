//
//  RoutineDuplicationTests.swift
//  fitbodTests
//
//  `RoutineDuplicator.duplicate(_:context:)`, the session editor's
//  Duplicate session (RM-026): the copy is the editor's draft, unsaved
//  changes included, saved as a new session that shares no row or superset
//  group with the original, which keeps what it last saved.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineDuplication")
struct RoutineDuplicationTests {
    enum Failure: Error { case disk }

    private func makeContext() throws -> ModelContext {
        let container = try InMemoryContainer.makeCurrent()
        return ModelContext(container)
    }

    /// Seeds a session template with:
    ///   - 2 SessionExerciseTemplate rows (Bench, OHP) in order
    ///   - 1 per-set override on the Bench row (setIndex 0, 6 reps @ RPE 9)
    ///   - warm-ups off on the OHP row
    ///   - 1 SupersetGroup linking both rows
    private func makeFixture(ctx: ModelContext) throws -> SessionTemplate {
        let routine = SessionTemplate()
        routine.name = "Push Day"
        routine.notes = "Heavy bench focus"
        routine.intentRaw = Intent.strength.rawValue
        routine.progressionKindRaw = ProgressionKind.rpe.rawValue
        ctx.insert(routine)

        let ex1 = exercise("Bench", in: ctx)
        let ex2 = exercise("OHP", in: ctx)

        let re1 = SessionExerciseTemplate()
        re1.sessionTemplate = routine
        re1.exercise = ex1
        re1.orderIndex = 0
        re1.targetSets = 3
        ctx.insert(re1)

        let re2 = SessionExerciseTemplate()
        re2.sessionTemplate = routine
        re2.exercise = ex2
        re2.orderIndex = 1
        re2.targetSets = 4
        re2.warmupOverride = WarmupConfig(enabled: false)
        ctx.insert(re2)

        let ov = RoutineExerciseSetOverride(
            setIndex: 0,
            targetRepsLow: 6,
            targetRepsHigh: 6,
            targetRPE: 9.0
        )
        ov.routineExercise = re1
        ctx.insert(ov)

        let group = SupersetGroup(
            routineID: routine.id,
            kindRaw: SupersetKind.paired.rawValue,
            sortOrder: 0
        )
        ctx.insert(group)
        re1.supersetGroupID = group.id
        re2.supersetGroupID = group.id

        try ctx.save()
        return routine
    }

    private func exercise(_ name: String, in ctx: ModelContext) -> Exercise {
        let exercise = Exercise.previewSample(name: name, equipment: .barbell, mechanic: .compound)
        ctx.insert(exercise)
        return exercise
    }

    private func duplicate(_ source: SessionTemplate, in ctx: ModelContext) throws -> SessionTemplate {
        try RoutineDuplicator.duplicate(RoutineDraft(routine: source), context: ctx)
    }

    /// `session` as the store has it, read through a fresh context.
    private func stored(_ session: SessionTemplate, in ctx: ModelContext) throws -> SessionTemplate {
        let id = session.id
        let reader = ModelContext(ctx.container)
        return try #require(try reader.fetch(FetchDescriptor<SessionTemplate>(predicate: #Predicate { $0.id == id })).first)
    }

    private func groups(of session: SessionTemplate, in ctx: ModelContext) throws -> [SupersetGroup] {
        let id = session.id
        return try ModelContext(ctx.container).fetch(FetchDescriptor<SupersetGroup>(predicate: #Predicate { $0.routineID == id }))
    }

    private func lifts(_ session: SessionTemplate) -> [SessionExerciseTemplate] {
        (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - A saved session's copy

    @Test("nameSuffixedWithCopy")
    func nameSuffixedWithCopy() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = try duplicate(source, in: ctx)
        #expect(copy.name == "Push Day (Copy)")
    }

    @Test("deepCopyOfRoutineExercises")
    func deepCopyOfRoutineExercises() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = try stored(try duplicate(source, in: ctx), in: ctx)

        let copyExercises = lifts(copy)
        #expect(copyExercises.count == 2)
        #expect(copyExercises[0].exercise?.name == "Bench")
        #expect(copyExercises[1].exercise?.name == "OHP")
        // IDs are FRESH — not shared with source.
        let sourceIDs = Set((source.exercises ?? []).map { $0.id })
        let copyIDs = Set(copyExercises.map { $0.id })
        #expect(sourceIDs.isDisjoint(with: copyIDs))
        for re in copyExercises {
            #expect(re.sessionTemplate?.id == copy.id)
        }
        #expect(copyExercises[0].targetSets == 3)
        #expect(copyExercises[1].targetSets == 4)
        #expect(copyExercises[1].warmupOverride == WarmupConfig(enabled: false))

        #expect(copy.notes == "Heavy bench focus")
        #expect(copy.intentRaw == Intent.strength.rawValue)
        #expect(copy.progressionKindRaw == ProgressionKind.rpe.rawValue)
        #expect(!copy.isArchived)
    }

    @Test("supersetGroupRemappedToClonedGroup")
    func supersetGroupRemappedToClonedGroup() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = try duplicate(source, in: ctx)

        let sourceGroups = try groups(of: source, in: ctx)
        let copyGroups = try groups(of: copy, in: ctx)
        #expect(sourceGroups.count == 1)
        #expect(copyGroups.count == 1)
        #expect(sourceGroups.first?.id != copyGroups.first?.id)
        // Cloned rows reference the CLONED group ID, not the source's.
        for re in try stored(copy, in: ctx).exercises ?? [] {
            #expect(re.supersetGroupID == copyGroups.first?.id)
        }
        for re in try stored(source, in: ctx).exercises ?? [] {
            #expect(re.supersetGroupID == sourceGroups.first?.id)
        }
    }

    @Test("perSetOverridesCloned")
    func perSetOverridesCloned() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let copy = try stored(try duplicate(source, in: ctx), in: ctx)

        let copyRE0 = try #require(lifts(copy).first)
        let copyOverrides = copyRE0.setOverrides ?? []
        #expect(copyOverrides.count == 1)
        #expect(copyOverrides.first?.setIndex == 0)
        #expect(copyOverrides.first?.targetRepsLow == 6)
        #expect(copyOverrides.first?.targetRepsHigh == 6)
        #expect(copyOverrides.first?.targetRPE == 9.0)

        let sourceRE0 = try #require(lifts(source).first)
        #expect((sourceRE0.setOverrides ?? []).first?.id != copyOverrides.first?.id)
        #expect(copyOverrides.first?.routineExercise?.id == copyRE0.id)
    }

    @Test("folderIDPreserved")
    func folderIDPreserved() throws {
        let ctx = try makeContext()
        let folder = RoutineFolder(name: "Hypertrophy Block")
        ctx.insert(folder)

        let source = try makeFixture(ctx: ctx)
        source.folderID = folder.id
        try ctx.save()

        let copy = try duplicate(source, in: ctx)
        #expect(copy.folderID == folder.id)
    }

    @Test("originalRoutineUntouched")
    func originalRoutineUntouched() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        _ = try duplicate(source, in: ctx)

        let original = try stored(source, in: ctx)
        #expect(original.name == "Push Day")
        #expect(lifts(original).count == 2)
        #expect((lifts(original).first?.setOverrides ?? []).count == 1)
        #expect(try ModelContext(ctx.container).fetchCount(FetchDescriptor<SessionTemplate>()) == 2)
    }

    // MARK: - Unsaved changes (RM-026)

    @Test("Unsaved changes go into the copy, and the session keeps what it saved")
    func unsavedChangesGoIntoTheCopyOnly() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let squat = exercise("Squat", in: ctx)
        try ctx.save()
        let draft = RoutineDraft(routine: source)
        draft.name = "  Push Day Heavy "
        draft.intent = .power
        draft.exercises[0].targetSets = 5
        draft.exercises[1].warmupOverride = WarmupConfig(enabled: true, skipNextSession: true)
        draft.append(exercise: squat)
        let draftIDs = draft.exercises.map(\.id)

        let copy = try stored(try RoutineDuplicator.duplicate(draft, context: ctx), in: ctx)
        #expect(copy.name == "Push Day Heavy (Copy)")
        #expect(copy.intent == .power)
        #expect(lifts(copy).map { $0.exercise?.name } == ["Bench", "OHP", "Squat"])
        #expect(lifts(copy).map(\.targetSets) == [5, 4, draft.exercises[2].targetSets])
        #expect(lifts(copy)[1].warmupOverride == WarmupConfig(enabled: true, skipNextSession: true))

        let original = try stored(source, in: ctx)
        #expect(original.name == "Push Day")
        #expect(original.intent == .strength)
        #expect(lifts(original).map { $0.exercise?.name } == ["Bench", "OHP"])
        #expect(lifts(original).map(\.targetSets) == [3, 4])
        #expect(lifts(original)[1].warmupOverride == WarmupConfig(enabled: false))

        // The editor's draft still edits the original, unsaved changes and all.
        #expect(draft.exercises.map(\.id) == draftIDs)
        #expect(draft.name == "  Push Day Heavy ")
        #expect(!ctx.hasChanges)
    }

    @Test("Each superset becomes one new group of the copy's, its lifts together")
    func eachSupersetBecomesOneNewGroup() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let names = ["Row", "Squat", "Curl"]
        let extra = names.map { exercise($0, in: ctx) }
        try ctx.save()
        let draft = RoutineDraft(routine: source)
        for lift in extra { draft.append(exercise: lift) }
        // An unsaved superset of Row and Curl, which gathers Curl up to Row.
        draft.setSuperset(of: draft.exercises[2], partners: [draft.exercises[4]])
        let unsaved = try #require(draft.newSupersetIDs.first)
        let saved = try #require(try groups(of: source, in: ctx).first?.id)

        let copy = try stored(try RoutineDuplicator.duplicate(draft, context: ctx), in: ctx)
        let order = lifts(copy)
        #expect(order.map { $0.exercise?.name } == ["Bench", "OHP", "Row", "Curl", "Squat"])
        let copyGroups = Set(try groups(of: copy, in: ctx).map(\.id))
        #expect(copyGroups.count == 2)
        #expect(copyGroups.isDisjoint(with: [saved, unsaved]))
        #expect(order[0].supersetGroupID == order[1].supersetGroupID)
        #expect(order[2].supersetGroupID == order[3].supersetGroupID)
        #expect(order[0].supersetGroupID != order[2].supersetGroupID)
        #expect(Set(order.compactMap(\.supersetGroupID)) == copyGroups)
        #expect(order[4].supersetGroupID == nil)

        // Saving the original afterwards gives it its own groups and leaves the copy's.
        try draft.persist(into: source, context: ctx)
        #expect(Set(try groups(of: source, in: ctx).map(\.id)) == [saved, unsaved])
        #expect(Set(try groups(of: copy, in: ctx).map(\.id)) == copyGroups)
    }

    @Test("A failed copy rolls the store back and keeps the draft for a retry")
    func aFailedCopyRollsBackAndKeepsTheDraft() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let draft = RoutineDraft(routine: source)
        draft.name = "Changed"
        // Bench leaves its superset, which ends it, then pairs with OHP again in a new one.
        draft.leaveSuperset(draft.exercises[0])
        draft.setSuperset(of: draft.exercises[0], partners: [draft.exercises[1]])
        let unsaved = draft.newSupersetIDs
        let before = draft.snapshotHash()

        #expect(throws: Failure.self) {
            try RoutineDuplicator.duplicate(draft, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        let reader = ModelContext(ctx.container)
        #expect(try reader.fetchCount(FetchDescriptor<SessionTemplate>()) == 1)
        #expect(try reader.fetchCount(FetchDescriptor<SessionExerciseTemplate>()) == 2)
        #expect(try reader.fetchCount(FetchDescriptor<RoutineExerciseSetOverride>()) == 1)
        #expect(try reader.fetchCount(FetchDescriptor<SupersetGroup>()) == 1)
        #expect(draft.snapshotHash() == before)
        #expect(draft.newSupersetIDs == unsaved)

        let copy = try RoutineDuplicator.duplicate(draft, context: ctx)
        #expect(copy.name == "Changed (Copy)")
        #expect(try ModelContext(ctx.container).fetchCount(FetchDescriptor<SessionTemplate>()) == 2)
        #expect(try groups(of: copy, in: ctx).count == 1)
    }

    @Test("A copy leaves logged workouts as they were")
    func aCopyLeavesLoggedWorkouts() throws {
        let ctx = try makeContext()
        let source = try makeFixture(ctx: ctx)
        let workout = try SessionFactory.start(template: source, context: ctx)
        workout.completedAt = .now
        try ctx.save()

        let draft = RoutineDraft(routine: source)
        draft.name = "Push Day Heavy"
        draft.exercises[0].targetSets = 5
        let copy = try RoutineDuplicator.duplicate(draft, context: ctx)

        let sessions = try ModelContext(ctx.container).fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        let logged = try #require(sessions.first)
        #expect(logged.id == workout.id)
        #expect(logged.template?.id == source.id)
        #expect(logged.sourceRoutineID == source.id)
        #expect(logged.displayName == "Push Day")
        let loggedLifts = (logged.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(loggedLifts.map(\.exerciseNameSnapshot) == ["Bench", "OHP"])
        #expect(loggedLifts.map(\.targetSets) == [3, 4])
        #expect(copy.id != source.id)
    }
}
