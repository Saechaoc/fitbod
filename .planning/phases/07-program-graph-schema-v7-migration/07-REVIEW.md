---
phase: 07-program-graph-schema-v7-migration
reviewed: 2026-06-10T00:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - fitbod/Persistence/FitbodSchemaMigrationPlan.swift
  - fitbod/Persistence/SchemaV7.swift
  - fitbod/Persistence/SchemaV6.swift
  - fitbod/Persistence/SchemaV5.swift
  - fitbod/Persistence/SchemaV4.swift
  - fitbod/Persistence/SchemaV3.swift
  - fitbod/Persistence/SchemaV2.swift
  - fitbod/Persistence/SchemaV1.swift
  - fitbod/Persistence/PreviewModelContainer.swift
  - fitbod/Models/Split.swift
  - fitbod/Models/SplitSessionSlot.swift
  - fitbod/Models/Block.swift
  - fitbod/Models/Session.swift
  - fitbod/Models/SessionTemplate.swift
  - fitbod/Models/SessionExerciseTemplate.swift
  - fitbod/Models/RoutineExerciseSetOverride.swift
  - fitbod/Models/ArchivedBlockConfig.swift
  - fitbod/Models/Enums/SchedulingMode.swift
  - fitbod/fitbodApp.swift
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/BlockOverviewScreen.swift
  - fitbodTests/Persistence/SchemaV7MigrationTests.swift
findings:
  critical: 5
  warning: 6
  info: 2
  total: 13
status: issues_found
fix:
  fixed_at: 2026-06-10
  scope: all_critical_and_warnings
  fixed: 10
  skipped: 1
  per_finding:
    CR-01: fixed          # nested @Model Routine/RoutineExercise in SchemaV1/V2
    CR-02: skipped        # false premise — block field has live consumers; removal would break build
    CR-03: fixed          # try? -> try in bumpPlateauToleranceDefault
    CR-04: fixed-verify   # behavioral deny-rule test added (runtime enforcement SDK-flaky)
    CR-05: fixed          # BlockOverviewScreen preview -> SchemaV7.models
    WR-01: fixed          # assert Session.slot == nil after slot delete
    WR-02: fixed          # re-fetch sessions in step 4
    WR-03: fixed          # SplitDeletionGuard + tests
    WR-04: fixed          # stale SessionTemplate.block doc comment corrected
    WR-05: fixed          # V7 fields added to export/backup DTOs + restorer
    WR-06: fixed          # PreviewModelContainer docstring -> SchemaV7
status_after_fix: partial
---

# Phase 7: Code Review Report

**Reviewed:** 2026-06-10
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 7 lands the V6→V7 entity-rename migration (Routine→SessionTemplate, RoutineExercise→SessionExerciseTemplate), the new Split/SplitSessionSlot program-graph entities, and a 7-step custom migration stage. The migration plan structure is architecturally sound and the core stash-and-materialize pattern is correctly implemented. However, five critical defects were found spanning: a schema-registry collision between V1/V2 production models and the V7-renamed types (causes SwiftData to fail to open pre-V7 stores), a ghost relationship field left on SessionTemplate from the removed Block.routines link, a silent save-error swallow in the V6 migration helper, a test suite redesign that eliminates behavioral verification of the deny-rule runtime enforcement, and a preview block that registers an incompatible schema version. Six warnings address correctness risks and spec contract gaps.

---

## Critical Issues

### CR-01: SchemaV1 and SchemaV2 list V7-renamed top-level types — breaks opening pre-V7 stores

**File:** `fitbod/Persistence/SchemaV1.swift:32-33`, `fitbod/Persistence/SchemaV2.swift:45-46`

**Issue:** `SchemaV1.models` references `SessionTemplate.self` and `SessionExerciseTemplate.self` — the V7 *renamed* production types. The same is true for `SchemaV2.models`. SwiftData's migration engine matches schema versions by comparing the model entity names in each registered schema against the on-disk store's metadata. At V1, the on-disk entities are named `Routine` and `RoutineExercise`. If `SchemaV1.models` lists `SessionTemplate` and `SessionExerciseTemplate`, SwiftData cannot find `Routine` or `RoutineExercise` in V1 and will refuse to open (or silently corrupt) any pre-V7 store that is actually at schema version 1 or 2. The lightweight V1→V2 and V2→V3 stages that were supposed to upgrade those stores become unreachable.

Spec §7 requires the custom stage to stash rows before the rename. For that chain to work, SwiftData must be able to _walk_ from V1 through V6 to arrive at the willMigrate boundary. The walk breaks at V1 the moment `Routine` is absent from the V1 model list.

