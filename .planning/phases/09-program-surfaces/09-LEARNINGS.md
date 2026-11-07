---
phase: 09
phase_name: "program-surfaces"
project: "Fitbod"
generated: "2026-11-03"
counts:
  decisions: 12
  lessons: 7
  patterns: 10
  surprises: 6
missing_artifacts:
  - "09-UAT.md"
---

# Phase 09 Learnings: program-surfaces

## Decisions

### Typed routes carry a UUID, never a model
`SplitDetailRoute` is `enum SplitDetailRoute: Hashable, Sendable { case detail(splitID: UUID) }`, parallel to `BlockOverviewRoute`.
Each destination resolves the model by id with a `FetchDescriptor` and shows a muted "not found" text when the id no longer resolves.

**Rationale:** UUID identity keeps routes `Sendable` under Swift 6 and matches the existing `BlockOverviewRoute` pattern.
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md, 09-02-SUMMARY.md

---

### Computed status and multi-hop links are filtered in Swift, never in #Predicate
Program's block ordering, the routine usage tags, the routine screen's live-block check and the session editor's reachability check all fetch with a plain or single-level predicate, then filter or sort in Swift.

**Rationale:** `Block.derivedStatus` is computed, not stored, and multi-level optional chains (template → slot → split → block) cannot be expressed in `#Predicate` (threats T-09-05, T-09-06, T-09-17).
**Source:** 09-02-PLAN.md, 09-02-SUMMARY.md, 09-06-PLAN.md, 09-06-SUMMARY.md

---

### Lifecycle, archive and schedule writes go through service seams only
Archiving a routine calls `BlockLifecycleService.assertSplitDeletable`.
Start, end, attach and swap call `BlockLifecycleService`.
Every `trainingDays` write calls `TrainingDaysWriter.sort`.
No view counts blocks or writes these fields itself.

**Rationale:** One deny rule and one write path per invariant (T-09-02, T-09-10, T-09-14); source pins in the copy tests fail if a view bypasses a seam.
**Source:** 09-01-PLAN.md, 09-04-PLAN.md, 09-04-SUMMARY.md, 09-05-SUMMARY.md

---

### Removing a session from a routine deletes only its slot
"Remove Session" deletes the `SplitSessionSlot`; the `SessionTemplate` stays in the store.

**Rationale:** `SplitSessionSlot.sessionTemplate` has a `.deny` delete rule that refuses hard-deleting a slotted template, and deleting a slot nullifies `Session.slot` so logged history survives. A test asserts the template survives removal (T-09-03).
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md

---

### Slot positions are renumbered on every write
After every add, remove or reorder, slot positions are rewritten to 0..<n and saved once.

**Rationale:** Contiguity is a test invariant, not a schema constraint: there is no `#Unique` on (split, position), and a duplicate position would silently merge rows (T-09-01).
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md

---

### Only the lifecycle service writes endDate
`BlockDraft.save` no longer writes `block.endDate`; only `BlockLifecycleService.end` does.
`computedEndDate` stays as a display-only projection.

**Rationale:** `endDate` is the completion freeze marker (spec §3/§4), and `derivedStatus` treats a non-nil `endDate` as completed (T-09-13).
**Source:** 09-05-PLAN.md, 09-05-SUMMARY.md

---

### The block builder writes block.split directly
`BlockDraft.save` sets `block.split` inside its own transaction instead of calling `BlockLifecycleService.attachSplit`.

**Rationale:** The builder only creates or edits draft and ready blocks; `attachSplit` exists to guard routine changes after activation.
**Source:** 09-05-PLAN.md, 09-05-SUMMARY.md

---

### Completed blocks render only from their archive
A completed block's screen reads the decoded `ArchivedBlockConfig`, never the live routine.
A block with no archive (`archivedConfigJSON == nil`, legacy builder-completed blocks) shows a quiet "NO ARCHIVE AVAILABLE" state; an archive that fails to decode shows the terminal "ARCHIVE UNREADABLE" view.
Attach/swap, the mode picker, day chips, Start, End and Edit are all hidden.

