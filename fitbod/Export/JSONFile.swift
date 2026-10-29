//
//  JSONFile.swift
//  fitbod
//
//  Wave-4 plan 06-09b — `Transferable` value type wrapping pre-rendered
//  JSON bytes. `ExportService.renderJSON()` returns it, and Settings'
//  `JSONExportItem` hands its bytes to the system share sheet.
//
//  Symmetric to `CSVFile.swift`. Filename format:
//  `fitbod-export-YYYY-MM-DD.json` locked at construction time by
//  `ExportService.renderJSON()`.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

public struct JSONFile: Transferable, Sendable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            file.data
        }
        .suggestedFileName { file in
            file.filename
        }
    }
}
