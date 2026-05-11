---
phase: 02
plan: 04-03
subsystem: session-logger
tags: [session-logger, notes, workout-notes, pinned-notes, per-set-notes, swiftui, swiftdata, sess-02, sess-11, wave-4]
requires:
  - "Plan 00-01 (SessionExercise.pinnedNote SchemaV2 additive field)"
  - "Plan 04-01 (SessionLoggerView header notes-chip TODO + SetRow notes-button anchor)"
  - "Plan 04-02 (SessionExerciseCard long-press menu 'Edit Pinned Note' stub)"
provides:
  - "WorkoutNotesSheet — workout-level notes editor bound to @Bindable session.notes"
  - "PerSetNoteSheet — per-set form-notes editor bound to @Bindable entry.notes"
  - "PinnedNoteSheet — per-exercise pinned-note editor bound to @Bindable sessionExercise.pinnedNote"
  - "PinnedNoteCapsule — inline pin.fill yellow capsule rendered above the column-header row when pinnedNote != nil"
  - "SessionExerciseCard.onEditPinnedNote — new init closure parameter wired to PinnedNoteSheet presentation"
affects:
  - "Wave 4 closure — SESS-02 + SESS-11 closed; together with 04-01 + 04-02 ships every user-visible SESS-* requirement (1-11)"
tech-stack:
  added: []
  patterns:
    - "UI-SPEC § Session logger verbatim — Workout Notes, Notes for this session, Done, Set {N} Note, e.g. right knee caved on rep 7, Pinned Note, Save, Cancel, Pinned note: {note}, Tap to edit, Note for set {N}"
    - "UI-SPEC Asset Contract — pin.fill (SF Symbol) on Color(.systemYellow).opacity(0.15) capsule (verbatim background; NOT Color.yellow)"
    - "SwiftUI .sheet(isPresented:) for workout-level / per-set notes (single-instance presentations)"
    - "SwiftUI .sheet(item: SessionExercise?) for pinned-note editor — same lifecycle pattern as plan 04-02's pendingSwap"
    - "Empty-string → nil normalization in every sheet's Binding(get:set:) — keeps 'has notes?' predicates simple downstream"
    - "Bindable model-direct mutation — no parallel @Observable draft wrapper (UI-SPEC anti-pattern explicitly avoided)"
    - "PinnedNoteCapsule render predicate (`if let note = se.pinnedNote, !note.isEmpty`) — defensive double-check against legacy empty-string rows"
    - "Per-set notes button foreground tint (accent when notes != nil, secondary-label otherwise) — UI-SPEC anti-pattern compliance ('empty-notes buttons stay quiet')"
key-files:
  created:
    - "fitbod/Sessions/WorkoutNotesSheet.swift"
    - "fitbod/Sessions/PerSetNoteSheet.swift"
    - "fitbod/Sessions/PinnedNoteSheet.swift"
    - "fitbod/Sessions/PinnedNoteCapsule.swift"
    - "fitbodTests/NotesPersistenceTests.swift"
  modified:
    - "fitbod/Sessions/SessionLoggerView.swift"
    - "fitbod/Sessions/SessionExerciseCard.swift"
    - "fitbod/Sessions/SetRow.swift"
decisions:
  - "Used the simpler `.sheet(isPresented:)` for WorkoutNotesSheet (the chip is on the header — only one possible target at any time) but `.sheet(item: SessionExercise?)` for PinnedNoteSheet (the trigger could fire from any of N cards in the list). Matches plan 04-02's existing pendingSwap / pendingRemove pattern for SessionExercise-keyed lifecycle."
  - "Made `onEditPinnedNote` a default-argument closure (`= { _ in }`) on SessionExerciseCard's init — same approach plan 04-02 used for `onSwap` / `onRemove`. Plan 04-01's #Preview block in SessionExerciseCard.swift continues to compile unchanged with two explicit closures; the third gets a quiet no-op default."
  - "Wired BOTH the long-press menu 'Edit Pinned Note' entry AND a tap on the inline PinnedNoteCapsule to the same `onEditPinnedNote` closure — single edit entry point for the same data, two affordances for discovery (the contextMenu surface is power-user; the capsule tap is the discoverable inline affordance once a note exists)."
  - "Empty-string → nil normalization applied uniformly across all three sheets via `set: { model.field = $0.isEmpty ? nil : $0 }`. This keeps downstream `field != nil` predicates simple and matches the plan body's defensive emptyStringNotesPersistAsNil test predicate."
  - "Two atomic commits (S-sized plan, ~440 LOC across 4 new sources + 3 modifications + 1 test): (1) the four new view files + the integration into the three existing files, (2) the NotesPersistenceTests suite. Production code lands before tests per the project's established multi-commit-per-plan convention."
  - "PinnedNoteSheet keeps both Save AND Cancel toolbar buttons (UI-SPEC verbatim), but neither performs a persistence action — the @Bindable write-through handles persistence on every keystroke. The buttons are UX affordances (clear 'I'm done' / 'I changed my mind' exit points). WorkoutNotesSheet has only 'Done' per the UI-SPEC distinction (workout notes are short-lived to the session; pinned notes live across sessions via the snapshot field)."
