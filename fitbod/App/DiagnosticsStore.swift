//
//  DiagnosticsStore.swift
//  fitbod
//
//  Keeps the reports MetricKit delivers, so Settings can share them (RM-063).
//  iOS sends a metrics report about once a day (why the app exited, peak
//  memory, launch and hang times) and a diagnostics report with the stacks
//  of a crash or hang. Each report becomes one JSON file in
//  `Application Support/Diagnostics/`, and only the newest 30 stay.
//  Nothing leaves the phone unless the lifter shares the files.
//

import Foundation
import MetricKit
import os

final class DiagnosticsStore: NSObject, MXMetricManagerSubscriber, Sendable {
    /// MetricKit delivers only while a subscriber is registered, so the app keeps this one.
    static let shared = DiagnosticsStore()
    static let folder = URL.applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
    static let kept = 30
    private static let log = Logger(subsystem: "com.fitbod.app", category: "diagnostics")

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads { Self.save(payload.jsonRepresentation(), kind: "metrics", in: Self.folder) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads { Self.save(payload.jsonRepresentation(), kind: "diagnostics", in: Self.folder) }
    }

    /// Writes one report, then deletes all but the newest `kept`.
    /// A name starts with the UTC time it was saved, so name order is age order;
    /// the random tail keeps two reports saved in the same millisecond apart.
    static func save(_ json: Data, kind: String, in folder: URL, at date: Date = .now) {
        let stamp = date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true).timeSeparator(.omitted))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try json.write(to: folder.appending(path: "\(stamp)-\(kind)-\(UUID().uuidString.prefix(8)).json"), options: .atomic)
        } catch {
            log.error("Could not save a \(kind, privacy: .public) report: \(error.localizedDescription, privacy: .public)")
            return
        }
        // A file left behind here goes on the next save.
        for old in reports(in: folder).dropFirst(kept) { try? FileManager.default.removeItem(at: old) }
    }

    /// The saved reports, newest first.
    static func reports(in folder: URL = folder) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
