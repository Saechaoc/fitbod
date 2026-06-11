---
phase: 07-program-graph-schema-v7-migration
verified: 2026-06-11T08:00:00Z
status: human_needed
score: 9/9 must-have truths verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/9
  gaps_closed:
    - "SchemaV7MigrationTests is green (incl. ghost-free picker, ref remapping, slot-nullify) — the phase's named deliverable"
    - "Block delete nullifies SessionTemplate.block (BlocksSection regression) and SchemaV6 count-pin is correct"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Real-store V6→V7 migration on the developer's device/phone (open the existing SchemaV6 store with FitbodSchemaMigrationPlan and confirm it migrates without crash, splits/templates materialize, completed-block archives present)"
    expected: "App launches, existing routines appear as SessionTemplates, blocks gain auto-splits, no data loss, no migration crash"
    why_human: "UI test runner cannot launch in the simulator environment (FBSOpenApplicationServiceErrorDomain Code=1 / RequestDenied / launch-failed — simulator contention from repeated test runs). The custom 7-step migration is only ever exercised end-to-end by SwiftData's real open-store path, which the in-process helper tests do not faithfully reproduce."
  - test: "CR-04 runtime .deny trap — hard-delete a slotted SessionTemplate on device and confirm SwiftData refuses (throws), template survives"
    expected: "ctx.delete(slottedTemplate) + save throws; template still present"
    why_human: "Runtime .deny enforcement is documented as SDK-flaky in-process; the behavioral test is wrapped in withKnownIssue(isIntermittent:). Real enforcement must be confirmed on the target environment per REVIEW CR-04 ('fixed (requires human verification)')."
  - test: "Migration-chain walk from a genuine pre-V7 on-disk store (V5 or V6 era) forward to V7"
    expected: "A device that has a real V5/V6 store opens and migrates to V7 cleanly. V5 schema now uses nested @Model Routine/RoutineExercise (CR-01 fix applied in 07-07), so entity name resolution should succeed."
    why_human: "Whether SwiftData's name-matching actually succeeds on a real V5 store can only be confirmed against a genuine on-disk store. In-memory tests exercise the schema type registrations but not SwiftData's version name-matching path against a persistent store on disk."
---

# Phase 7: Program Graph Schema V7 & Migration — Verification Report

**Phase Goal:** Schema V7 lands the program graph: Split + SplitSessionSlot entities (position-ordered, contiguity as test invariant, no #Unique), Routine→SessionTemplate / RoutineExercise→SessionExerciseTemplate renames, Block gains split/schedulingMode/trainingDays/archivedConfigJSON, Session gains slot/templateName + template ref rename, custom V6→V7 migration stage (7 steps per spec §7), SchemaV7MigrationTests green incl. ghost-free splits picker.

**Verified:** 2026-06-11T08:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plan 07-07, commits a53b59c, aa0a072, b2d14a8)

---

## Gap Closure Re-verification (07-07)

### Source Assertions (Pre-Test)

All three source-level fixes were confirmed in the codebase before running tests:

