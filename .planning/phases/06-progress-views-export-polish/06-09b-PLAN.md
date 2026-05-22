---
phase: 06
plan: 09b
type: execute
wave: 4
slug: export-service-and-settings
depends_on: ["06-09"]
files_modified:
  - fitbod/Export/CSVExporter.swift
  - fitbod/Export/JSONExporter.swift
  - fitbod/Export/CSVFile.swift
  - fitbod/Export/JSONFile.swift
  - fitbod/Export/ExportService.swift
  - fitbod/Settings/SettingsView.swift
  - fitbodTests/Phase6/CSVExporterTests.swift
  - fitbodTests/Phase6/JSONExporterTests.swift
  - fitbodTests/Phase6/Fixtures/csv/example-export.csv
autonomous: true
requirements: ["EXP-01", "EXP-02"]
must_haves:
  truths:
    - "CSV export emits one row per SetEntry with 23 columns in CONTEXT D-25 order; RFC 4180 quoting; UTF-8 BOM; ISO-8601 UTC; empty for nil (CONTEXT D-26)"
    - "JSONExporter.render(document:) uses JSONEncoder.exportConfigured() from 06-09 (.prettyPrinted + .sortedKeys + .iso8601 + UTC) — single configuration source-of-truth"
    - "CSVFile and JSONFile conform to Transferable via DataRepresentation; suggestedFileName uses 'fitbod-export-{ISO-date}.csv' / .json (CONTEXT D-27 + D-29)"
    - "Settings → Data section ships rows 'Export as CSV' and 'Export as JSON' wrapping ShareLink(item:) (CONTEXT D-27 + D-29)"
    - "Off-main rendering via @ModelActor ExportService to honor RESEARCH Pitfall 13 (ShareLink Transferable DataRepresentation runs on caller thread)"
    - "Empty string emitted when SessionExercise.exercise == nil per Open Question 2 deferred convention from 06-07 + 06-09"
    - "CSV byte-stability locked by golden-file snapshot test against `fitbodTests/Phase6/Fixtures/csv/example-export.csv`"
  artifacts:
    - path: "fitbod/Export/CSVExporter.swift"
      provides: "public enum CSVExporter { static func render(setEntries: [SetEntry], userSettings: UserSettings?) -> Data } — RFC 4180 + UTF-8 BOM + ISO-8601 UTC"
    - path: "fitbod/Export/JSONExporter.swift"
      provides: "public enum JSONExporter { static func render(document: ExportDocument) throws -> Data } — delegates to JSONEncoder.exportConfigured()"
    - path: "fitbod/Export/CSVFile.swift"
      provides: "public struct CSVFile: Transferable + DataRepresentation + suggestedFileName"
    - path: "fitbod/Export/JSONFile.swift"
      provides: "public struct JSONFile: Transferable + DataRepresentation + suggestedFileName"
    - path: "fitbod/Export/ExportService.swift"
      provides: "@ModelActor public actor ExportService { func renderCSV() async throws -> CSVFile; func renderJSON() async throws -> JSONFile; func snapshotDocument() async throws -> ExportDocument }"
    - path: "fitbod/Settings/SettingsView.swift"
      provides: "Adds a new 'Data' section with Export as CSV / Export as JSON rows wrapping ShareLink; off-main render via async Task"
  key_links:
    - from: "fitbod/Export/CSVFile.swift, JSONFile.swift"
      to: "fitbod/Settings/SettingsView.swift"
      via: "ShareLink(item: csvFile, preview: SharePreview(filename))"
      pattern: "ShareLink\\(item:"
    - from: "fitbod/Export/JSONExporter.swift"
      to: "fitbod/Export/ExportDTOs.swift (06-09)"
      via: "Reuses JSONEncoder.exportConfigured() — no duplicate encoder configuration"
      pattern: "JSONEncoder\\.exportConfigured"
---

<objective>
Ship CSV (EXP-01) and JSON (EXP-02) exports as `Transferable` value types consumed by `ShareLink` in the new Settings → Data section. Builds directly on the DTO graph + encoder configuration locked in 06-09; this plan is the user-facing rendering + Settings wiring half.

