//
//  FitbodBackupFile.swift
//  fitbod
//
//  Wave-5 plan 06-10 — `Transferable` value type wrapping an on-disk
//  `.fitbodbackup` archive URL. `BackupArchiver.archive(outputURL:)`
//  returns it, and Settings' `BackupShareItem` shares its file through
//  the system share sheet (Files / iCloud Drive / AirDrop).
//
//  ## Why FileRepresentation (not DataRepresentation)
//
//  Symmetric to CSVFile / JSONFile in 06-09b, but those wrap pre-
//  rendered Data; backups can be 10+ MB once images are included, so
//  holding the bytes in memory while ShareLink presents is wasteful.
//  The archiver writes to `documentDirectory/fitbod-backup-YYYY-MM-DD.fitbodbackup`
//  and ShareLink references the file by URL — system share sheet
//  takes ownership without re-reading the bytes through our process.
//
//  ## suggestedFileName
//
//  Locked at archive time by `BackupArchiver.archive(outputURL:)`.
//  Standard form: `fitbod-backup-2026-05-23.fitbodbackup`.
//
//  [CITED: CONTEXT D-30 + D-31 + RESEARCH §Pattern 5 REVISED +
//   Pitfall 13 (FileRepresentation over DataRepresentation for
//   large payloads)]
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

public struct FitbodBackupFile: Transferable, Sendable {
    public let url: URL
    public let filename: String

    public init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .fitbodBackup) { file in
            SentTransferredFile(file.url)
        }
        .suggestedFileName { file in
            file.filename
        }
    }
}
