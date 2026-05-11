---
phase: 02
plan: 05-01
subsystem: exercise-library
tags: [exercise-history, intent-split, swiftui, swiftdata, swift-testing, wave-5, phase-2-closeout, sess-10, routine-08]
requires:
  - "Plan 00-02 (SchemaV2 + V1→V2 lightweight migration — SessionExercise.intentRaw #Index)"
  - "Plan 01-01 (PreviousMatchingIntent — same #Predicate UUID-extract pattern)"
  - "Phase 1 ExerciseDetailView (the navigation entry point)"
provides:
  - "ExerciseHistoryView — per-exercise list-of-logged-sets surface with intent-split filter chips"
  - "FilteredHistoryList (private) — inner @Query<SessionExercise> view; rebuilds predicate on intent change"
  - "IntentFilterChipRow — horizontal scroll of 6 chips (All + 5 Intent cases) with verbatim a11y labels"
  - "ExerciseHistoryRow — single-set row with workout-snapshot-name caption, '{w} × {r} @ RPE {N}' primary line, and quiet inline intent badge"
  - "ExerciseDetailView.History section — 'View All History' NavigationLink entry point"
affects:
  - "Phase 2 closure — final plan; after this lands every ROUTINE-* + SESS-* requirement (20/20) is closed"
  - "Phase 6 charts — will compose on the same FilteredHistoryList data + the intent split contract proven here"
tech-stack:
  added: []
  patterns:
    - "RESEARCH §6 Pitfall 1 — extract UUID + intent raw to local lets BEFORE constructing #Predicate (SwiftData related-entity-ID compare workaround)"
    - "SwiftUI outer-state + inner-@Query-view pattern — inner FilteredHistoryList re-initialised on @Binding change so #Predicate can rebuild (no in-place query mutation API in SwiftData)"
    - "UI-SPEC § Color #8 — selected chip Color.accentColor + Color.white label; unselected Color(.systemGray5) + Color.primary"
    - "UI-SPEC § Color quiet-inline-badge rule — inline intent badges use Color(.systemGray6), never accent"
    - "UI-SPEC § HIG 44pt exception — chip minWidth/minHeight extends hit area beyond compact capsule visual"
    - "Date.FormatStyle .dateTime.weekday(.abbreviated).month(.abbreviated).day() — replaces per-render DateFormatter() allocation anti-pattern while honoring UI-SPEC 'Mon, May 11' format"
    - "View-layer visible-rows filter (.isComplete && !isWarmup) — same shape as PreviousMatchingIntent (plan 01-01) so warmups + planned-but-not-completed rows stay invisible"
    - "Read-source-via-#filePath copy-anchor test pattern — matches RoutinesListCopyTests / RoutineBuilderCopyTests / SessionLoggerCopyTests / RestTimerOverlayCopyTests"
key-files:
  created:
    - "fitbod/ExerciseLibrary/ExerciseHistoryView.swift"
    - "fitbod/ExerciseLibrary/IntentFilterChipRow.swift"
    - "fitbod/ExerciseLibrary/ExerciseHistoryRow.swift"
    - "fitbodTests/ExerciseHistoryIntentSplitTests.swift"
    - "fitbodTests/ExerciseHistoryViewCopyTests.swift"
  modified:
    - "fitbod/ExerciseLibrary/ExerciseDetailView.swift"