**Rationale:** The spec's archive contract (§6) forbids a live-template fallback for history (T-09-11).
**Source:** 09-04-PLAN.md, 09-04-SUMMARY.md, 09-VERIFICATION.md

---

### Routine attach and swap are limited to draft and ready blocks
The routine band is hidden on active blocks, and the picker branches explicitly on `block.split == nil` to call `attachSplit` or `swapSplit`; the service's own refusal stays as defense in depth (T-09-09).
Starting a ready block while another block is active first shows a swap-confirm sheet (T-09-12).

**Rationale:** A block's routine must not change once it is running, and starting a block silently ends the other one.
**Source:** 09-04-PLAN.md, 09-04-SUMMARY.md

---

### An empty routine gets a fix-it surface, not rest-day copy
When the active block's routine has no sessions, Today shows "ROUTINE HAS NO SESSIONS" with "GO TO ROUTINE ▸", which pushes the routine on Today's own stack.
Rest-day and no-block copy stay unchanged.

**Rationale:** Rest-day copy would falsely tell the lifter a rest is scheduled (T-09-07), and one NavigationStack per tab rules out jumping to Program.
**Source:** 09-03-PLAN.md, 09-03-SUMMARY.md

---

### Copy-adapt across token worlds instead of sharing components
The builder's mode and day chips copy BlockOverviewScreen's logic but use `NewBlockScreenTokens`.
Program's new rows (`BlockStatusCard`, `RoutineSplitRow`, `UsageTagFlow`) stay `fileprivate` in ProgramView.swift.

**Rationale:** The New Block builder and the BRU screens use separate token sets (09-RESEARCH Pattern 3), and keeping the rows fileprivate lets them use `ProgramChipFlow` and `ProgramScreenTokens` without widening visibility (Pitfall 7).
**Source:** 09-05-PLAN.md, 09-05-SUMMARY.md, 09-02-SUMMARY.md

---

### Two v1 shortcuts were accepted on purpose
- Creating a new session from the slot picker does not attach it; the picker reopens so the lifter selects it (two taps). The call site carries a `// v1 UX debt:` comment.
- Remove-slot uses `.confirmationDialog` instead of the spec's `.alert`, accepted at code review (IN-01) as the better iOS pattern.

**Rationale:** Keep v1 simple; both are documented and searchable choices, not defects.
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md, 09-VERIFICATION.md

---

## Lessons

### `guard … else { return }` does not compile in a @ViewBuilder
Inside a `@ViewBuilder` with an opaque return type, a bare `return` in a guard's else branch is rejected. Use `if let … { } else { }` instead.

**Context:** BlockOverviewScreen's archived-mode branch failed its first build this way and was restructured.
**Source:** 09-04-SUMMARY.md

---

### Copy pins on interpolated text must match the literal prefix
Source reads `"Routine · \(split.name)"`, so a pin on the closed string literal `"Routine · "` never matches. The pin has to match the prefix `"Routine · \(`.

**Context:** The SplitDetailView copy test failed until the pin matched the interpolation prefix.
**Source:** 09-01-SUMMARY.md

---

### Blanket "must not contain" guardrails break when a feature adopts the pattern
ProgramViewFidelityTests asserted that ProgramView.swift contained no `BRUSectionHead(`, and the new BLOCKS and ROUTINES sections legitimately use it.
The check was narrowed to positive assertions that each new section exists, and the empty-state pins were kept.

**Context:** A guardrail written for one screen state blocked the next feature in the same file.
**Source:** 09-02-PLAN.md, 09-02-SUMMARY.md

---

### Fixing a bug can break tests that pinned it
Removing the unconditional `endDate` write failed an existing BlockDraftSaveTests case that expected `endDate` to equal the computed end date; it now expects `nil`.

