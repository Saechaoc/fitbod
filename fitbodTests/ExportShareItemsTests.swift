//
//  ExportShareItemsTests.swift
//  fitbodTests
//
//  Review item 34: Export CSV, Export JSON and backup CREATE hand ShareLink
//  an item that renders its file only when the share sheet asks for it.
//  Each render reports its outcome so Settings can show its inline error.
//

import CoreTransferable
import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import fitbod

@MainActor
@Suite("ExportShareItems")
struct ExportShareItemsTests {

    /// Collects the outcomes the items report on the main actor.
    @MainActor
    final class Reports {
        var outcomes: [Bool] = []
    }

    private struct RenderFailed: Error {}

    private let container: ModelContainer

    init() throws {
        container = try InMemoryContainer.makeCurrent()
    }

    @Test("CSV renders when exported, with the export's header row")
    func csvRendersWhenExported() async throws {
        let reports = Reports()
        let item = CSVExportItem(container: container) { reports.outcomes.append($0) }
        #expect(reports.outcomes.isEmpty, "Making the item must not render anything")

        let data = try await item.exported(as: .commaSeparatedText)
        let firstLine = String(decoding: data, as: UTF8.self).split(separator: "\n").first.map(String.init)
        #expect(firstLine?.contains(CSVExporter.headerColumns[0]) == true)
        #expect(reports.outcomes == [true])
    }

    @Test("JSON renders when exported, version-stamped")
    func jsonRendersWhenExported() async throws {
        let reports = Reports()
        let item = JSONExportItem(container: container) { reports.outcomes.append($0) }
        let data = try await item.exported(as: .json)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["formatVersion"] as? Int == 1)
        #expect(reports.outcomes == [true])
    }

    @Test("A backup is written when exported, as a ZIP archive")
    func backupWritesWhenExported() async throws {
        let reports = Reports()
        let item = BackupShareItem(container: container) { reports.outcomes.append($0) }
        let data = try await item.exported(as: .fitbodBackup)
        #expect(data.prefix(2) == Data("PK".utf8))
        #expect(reports.outcomes == [true])
    }

    @Test("A failed render is reported, then rethrown so the share sheet stops")
    func failedRenderIsReported() async {
        let reports = Reports()
        await #expect(throws: RenderFailed.self) {
            try await ShareItemRendering.run(report: { reports.outcomes.append($0) }) { () async throws -> Data in
                throw RenderFailed()
            }
        }
        #expect(reports.outcomes == [false])
    }
}