Purpose: Both exports must produce **byte-stable** output for unit testing (golden-file snapshots). 06-09 locked the DTO + JSON encoder source-of-truth; 06-09b adds the user-facing rendering, off-main ExportService, and Settings rows. The Wave 4 backup (06-10) ships in parallel — it consumes the same DTOs from 06-09 directly.

Output: 4 new export source files (CSVExporter, JSONExporter, CSVFile, JSONFile) + 1 actor (ExportService) + 1 modified SettingsView + 2 test suites (CSV + JSON) + 1 golden CSV fixture.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/06-progress-views-export-polish/06-CONTEXT.md
@.planning/phases/06-progress-views-export-polish/06-RESEARCH.md
@.planning/phases/06-progress-views-export-polish/06-PATTERNS.md
@.planning/phases/06-progress-views-export-polish/06-UI-SPEC.md
@fitbod/Export/ExportDTOs.swift
@fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift
@fitbod/Settings/SettingsView.swift
@fitbod/Models/SetEntry.swift
@fitbod/Models/Session.swift
@fitbod/Models/SessionExercise.swift
@fitbod/Models/UserSettings.swift
@fitbod/Routines/PrescriptionDefaults.swift

<interfaces>
**CSV column order (CONTEXT D-25 — verbatim 23 columns):**
```
session_id, session_started_at, session_completed_at, session_intent, routine_id, routine_name,
exercise_id, exercise_name, set_index, set_kind, target_weight, target_reps, target_rpe,
actual_weight, actual_reps, actual_rpe, was_manual_override, partial_reps, tempo,
rest_taken_sec, e1rm, set_note, unit
```