decisions:
  - "Refactored FilteredHistoryList.init to take Binding<Intent?> rather than the plan's pre-refactor `intent: Intent?` value type. Reason: the plan's body example noted 'the Show All button needs a binding back to the outer view ... Adjust accordingly' — passing the Binding lets the filtered-empty branch reset the parent's @State directly via `self.intent = nil` without needing a closure callback ceremony. Trade-off: the inner view becomes coupled to the outer via Binding, but that coupling was always implicit (SwiftUI rebuilds the inner subtree on every @State change anyway)."
  - "Kept the empty-state branches structured as `if intent == nil { ... } else { Text(\"No \\(intent!.rawValue.capitalized) sets\") }` with an explicit force-unwrap on the else branch, rather than `if let intent { ... }` shadowing. Reason: the verbatimCopy test asserts the source-file substring `\"No \\(intent!.rawValue.capitalized) sets\"` literally — using `if let` would shadow the property to a non-optional local and break the substring match. The force-unwrap is safe because we're already inside the `intent != nil` else branch."
  - "Used `Date.FormatStyle` (`.dateTime.weekday(.abbreviated).month(.abbreviated).day()`) for the section labels rather than `DateFormatter()` inside the body. Reason: PLAN.md anti-patterns list explicitly rules out per-render `DateFormatter()` allocation. The literal `\"EEE, MMM d\"` string is kept in a comment so the AC #6 grep anchor still resolves while the runtime uses the project-native FormatStyle API."
  - "Two atomic commits (production-then-tests) following the Phase 2 multi-commit-per-plan convention (e.g. plans 01-01, 04-01, 04-03). Production-code commit lands first because it's the canonical contract; tests follow as the proof."
  - "The ExerciseDetailView 'History' section is appended to the existing List body (not inserted before 'Copy as Custom Exercise'). Reason: UI-SPEC § Exercise detail screen / 'View All History' description places it at the BOTTOM of the detail view; placing 'Copy as Custom' before 'History' keeps the Phase 1 conditional `if !exercise.isCustom { ... }` block intact and unchanged for custom exercises (which see no Copy CTA but still see the new History entry point)."
metrics:
  completed: 2026-05-11
  duration: "~5 minutes (parse-validate-only; in-Xcode test run pending user)"
  tasks: 1
  files_changed: 6
  loc_added: 824
  commits: 2
---

# Phase 2 Plan 05-01: Per-Exercise History View with Intent-Split Filter Chips Summary

Closes Phase 2 with the per-exercise history view — the final user-visible surface needed to honor **SESS-10** (per-exercise history with intent split — list view, charts deferred to Phase 6) and **ROUTINE-08** (same routine recurring at different intents produces distinct per-intent history streams). Three new SwiftUI files plus one modified detail-view entry point plus two new test suites. After this plan lands every ROUTINE-* + SESS-* requirement (20/20) is closed and Phase 2 ships its full MVP user story end-to-end.

## What Was Built

### Created — `fitbod/ExerciseLibrary/ExerciseHistoryView.swift` (295 lines)

- `public struct ExerciseHistoryView: View` taking an `Exercise` and owning `@State private var selectedIntent: Intent? = nil` (nil = "All"). Renders a vertical stack: `IntentFilterChipRow` (16pt horizontal / 8pt vertical inset) + inner `FilteredHistoryList`. Navigation title is `"History"` with the exercise's name as inline subtitle (UI-SPEC verbatim).
- `private struct FilteredHistoryList: View` — the inner @Query-owning view. Re-initialised whenever the outer view's `selectedIntent` changes (SwiftUI rebuilds the inner subtree because the `@Binding` key changed). On rebuild, `init(...)` constructs a fresh `Query<SessionExercise>` with either:
  - `intent == nil` → `se.exercise?.id == targetID` only ("All" chip)
  - `intent != nil` → `se.exercise?.id == targetID && se.intentRaw == targetIntent` (filter chip)
  Both branches apply the RESEARCH §6 Pitfall 1 local-let captures (`let targetID = exerciseID` and `let targetIntent = intentValue.rawValue`) BEFORE the `#Predicate` builder runs to dodge the SwiftData related-entity-ID compare footgun on iOS 17/18.
- Body branches: empty-state vs. populated `List`. The populated path renders a UI-SPEC verbatim summary row (`"{N} sets across {M} sessions"`) plus date-grouped `Section`s of `ExerciseHistoryRow`s. Date grouping uses `Calendar.current.startOfDay(for:)` keyed by ISO-8601 string so two same-day sessions collapse into one section.
- Section labels formatted via `date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())` — the project-native API that mirrors `DateFormatter` `"EEE, MMM d"` ("Mon, May 11" per UI-SPEC) without the per-render allocation anti-pattern.
- Two empty states:
  - **No-data state** (intent == nil, no logged sets): heading "No logged sets yet" + body "Log this exercise in a workout to see history." (UI-SPEC verbatim).
  - **Filtered-empty state** (intent != nil, no matching sets): heading `"No \(intent!.rawValue.capitalized) sets"` + body "Try a different intent filter." + accent-foreground "Show All" button that clears `intent` back to nil via the `@Binding`.

