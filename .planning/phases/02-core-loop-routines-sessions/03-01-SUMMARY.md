---
phase: 02
plan: 03-01
subsystem: routines-list-folders-resume-banner
tags: [routines, folders, resume-banner, swiftui, swiftdata, ui-spec, active-session-guard, soft-ref]
requires:
  - "00-01: RoutineFolder / SupersetGroup / RoutineExerciseSetOverride entities + Routine.folderID / RoutineExercise.supersetGroupID soft-ref fields"
  - "00-02: SchemaV2 lightweight-migration wiring"
  - "01-01: SessionFactory.start + SessionFactoryError + SessionFactory.active(in:) + PreviousMatchingIntent"
provides:
  - "fitbod/Routines/RoutinesListView.swift (public struct RoutinesListView: View)"
  - "fitbod/Routines/RoutineRow.swift (public struct RoutineRow: View)"
  - "fitbod/Routines/NewFolderSheet.swift (public struct NewFolderSheet: View)"
  - "fitbod/Routines/MoveRoutineSheet.swift (public struct MoveRoutineSheet: View)"
  - "fitbod/Routines/RoutineFolderDraft.swift (@Observable @MainActor public final class RoutineFolderDraft)"
  - "fitbod/Sessions/ResumeWorkoutBanner.swift (public struct ResumeWorkoutBanner: View)"
  - "RootView Routines tab wired to RoutinesListView; Today tab mounts ResumeWorkoutBanner via .safeAreaInset"
affects:
  - "fitbod/App/RootView.swift (PlaceholderTabView replaced on Routines tab; TodayTabHost host added)"
tech-stack:
  added: []  # no new dependencies — pure SwiftUI + SwiftData composition
  patterns:
    - "@Query<Routine> + @Query<RoutineFolder> + @Query<Session>(filter: #Predicate { $0.completedAt == nil }) reactive composition in a single outer view"
    - "Soft-ref delete handlers: query-and-nil routine.folderID BEFORE ctx.delete(folder); query-and-delete SupersetGroup rows by routineID BEFORE ctx.delete(routine)"
    - "@Observable @MainActor ephemeral draft with isValid: Bool gate (RoutineFolderDraft, mirrors CustomExerciseDraft from plan 01-03-04)"
    - "Reactive banner via @Query inside the banner view — parent does NOT pass a session in; the banner's own @Query keeps the UI in lockstep with completedAt mutations"
    - ".safeAreaInset(edge: .top) to mount the banner above the existing NavigationStack of PlaceholderTabView (avoids nested NavigationStack)"
    - "UI-SPEC verbatim copy pinned at the source level via on-disk file-read tests (RoutinesListCopyTests pattern mirrors RestTimerOverlayCopyTests from plan 02-03)"
    - "Active-session conflict guard: handleStartTap pre-checks activeSessions.isEmpty AND catches SessionFactoryError.activeSessionAlreadyExists (RESEARCH §6 Pitfall 7)"
key-files:
  created:
    - fitbod/Routines/RoutinesListView.swift
    - fitbod/Routines/RoutineRow.swift
    - fitbod/Routines/NewFolderSheet.swift
    - fitbod/Routines/MoveRoutineSheet.swift
    - fitbod/Routines/RoutineFolderDraft.swift
    - fitbod/Sessions/ResumeWorkoutBanner.swift
    - fitbodTests/RoutinesListCopyTests.swift
    - fitbodTests/RoutineFolderDraftTests.swift
    - fitbodTests/ActiveSessionConflictTests.swift
  modified:
    - fitbod/App/RootView.swift
decisions:
  - "Banner owns its own @Query<Session>(completedAt == nil) — parent does NOT pass a session in. This keeps the surface reactive: when Finish Workout fires elsewhere (plan 04-01), the banner self-dismisses without an explicit parent signal."
  - "Today tab uses .safeAreaInset(.top) on top of PlaceholderTabView rather than inlining the placeholder body. Preserves the PlaceholderTabView(phaseNumber: 2) literal token for AC #2 and avoids the nested NavigationStack anti-pattern."
  - "handleFolderDelete re-maps routine.folderID = nil BEFORE ctx.delete(folder). The order is load-bearing: if the folder were deleted first, SwiftData's relationship cache could still surface the routines under their original folder.id reference until the tab reopened."
  - "handleDelete query-and-deletes SupersetGroup rows whose routineID matches the routine's id BEFORE deleting the routine. The SupersetGroup soft-ref design (CONTEXT.md Area 6) means there's no SwiftData cascade to do this for us — Routine.exercises cascades RoutineExercise + RoutineExerciseSetOverride rows but does NOT touch SupersetGroup."
  - "Empty folder sections render a faint 'No routines in this folder' placeholder row instead of being hidden. Trade-off: a user who created a folder with intent (Push / Pull / Legs) gets a clear visible header to drop routines into, instead of the folder appearing only after the first routine is moved in. Matches UI-SPEC § Routines tab implicit expectation."
  - "Unfiled section uses a pre-generated static UUID rather than UUID() called on every body evaluation. SwiftUI's ForEach diff would treat a fresh-UUID-per-render section as a brand-new section every redraw, causing flicker / lost animation contexts."
  - "Cancelled the 'Resume Workout' alert button → conflictRoutine = nil (no navigation). The visible resume banner above the list already owns the navigation surface for resuming; the alert is just an informational gate, not a navigation hub."