**Context:** The test had encoded the buggy behavior as the contract.
**Source:** 09-05-SUMMARY.md

---

### SessionTemplate has no inverse slots collection
Reachability from a session template to the active block fetches `SplitSessionSlot`s with a single-level predicate on the template's id, then walks slot → split → blocks in Swift.

**Context:** The plan warned not to look for an inverse such as `editing.slots`, because none exists.
**Source:** 09-06-PLAN.md, 09-06-SUMMARY.md

---

### Source-level checks cannot verify feel, fit or rendering
All 36 must-haves were verified from source and tests, and the phase still closed as `human_needed`.
Six checks need a running app: the DONE-collapse animation, the slot-reorder feel, fit at the 390pt device floor on Program, SplitDetailView and BlockOverviewScreen, a device day-rollover smoke carried from Phase 8, the New Block launch flow, and Markdown bold in the swap-confirm sheet.

**Context:** Grep and source-introspection tests prove wiring and copy, not layout or motion.
**Source:** 09-VERIFICATION.md

---

### An archived screen can leak live reads outside the obvious branch
Code review found the archived week carousel still counting scheduled sessions from the live routine (CR-03), although the plan's completed-branch tests passed; it was fixed to read the archive.

**Context:** Those tests checked that `decodeArchive`, `ArchiveUnreadableView` and `archivedConfigJSON` appear in the source, not that every completed-mode view avoids `block.split`.
**Source:** 09-04-SUMMARY.md, 09-VERIFICATION.md

---

## Patterns

### Hysteresis drag-reorder for BRU lists
`LongPressGesture(minimumDuration: 0.25).sequenced(before: DragGesture(minimumDistance: 0))`, a row-local `@GestureState` translation with a spring reset, a 0.55-pitch threshold before re-targeting, parent callbacks (`onReorderBegan`, `onReorderTarget`, `onReorderEnded`), one save on drop, a haptic on pick-up, Reduce Motion disabling the gesture with an explanation, and VoiceOver "Move up" and "Move down" actions.

**When to use:** Reordering rows where `List.onMove` chrome would break the BRU design. It was copy-adapted from `NewBlockPhaseEditorRow` in BlockBuilderView.swift.
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md

---

### Reindex-on-write for ordered join rows
Renumber every position 0..<n after each add, remove or move, in one save, and test contiguity after each operation.

**When to use:** Any ordered relationship whose order the schema does not enforce.
**Source:** 09-01-PLAN.md, 09-01-SUMMARY.md

---

### Single-level predicate, then a Swift post-filter
Fetch with a predicate SwiftData can express (a stored Bool, one optional hop), then filter or sort in Swift for computed properties and multi-hop chains, with a code comment saying why.

**When to use:** Filtering on `derivedStatus`, or on relationships deeper than one level.
**Source:** 09-02-SUMMARY.md, 09-06-SUMMARY.md

---

### UUID route plus a resolving destination on each tab's stack
Push a UUID route. Each tab's NavigationStack registers `navigationDestination(for:)`, which fetches the model by id and shows a muted "not found" text if it is gone. A test pins the registration, because a pushed route with no destination silently does nothing (T-09-04).

**When to use:** Any screen for a SwiftData model that more than one tab can open.
**Source:** 09-02-PLAN.md, 09-02-SUMMARY.md, 09-03-SUMMARY.md

---

### Internal test seams for view logic
Logic a view needs goes into an `internal` function, such as `reindexSlots(_:)` or `isTemplateOnActiveBlock(_:context:)`, so unit tests call it with an in-memory container instead of building the view.

**When to use:** Logic inside a SwiftUI view that needs fast unit tests.
**Source:** 09-01-SUMMARY.md, 09-06-SUMMARY.md

---

### Inline decode-or-error with Result in a view body
`Result { try BlockLifecycleService.decodeArchive(json) }` inside the `@ViewBuilder` renders either the decoded view or the error view, with no extra state.

