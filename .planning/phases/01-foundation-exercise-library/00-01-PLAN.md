---
phase: 01
plan: 00-01
wave: 0
slug: project-hygiene
complexity: S
requirements: []
covers_pitfalls: ["#2 corollary (delete Item.swift)", "#9 (Swift 6 strict concurrency for @ModelActor)"]
depends_on: []
files_modified:
  - fitbod.xcodeproj/project.pbxproj
  - fitbod/Item.swift  # DELETED
created: 2026-05-10
---

# Plan 00-01 — Project Hygiene

> **Wave 0 / Sequence 1.** Establishes the build settings and folder skeleton that every later plan composes on. **Does not touch product code yet** — but does delete the stock `Item.swift` model file (its references in `fitbodApp.swift` and `ContentView.swift` are fixed in plan `01-PLAN-01-02`, which runs in Wave 1).

## Goal

Bump the Xcode project to Swift 6 with strict concurrency, confirm iOS deployment target ≥18.0, delete the stock `Item.swift` template model, and create the feature-organized folder hierarchy that Wave 1+ plans will fill in.

## Requirements Covered

This plan does not directly close any product requirements; it is enabling work that unblocks **FOUND-01..07** (which require Swift 6 strict concurrency for `@ModelActor`) and **LIB-01..06** (which depend on the folder layout for file placement).

## Files to Create / Modify

### Modify
- `fitbod.xcodeproj/project.pbxproj` — bump `SWIFT_VERSION` from `5.0` to `6.0` on the `fitbod` target; add `SWIFT_STRICT_CONCURRENCY = complete` on the target; verify `IPHONEOS_DEPLOYMENT_TARGET = 26.4` (already set per `01-RESEARCH.md` Environment Availability — confirm only). Edit via `sed`/`xcodebuild -modifyBuildSetting` or hand-edit the pbxproj.

### Delete
- `fitbod/Item.swift` — remove the file. References in `fitbod/fitbodApp.swift` (line 15: `Schema([Item.self])`) and `fitbod/ContentView.swift` (lines 13, 19, 22, 26, 49, 79) will produce compile errors until Wave 1 (`01-PLAN-01-02`) rewires the schema and replaces `ContentView`. **The project will not compile between plans `00-01` and `01-02` — this is expected and intentional.**

### Create (empty directories with `.gitkeep` placeholders)
Feature-organized layout per `01-RESEARCH.md` § Recommended Project Structure:

- `fitbod/App/.gitkeep`
- `fitbod/Persistence/.gitkeep`
- `fitbod/Models/.gitkeep`
- `fitbod/Models/Enums/.gitkeep`
- `fitbod/ExerciseLibrary/.gitkeep`
- `fitbod/Settings/.gitkeep`
- `fitbod/Resources/.gitkeep`
- `fitbod/Resources/ExerciseSeed/.gitkeep`
- `fitbodTests/TestSupport/.gitkeep`

Note: Xcode does not auto-discover folders not registered in the project file. The pbxproj must reference each new folder as a group. The simplest approach: use Xcode's "Add files to fitbod…" with "Create groups" (not "Create folder references"); or hand-edit the pbxproj to add `PBXGroup` entries. Either works; planner picks the lower-friction path.

## Acceptance Criteria

1. `xcodebuild -showBuildSettings -project fitbod.xcodeproj -target fitbod | grep -E '^\s+(SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET)'` shows:
   - `SWIFT_VERSION = 6.0`
   - `SWIFT_STRICT_CONCURRENCY = complete`
   - `IPHONEOS_DEPLOYMENT_TARGET = 26.4`
2. `fitbod/Item.swift` does not exist (`test ! -f fitbod/Item.swift && echo OK`).
3. The new folder hierarchy exists on disk under `fitbod/` and `fitbodTests/`:
   ```
   ls -d fitbod/App fitbod/Persistence fitbod/Models fitbod/Models/Enums fitbod/ExerciseLibrary fitbod/Settings fitbod/Resources fitbod/Resources/ExerciseSeed fitbodTests/TestSupport
   ```
   Each directory exists and contains at least a `.gitkeep`.
4. The project file references each new folder as a group (verified by opening `fitbod.xcodeproj` in Xcode and seeing the groups in the Navigator; programmatically: `grep -c "App/.gitkeep" fitbod.xcodeproj/project.pbxproj` returns ≥1 — or equivalent for each folder).
5. **Known intentional breakage:** `xcodebuild build` will fail with "Cannot find 'Item' in scope" errors. This is expected — the next plan (`01-PLAN-01-02`) fixes them. Verify the failure is *only* `Item` references (no other unrelated errors).

## Test Expectations

No new tests in this plan. The existing `fitbodTests/fitbodTests.swift` placeholder test stays untouched (it does not reference `Item`).

**Sanity check command (not a test):**
```bash
xcodebuild -showBuildSettings -project fitbod.xcodeproj -target fitbod 2>/dev/null | grep -E 'SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET'
```

## Decisions Honored

- **C-1 (CONTEXT.md Area 4 — `Item.swift` deletion):** "delete after `SchemaV1` is wired, before any production schema work." Interpretation: deleting the *file* in Wave 0 surfaces compile errors that Wave 1's schema work *must* address — preventing the pitfall #2 corollary where the stock model lingers. The file is gone in 00-01; the references in `fitbodApp.swift` are rewritten in `01-PLAN-01-02`.
- **R-1 (RESEARCH.md Pitfall 9 — Swift version):** Bumps `SWIFT_VERSION` to `6.0` so the `@ModelActor` work in Wave 2 has strict-concurrency guarantees from the start, not retroactively.
- **D-1 (Claude's discretion — folder layout):** Feature-organized layout per RESEARCH.md § Recommended Project Structure.

## Anti-Patterns Avoided

- **Not** keeping `Item.swift` "for now." (PITFALLS.md #2 corollary.)
- **Not** deferring the Swift 6 bump to "after the schema is done." (PITFALLS.md #9 — bumping retroactively means rewriting any actor code written under Swift 5 semantics.)
- **Not** creating `Views/` `Models/` `ViewModels/` (classic MVVM layout). The architecture is MV-VM-lite — no `ViewModels/` folder ever exists.

## Out of Scope (handled by later plans)

- Rewiring `fitbodApp.swift`'s `Schema([...])` array to remove the deleted `Item` reference → handled by `01-PLAN-01-02`.
- Replacing `ContentView` with `RootView` → handled by `01-PLAN-03-01`. (`01-PLAN-01-02` provides an interim `RootView` stub that just shows `Text("Wave 1 done — Wave 3 fills this in")` so the project compiles after Wave 1.)
- Adding the `exercises.json` resource to the bundle → handled by `01-PLAN-02-01`.
- Populating `AccentColor.colorset` → handled by `01-PLAN-00-02`.

## Commit Message Template

```
chore(01): bump Swift to 6.0 strict, delete Item.swift, scaffold folders

- SWIFT_VERSION 5.0 → 6.0 with SWIFT_STRICT_CONCURRENCY = complete on fitbod target
- delete fitbod/Item.swift (stock template — replaced by SchemaV1 in 01-PLAN-01-02)
- create feature-organized folder layout per 01-RESEARCH.md § Project Structure
- IPHONEOS_DEPLOYMENT_TARGET already at 26.4 (verified, no change)

Project will fail to compile until 01-PLAN-01-02 lands; Item references in
fitbodApp.swift and ContentView.swift are intentionally orphaned for one plan
to prevent the pitfall-#2-corollary of leaving the stock model in the schema.
```