metrics:
  duration_seconds: 385
  tasks_completed: 3
  files_changed: 10
  completed: "2026-05-11"
---

# Phase 2 Plan 03-01: Routines List, Folders, and Resume Workout Banner Summary

Wired the Routines tab to its real `RoutinesListView` (sectioned `List` grouped by `RoutineFolder`, "+" toolbar Menu for New Routine / New Folder, swipe + context-menu row actions, UI-SPEC verbatim empty state), added the `ResumeWorkoutBanner` reactive surface that appears on both the Routines tab (as the floating first list row) and the Today tab (as a `.safeAreaInset(.top)`), and shipped the active-session conflict guard. Closes the user-visible half of ROUTINE-06 (folders) and SESS-04 (resume-workout surfacing).

## Goal Status

Achieved. The user opens the app, taps Routines, sees their routines grouped by folder (or the empty-state CTA if none exist), and can:

1. Create a new folder via the "+" toolbar Menu → `NewFolderSheet` (Save disabled until the name is non-empty after trimming).
2. Move a routine between folders / back to Unfiled via the row's context-menu "Move…" entry → `MoveRoutineSheet`.
3. Delete a folder via the inline confirmation dialog — affected routines re-map to Unfiled (soft-ref invariant).
4. Delete a routine via swipe trailing — orphan `SupersetGroup` rows are explicitly cleaned up first.
5. Start a workout via swipe leading "Start Workout" — if an active session already exists, the UI-SPEC "Workout in Progress" alert surfaces with Resume Workout / Discard / Cancel.
6. See the "Resume Workout: {routineSnapshotName}" banner whenever `Session.completedAt == nil` — mounted reactively at the top of the Routines tab list AND the Today tab.

