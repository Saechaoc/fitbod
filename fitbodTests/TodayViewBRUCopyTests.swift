//
//  TodayViewBRUCopyTests.swift
//  fitbodTests
//
//  Verbatim BRU copy + structural assertions for the TodayView rewrite.
//  Phase 2.1 Plan 04 — Wave B audit items 10-17.
//
//  Strategy: source-file string search (same pattern as
//  TodayViewBlockStackingTests, RoutinesListCopyTests, etc.). SwiftUI
//  view trees are not amenable to unit-test introspection without a
//  running host — source pinning is the project standard for copy contracts.
//
//  Assertions cover:
//    1. Header copy — "Fitbod / Today"
//    2. Stat strip labels — "Day streak" / "Sessions" / week pattern
//    3. Black slab copy — "NEXT" / "DAY %02d / %02d" / "Start workout ▸"
//    4. Lift list section head — "Lift list" / "Tap to reorder"
//    5. Empty state — "No workout scheduled" / "Build a routine..." / "+ NEW ROUTINE"
//    6. Resume slab copy — "RESUME" / "Resume ▸" / "Discard"
//    7. BRU primitives presence — BRUHeaderBar / TodayStatStrip / BlockContextBand /
//       BlackSlabCTA / ResumeWorkoutSlab / LiftListSection
//    8. Phase 4/5 wiring preserved — DeloadWeekBanner / DeloadAdvisoryBanner /
//       FatigueSurfaceView / StartBlockCTA
//

import Foundation
import Testing
@testable import fitbod

@Suite("TodayViewBRUCopy")
struct TodayViewBRUCopyTests {

    // MARK: - 1. Header copy

    @Test("Header center copy is verbatim 'Fitbod / Today'")
    func headerCenterCopyVerbatim() throws {
        let source = try todayViewSource()
        #expect(source.contains("\"Fitbod / Today\""))
    }

    // MARK: - 2. Stat strip labels

    @Test("Stat strip labels are verbatim per UI-SPEC")
    func statStripLabelsVerbatim() throws {
        let stripSource = try sourceFile("fitbod/Views/TodayStatStrip.swift")
        #expect(stripSource.contains("\"Day streak\""))
        #expect(stripSource.contains("\"Sessions\""))
        // W{N} / {M} label computed from weekIndex + totalWeeks — verify format string
        #expect(stripSource.contains("W\\(weekIndex) / \\(totalWeeks)"))
    }

    @Test("Stat strip trend arrows are verbatim")
    func statStripTrendArrows() throws {
        let stripSource = try sourceFile("fitbod/Views/TodayStatStrip.swift")
        #expect(stripSource.contains("\"↑\""))
        #expect(stripSource.contains("\"↓\""))
        #expect(stripSource.contains("\"—\""))
    }

    // MARK: - 3. Black slab copy