metrics:
  duration_seconds: 195
  completed: "2026-05-11T18:19:22Z"
  files_created: 5
  files_modified: 3
  commits: 2
  test_count: 4
  loc_added: 431
---

# Phase 2 Plan 04-03: Session Notes (Workout / Pinned Per-Exercise / Per-Set) Summary

Three small SwiftUI sheets + one inline rendering view + three integration touch-ups close out Wave 4 of Phase 2. The header `square.and.pencil` chip in `SessionLoggerView` (anchored by plan 04-01 as a TODO) now presents `WorkoutNotesSheet` bound to `session.notes`. The long-press menu "Edit Pinned Note" entry on `SessionExerciseCard` (stubbed by plan 04-02) now presents `PinnedNoteSheet` bound to `sessionExercise.pinnedNote` — and an inline `PinnedNoteCapsule` ALSO renders above the column-header row whenever a pinned note is populated, tapping which opens the same sheet. A new `square.and.pencil` icon button on `SetRow` (placed BEFORE the completion checkmark) presents `PerSetNoteSheet` bound to `entry.notes`. All three sheets share the same write-through `Binding(get:set:)` pattern with empty-string → nil normalization so downstream "has notes?" predicates stay simple. Four `@Test` functions in `NotesPersistenceTests` pin the SwiftData round-trip for each field plus the defensive empty-string → nil normalization. Two atomic commits. Together with plans 04-01 + 04-02, this finishes the user-visible SESS-* surface (1-11) for Phase 2.

## Goal

Close the SESS-02 (per-set form notes) + SESS-11 (workout-level + pinned per-exercise notes inline) contracts that plan 04-01 anchored placement for but deferred the actual sheet UI of. Ship the three notes editor sheets, the inline yellow pinned-note capsule, and the integration into the existing session-logger surface — without touching the underlying SwiftData schema (all three fields landed in earlier plans: `Session.notes` from Phase 1, `SetEntry.notes` from Phase 1, `SessionExercise.pinnedNote` from plan 00-01's SchemaV2 additive delta).

## Requirements Covered

- **SESS-02** (per-set form notes) — `PerSetNoteSheet` binds `entry.notes` via `Binding(get:set:)` with empty-string → nil normalization. The `square.and.pencil` icon button is anchored before the completion checkmark on `SetRow`, with UI-SPEC verbatim a11y label "Note for set {N}". The button's foreground tints to accent when a note is populated (visual signal) and secondary-label otherwise (per UI-SPEC's anti-pattern compliance — "empty-notes buttons stay quiet"). `NotesPersistenceTests/setEntryNoteRoundTrip` pins the round-trip.

- **SESS-11** (workout-level + pinned per-exercise notes inline) —
  - **Workout-level:** `WorkoutNotesSheet` binds `session.notes` via the same Binding pattern; presented from the `square.and.pencil` header chip that plan 04-01 anchored as a TODO. The sheet has only a "Done" toolbar button per UI-SPEC verbatim (write-through is implicit in the binding). `NotesPersistenceTests/sessionNotesRoundTrip` pins the round-trip.
  - **Pinned per-exercise:** `PinnedNoteSheet` binds `sessionExercise.pinnedNote` (the SchemaV2 additive field from plan 00-01); presented from the `SessionExerciseCard` header's long-press menu "Edit Pinned Note" entry (the stub from plan 04-02) AND from tapping the inline `PinnedNoteCapsule` directly. The capsule renders a `pin.fill` SF Symbol + 2-line caption on a `Color(.systemYellow).opacity(0.15)` background (UI-SPEC verbatim — NOT `Color.yellow`). `NotesPersistenceTests/pinnedNoteRoundTrip` pins the round-trip.

## Files