Stubbed call sites (per the plan's anti-pattern list): "New Routine" sheet body (plan 03-02 fills in), row-tap edit mode (plan 03-02), `handleDuplicate` (plan 03-03).

## Files Changed (Detailed)

### Created — Production source (6 files)

| File | Lines | Role |
|------|-------|------|
| `fitbod/Routines/RoutinesListView.swift` | 411 | Routines tab body — sectioned List, toolbar Menu, conflict alert, folder-delete confirmation, empty state, soft-ref delete handlers |
| `fitbod/Routines/RoutineRow.swift` | 127 | One routine row — leading "Start Workout" swipe (accent + play.fill), trailing Delete/Duplicate swipes, 5-action context menu |
| `fitbod/Routines/NewFolderSheet.swift` | 65 | Form-in-NavigationStack sheet with @Bindable RoutineFolderDraft; Save .disabled(!draft.isValid) |
| `fitbod/Routines/MoveRoutineSheet.swift` | 100 | Folder picker Form with checkmark on current selection; "Unfiled" row writes folderID = nil |
| `fitbod/Routines/RoutineFolderDraft.swift` | 36 | @Observable @MainActor ephemeral draft; trimmed-non-empty isValid gate |
| `fitbod/Sessions/ResumeWorkoutBanner.swift` | 135 | Reactive @Query<Session>(completedAt == nil) banner; emits EmptyView when no active session; "Discard active workout?" confirmation alert |

### Created — Tests (3 files)

| File | @Test count | Role |
|------|-------------|------|
| `fitbodTests/RoutinesListCopyTests.swift` | 1 | Source-level UI-SPEC verbatim copy anchors (RoutinesListView / RoutineRow / NewFolderSheet / MoveRoutineSheet / ResumeWorkoutBanner — 26 #expect checks across 5 files) |
| `fitbodTests/RoutineFolderDraftTests.swift` | 3 | Truth-table coverage for isValid (empty / whitespace-only / valid) |
| `fitbodTests/ActiveSessionConflictTests.swift` | 4 | RESEARCH §6 Pitfall 7 guard — firstStartSucceeds, secondStartThrowsActiveSessionAlreadyExists, startAfterFinishingPriorSessionSucceeds, startAfterDiscardingPriorSessionSucceeds |

### Modified

- `fitbod/App/RootView.swift`: replaced `PlaceholderTabView(phaseNumber: 2)` on the Routines tab with `RoutinesListView()`; added `TodayTabHost` private struct that mounts `ResumeWorkoutBanner` above `PlaceholderTabView(phaseNumber: 2)` on the Today tab via `.safeAreaInset(edge: .top)`. The Today tab keeps its UI-SPEC placeholder copy ("Available in Phase 2") for AC compliance while still surfacing an active session via the banner.

## Acceptance Criteria

All 14 ACs from the plan satisfied:

| AC | Status | Verification |
|----|--------|--------------|
| 1. RoutinesListView exists with `public struct RoutinesListView: View` | PASS | File present; `grep -n 'public struct RoutinesListView: View'` returns 1 match (line 66) |
| 2. Routines tab wired in RootView; only Today keeps `PlaceholderTabView(phaseNumber: 2)` | PASS | `grep -n 'RoutinesListView()'` → 1 match; `grep -nE 'PlaceholderTabView\(phaseNumber: 2\)'` → 1 match (line 246, inside TodayTabHost) |
| 3. Toolbar Menu has "New Routine" + "New Folder" | PASS | `grep -cE '"New Routine"\|"New Folder"'` returns 5 (≥ 2) |
| 4. Conflict alert uses UI-SPEC verbatim copy | PASS | "Workout in Progress" + "Finish or discard the current workout before starting a new one." both present |
| 5. Empty state UI-SPEC verbatim | PASS | "No routines yet" + "Build a routine to start logging workouts." both present |
| 6. "Unfiled" section header renders only when ≥1 routine has folderID == nil | PASS | `sectionsForRendering` builds the unfiled section only when `!unfiled.isEmpty` |
| 7. handleFolderDelete re-maps routines BEFORE deleting folder | PASS | Code at lines 359-368 — fetch affected routines → set folderID = nil for each → ctx.delete(folder) → save() |
| 8. handleDelete cleans up SupersetGroup rows by routineID | PASS | Code at lines 332-345 — fetch SupersetGroup rows with `routineID == id` → delete each → ctx.delete(routine) → save() |
| 9. RoutineRow.swift has swipe + context menu | PASS | Three grep matches: `.swipeActions(edge: .leading)` (line 66), `.swipeActions(edge: .trailing)` (line 74), `.contextMenu` (line 87) |
| 10. NewFolderSheet + MoveRoutineSheet have verbatim titles + Save/Cancel toolbar | PASS | Both files contain "New Folder"/"Move Routine" navigationTitle + "Save"/"Cancel" toolbar buttons |
| 11. RoutineFolderDraft declared @Observable @MainActor + isValid: Bool | PASS | Three grep matches: `@Observable` (line 23), `public final class RoutineFolderDraft` (line 25), `isValid: Bool` (line 33) |
| 12. ResumeWorkoutBanner has @Query(completedAt == nil) + verbatim copy | PASS | All four required strings present: `completedAt == nil`, `"Resume Workout:`, `"Resume"`, `"Discard"` |
| 13. Test counts: 1 / 3 / 4 | PASS | `grep -c '@Test'` returns 1, 3, 4 for RoutinesListCopyTests / RoutineFolderDraftTests / ActiveSessionConflictTests respectively |
| 14. Parse-clean | PASS | `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` exits 0 |

## Tests

| Test | Suite | Asserts |
|------|-------|---------|
| verbatimCopy | RoutinesListCopy | 26 #expect checks pinning UI-SPEC § Routines tab + Move-routine sheet + ResumeWorkoutBanner strings across 5 source files |
| emptyDraftIsInvalid | RoutineFolderDraft | Empty name → isValid = false |
| whitespaceOnlyNameIsInvalid | RoutineFolderDraft | "   " name → isValid = false (regression case from CustomExerciseDraft convention) |
| namedDraftIsValid | RoutineFolderDraft | Trimmed-non-empty name → isValid = true |
| firstStartSucceeds | ActiveSessionConflict | No prior active session → SessionFactory.start returns a Session with completedAt == nil; SessionFactory.active(in:) returns that session |
| secondStartThrowsActiveSessionAlreadyExists | ActiveSessionConflict | RESEARCH §6 Pitfall 7 — the error code that RoutinesListView.handleStartTap catches and translates into the "Workout in Progress" alert |
| startAfterFinishingPriorSessionSucceeds | ActiveSessionConflict | completedAt set → next start succeeds |
| startAfterDiscardingPriorSessionSucceeds | ActiveSessionConflict | ctx.delete + save → next start succeeds (the "Discard" branch of the conflict alert) |

## Deviations from Plan

None of significance. The plan's source skeleton was implemented verbatim with three minor refinements:

1. **Banner mount on Today tab** — The plan said "Today tab placeholder: when SessionFactory.active(in: context) returns a Session, surface 'Resume workout: {Name}' banner." I implemented this by wrapping `PlaceholderTabView(phaseNumber: 2)` with `.safeAreaInset(edge: .top)` mounting the `ResumeWorkoutBanner`. This preserves the AC #2 grep check (`PlaceholderTabView(phaseNumber: 2)` returns 1 match) AND avoids nesting NavigationStack (the placeholder already owns one). The banner self-hides via `EmptyView()` when there's no active session, so the Today tab visually identical to before when nothing is in progress. Rationale recorded under `decisions`.

2. **Empty folder section placeholder** — The plan's source skeleton renders empty folders as headers with no body content. I added a faint `Text("No routines in this folder")` row (`.caption`, `.secondary`) so the user sees a visible affordance to drop routines into the folder. Without this, an empty folder appears as an orphan section header which is visually confusing. Recorded under `decisions`.

3. **Stable Unfiled section UUID** — The plan's source had `UUID()` called inline on every `body` invocation. I extracted this to a `static let unfiledSectionID = UUID()` so SwiftUI's `ForEach` diff sees the section as the same identity across redraws. Without this fix, the section would flicker / re-create the underlying state every body recomputation (animation glitch). This is a Rule 1 (bug) fix recorded in the `decisions` list.

All three are stylistic / correctness refinements within scope of the plan; nothing required user input.

## Threat Flags

None. This plan does not introduce new auth paths, network endpoints, file access patterns, or schema changes. All persistence touches use the existing `ModelContext` injected via `@Environment(\.modelContext)`, and all delete operations honor the soft-ref invariants documented in `CONTEXT.md` Area 6.

## Known Stubs

Three intentional stub call sites, documented at the source with `TODO plan {X-Y}` comments. These are documented stubs that the dependent plans will swap in:

| Stub | Location | Resolution plan |
|------|----------|-----------------|
| "New Routine" sheet body shows interim placeholder text | `RoutinesListView.swift` line ~115 | plan 03-02 (RoutineBuilderView) |
| Row-tap edit mode is a no-op | `RoutinesListView.swift` line ~191 (RoutineRow `onTap` closure passed to ForEach) | plan 03-02 (RoutineBuilderView) |
| `handleDuplicate(routine:)` is a no-op | `RoutinesListView.swift` line ~320 | plan 03-03 (RoutineDuplicator.duplicate) |
| Resume banner `onResume` closure is no-op (banner is reactive but post-tap navigation isn't wired) | `RoutinesListView.swift` line ~177, `RootView.swift` `TodayTabHost` | plan 04-01 (SessionLoggerView + NavigationPath wiring) |

The plan's anti-pattern list explicitly forbids implementing the destinations here — each stub has the dependent-plan number recorded both inline and in this section.

## Performance Notes

- All three `@Query` properties on `RoutinesListView` are routine-store-sized — at typical user-app scales (<100 routines, <10 folders, ≤1 active session) the queries are O(small).
- `sectionsForRendering` does two `routines.filter` passes per body invocation. For very large libraries this could be optimized with a single grouping pass, but for the expected scale (<100 routines) the linear scans are well below SwiftUI's body-recomputation threshold.
- `handleDelete` and `handleFolderDelete` each perform one `FetchDescriptor` query + N inserts/deletes + 1 save. The query is bound by routine.exercises (per-routine, small) or `routine.folderID == folderID` matches (per-folder, small) so no pagination is required.

## Self-Check: PASSED

All claimed deliverables verified:

- `fitbod/Routines/RoutinesListView.swift` — FOUND
- `fitbod/Routines/RoutineRow.swift` — FOUND
- `fitbod/Routines/NewFolderSheet.swift` — FOUND
- `fitbod/Routines/MoveRoutineSheet.swift` — FOUND
- `fitbod/Routines/RoutineFolderDraft.swift` — FOUND
- `fitbod/Sessions/ResumeWorkoutBanner.swift` — FOUND
- `fitbodTests/RoutinesListCopyTests.swift` — FOUND
- `fitbodTests/RoutineFolderDraftTests.swift` — FOUND
- `fitbodTests/ActiveSessionConflictTests.swift` — FOUND
- `fitbod/App/RootView.swift` modified (RoutinesListView wired, TodayTabHost added) — FOUND

Commit hashes verified in `git log --oneline`:
- `7a6dd7f feat(02-03-01): Routines tab + folders + Resume Workout banner` — FOUND
- `25a5ce0 test(02-03-01): Routines tab copy + folder draft + active-session conflict` — FOUND

Parse-clean exit code: 0 (`find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse`).
