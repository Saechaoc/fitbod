//
//  SetRowWhyLayoutTests.swift
//  fitbodTests
//
//  At 390pt the logger gives each row 358pt. Selected effort and non-working
//  set types must fit without the full effort picker open.
//

import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import fitbod

@MainActor
@Suite("SetRowWhyLayout")
struct SetRowWhyLayoutTests {

    /// Held by the suite so the models stay attached while the rows render.
    private let container: ModelContainer

    init() throws {
        container = try InMemoryContainer.makeCurrent()
    }

    private let explanation = PrescriptionExplanation(
        lastSessionLine: "100 × 5 @ RPE 8 (Oct 26)",
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 102.5,
        roundedLine: "→ 102.5 lb (rounded down to 2.5 lb plates)",
        status: .notApplicable,
        bumpOccurred: true,
        range: nil
    )

    /// Height of a set row at the proposed width.
    private func rowHeight(
        setType: SetType,
        width: CGFloat,
        isComplete: Bool = false,
        effortExpanded: Bool = false,
        dynamicTypeSize: DynamicTypeSize = .large
    ) throws -> CGFloat {
        let ctx = container.mainContext
        let exercise = Exercise.previewSample(
            name: "Barbell Bench Press - Medium Grip", equipment: .barbell, mechanic: .compound
        )
        ctx.insert(exercise)
        let session = Session()
        ctx.insert(session)
        let sessionExercise = SessionExercise()
        ctx.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = exercise
        sessionExercise.prescribedWeight = 102.5
        let entry = SetEntry()
        ctx.insert(entry)
        entry.sessionExercise = sessionExercise
        entry.setTypeRaw = setType.rawValue
        entry.weight = 102.5
        entry.reps = isComplete ? 5 : 0
        entry.rpe = isComplete ? 8.5 : nil
        entry.isComplete = isComplete
        try ctx.save()

        let row = SetRow(
            entry: entry,
            sessionExercise: sessionExercise,
            prescribed: 102.5,
            explanation: explanation,
            expandedEffortSetID: .constant(effortExpanded ? entry.id : nil),
            onCommit: {},
            onTapEmptyCell: {}
        )
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .modelContainer(container)
        return UIHostingController(rootView: row)
            .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            .height
    }

    @Test("A set type fits within the compact row at 390pt",
          arguments: [SetType.drop, .failure, .warmup])
    func typedSetKeepsOneChipLine(setType: SetType) throws {
        let working = try rowHeight(setType: .working, width: 358)
        let typed = try rowHeight(setType: setType, width: 358)
        #expect(typed == working, "A \(setType.rawValue) label should fit without growing the row")
    }

    @Test("A decimal effort rating fits the compact row until the picker expands")
    func loggedEffortKeepsRowCompact() throws {
        let open = try rowHeight(setType: .working, width: 358)
        let logged = try rowHeight(setType: .working, width: 358, isComplete: true)
        #expect(logged == open)
        let expanded = try rowHeight(setType: .working, width: 358, isComplete: true, effortExpanded: true)
        #expect(expanded > logged)
    }
}