| Path | Status | Purpose | LOC |
|------|--------|---------|----:|
| `fitbod/Sessions/WorkoutNotesSheet.swift` | NEW | Workout-level notes editor — Form + TextField bound to `session.notes` with empty-string → nil normalization; "Done"-only toolbar | 56 |
| `fitbod/Sessions/PerSetNoteSheet.swift` | NEW | Per-set form-notes editor — Form + TextField bound to `entry.notes`; navigation title "Set {N} Note" | 52 |
| `fitbod/Sessions/PinnedNoteSheet.swift` | NEW | Per-exercise pinned-note editor — Form + TextField bound to `sessionExercise.pinnedNote`; "Save"/"Cancel" toolbar (both dismiss; persistence is binding-driven) | 64 |
| `fitbod/Sessions/PinnedNoteCapsule.swift` | NEW | Inline `pin.fill` capsule on `Color(.systemYellow).opacity(0.15)`; renders above column-header row when `pinnedNote != nil`; tap fires `onTap` closure | 64 |
| `fitbod/Sessions/SessionLoggerView.swift` | MODIFIED | + `presentingWorkoutNotes` / `pendingPinnedNote` @State; + 2 sheet modifiers; + `onEditPinnedNote: { pendingPinnedNote = $0 }` passed to SessionExerciseCard; header notes button TODO replaced with `presentingWorkoutNotes = true` | +21 |
| `fitbod/Sessions/SessionExerciseCard.swift` | MODIFIED | + `onEditPinnedNote: (SessionExercise) -> Void` init closure with `= { _ in }` default; + conditional `PinnedNoteCapsule` render block above column-header row; long-press menu "Edit Pinned Note" TODO replaced with `onEditPinnedNote(sessionExercise)` | +12 |
| `fitbod/Sessions/SetRow.swift` | MODIFIED | + `presentingSetNote` @State; + per-set notes Button (square.and.pencil icon, accent when notes != nil, secondary-label otherwise, UI-SPEC a11y "Note for set {N}") placed before the completion checkmark with attached `.sheet(isPresented:)` for `PerSetNoteSheet` | +20 |
| `fitbodTests/NotesPersistenceTests.swift` | NEW | 4 `@Test` functions — sessionNotesRoundTrip, pinnedNoteRoundTrip, setEntryNoteRoundTrip, emptyStringNotesPersistAsNil; in-memory ModelContainer over Schema(SchemaV2.models) + FitbodSchemaMigrationPlan | 123 |

**Total:** 5 files created, 3 modified, ~431 LOC added.

## Acceptance Criteria

All 11 acceptance criteria from PLAN.md verified mechanically via the plan's grep commands.

| AC | Criterion | Status |
|----|-----------|:------:|
| 1 | `WorkoutNotesSheet.swift` has UI-SPEC verbatim placeholder + title + `@Bindable session: Session` | PASS (3 functional matches lines 32/42/49) |
| 2 | `PerSetNoteSheet.swift` has UI-SPEC verbatim placeholder + title format | PASS (2 functional matches lines 41/48) |
| 3 | `PinnedNoteSheet.swift` has UI-SPEC verbatim navigation title "Pinned Note" | PASS (1 match line 54) |
| 4 | `PinnedNoteCapsule.swift` renders `pin.fill` SF Symbol on `Color(.systemYellow).opacity(0.15)` background | PASS (2 functional matches lines 46/55) |
| 5 | `PinnedNoteCapsule.swift` uses UI-SPEC verbatim a11y "Pinned note: {note}" + "Tap to edit" | PASS (2 matches lines 59/60) |
| 6 | `SessionLoggerView.swift` has `presentingWorkoutNotes` + `WorkoutNotesSheet(session: session)` wire | PASS (4 matches across @State decl + sheet modifier + button body) |
| 7 | `SessionExerciseCard.swift` renders conditional `PinnedNoteCapsule(note:` + carries `onEditPinnedNote` init param | PASS (7 matches across decl + init param + closure body + menu entry + capsule render) |
| 8 | `SetRow.swift` has `Image(systemName: "square.and.pencil")` + `PerSetNoteSheet(entry: entry)` | PASS (2 matches lines 137/145) |
| 9 | `SetRow.swift` has UI-SPEC verbatim a11y `"Note for set {N}"` | PASS (1 match line 143) |
| 10 | `NotesPersistenceTests.swift` has exactly 4 `@Test` functions | PASS (`grep -c '@Test'` → 4) |
| 11 | Parse-clean: `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` exits 0 | PASS (silent stdout, exit 0) |

## Test Matrix Shipped

`NotesPersistenceTests` (4 tests — in-memory SwiftData fixture pattern mirroring `SetRowCommitTests` / `MidSessionSwapTests`):

