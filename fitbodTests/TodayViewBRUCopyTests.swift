// Legacy checks for retained Today primitives. State and route behavior
// is covered by TodayStateTests and TodayStateRoutesUITests.

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

    // MARK: - 3. Black slab copy

    @Test("Black slab labels are verbatim")
    func blackSlabLabelsVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/BlackSlabCTA.swift")
        #expect(slabSource.contains("\"TODAY\""))
        #expect(slabSource.contains("\"NEXT UP · "))
        #expect(slabSource.contains("\"Deload week · lighter sets\""))
        // The day counter and the bare NEXT left with redesign step 1.2.
        #expect(!slabSource.contains("DAY %02d / %02d"))
        #expect(!slabSource.contains("Text(\"NEXT\")"))
    }

    @Test("Black slab CTA label is verbatim 'Start workout ▸'")
    func blackSlabCTAVerbatim() throws {
        let slabSource = try sourceFile("fitbod/Views/BlackSlabCTA.swift")
        #expect(slabSource.contains("Start workout ▸"))
    }

    // MARK: - 4. Lift list section head

    @Test("Exercises head copy is verbatim")
    func exercisesHeadCopyVerbatim() throws {
        let sectionSource = try sourceFile("fitbod/Views/LiftListSection.swift")
        #expect(sectionSource.contains("\"Exercises · "))
        #expect(sectionSource.contains("\"View ›\""))
        // "Tap to reorder" was a false affordance (nothing reorders); the head shows a count.
        #expect(!sectionSource.contains("\"Tap to reorder\""))
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

    @Test("TodayView emptySplit fix-it uses SplitDetailRoute on Today's own stack")
    func emptySplitFixItNavigationPattern() throws {
        let source = try todayViewSource()
        #expect(source.contains("navigationPath.append(SplitDetailRoute.detail(splitID:"))
        #expect(source.contains(".blockDestinations"))
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
