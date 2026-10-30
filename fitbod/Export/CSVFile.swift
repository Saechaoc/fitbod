//
//  CSVFile.swift
//  fitbod
//
//  Wave-4 plan 06-09b — `Transferable` value type wrapping pre-rendered
//  CSV bytes. `ExportService.renderCSV()` returns it, and Settings'
//  `CSVExportItem` hands its bytes to the system share sheet (Files /
//  iCloud Drive / AirDrop).
//
//  ## Why a value type
//
//  RESEARCH §"Pitfall 13" — `ShareLink`'s `DataRepresentation` runs
//  the byte-producer closure on the caller thread. Pre-rendering the
//  bytes via `@ModelActor ExportService` (off main) and wrapping in
//  this Sendable value type keeps the main thread responsive during
//  the share-sheet present.
//
//  ## Filename
//
//  `fitbod-export-YYYY-MM-DD.csv` — locked at construction time by
//  `ExportService.renderCSV()`.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

public struct CSVFile: Transferable, Sendable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            file.data
        }
        .suggestedFileName { file in
            file.filename
        }
    }
}