    @Test("Black slab NEXT label is verbatim")
    func blackSlabNEXTVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/BlackSlabCTA.swift")
        #expect(slabSource.contains("\"NEXT\""))
    }

    @Test("Black slab DAY format string is verbatim")
    func blackSlabDAYFormatVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/BlackSlabCTA.swift")
        // DAY %02d / %02d pattern per UI-SPEC line 289
        #expect(slabSource.contains("DAY %02d / %02d"))
    }

    @Test("Black slab CTA label is verbatim 'Start workout ▸'")
    func blackSlabCTAVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/BlackSlabCTA.swift")
        #expect(slabSource.contains("Start workout ▸"))
    }

    // MARK: - 4. Lift list section head

    @Test("Lift list section head copy is verbatim")
    func liftListSectionHeadCopyVerbatim() throws {
        let sectionSource = try sourceFile("fitbod/Views/LiftListSection.swift")
        #expect(sectionSource.contains("\"Lift list\""))
        #expect(sectionSource.contains("\"Tap to reorder\""))
    }

    // MARK: - 5. Empty state copy

    @Test("Empty state copy is verbatim per UI-SPEC line 309-311")
    func emptyStateCopyVerbatim() throws {
        let source = try todayViewSource()
        #expect(source.contains("\"No workout scheduled\""))
        #expect(source.contains("\"Build a routine or pick one from your library.\""))
        #expect(source.contains("\"+ NEW ROUTINE\""))
    }

    // MARK: - 6. Resume slab copy

    @Test("Resume slab RESUME label is verbatim")
    func resumeSlabREVERBATIM() throws {
        let slabSource = try sourceFile("fitbod/Views/ResumeWorkoutSlab.swift")
        #expect(slabSource.contains("\"RESUME\""))
    }

    @Test("Resume slab Resume ▸ CTA is verbatim")
    func resumeSlabResumeCTAVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/ResumeWorkoutSlab.swift")
        #expect(slabSource.contains("Resume ▸"))
    }

    @Test("Resume slab Discard label is verbatim")
    func resumeSlabDiscardVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/ResumeWorkoutSlab.swift")
        #expect(slabSource.contains("\"Discard\""))
    }

    // MARK: - 7. BRU primitives presence in TodayView

    @Test("TodayView mounts BRUHeaderBar")
    func todayViewMountsBRUHeaderBar() throws {
        let source = try todayViewSource()
        #expect(source.contains("BRUHeaderBar"))
    }

    @Test("TodayView mounts TodayStatStrip")
    func todayViewMountsTodayStatStrip() throws {
        let source = try todayViewSource()
        #expect(source.contains("TodayStatStrip"))
    }

    @Test("TodayView mounts BlockContextBand")
    func todayViewMountsBlockContextBand() throws {
        let source = try todayViewSource()
        #expect(source.contains("BlockContextBand(block:"))
    }

    @Test("TodayView mounts BlackSlabCTA")
    func todayViewMountsBlackSlabCTA() throws {
        let source = try todayViewSource()
        #expect(source.contains("BlackSlabCTA"))
    }

    @Test("TodayView mounts ResumeWorkoutSlab")
    func todayViewMountsResumeWorkoutSlab() throws {
        let source = try todayViewSource()
        #expect(source.contains("ResumeWorkoutSlab"))
    }

    @Test("TodayView mounts LiftListSection")
    func todayViewMountsLiftListSection() throws {
        let source = try todayViewSource()
        #expect(source.contains("LiftListSection"))
    }

    // MARK: - 8. Phase 4/5 wiring preserved

    @Test("Phase 5 DeloadWeekBanner preserved in TodayView")
    func phase5DeloadWeekBannerPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("DeloadWeekBanner"))
        #expect(source.contains("phase.kind == .deload"))
    }

    @Test("Phase 5 DeloadAdvisoryBanner preserved in TodayView")
    func phase5DeloadAdvisoryBannerPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("DeloadAdvisoryBanner"))
        #expect(source.contains("currentAdvisory"))
    }

    @Test("Phase 5 FatigueSurfaceView preserved in TodayView")
    func phase5FatigueSurfaceViewPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("FatigueSurfaceView"))
        #expect(source.contains("isAdvisoryActive"))
    }

    @Test("Phase 4 StartBlockCTA preserved in TodayView")
    func phase4StartBlockCTAPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("StartBlockCTA"))
        #expect(source.contains("activeBlocks.isEmpty"))
    }

    @Test("Phase 4 navigationDestinations preserved in TodayView")
    func phase4NavigationDestinationsPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("navigationDestination(for: SessionRoute.self)"))
        #expect(source.contains("navigationDestination(for: MuscleSlugRoute.self)"))
    }

    @Test("Phase 5 weekly recap sheet preserved in TodayView")
    func phase5WeeklyRecapPreserved() throws {
        let source = try todayViewSource()
        #expect(source.contains("WeeklyRecapSheet"))
        #expect(source.contains("presentingWeeklyRecap"))
    }

    @Test("active session query uses completedAt == nil predicate")
    func activeSessionQueryPredicateIsCorrect() throws {
        let source = try todayViewSource()
        #expect(source.contains("$0.completedAt == nil"))
        #expect(source.contains("activeSessions"))
    }

    // MARK: - Helpers

    private func sourceFile(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func todayViewSource() throws -> String {
        try sourceFile("fitbod/Views/TodayView.swift")
    }
}
