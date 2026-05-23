---
phase: 06
plan: 09b
slug: export-service-and-settings
status: complete
completed: 2026-05-23
wave: 4
type: execute
requirements: ["EXP-01", "EXP-02"]
depends_on: ["06-09"]
tech_stack:
  added: []
  patterns:
    - "Transferable value type wrapping pre-rendered bytes (CSVFile / JSONFile) — RESEARCH Pattern 4"
    - "@ModelActor ExportService for off-main rendering (RESEARCH Pitfall 13)"
    - "JSONExporter as one-line glue over 06-09's JSONEncoder.exportConfigured()"
    - "RFC 4180 CSV emitter with UTF-8 BOM + ISO-8601 UTC dates + 23-column order"
    - "Golden-file snapshot test with manual host-tree fixture seeding"
key_files:
  created:
    - fitbod/Export/JSONExporter.swift
    - fitbod/Export/CSVExporter.swift
    - fitbod/Export/CSVFile.swift
    - fitbod/Export/JSONFile.swift
    - fitbod/Export/ExportService.swift
    - fitbodTests/Phase6/JSONExporterTests.swift
    - fitbodTests/Phase6/CSVExporterTests.swift
    - fitbodTests/Phase6/Fixtures/csv/example-export.csv
  modified:
    - fitbod/Settings/SettingsView.swift
decisions:
  - "Date.formatted(.iso8601) is the canonical ISO-8601 UTC formatter (Swift 6 / iOS 18). Verified `Date(timeIntervalSince1970: 1_700_000_000)` → '2023-11-14T22:13:20Z'. The plan's suggested `.timeZone(separator: .omitted)` API actually outputs only 'Z' (no date/time prefix) — discarded."
  - "Golden CSV fixture seeded manually via a one-off `swift` script (not via the test-runner regeneration path) — iOS Simulator sandbox cannot write to host source-tree paths via #filePath. The same defensive `guard FileManager.default.fileExists(atPath:)` pattern as ExportDocumentSnapshotTests gates the test."
  - "Deterministic CSVExporterTests fixture uses 4 hand-fixed UUIDs (`11111111-...`, `22222222-...`, `33333333-...`, `44444444-...`) assigned post-construction so the byte snapshot is reproducible. Mirrors ExportDocumentSnapshotTests UUID convention (which uses the `00000000-...{01..11}` family)."
  - "ExportService.dailyFilename uses an explicit `Locale('en_US_POSIX') + TimeZone('UTC')` DateFormatter rather than Date.formatted(.iso8601.year().month().day()) — produces deterministic YYYY-MM-DD output regardless of device locale."
  - "Image bytes are NOT included in JSON export. 06-10 backup writer is the surface that carries `images/<uuid>.jpg` into the .fitbodbackup ZIP. v1 JSON export carries imagePaths references only."
  - "csvFile / jsonFile @State variables are independent (not bundled into a single optional struct) so the user can prepare both exports concurrently without one render canceling the other."
metrics:
  duration_minutes: ~17
  tasks_completed: 3
  files_created: 8
  files_modified: 1
  commits: 3
---

# Phase 6 Plan 06-09b: CSV/JSON Export Service + Settings Summary

Ship CSV (EXP-01) and JSON (EXP-02) exports as `Transferable` value types consumed by `ShareLink` in the new Settings → Data section. Builds directly on the DTO graph + encoder configuration locked in 06-09; this plan is the user-facing rendering + Settings wiring half.

## Overview

The DTOs + envelope shipped in 06-09. This plan layers the byte-stable rendering surfaces on top and surfaces them through `ShareLink` in `SettingsView`. Both exports are byte-deterministic and locked by golden-file snapshot tests so future schema additions surface as snapshot diffs at commit time.

