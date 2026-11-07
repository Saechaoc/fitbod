//
//  BlockExportTests.swift
//  fitbodTests
//
//  EXPORT on the block review shares the block's sets as CSV: the Settings
//  Export CSV columns, only the sets finished within the block's dates
//  (decided 2026-11-05).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct BlockExportTests {

    @Test("The block's CSV holds only the sets finished within its dates")
    func csvKeepsTheBlocksWindow() async throws {
        let container = try InMemoryContainer.makeCurrent()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(28 * 86_400)
        for (offset, reps) in [(-1.0, 1), (1.0, 2), (27.0, 3), (29.0, 4)] {
            let set = SetEntry()
            set.weight = 100
            set.reps = reps
            set.isComplete = true
            set.completedAt = start.addingTimeInterval(offset * 86_400)
            context.insert(set)
        }
        try context.save()

        let csv = try await ExportService(modelContainer: container).renderCSV(from: start, to: end)
        let rows = String(decoding: csv.data, as: UTF8.self)
            .components(separatedBy: "\r\n")
            .filter { !$0.isEmpty }
            .dropFirst()

        #expect(rows.count == 2, "Only the two sets inside the block, not \(rows.count)")
        #expect(csv.filename.hasPrefix("fitbod-block-"))
    }
}