**When to use:** Rendering a value that may fail to decode, where failure is terminal.
**Source:** 09-04-SUMMARY.md

---

### Closure-driven fix-it surfaces
`EmptySplitFixIt` takes an `onGoToRoutine` closure, and the caller appends to its own navigation path, so the view does not depend on which stack it is in.

**When to use:** Empty or error states whose call to action navigates.
**Source:** 09-03-SUMMARY.md

---

### One reusable, non-blocking liveness banner
`LiveEditBanner` (signal stripe, "ACTIVE BLOCK", fixed body copy, one combined accessibility label) sits in the `.safeAreaInset(edge: .top)` stack under the header. It shows while the edited routine or session is on the active block and disappears on the next render once it is not.

**When to use:** Telling the lifter that an edit changes upcoming workouts, without blocking the edit.
**Source:** 09-01-SUMMARY.md, 09-06-PLAN.md, 09-06-SUMMARY.md

---

### A threat register drives the tests
Each plan lists STRIDE threats (T-09-01 to T-09-17) with a mitigation, and each summary confirms the test or source pin that enforces it.

**When to use:** UI work that touches data invariants such as ordering, delete rules or lifecycle state.
**Source:** 09-01-PLAN.md to 09-06-PLAN.md, 09-01-SUMMARY.md to 09-06-SUMMARY.md

---

### Compare full runs against a documented failure baseline
The full unit run failed exactly the 11 known baseline tests, all copy-drift checks on screens this phase did not touch, suite by suite, so the phase could show zero new failures.

**When to use:** Verifying a phase while known failures remain on main.
**Source:** 09-VERIFICATION.md

---

## Surprises

### The builder marked every saved block as completed
`BlockDraft.save` wrote `endDate = computedEndDate` unconditionally, and `derivedStatus` treats any `endDate` as completed, so drafts and ready blocks computed as completed.

**Impact:** Found while planning 09-05 and fixed there (T-09-13), with new behavior tests and a corrected existing test.
**Source:** 09-05-PLAN.md, 09-05-SUMMARY.md

---

### The spec assumed an older schema
When Phase 9 was registered, the program-graph spec named the new schema V5 and the template child entity `RoutineExerciseTemplate`. The live store was already at V6, so the new schema became V7 and the entity is `RoutineExercise`.

**Impact:** Corrected at registration, before planning.
**Source:** STATE.md

---

### A Phase 7 migration test crashed mid-run
During the full run, `SchemaV7MigrationTests` hit `Fatal error: Failed to cast model fitbod.SchemaV6.Routine` (SwiftData schema-registry contamination); the runner restarted and the suite passed.

**Impact:** Judged a pre-existing, non-deterministic Phase 7 flake (the file has no Phase 9 changes) and not counted against the phase.
**Source:** 09-VERIFICATION.md

---

### The UI smoke test could not launch the app
`NewBlockModalUITests` failed with `FBSOpenApplicationServiceErrorDomain Code=1 … RequestDenied by SBMainWorkspace`, an environment launch failure rather than a code failure.

**Impact:** Confirming the Program tab's New Block flow moved to human verification.
**Source:** 09-VERIFICATION.md

---

### The artifacts describe slot reordering differently
09-01's summary describes the hysteresis long-press drag. The verification's human check describes up/down move buttons: "NOT List drag — BRU no-chrome contract, see SplitDetailView.swift:19".

**Impact:** The human check has to confirm which interaction actually ships.
**Source:** 09-01-SUMMARY.md, 09-VERIFICATION.md

---

### Code review found 11 issues after every plan's self-check passed
Three were critical, including CR-01 (BlockDraftSaveTests on SchemaV7) and CR-03 (the archived week carousel reading live data).

**Impact:** 10 were fixed and 1 accepted (IN-01) before verification, which confirmed each fix in source.
**Source:** 09-VERIFICATION.md
