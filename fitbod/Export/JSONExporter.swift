//
//  JSONExporter.swift
//  fitbod
//
//  Wave-4 plan 06-09b — single-line glue over the canonical encoder
//  configuration that ships with the ExportDocument graph in
//  06-09's `ExportDTOs.swift`. Reuses `JSONEncoder.exportConfigured()`
//  so the JSON Export, the snapshot test, and the backup writer (06-10)
//  all produce byte-identical output.
//
//  EXP-02 contract. See CONTEXT D-28 for the envelope shape.
//

import Foundation

public enum JSONExporter {

    /// Encode an `ExportDocument` to a UTF-8 pretty-printed, sorted-keys
    /// JSON byte stream. The encoder configuration is owned by 06-09's
    /// `JSONEncoder.exportConfigured()` — this entry point is glue.
    public static func render(document: ExportDocument) throws -> Data {
        try JSONEncoder.exportConfigured().encode(document)
    }
}
