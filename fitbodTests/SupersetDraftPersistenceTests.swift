import SwiftData
import Testing
@testable import fitbod

@MainActor
struct SupersetDraftPersistenceTests {
    enum Failure: Error { case disk }

    private func fixture(_ names: [String] = ["Bench", "Row"]) throws -> (ModelContext, SessionTemplate) {
        let ctx = try LoggerFixtures.makeContext()
        let exercises = names.map { LoggerFixtures.exercise($0, in: ctx) }
        let template = try LoggerFixtures.template("Upper", exercises: exercises, in: ctx)
        return (ctx, template)
    }

    // MARK: - One trip (RM-026)

    @Test func oneTripPairsThePartnersInTheDraftOnly() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat"])
        let draft = RoutineDraft(routine: template)
        let (bench, row, squat) = (draft.exercises[0], draft.exercises[1], draft.exercises[2])
        draft.setSuperset(of: bench, partners: [row])
        let id = try #require(bench.supersetGroupID)
        #expect(row.supersetGroupID == id)
        #expect(squat.supersetGroupID == nil)
        #expect(draft.newSupersetIDs == [id])
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 0)
    }

    @Test func aNewSessionSavesItsSupersetWithIt() throws {
        let ctx = try LoggerFixtures.makeContext()
        let draft = RoutineDraft()
        draft.name = "Push"
        for name in ["Bench", "Fly"] { draft.append(exercise: LoggerFixtures.exercise(name, in: ctx)) }
        draft.setSuperset(of: draft.exercises[0], partners: [draft.exercises[1]])
        let template = SessionTemplate()
        ctx.insert(template)
        try draft.persist(into: template, context: ctx)

        let reader = ModelContext(ctx.container)
        let groups = try reader.fetch(FetchDescriptor<SupersetGroup>())
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        #expect(group.routineID == template.id)
        let saved = try #require(try reader.fetch(FetchDescriptor<SessionTemplate>()).first)
        #expect((saved.exercises ?? []).count == 2)
        #expect((saved.exercises ?? []).allSatisfy { $0.supersetGroupID == group.id })
    }

    @Test func theCheckedLiftsAreTheSupersetAndALoneLiftLeaves() throws {
        let (_, template) = try fixture(["Bench", "Row", "Squat", "Curl"])
        let draft = RoutineDraft(routine: template)
        let (bench, row, squat, curl) = (draft.exercises[0], draft.exercises[1], draft.exercises[2], draft.exercises[3])
        draft.setSuperset(of: bench, partners: [row])
        draft.setSuperset(of: squat, partners: [curl])
        let benchGroup = try #require(bench.supersetGroupID)
        #expect(squat.supersetGroupID != benchGroup)

        // Bench swaps Row for Squat; Curl, left alone, leaves its superset too.
        draft.setSuperset(of: bench, partners: [squat])
        #expect(bench.supersetGroupID == benchGroup)
        #expect(squat.supersetGroupID == benchGroup)
        #expect(row.supersetGroupID == nil)
        #expect(curl.supersetGroupID == nil)
    }

    @Test func leavingAPairEndsItButATrioKeepsTwo() throws {
        let (_, template) = try fixture(["Bench", "Row", "Squat"])
        let draft = RoutineDraft(routine: template)
        let (bench, row, squat) = (draft.exercises[0], draft.exercises[1], draft.exercises[2])
        draft.setSuperset(of: bench, partners: [row, squat])
        draft.leaveSuperset(squat)
        #expect(squat.supersetGroupID == nil)
        #expect(bench.supersetGroupID != nil)
        #expect(bench.supersetGroupID == row.supersetGroupID)
        draft.leaveSuperset(row)
        #expect(bench.supersetGroupID == nil)
        #expect(row.supersetGroupID == nil)
    }

    @Test func saveDeletesAGroupNoLiftUsesAndAFailedSaveKeepsIt() throws {
        let (ctx, template) = try fixture()
        let draft = RoutineDraft(routine: template)
        draft.setSuperset(of: draft.exercises[0], partners: [draft.exercises[1]])
        try draft.persist(into: template, context: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 1)

        let editor = RoutineDraft(routine: template)
        editor.leaveSuperset(editor.exercises[0])
        #expect(editor.exercises.allSatisfy { $0.supersetGroupID == nil })
        #expect(throws: Failure.self) {
            try editor.persist(into: template, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 1)
        #expect((template.exercises ?? []).allSatisfy { $0.supersetGroupID != nil })

        try editor.persist(into: template, context: ctx)
        let reader = ModelContext(ctx.container)
        #expect(try reader.fetchCount(FetchDescriptor<SupersetGroup>()) == 0)
        let saved = try #require(try reader.fetch(FetchDescriptor<SessionTemplate>()).first)
        #expect((saved.exercises ?? []).allSatisfy { $0.supersetGroupID == nil })
    }

    @Test func discardingASupersetDraftWritesNothing() throws {
        let (ctx, template) = try fixture()
        let draft = RoutineDraft(routine: template)
        draft.addSuperset(for: draft.exercises[0])
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 0)
        #expect((template.exercises ?? []).allSatisfy { $0.supersetGroupID == nil })
        let discarded = RoutineDraft(routine: template)
        #expect(discarded.newSupersetIDs.isEmpty)
        #expect(discarded.exercises.allSatisfy { $0.supersetGroupID == nil })
    }

    @Test func failedSupersetSaveKeepsTheDraftAndRetriesTogether() throws {
        let (ctx, template) = try fixture()
        let draft = RoutineDraft(routine: template)
        let groupID = draft.addSuperset(for: draft.exercises[0])
        draft.exercises[1].supersetGroupID = groupID
        draft.name = "Changed"
        #expect(throws: Failure.self) {
            try draft.persist(into: template, context: ctx, save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        #expect(template.name == "Upper")
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 0)
        #expect((template.exercises ?? []).allSatisfy { $0.supersetGroupID == nil })
        #expect(draft.newSupersetIDs == [groupID])
        #expect(draft.exercises.allSatisfy { $0.supersetGroupID == groupID })

        try draft.persist(into: template, context: ctx)
        let reader = ModelContext(ctx.container)
        let groups = try reader.fetch(FetchDescriptor<SupersetGroup>())
        #expect(groups.count == 1 && groups.first?.id == groupID)
        let saved = try #require(try reader.fetch(FetchDescriptor<SessionTemplate>()).first)
        #expect(saved.name == "Changed")
        #expect((saved.exercises ?? []).count == 2)
        #expect((saved.exercises ?? []).allSatisfy { $0.supersetGroupID == groupID })
        #expect(draft.newSupersetIDs.isEmpty)
    }

    @Test func anUnassignedNewGroupIsNotSaved() throws {
        let (ctx, template) = try fixture()
        let draft = RoutineDraft(routine: template)
        draft.addSuperset(for: draft.exercises[0])
        draft.exercises[0].supersetGroupID = nil
        try draft.persist(into: template, context: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<SupersetGroup>()) == 0)
    }
}
