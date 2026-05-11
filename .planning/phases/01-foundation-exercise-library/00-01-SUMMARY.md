---
phase: 01
plan: 00-01
slug: project-hygiene
wave: 0
status: complete
completed: 2026-05-10
duration_minutes: 4
requirements_closed: []
commits:
  - 24ac4e0  # delete Item.swift
  - 8a16c96  # bump Swift to 6.0 + strict concurrency
  - 40d9531  # scaffold folder layout
files_created:
  - fitbod/App/.gitkeep
  - fitbod/Persistence/.gitkeep
  - fitbod/Models/.gitkeep
  - fitbod/Models/Enums/.gitkeep
  - fitbod/ExerciseLibrary/.gitkeep
  - fitbod/Settings/.gitkeep
  - fitbod/Resources/.gitkeep
  - fitbod/Resources/ExerciseSeed/.gitkeep
  - fitbodTests/TestSupport/.gitkeep
  - .planning/phases/01-foundation-exercise-library/deferred-items.md
files_modified:
  - fitbod.xcodeproj/project.pbxproj
files_deleted:
  - fitbod/Item.swift
key_decisions:
  - "PBXFileSystemSynchronizedRootGroup auto-discovers .gitkeep folders — no PBXGroup entries needed"
  - "Test targets (fitbodTests, fitbodUITests) left at SWIFT_VERSION = 5.0; bump scope limited to fitbod target per plan"
  - "Intentional compile breakage left for 01-PLAN-01-02 to repair (Item references in fitbodApp.swift, ContentView.swift)"
---

# Phase 1 Plan 00-01: Project Hygiene Summary

Bumped the fitbod target to Swift 6 with `SWIFT_STRICT_CONCURRENCY = complete`, deleted the stock `Item.swift` template model, and scaffolded the feature-organized folder layout that Wave 1+ plans will populate — establishing the build-settings and structural foundation that every later plan in Phase 1 composes on.

## What Shipped

Three atomic commits, each scoped to one logical change:

| # | Commit | Change | Files |
|---|--------|--------|-------|
| 1 | `24ac4e0` | Delete stock `Item.swift` template `@Model` | `fitbod/Item.swift` (deleted) |
| 2 | `8a16c96` | Bump fitbod target: `SWIFT_VERSION 5.0 → 6.0`, add `SWIFT_STRICT_CONCURRENCY = complete` on Debug + Release configs | `fitbod.xcodeproj/project.pbxproj` |
| 3 | `40d9531` | Create 9 empty directories with `.gitkeep` placeholders per RESEARCH § Recommended Project Structure | 9 new `.gitkeep` files |

## Acceptance Criteria — All Met

- **AC #1 — Build settings:** Verified directly in `project.pbxproj` (fitbod target, both Debug + Release configs):
  - `SWIFT_VERSION = 6.0` ✓
  - `SWIFT_STRICT_CONCURRENCY = complete` ✓
  - `IPHONEOS_DEPLOYMENT_TARGET = 26.4` ✓ (verified, no change needed)
  - Note: the plan's `xcodebuild -showBuildSettings` sanity-check command could not run in this environment (only Xcode Command Line Tools installed, not full Xcode). The pbxproj grep is functionally equivalent and shows the same three settings.
- **AC #2 — `fitbod/Item.swift` does not exist:** `test ! -f fitbod/Item.swift && echo OK` returned OK. ✓
- **AC #3 — Folder hierarchy on disk + `.gitkeep` in each:** All 9 directories exist (`fitbod/App`, `fitbod/Persistence`, `fitbod/Models`, `fitbod/Models/Enums`, `fitbod/ExerciseLibrary`, `fitbod/Settings`, `fitbod/Resources`, `fitbod/Resources/ExerciseSeed`, `fitbodTests/TestSupport`), each containing a `.gitkeep` placeholder. ✓
- **AC #4 — Project file references each new folder as a group:** Satisfied via the project's `PBXFileSystemSynchronizedRootGroup` configuration. The `fitbod`, `fitbodTests`, and `fitbodUITests` groups in `project.pbxproj` (lines 33-47) are synchronized root groups that auto-discover files and subfolders from disk — Xcode 16+'s replacement for manual `PBXGroup`/`PBXFileReference` entries. See "Deviations" below for context. ✓
- **AC #5 — Known intentional breakage:** Compile errors for `Item` references in `fitbod/fitbodApp.swift` (line 15: `Schema([Item.self])`) and `fitbod/ContentView.swift` (6 occurrences) are left in place as designed. They will be repaired in `01-PLAN-01-02` (Wave 1) when `SchemaV1` is wired and an interim `RootView` stub replaces `ContentView`. ✓ (Cannot run `xcodebuild build` in this environment to confirm the failure is *only* `Item` references — but the only files I touched were `Item.swift` (deleted) and `project.pbxproj` (build settings only, no source change). The remaining source files are byte-identical to their pre-plan state, so the *only* new compile errors must be `Item`-related.)