| Test | Asserts |
|------|---------|
| `sessionNotesRoundTrip` | `session.notes = "Felt strong on bench today"` → fetch round-trip preserves the string verbatim |
| `pinnedNoteRoundTrip` | `sessionExercise.pinnedNote = "Keep elbows tucked"` → fetch round-trip preserves the string verbatim |
| `setEntryNoteRoundTrip` | `setEntry.notes = "Right knee caved on rep 7"` → fetch round-trip preserves the string verbatim |
| `emptyStringNotesPersistAsNil` | The shared `Binding(get:set:) {  $0.isEmpty ? nil : $0 }` normalization round-trips to `nil`, not to an empty string — defensive contract pin to keep `notes != nil` predicates simple downstream |

All four tests use the production wiring (`Schema(SchemaV2.models)` + `FitbodSchemaMigrationPlan.self` + `ModelConfiguration(isStoredInMemoryOnly: true)`) — same hermetic fixture pattern used by every SwiftData round-trip test added across Phase 2.

End-to-end visual rendering — the sheet `Form` layouts, the pinned-note capsule's `pin.fill` icon + yellow background, the per-set notes button's accent / secondary-label foreground swap — is deferred to **on-device manual verification** per the project's stance.

## Architecture Patterns Demonstrated

- **Single write-through binding shape for all three sheets:** every sheet's TextField uses `Binding(get: { model.field ?? "" }, set: { model.field = $0.isEmpty ? nil : $0 })`. The pattern keeps the model's optional field non-empty-when-populated and nil-when-cleared, eliminating the empty-string boundary case from every downstream "has notes?" predicate. No "Save" persistence button anywhere; persistence is the implicit SwiftData save lifecycle (or `try? ctx.save()` on commit elsewhere). The "Save" / "Cancel" buttons on `PinnedNoteSheet` are pure UX affordances — both just call `dismiss()`.

- **Two presentation idioms for two scopes:** `WorkoutNotesSheet` uses `.sheet(isPresented:)` (one possible target, lifecycle bound to a boolean) while `PinnedNoteSheet` uses `.sheet(item: SessionExercise?)` (N possible targets, lifecycle bound to which exercise was tapped). This is the exact same split plan 04-02 used for `pendingSwap` / `pendingRemove` — consistent SwiftUI idiom across the entire Wave-4 surface.

- **Single closure feeds two affordances:** `onEditPinnedNote` is wired to BOTH the long-press menu "Edit Pinned Note" entry on `SessionExerciseCard`'s header AND a tap on the inline `PinnedNoteCapsule`. One closure → two discovery affordances → one sheet → one model binding. The capsule is the discoverable inline path once a note exists; the menu is the power-user path to create the first one.

- **Default-argument closure parameters keep backward compat:** `SessionExerciseCard.init`'s `onEditPinnedNote: (SessionExercise) -> Void = { _ in }` matches plan 04-02's `onSwap` / `onRemove` precedent. The card's existing #Preview block (plan 04-01) compiles unchanged because the new parameter has a quiet no-op default; only the production call site in `SessionLoggerView` passes a real handler.

- **PinnedNoteCapsule colocates the render predicate with the model field:** the capsule renders only when `if let note = sessionExercise.pinnedNote, !note.isEmpty`. The double check (non-nil AND non-empty) is defensive against legacy rows that might have been written with an empty string before this plan's normalization landed — though those would be theoretical since `SchemaV2.SessionExercise.pinnedNote` defaults to `nil` and the only writers are this plan's three sheets, which all normalize empty → nil.

- **Per-set notes button foreground tint as the populated-state signal:** the `square.and.pencil` button's foreground swaps between `Color.accentColor` (notes != nil) and `Color.secondary` (notes == nil). Per UI-SPEC's anti-pattern callout — "empty-notes buttons stay quiet" — this keeps the per-set surface unclutered while signaling state to the user.

- **UI-SPEC Asset Contract compliance:** `pin.fill` (not `pin`) for the pinned-note capsule + the long-press menu entry icon; `square.and.pencil` for both the workout-notes header chip AND the per-set notes button. `Color(.systemYellow).opacity(0.15)` (NOT `Color.yellow.opacity(0.15)`) for the capsule background — the asset-catalog system yellow auto-adapts dark mode while the SwiftUI literal does not.

## Deviations from Plan

**None — plan executed exactly as written.**

The plan body's file shapes (`WorkoutNotesSheet`, `PerSetNoteSheet`, `PinnedNoteSheet`, `PinnedNoteCapsule`) were copied verbatim from the plan body into the source tree with the exact field names, helper methods, UI-SPEC verbatim copy strings, and binding shapes. The three modifications to existing files (`SessionLoggerView` / `SessionExerciseCard` / `SetRow`) follow the plan body's prescription line-for-line: `presentingWorkoutNotes` + `pendingPinnedNote` @State; `onEditPinnedNote` closure parameter; conditional `PinnedNoteCapsule` render; per-set notes button placement before the completion checkmark.