**Critical schema mapping (RESEARCH §"Schema reality vs CONTEXT"):**
| CSV column | Real source field |
|---|---|
| session_id | SessionExercise.session?.id?.uuidString |
| session_started_at | SessionExercise.session?.startedAt formatted UTC ISO-8601 |
| session_completed_at | SessionExercise.session?.completedAt formatted UTC ISO-8601 (empty when nil) |
| session_intent | SessionExercise.intentRaw (NOT Session.intent — doesn't exist) |
| routine_id | SessionExercise.session?.sourceRoutineID?.uuidString (empty when nil) |
| routine_name | SessionExercise.session?.routineSnapshotName |
| exercise_id | SessionExercise.exercise?.id?.uuidString (empty when exercise == nil per Pitfall 11) |
| exercise_name | SessionExercise.exercise?.name (empty when exercise == nil — Open Question 2 deferred per 06-07 + 06-09) |
| set_index | SetEntry.orderIndex |
| set_kind | SetEntry.setTypeRaw |
| target_weight | SessionExercise.prescribedWeight (empty when nil) |
| target_reps | "{targetRepsLow}-{targetRepsHigh}" composite — planner decision |
| target_rpe | SessionExercise.targetRPE (empty when nil) |
| actual_weight | SetEntry.weight |
| actual_reps | SetEntry.reps |
| actual_rpe | SetEntry.rpe (empty when nil) |
| was_manual_override | SetEntry.wasManualOverride formatted as "true" / "false" (field IS present today — Phase 3 forward-compat) |
| partial_reps | SetEntry.partialReps (empty when nil) |
| tempo | SetEntry.tempoActual (empty when nil) |
| rest_taken_sec | SetEntry.restAfterSeconds (empty when nil) |
| e1rm | OneRepMax.estimate(weight: setEntry.weight, reps: setEntry.reps) (empty when nil) |
| set_note | SetEntry.notes (empty when nil) |
| unit | UserSettings.unitSystem rawValue ("kg" or "lb") — single value, same per row |

**RFC 4180 quoting (RESEARCH §Don't Hand-Roll line 431):** Quote any field containing `,` `"` `\r` `\n`; escape `"` as `""`. UTF-8 BOM `EF BB BF` at start of output (Excel-friendly). Line terminator: `\r\n`. ISO-8601 dates emitted via `Date.ISO8601FormatStyle().timeZone(.gmt)` — trailing `Z` MUST be present.

**JSON exporter shape (consumes 06-09's JSONEncoder.exportConfigured()):**
```
public enum JSONExporter {
    public static func render(document: ExportDocument) throws -> Data {
        try JSONEncoder.exportConfigured().encode(document)
    }
}
```
That is the entire body — single line. 06-09 owns the encoder configuration; this plan only wires the public render entry point.

**ExportService (PATTERNS §"Export/ExportService.swift" lines 488–525):**
```
@ModelActor
public actor ExportService {
    private static let log = Logger(subsystem: "com.fitbod.app", category: "export")

    public func snapshotDocument() async throws -> ExportDocument {
        // Read every SchemaV2 entity from modelContext, build [ExportXDTO] arrays, return ExportDocument.
    }
    public func renderCSV() async throws -> CSVFile {
        // Read all SetEntry rows + UserSettings, render via CSVExporter, wrap in CSVFile with dated filename.
    }
    public func renderJSON() async throws -> JSONFile {
        let doc = try await snapshotDocument()
        let data = try JSONExporter.render(document: doc)
        return JSONFile(data: data, filename: dailyFilename(prefix: "fitbod-export", ext: "json"))
    }
}
```

**Transferable shapes (RESEARCH §"Pattern 4" lines 322–348):**
```
public struct CSVFile: Transferable, Sendable {
    public let data: Data
    public let filename: String
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

public struct JSONFile: Transferable, Sendable {
    public let data: Data
    public let filename: String
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { $0.filename }
    }
}
```

**Filename helper:**
```
func dailyFilename(prefix: String, ext: String, now: Date = .now) -> String {
    let date = now.formatted(.iso8601.year().month().day())   // "2026-05-22"
    return "\(prefix)-\(date).\(ext)"
}
```

**SettingsView edits (PATTERNS §"Settings/DataSettingsSection.swift" lines 542–589):** Add a new section below the existing sections in the existing SettingsView Form. Two rows: "Export as CSV" + "Export as JSON". Each row's body branches on a `@State` optional CSVFile? / JSONFile? — when nil, button labeled "Export as CSV" triggers `Task { csvFile = try await ExportService(modelContainer: modelContext.container).renderCSV() }`; when non-nil, render `ShareLink(item: csvFile, preview: SharePreview(csvFile.filename)) { Text("Share CSV") }`. Same pattern for JSON. Section footer verbatim "Exports include every set you've logged. Backups can be shared via Files, iCloud Drive, or AirDrop." (the "Backups" portion lands fully in Wave 4 but the footer copy ships now per UI-SPEC verbatim — the row is built out in 06-10). Note: the Wave 4 "Create backup" and "Restore from backup" rows are added in 06-10; this plan ships ONLY the two export rows.

**Off-main rendering (RESEARCH Pitfall 13):** ExportService is `@ModelActor` (off main); the Settings view kicks off rendering via `Task { ... }` then assigns the `Sendable` CSVFile/JSONFile result on the main actor. While rendering shows a `ProgressView()` inline next to the row label OR `.disabled(true)` on the row.

**CSV golden-snapshot fixture path:** `fitbodTests/Phase6/Fixtures/csv/example-export.csv`. The test seeds a deterministic [SetEntry] fixture using hand-fixed UUIDs + dates (mirror the same fixture convention as 06-09's JSON snapshot test), renders via CSVExporter.render, compares to committed fixture bytes. First-run regenerate-and-fail behavior identical to 06-09's JSON snapshot pattern.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: JSONExporter + CSVExporter + golden CSV fixture + snapshot tests</name>
  <files>fitbod/Export/JSONExporter.swift, fitbod/Export/CSVExporter.swift, fitbodTests/Phase6/JSONExporterTests.swift, fitbodTests/Phase6/CSVExporterTests.swift, fitbodTests/Phase6/Fixtures/csv/example-export.csv</files>
  <read_first>
    - fitbod/Routines/PrescriptionDefaults.swift (pure-function enum pattern)
    - fitbod/Export/ExportDTOs.swift (06-09 output — ExportDocument + JSONEncoder.exportConfigured)
    - fitbod/Models/UserSettings.swift (unitSystem field — verify exact rawValue strings "kg" / "lb")
    - fitbod/Models/SetEntry.swift (real field names + wasManualOverride present)
    - fitbod/Progress/OneRepMax.swift (06-01 — used to compute e1rm column)
    - .planning/phases/06-progress-views-export-polish/06-RESEARCH.md §"Don't Hand-Roll — RFC-4180 CSV quoting" line 431 + §"Pitfall 8 — ISO-8601 timezone defaults" lines 506–509
    - .planning/phases/06-progress-views-export-polish/06-CONTEXT.md D-25, D-26, D-28
    - .planning/phases/06-progress-views-export-polish/06-VALIDATION.md §"Per-Task Verification Map" EXP-01 + EXP-02
  </read_first>
  <behavior>
    - JSONExporter.render(document:) returns the bytes produced by JSONEncoder.exportConfigured().encode(document) — a single line of glue
    - CSVExporter.render(setEntries:userSettings:) produces byte-identical output for a deterministic fixture (golden snapshot match)
    - RFC-4180 quoting: a set_note containing comma `,` or quote `"` is wrapped in double quotes with internal quote escape `""`
    - UTF-8 BOM `EF BB BF` is the first 3 bytes of CSV output
    - Date columns end with literal `Z` (UTC)
    - was_manual_override emits "true" or "false" based on SetEntry.wasManualOverride field (which exists in v1 schema — RESEARCH §Schema reality)
    - empty fields for nil values (rpe, partial_reps, tempo, rest_taken_sec, e1rm, set_note, target_weight, target_reps when both bounds nil, target_rpe, routine_id)
    - exercise_name = "" when SessionExercise.exercise == nil (Open Question 2 deferred convention)
    - Both exporters tested against golden snapshot files
  </behavior>
  <action>(1) Create `fitbod/Export/JSONExporter.swift` containing `public enum JSONExporter { public static func render(document: ExportDocument) throws -> Data { try JSONEncoder.exportConfigured().encode(document) } }`. File-header doc-block cites 06-09 as the encoder configuration source-of-truth. Single import: Foundation.

(2) Create `fitbod/Export/CSVExporter.swift` containing `public enum CSVExporter { public static func render(setEntries: [SetEntry], userSettings: UserSettings?) -> Data }` and private helpers `rfc4180Quote(_ value: String) -> String`, `formatIsoUTC(_ date: Date) -> String` (uses `Date.ISO8601FormatStyle().timeZone(.gmt)`), `formatOptional<T>(_ value: T?, transform: (T) -> String) -> String` returning "" for nil. Header row: 23 column names per CONTEXT D-25 verbatim. Body row per SetEntry per the schema mapping table in Interfaces. UTF-8 BOM (EF BB BF) prepended. Line terminator `\r\n` per RFC 4180. Use real SchemaV2 field names. For e1rm column call `OneRepMax.estimate(weight: setEntry.weight, reps: setEntry.reps)`. Imports: Foundation + SwiftData.

(3) Create golden CSV fixture file `fitbodTests/Phase6/Fixtures/csv/example-export.csv` as a zero-byte placeholder.

(4) Create `fitbodTests/Phase6/JSONExporterTests.swift` with @Suite("JSONExporter (EXP-02 byte-stable)") covering: oneLineGlueOverEncoder, prettyPrintedAndSortedKeys (re-uses fixture from 06-09 ExportDocumentSnapshotTests if accessible; otherwise builds an equivalent inline fixture). Two @Test funcs.

(5) Create `fitbodTests/Phase6/CSVExporterTests.swift` with @Suite("CSVExporter (EXP-01 RFC 4180)") covering: bomPresent (first 3 bytes 0xEF 0xBB 0xBF), headerRow23Columns, rfc4180QuotingForEmbeddedCommaAndQuote (set_note "a,b" + set_note "say \"hi\""), isoUtcDatesEndWithZ, wasManualOverrideEmitsTrueOrFalse, emptyForNilFields, exerciseNameEmptyForNilExercise (Open Question 2 deferred convention), goldenSnapshotMatch (read fixture via #filePath ascent; regenerate-and-fail on empty; byte-equal compare otherwise). Six @Test funcs total.

Use `Bundle(for:)` or `#filePath` ascent to locate the golden CSV fixture relative to the test bundle. Imports for tests: Foundation + Testing + SwiftData + @testable import fitbod.</action>
  <verify>
    <automated>xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/CSVExporterTests -only-testing:fitbodTests/JSONExporterTests -quiet</automated>
  </verify>
  <done>Both exporters parse-clean; tests PASS on second run (after CSV fixture is committed); RFC 4180 quoting + ISO-8601 UTC + 23-column order verified; JSONExporter is a one-line glue over 06-09's encoder.</done>
</task>

<task type="auto">
  <name>Task 2: CSVFile + JSONFile Transferable + ExportService @ModelActor</name>
  <files>fitbod/Export/CSVFile.swift, fitbod/Export/JSONFile.swift, fitbod/Export/ExportService.swift</files>
  <read_first>
    - fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift (lines 58–60, 78 — @ModelActor + Logger + actor pattern)
    - fitbod/Export/JSONExporter.swift (Task 1 output)
    - fitbod/Export/CSVExporter.swift (Task 1 output)
    - fitbod/Export/ExportDTOs.swift (06-09 output)
    - .planning/phases/06-progress-views-export-polish/06-PATTERNS.md §"Export/ExportService.swift" lines 488–525
    - .planning/phases/06-progress-views-export-polish/06-RESEARCH.md §"Pattern 4 — Transferable" lines 322–348 + §"Pitfall 13 — ShareLink Transferable lazy rendering" lines 536–540
    - .planning/phases/06-progress-views-export-polish/06-CONTEXT.md D-27, D-29
  </read_first>
  <behavior>
    - CSVFile + JSONFile conform to Transferable via DataRepresentation with .suggestedFileName(closure)
    - ExportService is @ModelActor and runs renderCSV/renderJSON/snapshotDocument off main
    - snapshotDocument reads every SchemaV2 entity from modelContext and assembles an ExportDocument
    - renderCSV reads all SetEntry rows + UserSettings, calls CSVExporter.render, wraps in CSVFile
    - renderJSON calls snapshotDocument then JSONExporter.render, wraps in JSONFile
    - Filename format: "fitbod-export-YYYY-MM-DD.csv" / ".json"
  </behavior>
  <action>(1) Create `fitbod/Export/CSVFile.swift` per Interfaces (public struct + Transferable + DataRepresentation + suggestedFileName). Imports: SwiftUI + CoreTransferable + UniformTypeIdentifiers. (2) Create `fitbod/Export/JSONFile.swift` per Interfaces. (3) Create `fitbod/Export/ExportService.swift` per PATTERNS line 488–525 — `@ModelActor public actor ExportService` with `private static let log = Logger(subsystem: "com.fitbod.app", category: "export")` and three public async methods: `renderCSV() async throws -> CSVFile`, `renderJSON() async throws -> JSONFile`, `snapshotDocument() async throws -> ExportDocument`. Implement a `dailyFilename(prefix:ext:now:)` helper either as a private static func or a free function in the file. snapshotDocument iterates each SchemaV2 entity via FetchDescriptor, builds the matching ExportXDTO array, and assembles ExportDocument with formatVersion: 1, schemaVersion: ExportDocument.canonicalSchemaVersion, exportedAt: .now, unitSystem from the singleton UserSettings (default "kg" if missing). renderJSON delegates to snapshotDocument + JSONExporter.render. renderCSV reads SetEntry rows sorted by completedAt + UserSettings, calls CSVExporter.render, wraps in CSVFile with dailyFilename. Imports: Foundation + SwiftData + OSLog.</action>
  <verify>
    <automated>find fitbod/Export -name '*.swift' | xargs xcrun swiftc -parse 2>&1 | grep -v warning</automated>
  </verify>
  <done>CSVFile + JSONFile + ExportService parse-clean; @ModelActor on ExportService; all three render methods present.</done>
</task>

<task type="auto">
  <name>Task 3: SettingsView Data section — rows 1 + 2 (Export as CSV / Export as JSON)</name>
  <files>fitbod/Settings/SettingsView.swift</files>
  <read_first>
    - fitbod/Settings/SettingsView.swift (entire file — locate insertion point below existing sections)
    - fitbod/Export/ExportService.swift (Task 2 output)
    - fitbod/Export/CSVFile.swift, JSONFile.swift (Task 2 outputs)
    - .planning/phases/06-progress-views-export-polish/06-PATTERNS.md §"Settings/DataSettingsSection.swift" lines 542–591
    - .planning/phases/06-progress-views-export-polish/06-UI-SPEC.md §"Settings → Data section" copy table lines 280–303
    - .planning/phases/06-progress-views-export-polish/06-CONTEXT.md D-27, D-29
  </read_first>
  <behavior>
    - SettingsView shows two new rows "Export as CSV" + "Export as JSON" in a new "Data" section
    - Tapping a row when result is nil triggers async render; result populates a @State variable; row then renders ShareLink(item:) wrapping the Transferable file
    - While rendering: row is .disabled(true) + a `ProgressView()` inline; on completion: ShareLink ready
    - Section footer reads "Exports include every set you've logged. Backups can be shared via Files, iCloud Drive, or AirDrop." verbatim (forward-compat for 06-10 backup rows)
    - Error state: if Task throws, render `.caption .systemRed` "Couldn't prepare export. Try again." below the row
  </behavior>
  <action>Edit `fitbod/Settings/SettingsView.swift`: locate the existing Form sections; add a new section at the end with header "Data" + footer copy verbatim. Two rows: "Export as CSV" / "Export as JSON". Each row is a private @ViewBuilder helper that branches on `@State private var csvFile: CSVFile?` / `jsonFile: JSONFile?`. When nil: `Button("Export as CSV") { Task { await renderCSV() } }`; when non-nil: `ShareLink(item: csvFile!, preview: SharePreview(csvFile!.filename)) { Text("Share CSV") }`. While in-flight: show inline `ProgressView()` and disable button. Add private `func renderCSV() async` / `renderJSON() async` methods that instantiate `ExportService(modelContainer: modelContext.container)` and assign the result back on MainActor. Error path renders `.caption .systemRed` "Couldn't prepare export. Try again." in a sibling Text. **Do NOT add the Create-backup or Restore-from-backup rows here — those are 06-10's job.**</action>
  <verify>
    <automated>find fitbod/Settings -name 'SettingsView.swift' | xargs xcrun swiftc -parse 2>&1 | grep -v warning && grep -n 'Export as CSV\|Export as JSON\|Data' fitbod/Settings/SettingsView.swift</automated>
  </verify>
  <done>SettingsView has new Data section with two export rows; ShareLink wired; off-main rendering via @ModelActor confirmed.</done>
</task>

</tasks>

<verification>
- `xcodebuild test -only-testing:fitbodTests/CSVExporterTests -only-testing:fitbodTests/JSONExporterTests` exits 0 (after CSV fixture committed)
- `find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse` exits 0
- `grep -n 'Transferable' fitbod/Export/CSVFile.swift fitbod/Export/JSONFile.swift` confirms conformance
- `grep -n 'JSONEncoder.exportConfigured' fitbod/Export/JSONExporter.swift` confirms reuse of 06-09's encoder
</verification>

<success_criteria>
- CSV emits 23 columns in CONTEXT D-25 order + UTF-8 BOM + ISO-8601 UTC + RFC 4180 quoting
- JSON exporter is one-line glue over 06-09's JSONEncoder.exportConfigured() — no duplicate encoder config
- Both exports wrapped in Transferable and exposed via ShareLink in Settings → Data
- Off-main rendering via @ModelActor ExportService
- Golden CSV snapshot test in place (PASS after second run when fixture is committed)
- 06-10 backup writer consumes ExportDocument unchanged (no duplicate snapshot logic in 06-10)
</success_criteria>

<output>
Create `.planning/phases/06-progress-views-export-polish/06-09b-SUMMARY.md` documenting:
- CSV column order (23 entries) + RFC 4180 quoting confirmation
- JSONExporter glue line count (target: ~1 line over JSONEncoder.exportConfigured)
- ExportService @ModelActor methods
- SettingsView Data section row count (2 of 4 — 06-10 adds the other 2)
- Open Question 2 (exerciseSnapshotName field) — deferred; v1 emits empty-string for nil-exercise rows
- Commit SHAs
</output>
