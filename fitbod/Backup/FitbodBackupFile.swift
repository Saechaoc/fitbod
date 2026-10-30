//
//  FitbodBackupFile.swift
//  fitbod
//
//  Wave-5 plan 06-10 — `Transferable` value type wrapping an on-disk
//  `.fitbodbackup` archive URL. `BackupArchiver.archive(outputURL:)`
//  writes the archive and returns it, for restore's side file and the
//  backup tests.
//
//  ## Settings shares data, not this file
//
//  Backup CREATE in Settings shares `BackupShareItem`, which hands the
//  share sheet the same archive's bytes from
//  `BackupArchiver.archiveData(now:)`. Shared as this file, the archive
//  was built three times before the share sheet appeared, more than six
//  seconds after the tap (review item 34). The share sheet holds the
//  bytes in memory, which costs little: ZIPWriter builds the whole
//  archive in memory before it is written anyway.
//
//  ## suggestedFileName
//
//  Locked at archive time by `BackupArchiver.archive(outputURL:)`.
//  Standard form: `fitbod-backup-2026-05-23.fitbodbackup`.
//
//  [CITED: CONTEXT D-30 + D-31 + RESEARCH §Pattern 5 REVISED]
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
