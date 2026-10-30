//
//  SetRowWhyLayoutTests.swift
//  fitbodTests
//
//  Review item 4 (decision 8): the WHY control sits at the leading end of
//  a set row's second line. On the 390pt iPhone 17e the row gets 358pt
//  (16pt card padding each side), and that line must still hold WHY, the
//  five RPE chips and a set-type chip without the chips wrapping.
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

    /// Height of a set row with an explanation (so it shows WHY unless the
    /// set is logged) at `width`.
    private func rowHeight(
        setType: SetType,
        width: CGFloat,
        isComplete: Bool = false,
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
        entry.isComplete = isComplete
        try ctx.save()

        let row = SetRow(
            entry: entry,
            sessionExercise: sessionExercise,
            prescribed: 102.5,
            explanation: explanation,
            onCommit: {},
            onTapEmptyCell: {}
        )
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .modelContainer(container)
        return UIHostingController(rootView: row)
            .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            .height
    }

    @Test("A set-type chip fits beside WHY and the RPE chips at 390pt",
          arguments: [SetType.drop, .failure, .warmup])
    func typedSetKeepsOneChipLine(setType: SetType) throws {
        let working = try rowHeight(setType: .working, width: 358)
        let typed = try rowHeight(setType: setType, width: 358)
        #expect(typed == working, "A \(setType.rawValue) chip must not wrap the RPE chips at 390pt")
    }

    /// Ticket T09: a logged set shows no WHY. At default text it keeps WHY's
    /// space, so its chip line matches an open set's; at AX3, where WHY has
    /// a line of its own, the logged row drops that line.
    @Test("A logged set has no WHY line at AX3 and keeps its chip line at 390pt")
    func loggedSetHasNoWhy() throws {
        let open = try rowHeight(setType: .working, width: 358)
        let logged = try rowHeight(setType: .working, width: 358, isComplete: true)
        #expect(logged == open, "Hiding WHY must not move a logged set's chips at 390pt")

        let openAX3 = try rowHeight(setType: .working, width: 358, dynamicTypeSize: .accessibility3)
        let loggedAX3 = try rowHeight(setType: .working, width: 358, isComplete: true, dynamicTypeSize: .accessibility3)
        #expect(loggedAX3 < openAX3, "At AX3 a logged set must not keep a line for WHY")
    }
}