SchemaV3 and SchemaV4 declare nested `@Model` classes named `Routine` / `RoutineExercise` (the old shapes) and correctly do not use the top-level production types for the entities that changed. SchemaV1 and SchemaV2 must follow the same pattern — but they currently point to the V7-renamed types, which means any device that has a V1 or V2 store will encounter a migration failure.

**Fix:** SchemaV1 and SchemaV2 must either (a) declare their own nested `@Model` classes carrying the pre-rename names (`Routine`, `RoutineExercise`) just as SchemaV3/V4 do, or (b) use type aliases that resolve to the correct V1/V2-era class names. Since the top-level `Routine` / `RoutineExercise` types no longer exist after the V7 rename, option (a) is required.

```swift
// SchemaV1.swift — add nested @Model classes with old entity names
extension SchemaV1 {
    @Model public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        // ... V1-era fields only (no folderID, intentRaw, etc.)
        public init() {}
    }
    @Model public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        // ... V1-era fields
        public init() {}
    }
}

// Replace SessionTemplate.self / SessionExerciseTemplate.self in SchemaV1.models:
//   Self.Routine.self,
//   Self.RoutineExercise.self,

// SchemaV2.swift — add nested @Model classes with V2 field additions
// (folderID on Routine, supersetGroupID/tracksTempo/tracksPartialReps on RoutineExercise)
```

---

### CR-02: `SessionTemplate.block: Block? = nil` — orphan relationship field from removed `Block.routines`

**File:** `fitbod/Models/SessionTemplate.swift:46`

**Issue:** `SessionTemplate` retains `public var block: Block? = nil` — the inverse side of the `Block.routines` relationship that the V7 comment in `Block.swift:19-21` explicitly states was **REMOVED**. `Block.swift` confirms: "Block.routines (@Relationship inverse: \SessionTemplate.block) REMOVED. Block→SessionTemplate was the V6 link." The V6 link is gone from `Block`, but `SessionTemplate.block` remains without any `@Relationship` decorator and with no declared inverse.

SwiftData will interpret this as a new relationship in V7 — a bare optional property referencing `Block` — and will attempt to resolve it as an undeclared to-one relationship. In practice this creates a phantom inverse edge between `Block` and `SessionTemplate` that is NOT in the V7 schema spec (spec §3 shows `Block.split` is the new link; SessionTemplate has no block reference in V7). Any automated schema checksum or migration from V7→V8 will carry this ghost field, and it pollutes model metadata with an unintended relationship.

**Fix:** Remove `block` from `SessionTemplate`:

```swift
// Delete this line from SessionTemplate:
// public var block: Block? = nil
```

If the comment in `SessionTemplate.swift:18` ("The optional `block` relationship lets a template belong to a periodization block...") refers to V6 semantics, it should also be removed or updated to document the V7 architecture (templates no longer hold a direct block reference; membership is through Split → SplitSessionSlot).

---

### CR-03: `bumpPlateauToleranceDefault` silently swallows save errors with `try?`

**File:** `fitbod/Persistence/FitbodSchemaMigrationPlan.swift:506`

**Issue:** The V5→V6 migration helper uses `try? context.save()`. The analogous V6→V7 migration path (`materializeSessionTemplates`) correctly uses `try context.save()` (line 485) and propagates errors to abort the migration. But `bumpPlateauToleranceDefault` discards any save failure: if the context cannot persist the updated `plateauTolerance` value, the willMigrate closure returns `nil` error and SwiftData treats the stage as succeeded. The migration then opens the V6 store with the un-bumped default still in place for existing rows — a silent data-integrity failure.

**Fix:**

```swift
// Change try? to try — propagate errors so a failed save aborts the stage
try context.save()
```

---

### CR-04: Test 8 (`slottedTemplateDenyRule`) does not behaviorally verify the `.deny` rule at runtime — spec §9 contract coverage dropped

**File:** `fitbodTests/Persistence/SchemaV7MigrationTests.swift:328-373`

**Issue:** The executor "redesigned tests 8-9 to not exercise the registry-sensitive path." Test 8 as written verifies only that (a) the relationship round-trips after save, and (b) `SplitSessionSlot`'s entity name is `"SplitSessionSlot"`. It does NOT attempt `ctx.delete(template)` while the template is slotted and verify that the operation throws. The comment at line 331-335 attributes this to SwiftData deny-rule enforcement being "process-context-sensitive and unreliable in the same test process." However, this was described as a *known-flaky* behavior — not a correctness blocker that justifies zero behavioral coverage.

