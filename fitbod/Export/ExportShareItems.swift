//
//  ExportShareItems.swift
//  fitbod
//
//  Milestone 1 review item 34 — what Settings hands to `ShareLink` for
//  Export CSV, Export JSON and backup CREATE. Each item renders its file
//  only when the share sheet asks for it, so one tap opens the sheet.
//  Before, the first tap rendered the file and a second tap shared it.
//
//  Rendering still runs on the off-main actors (`ExportService`,
//  `BackupArchiver`). Each item reports whether rendering worked, so
//  Settings keeps showing its inline error when it fails.
//

import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Called on the main actor after each render: true when it worked.
public typealias ExportRenderReport = @MainActor @Sendable (_ succeeded: Bool) -> Void

/// One row per completed set (EXP-01), rendered when shared.
public struct CSVExportItem: Transferable, Sendable {
    public let container: ModelContainer
    public let report: ExportRenderReport

    public init(container: ModelContainer, report: @escaping ExportRenderReport) {
        self.container = container
        self.report = report
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in
            try await ShareItemRendering.run(report: item.report) {
                try await ExportService(modelContainer: item.container).renderCSV().data
            }
        }
        .suggestedFileName { _ in ExportService.dailyFilename(prefix: "fitbod-export", ext: "csv") }
    }
}

/// The full version-stamped JSON snapshot (EXP-02), rendered when shared.
public struct JSONExportItem: Transferable, Sendable {
    public let container: ModelContainer
    public let report: ExportRenderReport

    public init(container: ModelContainer, report: @escaping ExportRenderReport) {
        self.container = container
        self.report = report
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { item in
            try await ShareItemRendering.run(report: item.report) {
                try await ExportService(modelContainer: item.container).renderJSON().data
            }
        }
        .suggestedFileName { _ in ExportService.dailyFilename(prefix: "fitbod-export", ext: "json") }
    }
}

/// A `.fitbodbackup` archive, written when shared.
public struct BackupShareItem: Transferable, Sendable {
    public let container: ModelContainer
    public let report: ExportRenderReport

    public init(container: ModelContainer, report: @escaping ExportRenderReport) {
        self.container = container
        self.report = report
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .fitbodBackup) { item in
            try await ShareItemRendering.run(report: item.report) {
                SentTransferredFile(try await BackupArchiver(modelContainer: item.container).archive().url)
            }
        }
        .suggestedFileName { _ in BackupArchiver.dailyFilename(now: .now) }
    }
}

enum ShareItemRendering {
    /// Runs `render` and reports the outcome. A failure is rethrown so the
    /// share sheet stops.
    static func run<Output: Sendable>(
        report: ExportRenderReport,
        _ render: () async throws -> Output
    ) async throws -> Output {
        do {
            let output = try await render()
            await report(true)
            return output
        } catch {
            await report(false)
            throw error
        }
    }
}
