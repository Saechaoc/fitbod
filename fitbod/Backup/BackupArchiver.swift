//
//  BackupArchiver.swift
//  fitbod
//
//  Wave-5 plan 06-10 Task 3 — `@ModelActor` off-main archiver that
//  composes the `.fitbodbackup` ZIP container. Reuses 06-09b's
//  ExportService.snapshotDocument logic (via a parallel
//  implementation since ExportService methods are isolated to its
//  own actor) plus 06-09's JSONExporter, and delegates the ZIP
//  container to ZIPWriter from Task 2.
//
//  ## Container format (CONTEXT D-30 — locked over AppleArchive)
//
//  PKWARE ZIP with extension `.fitbodbackup`. Layout:
//
//    fitbod-backup-2026-05-23.fitbodbackup
//    ├── manifest.json          (BackupManifest encoded)
//    ├── store.json             (full ExportDocument encoded)
//    └── images/
//        ├── {exerciseUUID-1}.jpg
//        └── ...
//
//  ## SHA-256 checksum (RESEARCH §Security Domain V10)
//
//  CryptoKit.SHA256.hash(data: storeJSON) — hex-encoded lowercase
//  into manifest.checksum. Restore-side recomputes and rejects on
//  mismatch.
//
//  ## STORE-only in v1
//
//  All entries written with compressionMethod=0 (STORE) via ZIPWriter.
//  CONTEXT D-30 does NOT require compression; ZIP-format conformance
//  is the load-bearing requirement (Finder / `unzip` readability).
//
//  [CITED: CONTEXT D-30 + D-31 + RESEARCH §Pattern 5 REVISED +
//   Open Question 1 RESOLVED]
//

import CryptoKit
import Foundation
import OSLog
import SwiftData

@ModelActor
public actor BackupArchiver {

    private static let log = Logger(subsystem: "com.fitbod.app", category: "backup")

    /// Build a `.fitbodbackup` ZIP archive from the current SwiftData
    /// store and write it to disk. Returns the written file. Restore's
    /// side file and the backup tests use it.
    ///
    /// - Parameters:
    ///   - outputURL: optional output URL; defaults to
    ///     documentDirectory/fitbod-backup-YYYY-MM-DD.fitbodbackup.
    ///   - now: the archive's timestamp. Tests fix it.
    public func archive(outputURL: URL? = nil, now: Date = .now) async throws -> FitbodBackupFile {
        let (zipBytes, imageCount) = try zipArchive(now: now)

        // 9. Resolve outputURL — caller override or
        //    documentDirectory/fitbod-backup-YYYY-MM-DD.fitbodbackup.
        let resolvedURL: URL
        if let outputURL {
            resolvedURL = outputURL
        } else {
            let dir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let filename = Self.dailyFilename(now: now)
            resolvedURL = dir.appendingPathComponent(filename)
        }

        // 10. Atomic write.
        try zipBytes.write(to: resolvedURL, options: .atomic)

        Self.log.info("BackupArchiver wrote \(zipBytes.count) bytes (manifest+store+\(imageCount) images) to \(resolvedURL.lastPathComponent, privacy: .public)")

        return FitbodBackupFile(url: resolvedURL, filename: resolvedURL.lastPathComponent)
    }

    /// The same archive's bytes, unwritten, for Settings' CREATE share
    /// item. Only the bytes leave the actor.
    ///
    /// - Parameter now: the archive's timestamp. Tests fix it.
    public func archiveData(now: Date = .now) throws -> Data {
        try zipArchive(now: now).bytes
    }

    /// Steps 1 to 8: the ZIP bytes and how many images they hold, every
    /// timestamp in them `now`.
    private func zipArchive(now: Date) throws -> (bytes: Data, imageCount: Int) {
        // 1. Build the full ExportDocument from current ModelContext.
        let doc = try ExportSnapshot.document(in: modelContext, exportedAt: now)

        // 2. Encode store.json via 06-09b's JSONExporter (shared encoder
        //    config; byte-identical to JSON export).
        let storeJSON = try JSONExporter.render(document: doc)

        // 3. Compute SHA-256 hex of store.json bytes.
        let digest = SHA256.hash(data: storeJSON)
        let checksum = digest.map { String(format: "%02x", $0) }.joined()

        // 4. Collect image entries from custom exercises.
        let exercises = try fetchExercisesForImages()
        let imageEntries: [ZIPWriter.Entry] = exercises.compactMap { ex in
            guard let imageData = ex.imageData else { return nil }
            return ZIPWriter.Entry(
                path: "images/\(ex.id.uuidString).jpg",
                data: imageData,
                lastModified: now
            )
        }

        // 5. Build manifest record.
        let manifest = BackupManifest(
            formatVersion: ExportDocument.currentFormatVersion,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            createdAt: now,
            checksum: checksum,
            imageCount: imageEntries.count
        )

        // 6. Encode manifest.json (ISO-8601 dates + sortedKeys).
        let manifestJSON = try manifest.encoded()

        // 7. Assemble ZIP entries: manifest first (so an inspector
        //    reading the archive top-down sees it first), then
        //    store.json, then images.
        var entries: [ZIPWriter.Entry] = [
            ZIPWriter.Entry(path: "manifest.json", data: manifestJSON, lastModified: now),
            ZIPWriter.Entry(path: "store.json", data: storeJSON, lastModified: now),
        ]
        entries.append(contentsOf: imageEntries)

        // 8. Write the ZIP container.
        return (try ZIPWriter.write(entries: entries), imageEntries.count)
    }

    // MARK: - Filename

    static func dailyFilename(now: Date) -> String {
        ExportService.dailyFilename(prefix: "fitbod-backup", ext: "fitbodbackup", now: now)
    }

    // MARK: - Images

    /// Custom exercises keep their photo in `imageData`; the archive
    /// writes each one as `images/<uuid>.jpg`.
    private func fetchExercisesForImages() throws -> [Exercise] {
        try modelContext.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.id)]))
    }
}
