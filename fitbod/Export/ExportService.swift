//
//  ExportService.swift
//  fitbod
//
//  Wave-4 plan 06-09b — `@ModelActor` off-main rendering service for
//  the EXP-01 (CSV) + EXP-02 (JSON) exports. Settings' share items
//  (`CSVExportItem` / `JSONExportItem`) call it when the share sheet
//  asks for a file, and hand the rendered `CSVFile` / `JSONFile`
//  bytes to the share sheet.
//
//  ## Why @ModelActor (RESEARCH §Pitfall 13)
//
//  `ShareLink`'s `DataRepresentation` runs its byte-producer closure
//  on the caller's thread. If we built the bytes from inside the
//  closure, a large export would block the main thread while the
//  share sheet animated in. ExportService renders the bytes off main;
//  the share item's async closure only awaits it.
//
//  ## snapshotDocument
//
//  `ExportSnapshot.document` builds the document, the same one the
//  backup archive writes. Image bytes are not in the JSON export; the
//  backup carries them as `images/<uuid>.jpg`.
//
//  [CITED: CONTEXT D-27/D-29 + RESEARCH §Pattern 4 + Pitfall 13]
//

import Foundation
import OSLog
import SwiftData

@ModelActor
public actor ExportService {

    private static let log = Logger(subsystem: "com.fitbod.app", category: "export")

    // MARK: - Public render entry points

    /// Render the full SetEntry history into a CSV `Transferable`
    /// wrapping pre-rendered bytes. Filename is dated to the current
    /// day in ISO format.
    public func renderCSV() async throws -> CSVFile {
        let sets = try fetchAllCompletedSets()
        let settings = try fetchUserSettings()
        let data = CSVExporter.render(setEntries: sets, userSettings: settings)
        let filename = Self.dailyFilename(prefix: "fitbod-export", ext: "csv")
        return CSVFile(data: data, filename: filename)
    }

    /// The sets finished from `start` to `end`, the block review's EXPORT,
    /// in the same CSV as `renderCSV()`, named for a block.
    public func renderCSV(from start: Date, to end: Date) async throws -> CSVFile {
        let sets = try modelContext.fetch(FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.isComplete && $0.completedAt >= start && $0.completedAt <= end },
            sortBy: [SortDescriptor(\SetEntry.completedAt)]
        ))
        let data = CSVExporter.render(setEntries: sets, userSettings: try fetchUserSettings())
        return CSVFile(data: data, filename: Self.dailyFilename(prefix: "fitbod-block", ext: "csv"))
    }

    /// Render the full schema snapshot into a JSON `Transferable`
    /// wrapping pre-rendered bytes via 06-09's `JSONEncoder.exportConfigured()`.
    public func renderJSON() async throws -> JSONFile {
        let doc = try await snapshotDocument()
        let data = try JSONExporter.render(document: doc)
        let filename = Self.dailyFilename(prefix: "fitbod-export", ext: "json")
        return JSONFile(data: data, filename: filename)
    }

    /// Build an `ExportDocument` from the current SwiftData store, the
    /// same snapshot the backup archive writes.
    public func snapshotDocument() async throws -> ExportDocument {
        try ExportSnapshot.document(in: modelContext, exportedAt: .now)
    }

    // MARK: - Filename helper

    static func dailyFilename(prefix: String, ext: String, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        return "\(prefix)-\(date).\(ext)"
    }

    // MARK: - Per-entity fetch helpers

    private func fetchAllCompletedSets() throws -> [SetEntry] {
        try modelContext.fetch(FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.isComplete },
            sortBy: [SortDescriptor(\SetEntry.completedAt)]
        ))
    }

    private func fetchUserSettings() throws -> UserSettings? {
        try modelContext.fetch(FetchDescriptor<UserSettings>()).first
    }
}