| Fix | File | Evidence | Status |
|-----|------|----------|--------|
| Session.slot nullify inverse | `fitbod/Models/SplitSessionSlot.swift:48-49` | `@Relationship(deleteRule: .nullify, inverse: \Session.slot) public var sessions: [Session]? = []` | VERIFIED |
| SessionTemplate.block nullify inverse | `fitbod/Models/Block.swift:65` | `@Relationship(deleteRule: .nullify, inverse: \SessionTemplate.block) public var legacyTemplates: [SessionTemplate]? = []` | VERIFIED |
| No public Block.routines revived | `fitbod/Models/Block.swift` | `rg "Block.routines\|public var routines" Block.swift` — no hit | VERIFIED |
| SchemaV5 typealiases removed | `fitbod/Persistence/SchemaV5.swift` | `typealias Routine = fitbod.SessionTemplate` — removed; only `RoutineFolder` and `RoutineExerciseSetOverride` typealiases remain (different entities, correct) | VERIFIED |
| SchemaV5 nested @Model types | `fitbod/Persistence/SchemaV5.swift:132,167` | `@Model` nested types present at both lines; header comment confirms CR-01 rationale | VERIFIED |
| Stash entry-reset at stashV6Routines entry | `fitbod/Persistence/FitbodSchemaMigrationPlan.swift:223-224` | `v6RoutineStash = []; v6SessionStash = []` at function top, before any fetch | VERIFIED |
| Combined V6+V7 test container | `fitbodTests/Persistence/SchemaV7MigrationTests.swift:75` | `let combined = (SchemaV6.models + SchemaV7.models)` | VERIFIED |
| No remaining Routine/RoutineExercise forwarding typealiases | All persistence/*.swift | `rg "typealias Routine|typealias RoutineExercise"` — only hits are `RoutineFolder`/`RoutineExerciseSetOverride` (correct; not renamed entities) | VERIFIED |

### Six-Suite Exit Gate — Run 1

Command: `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:fitbodTests/SchemaV7MigrationTests -only-testing:fitbodTests/SchemaV6MigrationTests -only-testing:fitbodTests/SchemaV4MigrationTests -only-testing:fitbodTests/SchemaV2MigrationTests -only-testing:fitbodTests/SchemaV1Tests -only-testing:fitbodTests/BlocksSectionTests`

Note: One iPhone 17 Pro simulator had a stale on-disk SwiftData store (identical environment issue documented in 07-07-SUMMARY.md). The stale `default.store` was deleted from simulator 61A37501 before running; subsequent runs used a clean store.

| Suite | Result | Notes |
|-------|--------|-------|
| SchemaV7MigrationTests (14 tests) | ALL PASS | refRemapping PASS (2 templates); slotNullifyHistoryIntact PASS; templateNameBackfill PASS |
| SchemaV6MigrationTests (9 tests) | ALL PASS | schemaV6ModelsCountMatchesV5 PASS (16 == 16) |
| SchemaV4MigrationTests (10 tests) | ALL PASS | |
| SchemaV2MigrationTests (5 tests) | ALL PASS | freshV2ContainerRoundTrip launched on a different clone PID — not a test failure |
| SchemaV1Tests (16 tests) | ALL PASS | |
| BlocksSectionTests — deletingBlockNullifiesRoutineLink | PASS | Gap closed |
| BlocksSectionTests — copyAnchorsExistInRoutinesListView | FAIL | Pre-existing BRU source-introspection test; target source (RoutinesListView.swift) not modified in phase 7 or 07-07; adjudicated PRE-EXISTING in original verification |

**Overall run 1:** All phase-7 and gap-closure tests pass. Single failure is the pre-existing BRU copy test.

### Six-Suite Exit Gate — Run 2 (Determinism Check)

Same command repeated immediately after run 1.

| Suite | Result | Notes |
|-------|--------|-------|
| SchemaV7MigrationTests | ALL PASS | refRemapping passed (0.069s) on Clone 2 when Clone 1 crashed before bootstrapping (0.000s clone-crash cascade pattern — identical to the ~140 mass failures adjudicated as contamination in the initial verification; the test itself ran and passed on Clone 2 1254) |
| SchemaV6MigrationTests | ALL PASS | |
| SchemaV4MigrationTests | ALL PASS | |
| SchemaV2MigrationTests | ALL PASS | |
| SchemaV1Tests | ALL PASS | |
| BlocksSectionTests — deletingBlockNullifiesRoutineLink | PASS | |
| BlocksSectionTests — copyAnchorsExistInRoutinesListView | FAIL | Same pre-existing failure |

**Overall run 2:** Identical to run 1. The refRemapping 0.000s clone-crash appearance is confirmed contamination — Clone 1 crashed before establishing connection; Clone 2 (different PID) ran the full SchemaV7MigrationTests suite and passed all 14, including refRemapping (0.069s).

### Determinism Confirmation — SchemaV7MigrationTests in Clean Isolation

To provide a definitive ruling on determinism (ruling out clone-crash noise), ran SchemaV7MigrationTests twice with `-parallel-testing-enabled NO`:

**Run A (isolation):** 14/14 PASS — refRemapping 0.106s, slotNullifyHistoryIntact 0.017s, templateNameBackfill 0.011s.
**Run B (isolation):** 14/14 PASS — refRemapping 0.089s, slotNullifyHistoryIntact 0.009s, templateNameBackfill 0.007s.

Both runs identical-green. Suite is deterministic.

### Pre-existing Suite Status-Quo Check

Ran all 4 suites identified as pre-existing in the original verification to confirm 07-07 did not disturb them:

| Suite | Failures | Status |
|-------|----------|--------|
| FatigueSurfaceViewBRUTests | 4 (same as baseline) | UNCHANGED PRE-EXISTING |
| PrescriptionEditorBlockCaseFilterTests | 1 (same as baseline) | UNCHANGED PRE-EXISTING |
| SessionLoggerBRUCopyTests | 4 (same as baseline) | UNCHANGED PRE-EXISTING |
| TodayViewBlockStackingTests | 1 (same as baseline) | UNCHANGED PRE-EXISTING |

Total: 10 failures across 39 tests. Identical to baseline. No regressions introduced by 07-07.

### Per-Gap Closure Table

| Gap | Root Fix | Evidence | Status |
|-----|----------|----------|--------|
| **Gap 1a:** Session.slot not nullified on slot delete (slotNullifyHistoryIntact fails) | `SplitSessionSlot.sessions` `@Relationship(deleteRule:.nullify, inverse:\Session.slot)` added | slotNullifyHistoryIntact PASS both isolation runs | CLOSED |
| **Gap 1b:** SessionTemplate.block not nullified on block delete (BlocksSection regression) | `Block.legacyTemplates` `@Relationship(deleteRule:.nullify, inverse:\SessionTemplate.block)` added; Block.routines name stays dead | deletingBlockNullifiesRoutineLink PASS both six-suite runs | CLOSED |
| **Gap 2a:** refRemapping yields 0 templates (V7-only test container) | Combined test container: `Schema(SchemaV6.models + SchemaV7.models)` deduped by ObjectIdentifier | refRemapping PASS (2 templates) both isolation runs | CLOSED |
| **Gap 2b:** templateNameBackfill order-dependent (shared static stash leak) | Entry-reset `v6RoutineStash = []; v6SessionStash = []` at top of `stashV6Routines` | templateNameBackfill PASS both isolation runs; order-independent confirmed by running after refRemapping | CLOSED |
| **Gap 2c:** SchemaV6 count-pin wrong +2 arithmetic (16 != 18) | Assertion changed to `== SchemaV5.models.count` (16 == 16) | schemaV6ModelsCountMatchesV5 PASS | CLOSED |
| **Gap 3:** SchemaV5 typealias Routine = fitbod.SessionTemplate (CR-01 break at V5) | Removed typealiases; replaced with nested `@Model` classes `SchemaV5.Routine` / `SchemaV5.RoutineExercise` carrying V5-era shape | `rg "typealias Routine|typealias RoutineExercise" SchemaV5.swift` returns 0 hits on renamed entities; `@Model` nested types present | CLOSED (device confirmation item 3 remains) |

---

## Original Verification (2026-06-10) — Preserved for History

**Status at initial verification:** gaps_found — score 7/9

### Observable Truths (Initial)

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Split + SplitSessionSlot entities exist per spec §3 (cascade slots, deny sessionTemplate, no #Unique, Split.blocks inverse) | ✓ VERIFIED | Split.swift:30 cascade slots; :35 `@Relationship(.nullify, inverse:\Block.split) blocks` (CR fix). SplitSessionSlot.swift:39 `deleteRule:.deny` sessionTemplate; :35 explicit position Int; no #Unique on (split,position). |
| 2  | Routine→SessionTemplate / RoutineExercise→SessionExerciseTemplate renamed (top-level @Model + V5/V6 typealias chain) | ✓ VERIFIED | SessionTemplate.swift:44 `final class SessionTemplate`; SessionExerciseTemplate.swift exists; SessionFactory + Routines/Sessions clusters compile (full build green). |
| 3  | Block gains split (nullify) / schedulingMode (.rotation default) / trainingDays (verbatim, never re-sorted) / archivedConfigJSON; routines removed; derivedStatus ordered switch | ✓ VERIFIED | Block.swift:60 split; :63 schedulingModeRaw="rotation"; :86-93 trainingDays accessor stores order verbatim (NO sort); :71 archivedConfigJSON; :98-113 derivedStatus ordered completed→active→ready→draft with exact spec §3 ready predicate. Block.routines absent. |
| 4  | Session gains template (nullify) / slot (nullify) / templateName | ⚠️ PARTIAL → ✓ VERIFIED (07-07) | Session.swift:65 template, :69 slot, :72 templateName all present. Nullify now wired via SplitSessionSlot.sessions inverse (07-07 Task 1). |
| 5  | FitbodSchemaMigrationPlan registers 7 schemas / 6 stages; migrateV6toV7 custom stage implements all 7 spec §7 steps | ✓ VERIFIED | Plan.swift:54-55 (7 schemas), :59-60 (6 stages); migrateV6toV7 :138-147 custom; all 7 steps present in code. |
| 6  | Migration chain integrity: V1/V2/V3/V4/V6 carry nested legacy @Model types so a pre-V7 store can walk to V7 (CR-01 fix) | ⚠️ PARTIAL → ✓ VERIFIED (07-07) | V5 now has nested @Model Routine/RoutineExercise (07-07 Task 3). V1-V4, V6 already correct. All schemas now carry nested types resolving to correct entity names. Device confirmation still required (human item 3). |
| 7  | SchedulingMode enum + ArchivedBlockConfig Codable (v:1, iso8601, decode helper) | ✓ VERIFIED | SchedulingMode.swift:18-22 (rotation/fixedWeekly, default .rotation). ArchivedBlockConfig.swift:34 v:Int, :77 .iso8601 encode, :84-86 decode(from:) iso8601. |
| 8  | SchemaV7MigrationTests is green (ghost-free picker, ref remap, slot-nullify) — the phase's named deliverable | ✗ FAILED → ✓ VERIFIED (07-07) | 14/14 PASS on two consecutive isolated runs (-parallel-testing-enabled NO). refRemapping 2 templates, slotNullifyHistoryIntact slot==nil, templateNameBackfill order-independent. |
| 9  | Full Phase 1-6 + Phase 7 regression suite is green (0 failures excluding pre-existing) | ✗ FAILED → ✓ VERIFIED (07-07) | deletingBlockNullifiesRoutineLink PASS; schemaV6ModelsCountMatchesV5 PASS. All 6 suites green (excluding pre-existing BRU copy tests which are unchanged at baseline). |

**Score (re-verification): 9/9 truths verified.**

### Anti-Patterns (Updated)

| File | Line | Pattern | Severity | Status |
|------|------|---------|----------|--------|
| Session.swift | 69 | plain `var slot` — nullify not wired | 🛑 Blocker (initial) | RESOLVED: inverse wired via SplitSessionSlot.sessions (07-07) |
| SessionTemplate.swift | 51 | plain `var block` — inverse removed | 🛑 Blocker (initial) | RESOLVED: Block.legacyTemplates inverse wired (07-07) |
| SchemaV5.swift | 48-49 | `typealias Routine = fitbod.SessionTemplate` | ⚠️ Warning (initial) | RESOLVED: nested @Model types replace typealiases (07-07) |
| FitbodSchemaMigrationPlan.swift | 205-206 | static stash leaks across tests | ⚠️ Warning (initial) | RESOLVED: entry-reset added to stashV6Routines (07-07) |

No new anti-patterns introduced by 07-07.

### Human Verification Required

1. **Real-store V6→V7 migration on device**

   **Test:** Open the existing SchemaV6 store via FitbodSchemaMigrationPlan on the developer's device (not simulator). Confirm migration completes without crash, splits/templates materialize, completed-block archives present, no data loss.
   **Expected:** App launches; existing routines appear as SessionTemplates; blocks gain auto-splits; no data loss; no migration crash.
   **Why human:** UI runner cannot launch in this environment (FBSOpenApplicationServiceErrorDomain RequestDenied — simulator contention). The custom 7-step migration is exercised end-to-end only by SwiftData's real open-store path.

2. **CR-04 runtime .deny trap on device**

   **Test:** Hard-delete a slotted SessionTemplate on device; confirm SwiftData throws and the template survives.
   **Expected:** `ctx.delete(slottedTemplate)` + save throws; template still present.
   **Why human:** Runtime .deny enforcement is documented as SDK-flaky in-process; the behavioral test is wrapped in `withKnownIssue(isIntermittent:)`. Real enforcement must be confirmed on the target environment per REVIEW CR-04.

3. **Migration-chain walk from genuine pre-V7 on-disk store (V5/V6 era)**

   **Test:** Open a device/simulator that has a real V5 or V6 on-disk store with FitbodSchemaMigrationPlan and confirm it walks forward to V7 cleanly.
   **Expected:** App opens without crash; data migrates; SchemaV5's Routine entity names now resolve correctly because nested @Model types were added in 07-07 (Task 3). No store corruption.
   **Why human:** V5 entity name-matching against a real persistent store can only be confirmed against genuine on-disk data. In-memory test containers do not exercise SwiftData's version name-matching path.

---

_Initial verification: 2026-06-10T21:15:00Z_
_Re-verification: 2026-06-11T08:00:00Z_
_Verifier: Claude (gsd-verifier)_