### Auth gates encountered

None — this plan is pure SwiftUI + SwiftData; no network, no API keys, no permission prompts. The notification permission gate from plan 02-01's `LiveNotificationScheduler` is unchanged (still pending on first `engine.start(...)`).

## Known Stubs

None — every notes surface (workout-level / pinned per-exercise / per-set form) is fully wired end-to-end. The previously stubbed surfaces (plan 04-01's header notes chip TODO and plan 04-02's "Edit Pinned Note" menu entry stub) are now functional.

## Threat Flags

None — this plan introduces no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The three notes fields (`Session.notes`, `SessionExercise.pinnedNote`, `SetEntry.notes`) all pre-existed in the SwiftData schema before this plan; the only additions are the sheet views and their bindings.

## TDD Gate Compliance

Plan frontmatter is **not** `type: tdd` (it's a standard Wave 4 plan). The plan-level RED/GREEN gate sequence does not apply. Within the plan, the production code commit (1 × `feat`) preceded the test commit (1 × `test`) per the project's established multi-commit-per-plan convention.

## Commits

| Hash | Type | Summary |
|------|------|---------|
| `15927f5` | feat | Four new view files (WorkoutNotesSheet / PerSetNoteSheet / PinnedNoteSheet / PinnedNoteCapsule) + integration into SessionLoggerView / SessionExerciseCard / SetRow |
| `15b2f46` | test | NotesPersistenceTests (4 round-trip tests with empty-string → nil defensive verification) |

Two atomic commits on the main branch with the project's per-task convention. The SUMMARY commit follows separately.

## What this unblocks

- **Wave 4 closure** — together with plans 04-01 + 04-02, this finishes the user-visible session-logger surface for Phase 2. Every SESS-* requirement (1-11) is now closed:
  - SESS-01 / SESS-02 / SESS-03 / SESS-04 / SESS-09 / SESS-11 — plan 04-01
  - SESS-05 / SESS-06 / SESS-07 / SESS-08 — plan 04-02
  - SESS-02 (full) / SESS-11 (full) — plan 04-03 (this plan)
- **Plan 05-01 (per-exercise history with intent split)** — the read-side companion to the write-side session logger. With the logger fully shipped, plan 05-01 ships the history view that consumes the data written by plans 04-01 / 04-02 / 04-03. End-to-end Phase 2 minimum-lovable-product is then complete.
- **End-to-end Phase 2 lifecycle is now fully wireable:** Routines tab → "Start Workout" swipe → SessionFactory.start → SessionLoggerView pushes → tap header "Notes" chip → workout notes captured → long-press an exercise card → "Edit Pinned Note" → pinned note captured (or inline tap on capsule once populated) → tap the per-set notes icon on SetRow → form note captured → log sets with rest timer → swap/add mid-session → Finish → session.completedAt = .now → dismiss. Every Phase 2 user-visible flow is now reachable.

## Self-Check: PASSED

**Files claimed created — verified on disk:**
- `fitbod/Sessions/WorkoutNotesSheet.swift` — FOUND
- `fitbod/Sessions/PerSetNoteSheet.swift` — FOUND
- `fitbod/Sessions/PinnedNoteSheet.swift` — FOUND
- `fitbod/Sessions/PinnedNoteCapsule.swift` — FOUND
- `fitbodTests/NotesPersistenceTests.swift` — FOUND

**Files claimed modified — verified on disk:**
- `fitbod/Sessions/SessionLoggerView.swift` — FOUND (presentingWorkoutNotes + pendingPinnedNote @State; both sheet modifiers; onEditPinnedNote passed to SessionExerciseCard; header notes button wired)
- `fitbod/Sessions/SessionExerciseCard.swift` — FOUND (onEditPinnedNote closure parameter; PinnedNoteCapsule render block; long-press menu "Edit Pinned Note" wired)
- `fitbod/Sessions/SetRow.swift` — FOUND (presentingSetNote @State; per-set notes button before completion checkmark; PerSetNoteSheet sheet modifier)

**Commits claimed — verified in git log:**
- `15927f5` (feat — four new view files + three file integrations) — FOUND
- `15b2f46` (test — NotesPersistenceTests with 4 round-trip @Test functions) — FOUND

**Parse-clean (AC11):** `find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse` → silent stdout, exit 0.