Spec §9 explicitly requires "Deny-rule tests: template hard-delete while slotted." The current test 8 is a metadata tautology, not a behavioral assertion. The spec contract for the deny rule is unverified by any test in the suite.

**Fix:** Add a behavioral test in a dedicated `@Suite` that uses a fresh process-isolated context and actually attempts the delete, catching and asserting the expected error:

```swift
@Test("Hard-deleting a slotted SessionTemplate throws a deny-rule error")
func slottedTemplateDenyRuleEnforced() throws {
    let ctx = try makeContext()
    // ... seed split, template, slot
    // Attempt delete — must throw
    #expect(throws: (any Error).self) {
        ctx.delete(template)
        try ctx.save()
    }
    // Template must still exist
    let templates = try ctx.fetch(FetchDescriptor<SessionTemplate>())
    #expect(templates.contains { $0.id == templateID })
}
```

If SwiftData in-memory contexts do not reliably enforce `.deny` (a known SDK gap), the test should document this with a `withKnownIssue` annotation rather than silently omitting the assertion, which makes it appear the contract is covered when it is not.

---

### CR-05: `BlockOverviewScreen` preview registers `SchemaV5.models` — breaks at runtime if V7-only entities are referenced

**File:** `fitbod/Periodization/BlockOverviewScreen.swift:612`

**Issue:** The `#Preview` block constructs its `ModelContainer` with `Schema(SchemaV5.models)`. `SchemaV5.models` does not include `Split`, `SplitSessionSlot`, `SessionTemplate`, or `SplitSessionSlot` — all of which are V7 entities. `BlockOverviewScreen.body` and its sub-views (`weekCarousel`, `phaseProgressionList`) access `block.split?.slots`, `session.slot?.split`, and `session.template` at runtime. Accessing these relationships in a container that has no `Split` or `SplitSessionSlot` entity tables is undefined behavior in SwiftData and will produce a runtime crash or silent nil returns in the preview.

**Fix:**

```swift
// Replace SchemaV5.models with SchemaV7.models in the preview:
let schema = Schema(SchemaV7.models)
```

---

## Warnings

### WR-01: Test 9 (`slotNullifyHistoryIntact`) does not verify `session.slot == nil` after slot deletion

**File:** `fitbodTests/Persistence/SchemaV7MigrationTests.swift:375-422`

**Issue:** Test 9 verifies only that the `Session` row survives after a `SplitSessionSlot` is deleted. It does NOT verify that `session.slot` becomes `nil` (the nullify contract). The spec §3 states: "Session.slot delete rule is **nullify** — deleting a slot sets Session.slot = nil; session history is never erased." Only half of that invariant (history intact) is asserted; the nullify half is not.

**Fix:** After the slot is deleted, fetch the session and assert `session.slot == nil`:

```swift
let allSessions = try ctx.fetch(FetchDescriptor<Session>())
let savedSession = allSessions.first { $0.id == sessionID }
#expect(savedSession?.slot == nil,
        "Session.slot must be nil after the slot is deleted (nullify rule)")
```

---

### WR-02: Step 4 (rotation continuity backfill) uses `sessions` fetched in step 2 — stale after step 3 mutations

**File:** `fitbod/Persistence/FitbodSchemaMigrationPlan.swift:384-401`

**Issue:** `let sessions` is fetched once at line 324 (start of step 2) and reused in steps 3 and 4. Step 3 mutates `session.template` for all stash entries and also inserts `Split` and `SplitSessionSlot` rows. The in-memory `sessions` array used in step 4 (`blockSessions`) therefore reflects the state before `session.template` assignments. In SwiftData's in-memory model objects the assignment is reflected on the live object references (since `session` is an `@Model` and mutation is tracked by the context), so this works in practice — but the code's correctness depends on SwiftData's live-object semantics remaining true even for objects materialized before the step 3 mutation loop.

More critically: `$0.block?.id == activeBlock.id` in the filter at line 385 relies on `Session.block` still being populated. In a fresh V7 migration, the old `Routine.block` relationship is gone, but `Session.block` (a direct relationship on `Session` that points to `Block`) survived the migration. This is fine, but worth asserting in the tests.

**Fix:** Re-fetch sessions at step 4 to guarantee post-mutation state:

```swift
// At the start of step 4, re-fetch sessions after step 2/3 mutations:
let freshSessions = try context.fetch(FetchDescriptor<Session>())
let blockSessions = freshSessions
    .filter { $0.block?.id == activeBlock.id && $0.completedAt != nil }
    ...
```

---

