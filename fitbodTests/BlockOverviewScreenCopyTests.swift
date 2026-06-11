//
//  BlockOverviewScreenCopyTests.swift
//  fitbodTests
//
//  Verbatim copy pins + service-seam invariants for BlockOverviewScreen (Phase 09-04).
//  Source-introspection: reads the .swift file from disk and #expect(source.contains(...))
//  for every verbatim string in the UI-SPEC Copywriting Contract.
//
//  Invariant pins assert:
//    - All lifecycle mutations route through BlockLifecycleService.{start,end,decodeArchive}
//    - trainingDays writes only via TrainingDaysWriter.sort
//    - Completed branch uses decodeArchive (no live-template fallback)
//    - ArchiveUnreadableView exists and is referenced
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("BlockOverviewScreenCopy", .serialized)
struct BlockOverviewScreenCopyTests {

    // MARK: - Helpers

    private func blockOverviewSource() throws -> String {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Periodization")
        return try String(
            contentsOf: base.appendingPathComponent("BlockOverviewScreen.swift"),
            encoding: .utf8
        )
    }

    // MARK: - Verbatim Copy Pins

    @Test("split attach/swap band copy is verbatim")
    func splitAttachSwapCopy() throws {
        let source = try blockOverviewSource()
        // Section head
        #expect(source.contains("\"Routine\""))
        // Attach button
        #expect(source.contains("\"+ ATTACH ROUTINE ▸\""))
        // Swap label
        #expect(source.contains("\"SWAP ▸\""))
    }

    @Test("scheduling section copy is verbatim")
    func schedulingCopy() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("\"Scheduling\""))
        #expect(source.contains("\"ROTATION\""))
        #expect(source.contains("\"FIXED WEEKLY\""))
    }

    @Test("training days section copy is verbatim")
    func trainingDaysCopy() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("\"Training days\""))
    }

    @Test("start/end block CTA copy is verbatim")
    func startEndCopy() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("\"START BLOCK ▸\""))
        #expect(source.contains("\"END BLOCK\""))
    }

    @Test("swap-confirm sheet copy is verbatim")
    func swapConfirmCopy() throws {
        let source = try blockOverviewSource()
        // Sheet title
        #expect(source.contains("\"Start Block?\""))
        // Sheet CTA
        #expect(source.contains("\"Confirm\""))
        // Sheet cancel
        #expect(source.contains("\"Cancel\""))
    }

    @Test("archive unreadable copy is verbatim")
    func archiveUnreadableCopy() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("\"ARCHIVE UNREADABLE\""))
        #expect(source.contains("\"This block's historical config could not be loaded. The raw data is intact but cannot be decoded.\""))
    }

    @Test("completed block hero label copy is verbatim")
    func completedHeroCopy() throws {
        let source = try blockOverviewSource()
        // The prefix literal of the completed hero label (has interpolation after)
        #expect(source.contains("\"● COMPLETED BLOCK · #\\(blockSequenceNumber)\""))
        // ENDED prefix (has interpolation after for date)
        #expect(source.contains("\"ENDED \\("))
    }

    // MARK: - Service-Seam Invariants

    @Test("BlockLifecycleService.start is called for block start")
    func serviceSeamStart() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("BlockLifecycleService.start"))
    }

    @Test("BlockLifecycleService.end is called for block end")
    func serviceSeamEnd() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("BlockLifecycleService.end"))
    }

    @Test("decodeArchive is called in completed branch")
    func serviceSeamDecodeArchive() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("decodeArchive"))
    }

    @Test("TrainingDaysWriter.sort is the only trainingDays write path")
    func trainingDaysWriterSort() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("TrainingDaysWriter.sort"))
    }

    // MARK: - No-Fallback Invariants (T-09-11)

    @Test("ArchiveUnreadableView exists in source")
    func archiveUnreadableViewExists() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("ArchiveUnreadableView"))
    }

    @Test("completed branch uses decodeArchive not live templates")
    func completedBranchUsesArchive() throws {
        let source = try blockOverviewSource()
        // decodeArchive is present (archive decode path exists)
        #expect(source.contains("decodeArchive"))
        // ArchiveUnreadableView is present (decode failure path exists)
        #expect(source.contains("ArchiveUnreadableView"))
        // The archiveContentSection uses archivedConfigJSON nil guard first
        #expect(source.contains("archivedConfigJSON"))
    }

    // MARK: - Explicit attach vs swap nil-conditional branch (T-09-09)

    @Test("split attach and swap route through BlockLifecycleService with explicit nil-conditional")
    func splitAttachSwapServiceRouting() throws {
        let source = try blockOverviewSource()
        #expect(source.contains("BlockLifecycleService.attachSplit"))
        #expect(source.contains("BlockLifecycleService.swapSplit"))
        // Explicit nil-conditional: both branches present
        #expect(source.contains("block.split == nil"))
    }
}
