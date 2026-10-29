---
id: T08
title: One-tap export and backup
phase: 1
items: [34, 14]
depends_on: [T01]
size: M
sim: small
owns: [fitbod/Settings/SettingsView.swift, fitbod/Export/CSVFile.swift, fitbod/Export/JSONFile.swift, fitbod/Export/ExportService.swift, fitbod/Backup/FitbodBackupFile.swift, new:fitbodUITests/OneTapShareUITests.swift]
---

# T08: One-tap export and backup

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In Settings, Export CSV, Export JSON and backup CREATE each need two taps.
The first tap renders the file and swaps the card for a share control, and only the second tap opens the share sheet.
The backup footer also steers the user to the risky action.
RESTORE is the filled orange primary button, and CREATE is a plain ghost button, even though restore replaces data.

## Target

- The export cards and the backup footer in `fitbod/Settings/SettingsView.swift`.
- The share file types `CSVFile`, `JSONFile` and `FitbodBackupFile`, and `ExportService`, which renders them.

## Change

1. One tap on Export CSV opens the share sheet with the CSV file.
2. One tap on Export JSON does the same with the JSON file.
3. One tap on CREATE opens the share sheet with the backup file.
4. Each file renders when the share sheet asks for it, not before (see "One-tap share" in [../tradeoffs.md](../tradeoffs.md)).
5. SwiftData reads happen on the main actor, and only plain value snapshots cross to other threads.
6. CREATE becomes the filled primary button, and RESTORE becomes the secondary ghost button.
7. RESTORE keeps its existing confirmation before it replaces data.
8. If rendering fails, the user sees the existing error message, never a silent no-op.

## Constraints

- File names and file contents stay exactly as they are today.
  T41 changes the backup format, not this ticket.
- Swift 6 strict concurrency must stay clean, with no new warnings.
- Do not add a progress screen or any new step between the tap and the share sheet.

## Ownership

You may edit the files in `owns`, plus existing Settings UI tests and export tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open Settings, tap Export CSV once, and assert that the system share sheet appears within 5 seconds.
- Do the same for Export JSON and for CREATE.

All three fail today, because the first tap only renders the file.
Find the share sheet by an element it always shows, such as its "Save to Files" row, and close it without sharing.

## Observable acceptance

- The three repro tests pass on the small phone.
- A pixel check shows that CREATE has the signal fill and RESTORE does not.
- The restore confirmation still appears before any data is replaced.
- `SettingsBRUUITests` passes on the small phone.
- `CSVExporterTests`, `JSONExporterTests`, `ExportDocumentSnapshotTests` and `BackupArchiverTests` pass with `fitbodTests`.
- Screenshots of the backup footer in light and dark mode are in `screens/`.

## Hints

- The two-tap flow is in `SettingsView.swift` near lines 303-345 and 412-430, and CSV rendering is near `renderCSV` at 615-626.
- `CSVFile`, `JSONFile` and `FitbodBackupFile` already conform to `Transferable`.
  Their header comments explain why the bytes are rendered up front today.
- A transfer representation's exporting closure is async, so it can hop to the main actor for the SwiftData reads and render the bytes afterwards.
- `ModelContainer` is `Sendable`, and `ModelContext` is not.
