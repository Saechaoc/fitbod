//
//  JSONExporterTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-09b — confirms `JSONExporter.render(document:)` is a
//  byte-identical pass-through of 06-09's
//  `JSONEncoder.exportConfigured()`. The byte-stability snapshot lives
//  in `ExportDocumentSnapshotTests` (06-09) — this suite only verifies
//  the one-line glue.
//

import Foundation
import Testing
@testable import fitbod

@Suite("JSONExporter (EXP-02 byte-stable glue)")
struct JSONExporterTests {

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func minimalFixture() -> ExportDocument {
        ExportDocument(
            formatVersion: 1,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: fixedDate,
            unitSystem: "kg",
            exercises: [],
            routines: [],
            routineFolders: [],
            supersetGroups: [],
            sessions: [],
            blocks: [],
            muscleGroups: [],
            exerciseMuscleStimuli: [],
            muscleVolumeTargets: [],
            plateInventories: [],
            userSettings: nil
        )
    }

    @Test("oneLineGlueOverEncoder — JSONExporter.render matches direct encoder output")
    func oneLineGlueOverEncoder() throws {
        let doc = Self.minimalFixture()
        let viaExporter = try JSONExporter.render(document: doc)
        let viaEncoder = try JSONEncoder.exportConfigured().encode(doc)
        #expect(viaExporter == viaEncoder)
    }

    @Test("prettyPrintedAndSortedKeys — output contains sorted top-level keys + ISO-8601 Z")
    func prettyPrintedAndSortedKeys() throws {
        let doc = Self.minimalFixture()
        let data = try JSONExporter.render(document: doc)
        let s = try #require(String(data: data, encoding: .utf8))

        // .sortedKeys: alphabetical envelope keys
        let posExercises = s.range(of: "\"exercises\"")?.lowerBound
        let posExportedAt = s.range(of: "\"exportedAt\"")?.lowerBound
        let posFormatVersion = s.range(of: "\"formatVersion\"")?.lowerBound
        #expect(posExercises != nil)
        #expect(posExportedAt != nil)
        #expect(posFormatVersion != nil)
        if let a = posExercises, let b = posExportedAt, let c = posFormatVersion {
            #expect(a < b)
            #expect(b < c)
        }

        // ISO-8601 UTC trailing Z
        #expect(s.contains("\"exportedAt\""))
        #expect(s.contains("Z\""))
    }
}