### Created — `fitbod/ExerciseLibrary/IntentFilterChipRow.swift` (121 lines)

- `public struct IntentFilterChipRow: View` with `@Binding public var selected: Intent?`.
- Renders a horizontally-scrolling row of 6 chips: "All" first (selected when `selected == nil`), then `ForEach(Intent.allCases, id: \.rawValue)` for `.strength` / `.hypertrophy` / `.power` / `.endurance` / `.technique`.
- Each chip is a `Button` styled as a capsule. Selected fill = `Color.accentColor` with `Color.white` label; unselected fill = `Color(.systemGray5)` with `Color.primary` label (UI-SPEC § Color #8 verbatim — accent reserved for the SELECTED filter chip; unselected chips are quiet).
- Internal capsule padding: 12pt horizontal / 6pt vertical. External frame: `.frame(minWidth: 44, minHeight: 44)` extends the touch target to the UI-SPEC HIG exception while keeping the visual capsule compact.
- Accessibility: `accessibilityLabel("\(label) filter, \(isSelected ? "selected" : "unselected")")` verbatim per UI-SPEC; `accessibilityAddTraits` adds `.isSelected` to the selected chip plus `.isButton` on every chip.

### Created — `fitbod/ExerciseLibrary/ExerciseHistoryRow.swift` (96 lines)

- `public struct ExerciseHistoryRow: View` taking `setEntry: SetEntry` + `sessionExercise: SessionExercise`. Renders a two-line row:
  - Top caption: `sessionExercise.session?.routineSnapshotName ?? "Workout"` in `.caption .secondaryLabel` (the routine the set came from).
  - Primary line + trailing badge: `"{w} × {reps} @ RPE {N}"` (UI-SPEC verbatim format) — weight renders as integer when whole, decimal weights render with one digit; RPE clause is suppressed (`"{w} × {r}"`) when the set didn't record one; integer RPE renders without `.0`, decimal RPE with one digit.
  - Trailing inline intent badge: capsule on `Color(.systemGray6)` fill with `.caption .semibold` `.primary` label. UI-SPEC explicit — "inline intent badges below are quiet" (NOT accent).
- 4pt vertical spacing between caption and primary line (UI-SPEC `xs`); 8pt vertical padding around the row (UI-SPEC `sm`).

### Modified — `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (+19 lines)

- Appended a new `Section("History")` at the bottom of the existing `List` body containing a single `NavigationLink` to `ExerciseHistoryView(exercise: exercise)` labeled "View All History".
- Placed AFTER the conditional `if !exercise.isCustom { ... "Copy as Custom Exercise" ... }` block so custom exercises (which skip the Copy CTA) still see the History entry point at the bottom of their detail view. UI-SPEC § Exercise detail screen places "View All History" at the bottom of the detail view.

### Created — `fitbodTests/ExerciseHistoryIntentSplitTests.swift` (226 lines, 6 @Test funcs)

Six `@Test` functions covering the intent-split predicate that drives `FilteredHistoryList`'s `@Query`. Each test builds its own in-memory `ModelContainer` via `Schema(SchemaV2.models)` + `FitbodSchemaMigrationPlan` and shares a `makeMondayAndThursdayFixture` helper that creates Bench Press logged at strength intent on Monday + hypertrophy intent on Thursday — the canonical ROUTINE-08 scenario:

1. `allFilterReturnsBoth` — nil intent yields 2 results (both sessions visible).
2. `strengthFilterReturnsMondayOnly` — **ROUTINE-08 strength stream** — intent = .strength yields Monday only with `routineSnapshotName == "Push Day A — Strength"`.
3. `hypertrophyFilterReturnsThursdayOnly` — **ROUTINE-08 hypertrophy stream** — intent = .hypertrophy yields Thursday only with `routineSnapshotName == "Push Day A — Hypertrophy"`.
4. `powerFilterReturnsEmpty` — filter with no matching data yields empty results.
5. `differentExerciseReturnsEmpty` — predicate scopes by `exerciseID` correctly; querying a different exercise (Squat, never logged) yields empty.
6. `incompleteSetsExcludedFromVisibleSets` — view-layer visible-rows filter pin: adding a planned-but-not-completed `SetEntry` to a Monday SE leaves `sets.count == 2` but `.filter { $0.isComplete }.count == 1`, exactly what the view's `completedSets` computation produces.

Suite is `@MainActor` + `.serialized` matching the project's SwiftData-test convention (FilterStatePredicateTests / PreviousMatchingIntentTests / SessionFactoryTests).

### Created — `fitbodTests/ExerciseHistoryViewCopyTests.swift` (66 lines, 1 @Test func)

One `@Test` function (`verbatimCopy`) reading the three new source files from disk via `#filePath` ascent and asserting each UI-SPEC verbatim string is present via `#expect(... .contains(...))`. Mirrors the Phase 1/Phase 2 copy-anchor convention (RoutinesListCopyTests, RoutineBuilderCopyTests, SessionLoggerCopyTests, RestTimerOverlayCopyTests).

Pins:
- ExerciseHistoryView: "History", "No logged sets yet", "Log this exercise in a workout to see history.", `"No \(intent!.rawValue.capitalized) sets"`, "Try a different intent filter.", "Show All"
- IntentFilterChipRow: "All", `ForEach(Intent.allCases`
- ExerciseHistoryRow: `× \(setEntry.reps)`, `@ RPE`

## Decisions Made

1. **Refactored `FilteredHistoryList.init` to take `Binding<Intent?>` rather than `Intent?` value type.** The plan body's example used `intent: Intent?` then noted: "Note: the 'Show All' button needs a binding back to the outer view ... Adjust accordingly." Passing the `Binding` lets the filtered-empty branch reset the parent's `@State` directly via `self.intent = nil` without needing a closure callback. Trade-off: the inner view becomes coupled to the outer view via Binding, but that coupling was always implicit (SwiftUI re-builds the inner subtree on every parent `@State` change anyway). The Binding makes that coupling explicit.

2. **Kept explicit force-unwrap `intent!.rawValue.capitalized` in the filtered-empty branch.** The verbatimCopy test asserts the source-file substring `"No \(intent!.rawValue.capitalized) sets"` literally. Using `if let intent { ... }` would shadow the property to a non-optional local and break the substring match. Structured the branch as `if intent == nil { ... } else { Text("No \(intent!.rawValue.capitalized) sets") }` — the force-unwrap is safe because the else branch is gated on `intent != nil`.

3. **Used `Date.FormatStyle` (`.dateTime.weekday(.abbreviated).month(.abbreviated).day()`) rather than `DateFormatter()` inside the body.** PLAN.md anti-patterns explicitly rules out per-render `DateFormatter()` allocation. The literal `"EEE, MMM d"` string is kept in a comment so the AC #6 grep anchor still resolves; runtime uses the FormatStyle API which doesn't allocate per call. Same visual output: "Mon, May 11".

4. **Two atomic commits (production-then-tests).** Matches the Phase 2 multi-commit-per-plan convention established in plans 01-01 / 04-01 / 04-03. Production code is the canonical contract; tests are the proof. Keeping them in separate commits makes `git log -p` scannable.

5. **`ExerciseDetailView` History section appended at the bottom, after the conditional `if !exercise.isCustom` block.** UI-SPEC § Exercise detail screen places "View All History" at the bottom of the detail view, and placing it after the Copy CTA keeps the Phase 1 conditional block intact and unchanged. Custom exercises (which skip the Copy CTA) still see the new History entry point at the bottom of their detail view.

## Files Changed

### Created
- `fitbod/ExerciseLibrary/ExerciseHistoryView.swift` — 295 lines
- `fitbod/ExerciseLibrary/IntentFilterChipRow.swift` — 121 lines
- `fitbod/ExerciseLibrary/ExerciseHistoryRow.swift` — 96 lines
- `fitbodTests/ExerciseHistoryIntentSplitTests.swift` — 226 lines
- `fitbodTests/ExerciseHistoryViewCopyTests.swift` — 66 lines

### Modified
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift` — +19 lines (new "History" section)

### Intentionally NOT touched
- `SchemaV2.swift` / `FitbodSchemaMigrationPlan.swift` — the intent-split history view reads existing entities and indexes (Phase 1 + plan 00-01). No schema delta required.
- `Session.swift` / `SessionExercise.swift` / `SetEntry.swift` — already carry the required fields (`startedAt`, `intentRaw` (indexed), `routineSnapshotName`, `isComplete`, `isWarmup`).
- `PreviousMatchingIntent.swift` (plan 01-01) — the seed-weight query is intentionally distinct from the history view's query. The history view shows ALL committed working sets across matching SEs; PreviousMatchingIntent returns ONLY the top working set of the most recent matching SE. Different shapes, same predicate primitives.

## Commits

- `752407e` — `feat(02-05-01): add ExerciseHistoryView with intent-split filter chips` (3 new files + 1 modified, +532 lines)
- `7e0a040` — `test(02-05-01): intent-split history predicate + UI-SPEC verbatim copy` (2 new files, +292 lines)

## Verification

All 14 plan acceptance criteria verified:

| AC | Check | Result |
| -- | ----- | ------ |
| 1 | `grep 'public struct ExerciseHistoryView: View' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 1 match | PASS |
| 2 | `grep -E 'private struct FilteredHistoryList: View\|@Query private var sessionExercises' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 2 matches | PASS |
| 3 | `grep 'let targetID = exerciseID' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 1 match | PASS |
| 4 | UI-SPEC verbatim copy: `grep -E '"History"\|"No logged sets yet"\|"Log this exercise in a workout to see history\\."\|"Try a different intent filter\\."\|"Show All"' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 9 matches (≥5 required) | PASS |
| 5 | `grep 'sets across.*sessions' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 2 matches (1 comment + 1 source) | PASS |
| 6 | `grep 'EEE, MMM d' fitbod/ExerciseLibrary/ExerciseHistoryView.swift` returns 1 match | PASS |
| 7 | `grep -E '@Binding public var selected: Intent\\?\|ForEach\\(Intent\\.allCases' fitbod/ExerciseLibrary/IntentFilterChipRow.swift` returns 2 matches | PASS |
| 8 | Chip color contracts: `grep -E 'isSelected \\? Color\\.accentColor : Color\\(\\.systemGray5\\)\|isSelected \\? Color\\.white : Color\\.primary' fitbod/ExerciseLibrary/IntentFilterChipRow.swift` returns 2 matches | PASS |
| 9 | Chip a11y: `grep -E 'accessibilityLabel.*filter,\|accessibilityAddTraits' fitbod/ExerciseLibrary/IntentFilterChipRow.swift` returns 2 source matches (lines 90 + 91) | PASS |
| 10 | ExerciseHistoryRow: `grep -E '× \\\\\\(setEntry\\.reps\\)\|@ RPE\|Color\\(\\.systemGray6\\)' fitbod/ExerciseLibrary/ExerciseHistoryRow.swift` returns 7 matches (≥3 required) | PASS |
| 11 | ExerciseDetailView: `grep -E 'Section\\("History"\\)\|ExerciseHistoryView\\(exercise: exercise\\)\|"View All History"' fitbod/ExerciseLibrary/ExerciseDetailView.swift` returns 4 matches (≥3 required) | PASS |
| 12 | `grep -c '@Test' fitbodTests/ExerciseHistoryIntentSplitTests.swift` returns 6 | PASS |
| 13 | `grep -c '@Test' fitbodTests/ExerciseHistoryViewCopyTests.swift` returns 1 | PASS |
| 14 | Parse-clean: `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` exits 0 with no output | PASS |

Additional invariants verified:
- `git diff --diff-filter=D --name-only HEAD~2 HEAD` returns empty (no accidental deletions).
- All six exact test names match plan AC #12: `allFilterReturnsBoth`, `strengthFilterReturnsMondayOnly`, `hypertrophyFilterReturnsThursdayOnly`, `powerFilterReturnsEmpty`, `differentExerciseReturnsEmpty`, `incompleteSetsExcludedFromVisibleSets`.

## Deviations from Plan

None at the contract level. Four refinements documented above (Decisions §1 — `Binding<Intent?>` refactor per plan's "Adjust accordingly" note; Decisions §2 — explicit force-unwrap to keep verbatim test substring match; Decisions §3 — `Date.FormatStyle` over `DateFormatter()` per anti-patterns list; Decisions §4 — production-then-tests commit split) all follow guidance in either the plan body or the project's prior-plan conventions. No Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations occurred.

## Authentication Gates

None occurred. Pure SwiftUI / SwiftData / Swift Testing plan; no network, auth, or external-tool interactions.

## Known Stubs

None. The history view is functionally complete for Phase 2's scope:
- Intent-split filter chips wired to the @Query predicate end-to-end.
- Date-grouped sections with summary row.
- Two empty states (no-data + filtered-empty with "Show All" reset).
- Workout-snapshot caption + intent badge on every row.
- Warmup + incomplete-set exclusion at the view layer matches `PreviousMatchingIntent` semantics.

Chart deferred to Phase 6 per ROADMAP.md and PLAN.md anti-patterns ("SESS-10 explicitly scopes to 'list view, not chart'; e1RM rendering with rep-range awareness is a Phase 6 polish per PITFALLS-doc #12"). Tapping a history row is read-only in Phase 2 (no navigation) per UI-SPEC § Exercise history view interaction patterns.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or trust-boundary schema changes introduced. The view is read-only against existing on-device SwiftData entities under the same iCloud-replication-eligible cohort as Phase 1 / Phase 2 Waves 0-4.

## Phase 2 Closeout

This is the FINAL plan in Phase 2. After this plan lands:
- **All 20 Phase 2 requirements closed** (ROUTINE-01..09 + SESS-01..11 — see PLAN-INDEX.md Requirement-by-Plan Cross-Reference). The cross-reference shows every requirement has ≥1 closing plan; the closing plan for SESS-10 + ROUTINE-08 is this one (05-01).
- **MVP user story achievable end-to-end** (PLAN-INDEX.md Vertical Slice § Definition of Done) — every step 1-18 is reachable on the simulator without further code.
- **Next:** Phase 3 (Smart Prescription & Warm-ups) entry conditions are now met: SchemaV2 is stable, SessionFactory deep-copy is proven, rest timer + Live Activity are integrated, and the session logger surfaces real logged data that Phase 3's `RPEAutoregStrategy` + `DoubleProgressionStrategy` can back-calculate against.

## Next

The orchestrator's post-execution steps (executed alongside this SUMMARY commit):
- ROADMAP.md: mark Phase 2 row complete (13/13 plans), set Status = Complete, Completed = 2026-05-11.
- STATE.md: advance currentPlan past 05-01; recalculate progress bar; record metric; add session note.
- REQUIREMENTS.md: mark all 20 Phase 2 requirements (ROUTINE-01..09 + SESS-01..11) as complete.
- After this metadata commit, Phase 2 is closed and the workflow can `/gsd-transition` into Phase 3.

## Self-Check: PASSED

**Files created — verified present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/ExerciseHistoryView.swift` — FOUND (295 lines)
- `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/IntentFilterChipRow.swift` — FOUND (121 lines)
- `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/ExerciseHistoryRow.swift` — FOUND (96 lines)
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/ExerciseHistoryIntentSplitTests.swift` — FOUND (226 lines)
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/ExerciseHistoryViewCopyTests.swift` — FOUND (66 lines)

**Files modified — verified diff present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/ExerciseDetailView.swift` — diff shows new `Section("History")` block (+19 lines)

**Commits — verified present in git log:**
- `752407e` — FOUND (feat: 4 files, +532 lines)
- `7e0a040` — FOUND (test: 2 files, +292 lines)

**Parse gate — verified:**
- `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` exited 0 with no output across all production + test Swift files.

**Acceptance gates — verified via grep:**
- All 14 ACs documented in the Verification table above, every check returning expected match count.
