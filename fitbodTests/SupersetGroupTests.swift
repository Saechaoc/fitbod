//
//  SupersetGroupTests.swift
//  fitbodTests
//
//  Behavioral coverage for the `SupersetGroup` entity + the
//  `RoutineExercise.supersetGroupID` soft-ref assignment flow that the
//  `SupersetAssignmentSheet` mutates (plan 03-03). Three `@Test`
//  functions:
//
//    1. createAndAssign — insert SupersetGroup + assign via
//       RoutineExercise.supersetGroupID round-trips through SwiftData
//    2. unassignSetsNil — setting supersetGroupID = nil clears the
//       assignment
//    3. kindAccessor — kindRaw "giant" → kind .giant; "paired" → .paired
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SupersetGroup (plan 03-03)")
struct SupersetGroupTests {

    private func makeContext() throws -> ModelContext {
        let container = try InMemoryContainer.makeCurrent()
        return ModelContext(container)
    }

    // MARK: - 1

    @Test("createAndAssign")
    func createAndAssign() throws {
        let ctx = try makeContext()
        let routine = SessionTemplate()
        ctx.insert(routine)

        let re = SessionExerciseTemplate()
        re.sessionTemplate = routine
        ctx.insert(re)

        let group = SupersetGroup(
            routineID: routine.id,
            kindRaw: SupersetKind.paired.rawValue,
            sortOrder: 0
        )
        ctx.insert(group)
        re.supersetGroupID = group.id
        try ctx.save()

        let id = routine.id
        let groups = try ctx.fetch(FetchDescriptor<SupersetGroup>(
            predicate: #Predicate { $0.routineID == id }
        ))
        #expect(groups.count == 1)
        #expect(re.supersetGroupID == group.id)
    }

    // MARK: - 2

    @Test("unassignSetsNil")
    func unassignSetsNil() throws {
        let ctx = try makeContext()
        let routine = SessionTemplate()
        ctx.insert(routine)
        let re = SessionExerciseTemplate()
        re.sessionTemplate = routine
        let group = SupersetGroup(routineID: routine.id)
        ctx.insert(group)
        re.supersetGroupID = group.id
        ctx.insert(re)
        try ctx.save()

        re.supersetGroupID = nil
        try ctx.save()
        #expect(re.supersetGroupID == nil)
    }

    // MARK: - 3

    @Test("kindAccessor")
    func kindAccessor() {
        let group = SupersetGroup(routineID: UUID(), kindRaw: "giant")
        #expect(group.kind == .giant)
        let group2 = SupersetGroup(routineID: UUID(), kindRaw: "paired")
        #expect(group2.kind == .paired)
    }
}
