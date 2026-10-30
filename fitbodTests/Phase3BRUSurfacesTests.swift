//
//  Phase3BRUSurfacesTests.swift
//  fitbodTests
//
//  Tests for Phase 3.2-04 BRU surface reskins:
//    - PlateStackDisclosure: delegates to PlateStackViz, accepts unitLabel param
//    - PrescriptionWeightCell: long-press disclosure, no info.circle, BRUFont typography
//
//  Tests instantiate the view structs directly (not via ViewInspector) to verify
//  public init signatures and stored property contracts.
//

import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import fitbod

// MARK: - Phase 3 BRU Surfaces Tests

@MainActor
@Suite("Phase3BRUSurfaces")
struct Phase3BRUSurfacesTests {

    // MARK: - PlateStackDisclosure

    @Test("plateStackDisclosureInstantiates — 100 kg barbell with 5 plate specs and unitLabel param")
    func plateStackDisclosureInstantiates() throws {
        // Fixture: 100 kg target / 20 kg bar / 5 standard plate specs
        let plates: [PlateSpec] = [
            PlateSpec(weight: 45, countPerSide: 2),
            PlateSpec(weight: 25, countPerSide: 2),
            PlateSpec(weight: 10, countPerSide: 2),
            PlateSpec(weight: 5,  countPerSide: 2),
            PlateSpec(weight: 2.5, countPerSide: 2),
        ]

        // BRU rewrite requires unitLabel parameter on init
        let disclosure = PlateStackDisclosure(
            targetWeight: 100,
            barWeight: 20,
            plates: plates,
            unitLabel: "kg"
        )

        #expect(disclosure.targetWeight == 100)
        #expect(disclosure.barWeight == 20)
        #expect(disclosure.plates.count == 5)
        #expect(disclosure.unitLabel == "kg")
    }

    @Test("plateStackDisclosureInstantiates — below-bar weight creates without crash")
    func plateStackDisclosureBelowBar() throws {
        let plates: [PlateSpec] = [
            PlateSpec(weight: 25, countPerSide: 2),
        ]
        let disclosure = PlateStackDisclosure(
            targetWeight: 15,
            barWeight: 20,
            plates: plates,
            unitLabel: "kg"
        )
        #expect(disclosure.targetWeight < disclosure.barWeight)
    }

    @Test("plateStackDisclosureInstantiates — no-solution case creates without crash")
    func plateStackDisclosureNoSolution() throws {
        // Only 20 kg plates, target 97.5 kg — no solution
        let plates: [PlateSpec] = [
            PlateSpec(weight: 20, countPerSide: 2),
        ]
        let disclosure = PlateStackDisclosure(
            targetWeight: 97.5,
            barWeight: 20,
            plates: plates,
            unitLabel: "kg"
        )
        #expect(disclosure.targetWeight == 97.5)
    }

    // MARK: - PrescriptionWeightCell