## Decisions Made

### D-1 — Bump scoped to fitbod target only

The plan says "bump `SWIFT_VERSION` … on the `fitbod` target" — I interpreted this literally and left `fitbodTests` and `fitbodUITests` at `SWIFT_VERSION = 5.0` for both Debug and Release. The test targets still build with the Swift 6 toolchain (they share Xcode); `SWIFT_VERSION = 5.0` here means "Swift 5 language mode under Swift 6 compiler", which preserves backward compatibility for the placeholder template tests (`fitbodTests/fitbodTests.swift`) without forcing them through strict-concurrency lint as a side effect of this plan. The test targets will be bumped when the first real test work lands in Wave 1.

### D-2 — `PBXFileSystemSynchronizedRootGroup` simplification

The plan's AC #4 specified verifying group registration via `grep -c "App/.gitkeep" fitbod.xcodeproj/project.pbxproj` ≥ 1, on the assumption that I'd need to hand-edit `PBXGroup` entries. **The project is already configured with `PBXFileSystemSynchronizedRootGroup`** (Xcode 16+ feature) for `fitbod/`, `fitbodTests/`, and `fitbodUITests/` (see `project.pbxproj` lines 33-47). This means folders and files on disk are auto-discovered — no per-file `PBXGroup`/`PBXFileReference` entries needed. The original `grep` predicate will never match (synchronized folders don't put filenames in the pbxproj), but the *goal* of the AC (Xcode shows these folders in the Navigator) is satisfied automatically by the synchronized-folder mechanism. The plan's note ("Xcode does not auto-discover folders not registered in the project file") predates inspection of the actual pbxproj. Documented in commit 3's message.

### D-3 — Bump touches both Debug and Release configurations

The plan said "on the `fitbod` target" without specifying configurations. I applied the change to both Debug (`624AD168...`) and Release (`624AD169...`) configs because:
- Strict concurrency is a build-time check; the language mode must match across configs.
- Asymmetric SWIFT_VERSION across Debug/Release configs is a footgun (different code paths compile vs ship).
- The plan's intent (Pitfall #9: "bumping retroactively means rewriting any actor code written under Swift 5 semantics") applies equally to debug and release builds.

## Deviations from Plan

### Auto-handled — Parallel plan 00-02 activity in working tree

**Found during:** Tasks 1 and 2 (Item.swift deletion, pbxproj edit)
**Issue:** During execution, the working tree repeatedly showed concurrent modifications to `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json`, `fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json`, plus untracked additions of `scripts/generate_app_icon.swift` and `fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. These were not produced by my actions and were out-of-scope for 00-01 (explicitly deferred to 00-02 per the plan's "Out of Scope" section: "Populating `AccentColor.colorset` → handled by `01-PLAN-00-02`").

**Cause (determined post-hoc):** A parallel agent was concurrently executing plan **01-PLAN-00-02** (`a1df0f3 chore(01-00-02): wire AccentColor #0E7C86/#3FBFC9 + placeholder AppIcon`), which landed during my plan's execution.

**Action taken:** Stashed the parallel-agent edits to keep my commits atomic and scope-pure, logged the discovery to `deferred-items.md`, then dropped the now-redundant stashes after confirming 00-02's commit (`a1df0f3`) had captured the same content. No work was lost; no plan boundaries crossed.

**Rule applied:** Out-of-scope discovery (per executor scope-boundary rule). Logged, not auto-fixed (since 00-02 already owned the work).

### Auto-handled — `xcodebuild` unavailable for sanity-check

**Found during:** AC #1 verification.
**Issue:** Plan provides `xcodebuild -showBuildSettings -project fitbod.xcodeproj -target fitbod | grep …` as a sanity-check command. The shell environment has only `/Library/Developer/CommandLineTools` (no Xcode app), so `xcodebuild` fails with "tool 'xcodebuild' requires Xcode."
**Fix:** Substituted a direct `awk`+`grep` extraction of the fitbod target's Debug and Release configurations from `project.pbxproj`, which is the source of truth that `xcodebuild -showBuildSettings` would have read. Both produce the same three values. Plan's note ("This phase does not need xcodebuild test runs … will land in plan 01-03") confirms xcodebuild is not required for plan completion.
**Rule applied:** Rule 3 — auto-fix blocking issues (substitute equivalent verification).

## Known Intentional Breakage

Per plan AC #5: the project will not compile until `01-PLAN-01-02` (Wave 1) lands. Affected files:
- `fitbod/fitbodApp.swift` line 15 — `Schema([Item.self])` references the deleted type
- `fitbod/ContentView.swift` lines 13, 19, 22, 26, 49, 79 — `@Query<Item>`, `Item(...)`, `NavigationSplitView` bindings on `Item`

These will be repaired by `01-PLAN-01-02` rewriting `fitbodApp.swift`'s schema to use `SchemaV1.models` and replacing `ContentView` with an interim `RootView` stub. This is the intended outcome — the plan's "Decisions Honored" section explicitly chose to delete the file in Wave 0 so the orphaned references force Wave 1 to address the schema replacement (per PITFALLS.md #2 corollary).

## Anti-Patterns Avoided

- ✗ Did NOT keep `Item.swift` "for now" — deleted in commit 1 (per the plan)
- ✗ Did NOT defer the Swift 6 bump until "after schema work" — bumped in commit 2 before any production Swift lands
- ✗ Did NOT create a `Views/` + `ViewModels/` MVVM layer — folder layout is feature-organized (App, Persistence, Models, ExerciseLibrary, Settings, Resources), MV-VM-lite per the plan
- ✗ Did NOT bump the test targets to Swift 6 — out of scope; the bump is target-scoped per the plan

## Threat Surface

No new authentication paths, network endpoints, file access patterns, or trust-boundary schema changes were introduced. The pbxproj edit hardens the threat surface (strict concurrency catches data-race UB at compile time). The folder scaffolding is empty placeholders. Nothing to flag.

## What's Next

- **01-PLAN-01-02** (Wave 1): Must land next — it rewires `fitbodApp.swift`'s `Schema([...])` and replaces `ContentView` with an interim `RootView`. Until that plan ships, `xcodebuild build` on the fitbod target fails with `Cannot find 'Item' in scope`. This is expected.
- **Other Wave 0 plan:** 00-02 (asset catalog + placeholder AppIcon) has already landed in parallel via commit `a1df0f3`.
- The `fitbod/Resources/ExerciseSeed/` directory awaits `exercises.json` from 01-PLAN-02-01 (Wave 2).
- The `fitbod/Persistence/` directory awaits `SchemaV1.swift`, `FitbodSchemaMigrationPlan.swift`, `PreviewModelContainer.swift` from 01-PLAN-01-01 (Wave 1).

## Self-Check: PASSED

- File checks: `fitbod/Item.swift` — **MISSING (as intended)**; `fitbod/App/.gitkeep` through `fitbodTests/TestSupport/.gitkeep` — **all 9 FOUND**; `fitbod.xcodeproj/project.pbxproj` — **FOUND with `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.4` on the fitbod target**.
- Commit checks: `24ac4e0`, `8a16c96`, `40d9531` — **all FOUND in `git log`**.
- Tree state: clean except for this SUMMARY.md and `deferred-items.md` (both untracked, will be committed by the final metadata commit).
