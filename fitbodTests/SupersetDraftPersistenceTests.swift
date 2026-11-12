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

        // Bench swaps Row for Squat, which joins it; Curl, left alone, leaves its superset too.
        draft.setSuperset(of: bench, partners: [squat])
        #expect(bench.supersetGroupID == benchGroup)
        #expect(squat.supersetGroupID == benchGroup)
        #expect(row.supersetGroupID == nil)
        #expect(curl.supersetGroupID == nil)
        #expect(names(draft) == ["Bench", "Squat", "Row", "Curl"])
    }

    @Test func leavingAPairEndsItButATrioKeepsTwoTogether() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat"])
        let draft = RoutineDraft(routine: template)
        let (bench, row, squat) = (draft.exercises[0], draft.exercises[1], draft.exercises[2])
        draft.setSuperset(of: bench, partners: [row, squat])
        // The middle lift leaves, and moves past the two that stay together.
        draft.leaveSuperset(row)
        #expect(row.supersetGroupID == nil)
        #expect(bench.supersetGroupID != nil)
        #expect(bench.supersetGroupID == squat.supersetGroupID)
        #expect(names(draft) == ["Bench", "Squat", "Row"])
        draft.leaveSuperset(squat)
        #expect(draft.exercises.allSatisfy { $0.supersetGroupID == nil })
        #expect(!ctx.hasChanges)
    }

    @Test func pairingLiftsApartGathersThemAtTheFirst() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat", "Curl"])
        let draft = RoutineDraft(routine: template)
        let (bench, squat) = (draft.exercises[0], draft.exercises[2])
        draft.setSuperset(of: squat, partners: [bench])
        #expect(names(draft) == ["Bench", "Squat", "Row", "Curl"])
        #expect(draft.exercises.map(\.orderIndex) == [0, 1, 2, 3])
        #expect(bench.supersetGroupID != nil)
        #expect(bench.supersetGroupID == squat.supersetGroupID)
        #expect(!ctx.hasChanges)
    }

    @Test func aSupersetWithNoPartnersEnds() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat"])
        let draft = RoutineDraft(routine: template)
        let (bench, row, squat) = (draft.exercises[0], draft.exercises[1], draft.exercises[2])
        draft.setSuperset(of: bench, partners: [row])
        draft.setSuperset(of: bench, partners: [])
        draft.setSuperset(of: squat, partners: [])
        #expect(draft.exercises.allSatisfy { $0.supersetGroupID == nil })
        #expect(names(draft) == ["Bench", "Row", "Squat"])
        #expect(!ctx.hasChanges)
    }

    @Test func theBracketOpensAndClosesAtASupersetsEnds() throws {
        let (_, template) = try fixture(["Bench", "Row", "Squat", "Curl"])
        let draft = RoutineDraft(routine: template)
        draft.setSuperset(of: draft.exercises[0], partners: [draft.exercises[1], draft.exercises[2]])
        #expect(draft.supersetEdges(at: 0) == (opens: true, closes: false))
        #expect(draft.supersetEdges(at: 1) == (opens: false, closes: false))
        #expect(draft.supersetEdges(at: 2) == (opens: false, closes: true))
        #expect(draft.supersetEdges(at: 3) == (opens: true, closes: true))
    }

    @Test func aMoveInsideASupersetReordersItAndOneOutOfItLeaves() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat", "Curl"])
        let draft = RoutineDraft(routine: template)
        let (squat, curl) = (draft.exercises[2], draft.exercises[3])
        draft.setSuperset(of: squat, partners: [curl])

        // Row passes the Squat and Curl superset whole, down and back up.
        draft.move(at: 1, up: false)
        #expect(names(draft) == ["Bench", "Squat", "Curl", "Row"])
        draft.move(at: 3, up: true)
        #expect(names(draft) == ["Bench", "Row", "Squat", "Curl"])
        #expect(squat.supersetGroupID != nil)
        #expect(squat.supersetGroupID == curl.supersetGroupID)

        // Inside the superset, Curl swaps with Squat and both stay in it.
        draft.move(at: 3, up: true)
        #expect(names(draft) == ["Bench", "Row", "Curl", "Squat"])
        #expect(squat.supersetGroupID == curl.supersetGroupID)

        // Curl moves up out past Row: it leaves, and Squat, left alone, leaves too.
        draft.move(at: 2, up: true)
        #expect(names(draft) == ["Bench", "Curl", "Row", "Squat"])
        #expect(draft.exercises.allSatisfy { $0.supersetGroupID == nil })
        #expect(draft.exercises.map(\.orderIndex) == [0, 1, 2, 3])
        #expect(!ctx.hasChanges)
    }

    @Test func aCopyOfAPairedLiftGoesAfterItsSuperset() throws {
        let (ctx, template) = try fixture(["Bench", "Row", "Squat"])
        let draft = RoutineDraft(routine: template)
        let (bench, row) = (draft.exercises[0], draft.exercises[1])
        draft.setSuperset(of: bench, partners: [row])
        draft.duplicate(bench)
        #expect(names(draft) == ["Bench", "Row", "Bench", "Squat"])
        #expect(draft.exercises[2].supersetGroupID == nil)
        #expect(draft.exercises[2].id == nil)
        #expect(bench.supersetGroupID == row.supersetGroupID)
        draft.duplicate(draft.exercises[3])
        #expect(names(draft) == ["Bench", "Row", "Bench", "Squat", "Squat"])
        #expect(draft.exercises.map(\.orderIndex) == [0, 1, 2, 3, 4])
        #expect(!ctx.hasChanges)
    }

    private func names(_ draft: RoutineDraft) -> [String?] {
        draft.exercises.map { $0.exercise?.name }
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