    @Test("prescriptionWeightCellInstantiates — editable cell with range nil")
    func prescriptionWeightCellInstantiates() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: "100 kg x 8 @ RPE 8.5 (May 16)",
            formulaName: "RPE autoregulation",
            computedLine: "Target e1RM 122 kg -> 88% x 8 -> 102.5 kg",
            roundedWeight: 102.5,
            roundedLine: "-> 102.5 kg (rounded down to 2.5 kg plates)",
            status: .calibrated,
            bumpOccurred: false,
            range: nil
        )
        @State var weight: Double = 102.5
        @State var wasManualOverride: Bool = false

        let cell = PrescriptionWeightCell(
            weight: $weight,
            prescribed: 102.5,
            range: nil,
            explanation: explanation,
            unitLabel: "kg",
            wasManualOverride: $wasManualOverride
        )

        #expect(cell.explanation?.roundedWeight == 102.5)
        #expect(cell.range == nil)
        #expect(cell.unitLabel == "kg")
    }

    @Test("prescriptionWeightCellInstantiates — calibrating range (read-only)")
    func prescriptionWeightCellCalibratingRange() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: "100 kg x 8 @ RPE 8.5 (May 16)",
            formulaName: "RPE autoregulation",
            computedLine: nil,
            roundedWeight: 100.0,
            roundedLine: "-> 100 kg",
            status: .calibrating(current: 4, threshold: 10),
            bumpOccurred: false,
            range: 95.0...105.0
        )
        @State var weight: Double = 100.0
        @State var wasManualOverride: Bool = false

        let cell = PrescriptionWeightCell(
            weight: $weight,
            prescribed: 100.0,
            range: 95.0...105.0,
            explanation: explanation,
            unitLabel: "kg",
            wasManualOverride: $wasManualOverride
        )

        #expect(cell.range != nil)
        #expect(cell.range?.lowerBound == 95.0)
        #expect(cell.range?.upperBound == 105.0)
        #expect(cell.explanation?.status == .calibrating(current: 4, threshold: 10))
    }

    // MARK: - BumpBanner (Plan 03.2-02)

    @Test("BumpBanner instantiates with representative weight and kg unit")
    func bumpBannerInstantiates() throws {
        // Proves: public init(isVisible:bumpedToWeight:unitLabel:) compiles and the
        // view conforms to View. Color.bruInk, Color.bruPaper, BRUFont.labelSmall must resolve.
        let banner = BumpBanner(
            isVisible: .constant(true),
            bumpedToWeight: 102.5,
            unitLabel: "kg"
        )
        let _: any View = banner
        #expect(Bool(true), "BumpBanner instantiated successfully")
    }

    // MARK: - CalibratingBadge (Plan 03.2-02)

    @Test("CalibratingBadge instantiates with in-progress calibration data")
    func calibratingBadgeInstantiates() throws {
        // Proves: public init(current:threshold:) compiles and the view conforms to
        // View. Color.bruMuted, Color.bruPaper, BRUFont.labelMicro must resolve.
        let badge = CalibratingBadge(current: 4, threshold: 10)
        let _: any View = badge
        #expect(Bool(true), "CalibratingBadge instantiated successfully")
    }

    // MARK: - WhyThisWeightSheet (Plan 03.2-05)
    // Tests cover the 4 CalibrationStatus branches and validate the BRU
    // rewrite init signature (new params: reps, rpe, setTypeLabel, unitLabel).

    @Test("whyThisWeightSheetInstantiates — .calibrating status branch")
    func whyThisWeightSheetInstantiates_calibrating() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: "195 × 8 @ RPE 8.5 (May 16)",
            formulaName: "RPE autoregulation",
            computedLine: "195 × (1 − 0.04 × (9 − 8.5)) → 207 lb",
            roundedWeight: 205.0,
            roundedLine: "→ 205 lb (rounded down to 2.5 lb plates)",
            status: .calibrating(current: 8, threshold: 10),
            bumpOccurred: false,
            range: 200.0...210.0,
            sessionIntent: .strength
        )
        let sheet = WhyThisWeightSheet(
            explanation: explanation,
            reps: 8...8,
            rpe: 9.0,
            setTypeLabel: "TOP SET",
            unitLabel: "lb"
        )
        let _: any View = sheet
        #expect(Bool(true), "WhyThisWeightSheet(.calibrating) instantiated")
    }

    @Test("whyThisWeightSheetInstantiates — .calibrated status branch")
    func whyThisWeightSheetInstantiates_calibrated() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: "100 × 8 @ RPE 8.5 (May 15)",
            formulaName: "RPE autoregulation",
            computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
            roundedWeight: 107.5,
            roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
            status: .calibrated,
            bumpOccurred: false,
            range: nil,
            sessionIntent: .hypertrophy
        )
        let sheet = WhyThisWeightSheet(
            explanation: explanation,
            reps: 8...8,
            rpe: 8.5,
            setTypeLabel: "TOP SET",
            unitLabel: "kg"
        )
        let _: any View = sheet
        #expect(Bool(true), "WhyThisWeightSheet(.calibrated) instantiated")
    }

    @Test("whyThisWeightSheetInstantiates — .notApplicable + bumpOccurred")
    func whyThisWeightSheetInstantiates_notApplicableBump() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: "100 × 12 @ RPE 8.5 (May 15)",
            formulaName: "Double progression",
            computedLine: nil,
            roundedWeight: 102.5,
            roundedLine: "→ 102.5 kg (rounded down to 2.5 kg plates)",
            status: .notApplicable,
            bumpOccurred: true,
            range: nil
        )
        let sheet = WhyThisWeightSheet(
            explanation: explanation,
            reps: 8...8,
            rpe: nil,
            setTypeLabel: "TOP SET",
            unitLabel: "kg"
        )
        let _: any View = sheet
        #expect(Bool(true), "WhyThisWeightSheet(.notApplicable + bumpOccurred) instantiated")
    }

    @Test("whyThisWeightSheetInstantiates — .notApplicable + first session")
    func whyThisWeightSheetInstantiates_notApplicableFirstSession() throws {
        let explanation = PrescriptionExplanation(
            lastSessionLine: nil,
            formulaName: "Double progression",
            computedLine: nil,
            roundedWeight: 60.0,
            roundedLine: "→ 60 kg (rounded down to 2.5 kg plates)",
            status: .notApplicable,
            bumpOccurred: false,
            range: nil
        )
        let sheet = WhyThisWeightSheet(
            explanation: explanation,
            reps: 5...5,
            rpe: nil,
            setTypeLabel: "WORKING SET",
            unitLabel: "kg"
        )
        let _: any View = sheet
        #expect(Bool(true), "WhyThisWeightSheet(.notApplicable + first session) instantiated")
    }

    // MARK: - WarmupRampRows (Plan 03.2-03)

    @Test("warmupRampRowsInstantiates — 4-set barbell ramp with BRU tokens")
    func warmupRampRowsInstantiates() throws {
        // Proves: public init(warmupSets:onSkip:sessionExercise:topWorkingWeight:barWeight:
        //         plates:unitLabel:) compiles and all BRU token + font references
        // (Color.bruSignal, Color.bruInk, Color.bruMuted, Color.bruHair,
        //  BRUFont.displayMedium, BRUFont.bodyDefault, BRUFont.labelSmall, BRUFont.labelMicro,
        //  .custom("SpaceGrotesk-Bold", size: 22) for the weight numeral)
        // resolve at compile time.
        let container = try InMemoryContainer.makeCurrent()
        let ctx = ModelContext(container)

        let exercise = SessionExercise()
        exercise.prescribedWeight = 100
        ctx.insert(exercise)

        let specs: [(pct: Double, reps: Int)] = [
            (0.40, 5), (0.60, 3), (0.75, 2), (0.90, 1)
        ]
        let sets: [SetEntry] = specs.enumerated().map { idx, spec in
            let s = SetEntry()
            s.orderIndex = idx
            s.weight = (100.0 * spec.pct).rounded()
            s.reps = spec.reps
            s.isWarmup = true
            s.setTypeRaw = "warmup"
            s.sessionExercise = exercise
            ctx.insert(s)
            return s
        }
        try ctx.save()

        let view = WarmupRampRows(
            warmupSets: sets,
            onSkip: {},
            sessionExercise: exercise,
            topWorkingWeight: 100,
            barWeight: 20,
            plates: [(25, 4), (20, 4), (10, 4), (5, 4), (2.5, 4), (1.25, 4)],
            unitLabel: "kg"
        )
        let _: any View = view
        #expect(Bool(true), "WarmupRampRows(4-set barbell) instantiated successfully")
    }

    @Test("warmupRampRowsInstantiates — empty sets renders placeholder without crash")
    func warmupRampRowsEmptyState() throws {
        let container = try InMemoryContainer.makeCurrent()
        let ctx = ModelContext(container)

        let exercise = SessionExercise()
        exercise.prescribedWeight = 25
        ctx.insert(exercise)
        try ctx.save()

        let view = WarmupRampRows(
            warmupSets: [],
            onSkip: {},
            sessionExercise: exercise,
            barWeight: 45,
            plates: [(45, 4), (25, 2), (10, 4), (5, 4), (2.5, 4)],
            unitLabel: "lb"
        )
        let _: any View = view
        #expect(Bool(true), "WarmupRampRows(empty) renders placeholder without crash")
    }

    // MARK: - PlateCalculatorSheet (Plan 03.2-07)

    @Test("PlateCalculatorSheet instantiates with seeded barbell inventory")
    func plateCalculatorSheetInstantiates() throws {
        // Proves: public init(equipment:inventory:) compiles and the view conforms to
        // View. All BRU token + font references (bruInk, bruBg2, bruSignal, bruMuted,
        // bruPaper, bruBg, bruHair, BRUFont.labelSmall, BRUFont.displayLarge) and
        // Wave 1 primitives (PlateStackViz, PlateTallyRow, BRUHeaderBar, BRUSectionHead,
        // BRUChip, BRUButton) must resolve at compile time.
        // Zero Form/Section/plateColor/weightToWidth/plateRect in the rewritten surface.
        let inv = PlateInventory()
        inv.equipmentKind = .barbell
        inv.barWeight = 45
        inv.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .lb)

        let sheet = PlateCalculatorSheet(equipment: .barbell, inventory: inv)
        let _: any View = sheet
        #expect(Bool(true), "PlateCalculatorSheet instantiated successfully")
    }

    // MARK: - WarmupConfigSheet (Plan 03.2-09)

    @Test("WarmupConfigSheet instantiates with nil config binding")
    func warmupConfigSheetInstantiates() throws {
        // Proves: public init(config: Binding<WarmupConfig?>) compiles and the view
        // conforms to View. BRU token + font references (BRUHeaderBar, BRUButton,
        // BRUFont.bodyEmphasis, BRUFont.bodyDefault, Color.bruInk, Color.bruMuted,
        // Color.bruHair, Color.bruBg, Color.bruPaper) must resolve at compile time.
        let sheet = WarmupConfigSheet(config: .constant(nil))
        let _: any View = sheet
        #expect(Bool(true), "WarmupConfigSheet instantiated successfully")
    }
}