The off-main `@ModelActor ExportService` is the central rendering brain — `renderCSV()`, `renderJSON()`, and the shared `snapshotDocument()` (consumed by 06-10's `BackupArchiver` unchanged) all live there.

## Implementation

### Task 1 — JSONExporter + CSVExporter + golden-CSV snapshot tests

**`fitbod/Export/JSONExporter.swift`** (19 lines)
- `public enum JSONExporter { static func render(document:) throws -> Data }`
- One-line body: `try JSONEncoder.exportConfigured().encode(document)`
- 06-09 owns the encoder configuration; this plan wires the public entry point.

**`fitbod/Export/CSVExporter.swift`** (171 lines)
- `public enum CSVExporter { static func render(setEntries:userSettings:) -> Data }`
- `public static let headerColumns: [String]` — 23 columns in CONTEXT D-25 verbatim order.
- `public static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]` — Excel-friendly UTF-8 prefix.
- Per-row build: maps `SetEntry → 23 columns` per the schema-mapping table (file-header documents every column's source field).
- Line terminator `\r\n` per RFC 4180.
- `static func rfc4180Quote(_:)` wraps fields containing `,`/`"`/`\r`/`\n` in `"…"` and doubles embedded `"` → `""`.
- `static func formatISO(_ date: Date) -> String` uses `Date.formatted(.iso8601)` which Swift 6 / iOS 18 verified emits trailing `Z`.
- `static func formatDouble(_ value: Double) -> String` — integer values render without fractional component; decimals via `%g`.
- Booleans → `true`/`false` lowercase literals; nil optionals → empty string (never literal "nil").

**`fitbodTests/Phase6/JSONExporterTests.swift`** (2 @Test, 1 minimalFixture helper)
- `oneLineGlueOverEncoder` — `JSONExporter.render(document:)` byte-equals direct `JSONEncoder.exportConfigured().encode(...)`.
- `prettyPrintedAndSortedKeys` — output contains alphabetized envelope keys (`exercises` < `exportedAt` < `formatVersion`) + ISO-8601 UTC `Z` suffix.

**`fitbodTests/Phase6/CSVExporterTests.swift`** (8 @Test, `@MainActor @Suite .serialized`)
- `bomPresent` — first 3 bytes are `0xEF 0xBB 0xBF`
- `headerRow23Columns` — header has exactly 23 columns matching `headerColumns`
- `rfc4180QuotingForEmbeddedCommaAndQuote` — `,`/`"`/`\n` escaping
- `isoUtcDatesEndWithZ` — date columns end with literal `Z`
- `wasManualOverrideEmitsTrueOrFalse` — boolean lowercase literal
- `emptyForNilFields` — nil → empty string; no literal "nil" anywhere
- `exerciseNameEmptyForNilExercise` — Open Q2 deferred convention
- `goldenSnapshotMatch` — byte-equal against `Fixtures/csv/example-export.csv` (gracefully skips when path unreachable from test sandbox per the same defensive pattern in `ExportDocumentSnapshotTests`)

Hand-fixed UUIDs `11..44` family + `Date(timeIntervalSince1970: 1_700_000_000)` anchor make every test fixture byte-deterministic.

**`fitbodTests/Phase6/Fixtures/csv/example-export.csv`** (477 bytes)
Golden snapshot generated via a one-off `swift` script that mirrors `CSVExporter.render` exactly (UTF-8 BOM + 23-column header + one data row for 100×5 RPE 8 strength bench with e1RM = Brzycki 112.5).

### Task 2 — CSVFile + JSONFile + ExportService

**`fitbod/Export/CSVFile.swift`** (41 lines)
- `public struct CSVFile: Transferable, Sendable` with `data: Data` + `filename: String`
- `transferRepresentation: some TransferRepresentation` returns `DataRepresentation(exportedContentType: .commaSeparatedText)` + `.suggestedFileName { $0.filename }`
- Pre-rendered byte wrapper keeps the `ShareLink` caller-thread closure trivial (RESEARCH Pitfall 13)

**`fitbod/Export/JSONFile.swift`** (33 lines)
- Symmetric to CSVFile; uses `.json` content type

**`fitbod/Export/ExportService.swift`** (319 lines)
- `@ModelActor public actor ExportService`
- `Logger(subsystem: "com.fitbod.app", category: "export")`
- `renderCSV() async throws -> CSVFile` — fetches isComplete SetEntry rows + UserSettings; calls `CSVExporter.render`; wraps in `CSVFile(data:filename:)` with `dailyFilename("fitbod-export", "csv")`.
- `renderJSON() async throws -> JSONFile` — delegates to `snapshotDocument()`; calls `JSONExporter.render`; wraps in `JSONFile(data:filename:)`.
- `snapshotDocument() async throws -> ExportDocument` — per-entity FetchDescriptors sorted by id (sessions sorted by startedAt for round-trip-stable output); 11 per-entity model→DTO mappers compose the envelope.
- `dailyFilename(prefix:ext:now:)` uses `DateFormatter` with `Locale("en_US_POSIX") + TimeZone("UTC")` for deterministic YYYY-MM-DD output regardless of device locale.
- The `snapshotDocument()` method is the SHARED source-of-truth for both JSON export AND 06-10 backup writer (no duplicate snapshot logic).
- Image bytes are NOT carried in JSON export — see decisions block.

### Task 3 — SettingsView Data section

**`fitbod/Settings/SettingsView.swift`** (modified, +119 lines)
- New `@State` block: `csvFile: CSVFile?` + `jsonFile: JSONFile?` + `csvRendering: Bool` + `jsonRendering: Bool` + `csvError: String?` + `jsonError: String?`
- New `@Environment(\.modelContext) private var modelContext` to instantiate `ExportService(modelContainer:)`.
- `dataSection` `@ViewBuilder` — `Section` "Data" with two rows + footer "Exports include every set you've logged. Backups can be shared via Files, iCloud Drive, or AirDrop." (UI-SPEC verbatim; forward-compat for 06-10).
- `csvRow` / `jsonRow` branch on `file == nil`:
  - nil: `Button` "Export as CSV" / "Export as JSON" with inline `ProgressView()` when rendering; `.disabled(true)` during render.
  - non-nil: `ShareLink(item: file, preview: SharePreview(file.filename)) { Text("Share CSV") }` (and "Share JSON").
- Error caption beneath the row: `.font(.caption).foregroundStyle(Color(.systemRed))` "Couldn't prepare export. Try again." (UI-SPEC verbatim).
- `@MainActor renderCSV() async` / `renderJSON() async` instantiate `ExportService(modelContainer: modelContext.container)` and assign the result back on MainActor; error path catches throws.

### Verification

- `xcodebuild build` → **BUILD SUCCEEDED** after each task
- `xcodebuild test -only-testing:fitbodTests/CSVExporterTests` → 8/8 @Test **PASS**
- `xcodebuild test -only-testing:fitbodTests/JSONExporterTests` → 2/2 @Test **PASS**
- `grep -n 'Transferable' fitbod/Export/CSVFile.swift fitbod/Export/JSONFile.swift` confirms conformance
- `grep -n 'JSONEncoder.exportConfigured' fitbod/Export/JSONExporter.swift` confirms reuse of 06-09's encoder

### Deviations from Plan

**1. [Rule 1 - API correction] Date.formatted(.iso8601) is the canonical UTC formatter, NOT `.timeZone(separator: .omitted)`**
- **Found during:** Task 1 — first CSV snapshot test failed with date columns rendering as bare "Z"
- **Issue:** Plan's interface example used `Date.ISO8601FormatStyle().timeZone(separator: .omitted)`. This API actually produces only the timezone designator "Z" — no date or time prefix. Default `.iso8601` already emits `YYYY-MM-DDTHH:MM:SSZ` with explicit UTC suffix on Swift 6 / iOS 18.
- **Fix:** Replaced `.iso8601.timeZone(separator: .omitted)` with `.iso8601`. Verified output: `Date(timeIntervalSince1970: 1_700_000_000)` → "2023-11-14T22:13:20Z".
- **Files modified:** fitbod/Export/CSVExporter.swift
- **Commit:** bc32876

**2. [Rule 3 - Host-tree fixture seeding] Golden CSV fixture manually generated via one-off swift script**
- **Found during:** Task 1 — `goldenSnapshotMatch` test passed but didn't write the fixture because iOS Simulator sandboxing prevents writes to host source-tree paths.
- **Issue:** Plan's test design assumed the test runner could regenerate the fixture on first run via `try generated.write(to: fixtureURL)`. iOS Simulator sandbox returns an error silently and the file remains empty. The same constraint applies to ExportDocumentSnapshotTests (which uses the same defensive `guard FileManager.default.fileExists` pattern).
- **Fix:** Generated the golden fixture via a `/tmp/gen_csv_fixture.swift` one-off script that exactly mirrors CSVExporter.render output (UTF-8 BOM + 23-column header + one row for 100×5 RPE 8 strength bench). The committed fixture (477 bytes) drives `goldenSnapshotMatch` to byte-equal pass.
- **Files modified:** fitbodTests/Phase6/Fixtures/csv/example-export.csv (newly populated)
- **Commit:** bc32876

**3. [Rule 2 - Deterministic test UUIDs] Added 4 hand-fixed UUID statics to CSVExporterTests**
- **Found during:** Task 1 fixture generation
- **Issue:** SwiftData auto-generates UUIDs at insert time; the golden CSV fixture must be byte-deterministic across runs.
- **Fix:** Added 4 static UUIDs (`11111111-...`, `22222222-...`, `33333333-...`, `44444444-...`) and assign them via `entity.id = Self.fixtureID` after `ctx.insert(entity)` but before `ctx.save()`. Mirrors ExportDocumentSnapshotTests UUID convention.
- **Files modified:** fitbodTests/Phase6/CSVExporterTests.swift
- **Commit:** bc32876

### Known Stubs

None. The Wave 4 "Create backup" / "Restore from backup" rows are intentionally absent from this plan — they ship in 06-10 (which is OUT OF SCOPE per the user's mission for this execution wave).

## Deferred Items

- **Open Question 2 — `SessionExercise.exerciseSnapshotName: String?`:** Deferred. v1 emits empty-string for nil-exercise rows (`exercise_name = ""`).
- **06-10 backup + restore rows in Settings → Data section:** Out of scope for this execution wave. The footer copy is forward-compat ready ("Backups can be shared via …") so 06-10 only needs to add two new rows above/below the existing Export rows.

## Commit SHAs

- **`bc32876`** — `feat(06-09b): JSONExporter + CSVExporter + byte-stable snapshot tests`
- **`a6a850d`** — `feat(06-09b): CSVFile + JSONFile + ExportService @ModelActor`
- **`f786ffc`** — `feat(06-09b): SettingsView Data section — Export as CSV / Export as JSON`

## Self-Check: PASSED

Files exist:
- FOUND: fitbod/Export/JSONExporter.swift
- FOUND: fitbod/Export/CSVExporter.swift
- FOUND: fitbod/Export/CSVFile.swift
- FOUND: fitbod/Export/JSONFile.swift
- FOUND: fitbod/Export/ExportService.swift
- FOUND: fitbodTests/Phase6/JSONExporterTests.swift
- FOUND: fitbodTests/Phase6/CSVExporterTests.swift
- FOUND: fitbodTests/Phase6/Fixtures/csv/example-export.csv (477 bytes)

Modified:
- FOUND: fitbod/Settings/SettingsView.swift (dataSection + async render helpers)

Commits exist:
- FOUND: bc32876
- FOUND: a6a850d
- FOUND: f786ffc

Reuse contract confirmed:
- FOUND: `JSONEncoder.exportConfigured` in fitbod/Export/JSONExporter.swift (one-line glue)
- FOUND: `Transferable` in CSVFile.swift + JSONFile.swift (DataRepresentation + .suggestedFileName)
- FOUND: `@ModelActor` on ExportService — off-main render guarantee
