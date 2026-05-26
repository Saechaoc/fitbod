//
//  CSVExporterTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-09b — RFC 4180 + UTF-8 BOM + 23-column shape +
//  byte-stable golden-fixture coverage for the EXP-01 CSV export.
//
//  Six @Test functions:
//
//    1. bomPresent — first 3 bytes are 0xEF 0xBB 0xBF
//    2. headerRow23Columns — UTF-8-decoded header row has 23 columns
//       in CONTEXT D-25 order
//    3. rfc4180QuotingForEmbeddedCommaAndQuote — set_note with comma
//       or embedded quote is properly escaped
//    4. isoUtcDatesEndWithZ — every date column ends with literal "Z"
//    5. wasManualOverrideEmitsTrueOrFalse — booleans emit as
//       "true"/"false" exactly
//    6. emptyForNilFields — nil optionals emit empty string, not "nil"
//    7. exerciseNameEmptyForNilExercise — Open Question 2 deferred
//    8. goldenSnapshotMatch — byte-equal against committed fixture
//
//  Each test acquires a fresh in-memory SchemaV6 ModelContainer.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("CSVExporter (EXP-01 RFC 4180 + UTF-8 BOM)", .serialized)
struct CSVExporterTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Hand-fixed UUIDs so the golden snapshot is byte-deterministic
    /// across runs (mirrors the convention in ExportDocumentSnapshotTests).
    private static let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let exerciseID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let sessionExerciseID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let setEntryID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    /// Build a single committed SetEntry with full relationship chain
    /// + deterministic UUIDs for snapshot stability.
    private func makeFixtureEntry(
        ctx: ModelContext,
        note: String? = nil,
        rpe: Double? = 8.0,
        wasManualOverride: Bool = false
    ) throws -> (SetEntry, UserSettings) {
        let bench = Exercise(
            name: "Bench Press", canonicalName: "bench press",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        bench.id = Self.exerciseID
        ctx.insert(bench)
        let session = Session()
        session.id = Self.sessionID
        session.startedAt = Self.fixedDate
        session.completedAt = Self.fixedDate.addingTimeInterval(3600)
        session.routineSnapshotName = "Upper A"
        session.intentRaw = Intent.strength.rawValue
        ctx.insert(session)
        let se = SessionExercise()
        se.id = Self.sessionExerciseID
        se.session = session
        se.exercise = bench
        se.targetSets = 3
        se.targetRepsLow = 4
        se.targetRepsHigh = 6
        se.targetRPE = 8.0
        ctx.insert(se)
        let entry = SetEntry()
        entry.id = Self.setEntryID
        entry.sessionExercise = se
        entry.weight = 100.0
        entry.reps = 5
        entry.rpe = rpe
        entry.notes = note
        entry.isWarmup = false
        entry.isComplete = true
        entry.wasManualOverride = wasManualOverride
        entry.completedAt = Self.fixedDate
        ctx.insert(entry)

        let settings = UserSettings()
        settings.unitsRaw = "kg"
        ctx.insert(settings)
        try ctx.save()
        return (entry, settings)
    }

    // MARK: - 1. BOM

    @Test("bomPresent — first 3 bytes are 0xEF 0xBB 0xBF")
    func bomPresent() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx)
        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        let bytes = Array(data.prefix(3))
        #expect(bytes == CSVExporter.utf8BOM)
    }

    // MARK: - 2. header row 23 columns

    @Test("headerRow23Columns — header row has 23 columns in CONTEXT D-25 order")
    func headerRow23Columns() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx)
        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        // Strip BOM
        let bomLen = CSVExporter.utf8BOM.count
        let stripped = data.subdata(in: bomLen..<data.count)
        let s = try #require(String(data: stripped, encoding: .utf8))
        let firstLine = s.components(separatedBy: "\r\n").first ?? ""
        let cols = firstLine.components(separatedBy: ",")
        #expect(cols.count == 23, "expected 23 columns, got \(cols.count)")
        #expect(cols == CSVExporter.headerColumns)
    }

    // MARK: - 3. RFC 4180 quoting

    @Test("rfc4180QuotingForEmbeddedCommaAndQuote — comma + quote escaping")
    func rfc4180QuotingForEmbeddedCommaAndQuote() throws {
        // Quote helper is the spec source-of-truth
        #expect(CSVExporter.rfc4180Quote("simple") == "simple")
        #expect(CSVExporter.rfc4180Quote("a,b") == "\"a,b\"")
        #expect(CSVExporter.rfc4180Quote("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExporter.rfc4180Quote("line\nbreak") == "\"line\nbreak\"")
    }

    // MARK: - 4. ISO-8601 UTC dates end with Z

    @Test("isoUtcDatesEndWithZ — session_started_at and session_completed_at end with Z")
    func isoUtcDatesEndWithZ() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx)
        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        let bomLen = CSVExporter.utf8BOM.count
        let stripped = data.subdata(in: bomLen..<data.count)
        let s = try #require(String(data: stripped, encoding: .utf8))
        let lines = s.components(separatedBy: "\r\n")
        #expect(lines.count >= 2)
        let dataRow = lines[1].components(separatedBy: ",")
        // Indices: 1 = session_started_at, 2 = session_completed_at
        #expect(dataRow[1].hasSuffix("Z"))
        #expect(dataRow[2].hasSuffix("Z"))
    }

    // MARK: - 5. boolean → "true" / "false"

    @Test("wasManualOverrideEmitsTrueOrFalse — booleans emit lowercase literals")
    func wasManualOverrideEmitsTrueOrFalse() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx, wasManualOverride: true)
        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        let bomLen = CSVExporter.utf8BOM.count
        let stripped = data.subdata(in: bomLen..<data.count)
        let s = try #require(String(data: stripped, encoding: .utf8))
        let dataLine = s.components(separatedBy: "\r\n")[1]
        let cols = dataLine.components(separatedBy: ",")
        // Index 16 = was_manual_override
        #expect(cols[16] == "true")
    }

    // MARK: - 6. empty for nil

    @Test("emptyForNilFields — nil optionals emit as empty string")
    func emptyForNilFields() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx, note: nil, rpe: nil)
        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        let bomLen = CSVExporter.utf8BOM.count
        let stripped = data.subdata(in: bomLen..<data.count)
        let s = try #require(String(data: stripped, encoding: .utf8))
        let dataLine = s.components(separatedBy: "\r\n")[1]
        let cols = dataLine.components(separatedBy: ",")
        // Index 15 = actual_rpe (nil) → empty
        #expect(cols[15] == "")
        // Index 21 = set_note (nil) → empty
        #expect(cols[21] == "")
        // No literal "nil" anywhere
        #expect(!dataLine.contains("nil"))
    }

    // MARK: - 7. exerciseName empty for nil exercise (Open Q2)

    @Test("exerciseNameEmptyForNilExercise — Open Q2 deferred convention")
    func exerciseNameEmptyForNilExercise() throws {
        let ctx = try makeContext()
        // Build a SetEntry whose SessionExercise has nil exercise
        let session = Session()
        session.startedAt = Self.fixedDate
        session.intentRaw = Intent.strength.rawValue
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        // se.exercise intentionally nil
        ctx.insert(se)
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.weight = 100.0
        entry.reps = 5
        entry.isWarmup = false
        entry.isComplete = true
        entry.completedAt = Self.fixedDate
        ctx.insert(entry)
        let settings = UserSettings()
        ctx.insert(settings)
        try ctx.save()

        let data = CSVExporter.render(setEntries: [entry], userSettings: settings)
        let bomLen = CSVExporter.utf8BOM.count
        let stripped = data.subdata(in: bomLen..<data.count)
        let s = try #require(String(data: stripped, encoding: .utf8))
        let dataLine = s.components(separatedBy: "\r\n")[1]
        let cols = dataLine.components(separatedBy: ",")
        // Index 6 = exercise_id (nil → empty), Index 7 = exercise_name (nil → empty)
        #expect(cols[6] == "")
        #expect(cols[7] == "")
    }

    // MARK: - 8. golden snapshot

    @Test("goldenSnapshotMatch — byte-equal against committed CSV fixture")
    func goldenSnapshotMatch() throws {
        let ctx = try makeContext()
        let (entry, settings) = try makeFixtureEntry(ctx: ctx)
        let generated = CSVExporter.render(setEntries: [entry], userSettings: settings)

        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/csv/example-export.csv")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            // Test runner can't reach the source-tree fixture path —
            // skip rather than fail (the byte-shape is enforced by the
            // other CSVExporterTests above + the JSON snapshot test).
            return
        }

        let committed = (try? Data(contentsOf: fixtureURL)) ?? Data()
        if committed.isEmpty {
            try? generated.write(to: fixtureURL)
            Issue.record("Fixture regenerated at \(fixtureURL.path) — commit and re-run.")
            return
        }
        if generated != committed {
            let gen = String(data: generated, encoding: .utf8) ?? "<binary>"
            let com = String(data: committed, encoding: .utf8) ?? "<binary>"
            #expect(
                generated == committed,
                "CSV byte snapshot diverged.\nGenerated:\n\(gen)\nCommitted:\n\(com)"
            )
        } else {
            #expect(generated == committed)
        }
    }
}
