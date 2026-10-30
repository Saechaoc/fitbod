---
id: T41
title: Backup keeps routines
phase: 4
items: [N1]
depends_on: [T08, T40]
size: L
sim: small
owns: [fitbod/Backup/BackupArchiver.swift, fitbod/Backup/BackupRestorer.swift, fitbod/Backup/BackupManifest.swift, fitbod/Export/ExportDTOs.swift, fitbod/Export/ExportService.swift, fitbod/Export/CSVExporter.swift, new:fitbodTests/BackupRoutinesRoundTripTests.swift, new:fitbodUITests/BackupRestoreRoutinesUITests.swift]
---

# T41: Backup keeps routines

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding N1, found while this bundle was written.
A backup holds exercises, sessions, blocks, logged workouts and settings, but no routines and no routine slots.
Restore says it wipes everything, but it never deletes routines or slots.
It deletes every session while old slots still point at them.
So a restore onto a fresh install brings back no routines.
A restore over existing routines may crash, or leave routines whose sessions are gone.
Either way, blocks lose their routine, and Today's rotation starts over.

This is also finding F133, which the T95 worker found by reading the code.
The backup writes each logged exercise's name from the live library entry, or "" once a custom exercise is deleted, and it never writes `exerciseNameSnapshot`.
So a restored workout loses the name it was logged under, and a deleted exercise's workouts come back nameless.
The JSON and CSV exports write the same live name.

## Target

- The backup archive and restore in `fitbod/Backup/`.
- The shared export types in `fitbod/Export/ExportDTOs.swift`, and `ExportService.swift` if the JSON export builds the same document.

## Change

1. A backup includes every routine, archived or not, with every stored field, and its slots in order, each with the id of its session.
2. Each block in a backup carries the id of its routine.
   Each logged workout carries the id of the slot it came from.
3. Restore deletes slots and routines first, then everything else, so no slot ever points at a deleted session.
   If T40 found that a slot delete is refused while the slot still links a session, clear each link before the delete.
4. Restore rebuilds routines and slots, links each slot to its restored session by id, links each block to its routine, and links each logged workout to its slot.
5. The backup format version goes up by one.
6. A backup in the older format still restores.
   It holds no routines, so after the restore the app has no routines (see "Backup keeps routines (finding N1)" in [../tradeoffs.md](../tradeoffs.md)).
7. If the JSON export builds the same document, it includes routines too, and you update `ExportDocumentSnapshotTests` on purpose.
8. List in `notes.md` every other SchemaV7 model type or field that the backup still leaves out, without fixing it.
9. Each logged exercise in a backup carries `exerciseNameSnapshot`, and restore writes it back.
   The backup's exercise name is the log's `displayName`, and restoring an older backup puts that name into the snapshot.
10. The JSON and CSV exports write each log's `displayName`, and the "Open Q2 deferred" comments go.

## Constraints

- No schema change.
- Keep the checksum, the schema-version check and the in-progress workout gate exactly as they are.
- The old `routines` list in the export types holds session templates, which is pre-V7 naming.
  Name the new list after `Split`, so the two never get mixed up.
- Never write the user's email or any personal data into test fixtures.

## Ownership

You may edit the files in `owns`, plus backup and export tests your change breaks.
Ask before you edit anything else.

## Repro first

- Write `BackupRoutinesRoundTripTests` first.
  Build a store with two routines, one archived, each with two ordered slots, a block that uses one routine, and a logged workout from one slot.
  Back it up, restore it into a fresh store, and assert that all of it comes back with the same order and links.
- Restore that backup over a store that already has routines, and assert that no slot points at a missing session.
- Restore a backup in the old format, and assert that it succeeds.
- Log a workout, rename its exercise in the library, back up and restore, and assert that the restored log's `displayName` is the old name.

The first two and the rename test fail today.
If the restore over existing routines crashes the test process, that crash is the failure: save its summary to `repro-fail.txt`.
Then try the same round trip through Settings in `BackupRestoreRoutinesUITests` on the small phone: CREATE a backup, save it to Files, RESTORE it, and check Program's routines.
If the system file sheets make that unreliable, say so in `notes.md`, and use a DEBUG-only launch helper that calls the same archiver and restorer the buttons use.

## Observable acceptance

- Every repro test passes.
- `BackupArchiverTests`, `BackupRoundTripTests`, `BackupVersionSkewTests` and `ExportDocumentSnapshotTests` pass with `fitbodTests`.
- The UI round trip, or its DEBUG fallback, passes on the small phone, and its screenshot shows the restored routines on Program.
- `notes.md` holds the list from step 8.

## Hints

- The restore deletes are near `BackupRestorer.swift:226-241`, and the archive's format version is set near `BackupArchiver.swift:80` and 160.
- Restore already keeps every row's id, so links by id are safe.
- The block and workout types already carry soft links by name (`splitName`, `slotPosition`, `slotSplitName`); keep them for older backups.
  Comments near them in `BackupRestorer.swift` say the routine wiring was deferred, and this ticket is that work.
- Read `evidence/T40/notes.md` and `evidence/T40/delete-paths.md` before you change the delete order.
- `BackupVersionSkewTests` holds the restore's safety checks, such as the checksum and the in-progress workout gate.
- `T08` changed how CREATE shares the backup file.
- The live-name writes are near `BackupArchiver.swift:369`, `ExportService.swift:300` and `CSVExporter.swift:108`; `SessionExercise.displayName` reads the snapshot first.