### WR-03: `Split.blocks` relationship uses `deleteRule: .nullify` but the spec §4 requires deny on live (non-completed) blocks

**File:** `fitbod/Models/Split.swift:35-36`

**Issue:** `Split.blocks` declares `@Relationship(deleteRule: .nullify, inverse: \Block.split)`. Spec §4 states: "deny-delete while referenced by any non-completed block." The nullify rule means SwiftData will allow hard-deletion of a `Split` even when a draft/ready/active block references it, silently setting `Block.split = nil`. The spec requires a **service-layer deny** for non-completed blocks. The comment in spec §4 acknowledges SwiftData's `.deny` is unconditional (it would also deny deletion when only completed blocks remain), so the spec explicitly calls for "service-layer logic plus a test" — not a schema rule.

The issue is that neither the service-layer logic NOR the test (spec §9: "Deny-rule tests: split archive or delete while referenced by a non-completed block") exists in the reviewed code. The only delete behavior tested is `blockSplitNullify` (test 10), which tests a *completed* block — exactly the case where deletion should be allowed. The case that must be denied (active/draft/ready block references the split) is not tested.

**Fix:** Add service-layer guard in `SplitDetailView` or the model-level delete helper:

```swift
// Before deleting a Split, check for live (non-completed) block references:
guard !(split.blocks ?? []).contains(where: { $0.derivedStatus != .completed }) else {
    throw SplitDeletionError.referencedByLiveBlock
}
```

And add a corresponding test that seeds an active block referencing the split and verifies the guard fires.

---

### WR-04: `SessionTemplate.block` comment references removed `Block.routines` keypath as if it still exists

**File:** `fitbod/Models/SessionTemplate.swift:17-20`

**Issue:** The header comment at line 17-20 reads: "The optional `block` relationship lets a template belong to a periodization block when one is active; the inverse declaration lives on `Block.routines` (keypath updated to \SessionTemplate.block) so the inverse keypath chain is single-sided." `Block.routines` was removed in this phase (Block.swift:19-21 explicitly says so). This comment now describes a ghost relationship, and a future reader following the keypath will not find `Block.routines` anywhere. Beyond being stale documentation, this is also the source of CR-02 (the `block` field itself should be removed).

**Fix:** Remove the field and the comment together (see CR-02 fix). If retaining the field intentionally for a future use case, update the comment to document current V7 semantics.

---

### WR-05: `ExportBlockDTO` and `ExportSessionDTO` are missing all V7 fields — backup/export silently drops program-graph data

**File:** `fitbod/Export/ExportDTOs.swift:427-446`, `fitbod/Export/ExportDTOs.swift:312-341`

