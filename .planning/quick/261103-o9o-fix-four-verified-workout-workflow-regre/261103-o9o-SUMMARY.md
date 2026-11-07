---
phase: quick-261103-o9o
plan: "01"
status: complete
subsystem: sessions
tags: [swiftui, swiftdata, locale, validation, undo, units, regression-tests]
requires: []
provides:
  - Full-string localized correction parsing and checked numeric storage/rendering
  - Transactional variation Undo with complete pending and warm-up value snapshots
  - Exercise override-or-global summary and editor labels without conversion
affects: [workout-logger, workout-history, history-corrections]
tech-stack:
  added: []
  patterns:
    - Explicit invalid-row state independent of the last valid numeric value
    - Ephemeral value-snapshot restoration with rollback and retry
key-files:
  created: []
  modified:
    - fitbod/Sessions/SessionEditService.swift
    - fitbod/Sessions/SessionHistoryView.swift
    - fitbod/Sessions/WorkoutEditView.swift
    - fitbod/Sessions/SwapExerciseSheet.swift
    - fitbod/Sessions/SessionExerciseCard.swift
    - fitbod/App/StalledExerciseSeed.swift
    - fitbod/Sessions/SessionDetailView.swift
    - fitbod/Sessions/WorkoutEditDraft.swift
    - fitbodTests/Logger/SessionEditServiceTests.swift
    - fitbodTests/SwapExercisePrescriptionTests.swift
    - fitbodTests/SettingsUnitsIntegrationTests.swift
    - fitbodUITests/SessionHistoryBRUUITests.swift
    - fitbodUITests/WorkoutSwapJourneyUITests.swift
key-decisions:
  - Validate complete ungrouped locale input before updating numeric values; invalid text remains dirty and blocks Save.
  - Restore captured prescription and set metadata directly, never by swapping or re-evaluating history.
  - Keep exercise unit metadata only in the detached edit draft; aggregate workout labels keep their existing global-unit policy.
requirements-completed: [REG-01, REG-02, REG-03, REG-04]
duration: 45m 27s
completed: 2026-11-03
---

# Quick 261103-o9o Plan 01: Workout workflow regression fixes

**Locale-correct atomic corrections, non-trapping volume labels, captured-state variation Undo, and effective exercise-unit labels now have passing unit and real relaunch coverage.**

## Performance and handoff

- Started: 2026-11-04T01:44:15Z.
- Code and final validation finished: 2026-11-04T02:29:42Z.
- Tasks implemented: 3; verified regressions: REG-01 through REG-04.
- Implementation files modified: 13; no persisted model/schema changes, conversions, dependencies, or installs.
- The parent reviewed the final code diff and independently verified the final result bundles. PLAN/SUMMARY and STATE are recorded separately from the code commits; ROADMAP is unchanged.

## Atomic task commits

1. **Task 1 — locale input and safe correction volume:** `b8910f1`
2. **Task 2 — captured-state variation Undo:** `b55a763`
3. **Task 3 — effective exercise-unit labels:** `a3c4e52`

Each commit contains only that task's authorized source and tests. No tracked files were deleted.

## Changes delivered

- `SessionEditService.swift`: full-input locale parsing, matching initial number formatting, explicit supported-number checks, and pre-write validation of set/exercise/workout totals using checked `Int(exactly:)` representability.
- `WorkoutEditView.swift`: invalid row text cannot save zero or a stale value through another edit; invalid text triggers Cancel confirmation; fixing/deleting the row restores Save. Exercise volumes use the draft override or current global unit.
- `SessionHistoryView.swift`: shared safe rounded-volume formatting; unsupported values display `—`; ordinary rounding, grouping, zero omission, and compact `k` formatting are retained.
- `SwapExerciseSheet.swift`: ephemeral `VariationUndoSnapshot` captures the original name/prescription and every scalar of affected pending/warm-up sets, including IDs/order/skipped state. Restoration uses a checked transaction, rolls back failures, permits retry, and never assigns to completed working rows.
- `SessionExerciseCard.swift`: snapshot-based Undo, permanent invalidation on logging/explicit swaps, visible restoration errors, and refreshed row-local inputs after swap/Undo.
- `StalledExerciseSeed.swift`: opt-in DEBUG variation fixture reaches the real detector branch with flat history, sufficient weekly primary-muscle volume, no active block, and a logged matching Dumbbell Bench Press candidate. The ordinary stalled seed retains its behavior.
- `SessionDetailView.swift`: resolve per-exercise units by `SessionExercise.id`, pass them through set text/accessibility/volume, and reuse safe aggregate-volume rendering.
- `WorkoutEditDraft.swift`: optional unit override is transient display metadata only.
- Three unit suites and two real UI suites cover these behaviors, including duplicate exercise snapshot names and relaunch without reset.

## Verification

Every `scripts/test.sh` invocation used:

- `FITBOD_TEST_DEVICE=141B2C6B-3E81-4015-90A0-2F65784DFD16`
- `FITBOD_TEST_WORKERS=1`
- `FITBOD_TEST_DD=/tmp/fitbod-fixes-138321cc-dd`
- `FITBOD_TEST_OUT=/Users/csaechao4/.copilot/session-state/138321cc-82fd-4c42-9a09-cda2ae2e448e/files/fix-results`

Only the dedicated iPhone 17e ran tests, serially, at the 390-point support floor with default text/light appearance. Journeys reset only their initial launch and use `UITestNavigation.relaunch` without reset/seed arguments for persistence assertions.

Result bundle paths below are relative to the `FITBOD_TEST_OUT` directory above. Counts are the test harness/xcresult top-level test counts, not expanded parameter-case runs.

