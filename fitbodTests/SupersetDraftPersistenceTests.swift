import SwiftData
import Testing
@testable import fitbod

@MainActor
struct SupersetDraftPersistenceTests {
    enum Failure: Error { case disk }

    private func fixture() throws -> (ModelContext, SessionTemplate) {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let row = LoggerFixtures.exercise("Row", in: ctx)
        let template = try LoggerFixtures.template("Upper", exercises: [bench, row], in: ctx)
        return (ctx, template)
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
