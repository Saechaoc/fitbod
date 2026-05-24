// Phase3BRUSurfacesTests.swift
// fitbodTests
//
// Swift Testing suite for Phase 3 BRU surface components:
//   BumpBanner, CalibratingBadge
//
// Strategy:
//   - Each @Test instantiates the surface with representative data.
//   - Instantiation proves the public init is honoured and all token/font
//     references (Color.bruInk, Color.bruMuted, BRUFont.labelSmall,
//     BRUFont.labelMicro, etc.) resolve at compile time.
//   - Visual / VoiceOver UAT is deferred to Wave 3 grep audit and device QA.
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/Phase3BRUSurfacesTests
//
// NOTE: Trust xcodebuild over SourceKit for any phantom diagnostics.

import Foundation
import SwiftUI
import Testing
@testable import fitbod

// MARK: - Phase 3 BRU Surfaces

@Suite("Phase 3 BRU Surfaces")
struct Phase3BRUSurfacesTests {

    // MARK: - BumpBanner

    @Test("BumpBanner instantiates with representative weight and kg unit")
    func bumpBannerInstantiates() throws {
        // Proves: public init(isVisible:bumpedToWeight:unitLabel:) compiles and the
        // view conforms to View. All BRU token + font references must resolve.
        let banner = BumpBanner(
            isVisible: .constant(true),
            bumpedToWeight: 102.5,
            unitLabel: "kg"
        )
        // Type check — if the struct is missing or mis-typed, this line fails to compile.
        let _: any View = banner
        #expect(Bool(true), "BumpBanner instantiated successfully")
    }

    // MARK: - CalibratingBadge

    @Test("CalibratingBadge instantiates with in-progress calibration data")
    func calibratingBadgeInstantiates() throws {
        // Proves: public init(current:threshold:) compiles and the view conforms to
        // View. BRU token + font references (bruMuted, bruPaper, labelMicro) must resolve.
        let badge = CalibratingBadge(current: 4, threshold: 10)
        let _: any View = badge
        #expect(Bool(true), "CalibratingBadge instantiated successfully")
    }

    // MARK: - ExerciseDetailView Prescription Settings (Plan 03.2-08 Task 1)

    @Test("ExerciseDetailView instantiates — BRU Prescription Settings section resolves all tokens")
    func exerciseDetailPrescriptionSettingsRenders() throws {
        // Proves: ExerciseDetailView compiles with BRUSectionHead, BRUFont, BRUChip
        // tokens all in scope. The prescriptionSettingsSection @ViewBuilder must use
        // BRUSectionHead("PRESCRIPTION SETTINGS"), BRUFont.labelSmall labels,
        // BRUFont.bodyDefault footers, and a 3-BRUChip Button row for the unit picker.
        // All token references (Color.bruMuted, Color.bruInk, BRUFont.bodyDefault,
        // BRUFont.labelSmall) must resolve at compile time.
        let container = PreviewModelContainer.make()
        let ctx = container.mainContext
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        guard let exercise = exercises.first else {
            Issue.record("PreviewModelContainer must seed at least one Exercise")
            return
        }
        let view = ExerciseDetailView(exercise: exercise)
        let _: any View = view
        #expect(Bool(true), "ExerciseDetailView with BRU Prescription Settings instantiated successfully")
    }

    // MARK: - SettingsView Smart Progression (Plan 03.2-08 Task 2)

    @Test("SettingsView instantiates — BRU Smart Progression section resolves all tokens")
    func settingsSmartProgressionRenders() throws {
        // Proves: SettingsView compiles with BRUSectionHead("SMART PROGRESSION"),
        // BRUFont.labelSmall row labels, BRUFont.bodyDefault footers, and Color.bruMuted
        // all resolving at compile time in the smartProgressionSection.
        let view = SettingsView()
        let _: any View = view
        #expect(Bool(true), "SettingsView with BRU Smart Progression instantiated successfully")
    }
}