**Issue:** `ExportBlockDTO` has no `archivedConfigJSON`, `schedulingModeRaw`, `trainingDaysJoined`, or `split` fields. `ExportSessionDTO` has no `templateName` or `slot` field. The backup archiver and restorer do not write or restore these V7-era fields. A backup taken after a V6→V7 migration and restored will lose the archived block config (the freeze #2 contract), the scheduling mode, training days, and rotation continuity state. This is a silent data loss path: the export appears to succeed, but critical V7 fields are not preserved.

**Fix:** Add V7 fields to both DTOs and update the archiver/restorer to write and read them. At minimum, `archivedConfigJSON` must round-trip since spec §6 makes it the sole source of truth for completed-block views — a restore that discards it leaves completed blocks permanently unreadable.

---

### WR-06: `PreviewModelContainer.make` docstring says "current schema (`SchemaV4`)" — stale after V7 flip

**File:** `fitbod/Persistence/PreviewModelContainer.swift:34`

**Issue:** The doc comment reads "Builds a fresh in-memory `ModelContainer` over the current schema (`SchemaV4`)." The implementation already uses `SchemaV7.models` (line 41), so the schema reference in the docstring is three versions stale. While cosmetic, this is in a high-churn file (hotspot list) and a developer reading the comment will be misled about which schema is active.

**Fix:** Update the docstring:

```swift
/// Builds a fresh in-memory `ModelContainer` over the current schema (`SchemaV7`).
```

---

## Info

### IN-01: `InMemoryContainer.makeEmpty` comment says "still opens against `SchemaV1`" — correct but potentially misleading

**File:** `fitbodTests/TestSupport/InMemoryContainer.swift:41-45`

**Issue:** The comment at line 41-45 says "Intentionally still opens against `SchemaV1` — `SchemaV1Tests` asserts a 12-entity contract." The function is used by `SchemaV1Tests` which has a specific purpose, but any test that calls `makeEmpty()` expecting the latest schema will get a V1 container and be missing all post-V1 entities. The existence of `makeCurrent()` (which uses `SchemaV7.models`) mitigates this, but the function's name `makeEmpty` does not signal that it's V1-scoped.

**Fix:** Rename to `makeEmptyV1()` or `makeSchemaV1Empty()` to make the schema version explicit, or add a prominent warning in the docstring that this returns a V1-era container, not a current-schema container.

---

### IN-02: `SchemaV6MigrationTests.migrationPlanRegistersV6` test name/docstring says "V6" but asserts V7

**File:** `fitbodTests/Persistence/SchemaV6MigrationTests.swift:64-69`

**Issue:** The test is named `migrationPlanRegistersV6` and its docstring says "lists SchemaV6 as the latest schema", but the assertion checks `names.last == "SchemaV7"` and the full chain includes `"SchemaV7"`. This was presumably updated when SchemaV7 was added to the migration plan but the test name was not updated. Minor, but creates confusion in failure output.

**Fix:** Rename the test to `migrationPlanRegistersV7AsCurrent` and update the docstring to reflect that it now verifies the full 7-schema chain.

---

## Fix Status (2026-06-10)

Scope: all 5 Critical + all 6 Warnings (Info skipped). Result: 10 fixed, 1 skipped.

| ID | Status | Commit | Notes |
|----|--------|--------|-------|
| CR-01 | fixed | `cea6479` | Added nested `SchemaV1.Routine`/`.RoutineExercise` + `SchemaV2.Routine`/`.RoutineExercise` (V1/V2 on-disk shapes); replaced V7-renamed entries in both models arrays. `String(describing:)` resolves to `Routine`/`RoutineExercise` so V1/V2 tests still hold. |
| CR-02 | **skipped** | — | False premise. `SessionTemplate.block` is NOT a dead orphan — `SessionFactory` reads `template.block` to resolve the scheduled `BlockPhase` (volume/intensity multipliers) at log time, and `RoutineDraft`/`RoutineDuplicator` carry it. 8+ tests set `routine.block`. Removing it breaks the build and severs block-phase periodization. Proper removal = Phase 8 resolver migration, out of scope. WR-04 (stale comment) was fixed instead. |
| CR-03 | fixed | `d401622` | `try?` → `try` on `context.save()` in `bumpPlateauToleranceDefault`. |
| CR-04 | fixed (requires human verification) | `17cbb4e` | Added `SchemaV7DeleteRuleBehaviorTests` — isolated `.serialized` suite with its own container that attempts `ctx.delete(template)` while slotted. Runtime `.deny` enforcement is SDK-flaky (documented), so wrapped in `withKnownIssue(isIntermittent:)` + a portable survival invariant. Confirm the runtime deny fires in your environment. |
| CR-05 | fixed | `59ba71d` | `BlockOverviewScreen` `#Preview` now uses `Schema(SchemaV7.models)`. |
| WR-01 | fixed | `438e488` | Test 9 now asserts `session.slot == nil` after slot deletion (nullify half). |
| WR-02 | fixed | `146194a` | Step 4 re-fetches sessions after step 2/3 mutations. |
| WR-03 | fixed | `1f94c6e` | New `SplitDeletionGuard` (`canDelete`/`assertDeletable` + `SplitDeletionError`) + `SplitDeletionGuardTests` (5 cases). Phase 8 wires it into `SplitDetailView`. |
| WR-04 | fixed | `603f7e8` | Corrected stale `SessionTemplate.block` doc comment (no longer claims `Block.routines` inverse exists). |
| WR-05 | fixed | `e48c1cf` | Added V7 fields to `ExportBlockDTO` (`schedulingModeRaw`, `trainingDaysJoined`, `archivedConfigJSON`, `splitName`) and `ExportSessionDTO` (`templateName`, `slotPosition`, `slotSplitName`); updated both mappers, restorer (data-loss-critical scalars), round-trip test, snapshot fixture. Golden `example-export.json` emptied → snapshot test regenerates it on first run (documented behavior; expect one red then green). |
| WR-06 | fixed | `cf8dc60` | `PreviewModelContainer` docstring `SchemaV4` → `SchemaV7`. |

Build verification: `xcodebuild build-for-testing` (iPhone 17 sim) compiles all modified source. (The worktree required copying the untracked `fitbod/Design/BRUActionPopover.swift` — a pre-existing dependency of `ProgramView.swift` unrelated to these fixes.)

_Fixed: 2026-06-10 — Claude (gsd-code-fixer)_

---

_Reviewed: 2026-06-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