| Validation | Passed | Failed | Expected failures | Skipped | Result bundle |
|---|---:|---:|---:|---:|---|
| Task 1 RED numeric reproduction | 6 | 3 | 0 | 0 | `fast-20261103-174643/fast.xcresult` |
| Task 1 focused units | 15 | 0 | 0 | 0 | `fast-20261103-175000/fast.xcresult` |
| Task 1 History/editor UI | 4 | 0 | 0 | 0 | `fast-20261103-175027/fast.xcresult` |
| Task 2 RED Undo reproduction | 11 | 1 | 0 | 0 | `fast-20261103-175548/fast.xcresult` |
| Task 2 final focused units | 16 | 0 | 0 | 0 | `fast-20261103-181336/fast.xcresult` |
| Task 2 final swap/variation UI | 4 | 0 | 0 | 0 | `fast-20261103-181126/fast.xcresult` |
| Task 3 RED hosted unit-label reproduction | 2 | 1 | 0 | 0 | `fast-20261103-181610/fast.xcresult` |
| Task 3 focused units | 8 | 0 | 0 | 0 | `fast-20261103-181731/fast.xcresult` |
| Task 3 both override/relaunch UI journeys | 2 | 0 | 0 | 0 | `fast-20261103-181858/fast.xcresult` |
| **Final whole unit target** | **1233** | **0** | **1** | **0** | **`fast-20261103-182050/fast.xcresult`** |
| **Final serial UI selection** | **11** | **0** | **0** | **0** | **`fast-20261103-182250/fast.xcresult`** |

Final UI enumeration confirmed all six `SessionHistoryBRUUITests`, all four `WorkoutSwapJourneyUITests`, and `NumberEntryUITests/testLoggerWeightAndRepsTypeOver` ran and passed. This includes comma correction, invalid draft cancellation, correction save/delete/relaunch, both unit directions, explicit swap persistence, complete Undo/relaunch, and permanent Undo invalidation.

The supplied baseline was 1241 passes plus one expected failure at `a21dffc`. The shared checkout already contained `5e63c71` on entry, whose cleanup removed 28 `@Test` declarations net. These fixes add 20 tests: **1241 - 28 + 20 = 1233 passes**, with the same one expected failure. No tests were removed, skipped, disabled, or newly marked expected-failure by these fixes.

`git diff --check` passed. Builds succeeded for final focused/full runs. GitNexus upstream impacts were run before existing-symbol edits; CRITICAL UI reach was reported. Each pre-commit `detect-changes --scope all` reported exactly the five expected task files. Stale indexes were refreshed with the existing CLI's `analyze --force --index-only`.

## Deviations from plan

### Auto-fixed blocking issue

**[Rule 3 — Blocking] Present the variation sheet from one concrete card row.**
- Found during Task 2's real variation journey.
- The Section-mounted sheet remained below the screen: captured hierarchy showed the sheet at y=844 and the candidate at y=949 on a 390×844 window. Waiting/scrolling did not make it selectable.
- Moved the variation presentation and its new failure alert to the single header row. The same candidate-selection and restoration assertions then passed.
- File: `fitbod/Sessions/SessionExerciseCard.swift`; commit: `b55a763`.

### Execution adjustments

- Preserved the newer pre-existing `5e63c71` cleanup rather than resetting the shared checkout to the prompt's older base; the unit-count difference is audited above.
- Used the already-created dedicated simulator; created no phones/clones and touched no other simulator.
- Narrowed NumberEntry validation to the authorized logger weight/reps case because other number-entry screens are unchanged; new editor correction tests cover the affected editor inputs.
- Followed the requested three atomic passing code/test commits; RED failures were recorded before implementation, with tests and fixes committed together per task.
- No SwiftLint/SwiftFormat CLI was installed. Used existing builds/tests and whitespace checks, without installing tools or reformatting unrelated code.

## Issues encountered and resolved

- A new fixture guard initially treated catalog primary-muscle metadata as comma-delimited. Read-only inspection of the dedicated test store established the actual `|chest|` representation; the guard was corrected without changing detector logic or forcing a chip.
- New UI selectors were corrected to match BRU labels case-insensitively and wait for concrete picker targets. The empty reps field is exposed as its `—` placeholder, which the reset assertion now checks.
- Intermediate Task 2 failing UI evidence remains available: `fast-20261103-180035`, `fast-20261103-180300`, and `fast-20261103-180544` each had 1 pass/3 failures; diagnostic `fast-20261103-180835` and placeholder-contract `fast-20261103-181018` each had 0 passes/1 failure. Each directory contains `fast.xcresult`. All final gates passed after the documented corrections.
- Pre-existing unit fixtures warn about uninstalled `@State`, and existing logger/UI paths warn about invalid frame dimensions. Both final test runs pass; unrelated layout and fixture cleanup remains deferred under `docs/DEVELOPMENT.md`.
- The configured `swift-reviewer` agent could not launch because its `sonnet` model alias is unavailable. The parent completed the final Swift review directly, covering all 13 changed source/test files, with no blocking findings.

## Stub and threat checks

No unimplemented paths or goal-blocking stubs remain. Empty field/unsupported-volume em dashes are deliberate display contracts. No new network, auth, file-access, or schema trust boundary was introduced beyond the plan's text-validation, Undo, and DEBUG-fixture surfaces.

## Completion

The three code commits are reviewed, final unit/UI results are independently checked, and STATE records the completed quick task. User-owned `.lavish` files and the concurrent `5e63c71` cleanup are preserved. Incidental GitNexus skill copies generated during the parent's index repair were removed; tracked AGENTS/CLAUDE/.gitignore metadata is unchanged.

## Self-Check: PASSED

All 13 changed source/test files, the plan, and this summary exist. All three task commits resolve in git. No schema, dependency, conversion, or unrelated code changes were made. GitNexus was refreshed using index-only mode. Only the dedicated test simulator was used for validation.
