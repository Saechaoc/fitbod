# Fitbod

A personal iPhone app for granular, prescriptive weight training: explicit exercise targets, selectable progression, training blocks, warmup ramps and muscle-volume tracking.

## Canonical workflow

Agent entrypoint: `AGENTS.md`; development/completion policy: `docs/DEVELOPMENT.md`; commands: `docs/SETUP.md`; code patterns: `CONVENTIONS.md`.
`docs/ROADMAP.md` owns priorities, unfinished work, product decisions and acceptance criteria.
Read the relevant RM entry before starting and update it when scope, status, dependencies or evidence changes.
Read only the roadmap index (the lines above `## Feature definitions`, about the first 80) and your own entry (`rg -n 'id="rm-0NN"' docs/ROADMAP.md`), never the whole file.
Keep stable RM IDs and original finding IDs; do not create competing backlogs, status handoffs or ticket ledgers.
No GSD command or generated planning artifact is required before editing.
Use a short execution plan in the conversation; existing implementation notes are subordinate input.
Technical contracts live in `ARCHITECTURE.md`; approved design layouts and the design-map audit are references.
Record concise test results and limitations in the relevant RM entry. Keep run logs and screenshots in CI artifacts or ignored local output; do not create report archives or evidence dumps in the repository.
Routine verification is the agent's responsibility. Planned → Active → Done requires working agreed scope, appropriate passing checks and current docs, without routine personal sign-off.
Finished implementation with unavailable required proof is Implemented; verification pending: name the exact open check in the roadmap, block only dependent work and continue independent planning/development. Ask for user involvement only for unavailable observations or product decisions.
Separate Requires, Scheduled after and Verify when. Archive finished substantial plans under `docs/archive/features/` with historical scope, build/commit, results and RM backlink; keep pending device checks open in the roadmap. Preserve unsupported old completion claims as historically shipped; acceptance unrecorded, without a whole-app retest.

## Stack

Swift 6 strict concurrency · SwiftUI · SwiftData local-only · iOS 26.4.
Swift Charts for charts; Canvas/paths for the muscle silhouette.
Swift Testing for unit/model tests; XCTest/XCUIApplication for UI tests.
Bundled free-exercise-db catalog with stable-ID incremental seeding and local additions.
Rationale: `docs/STACK-RESEARCH.md`. Setup/test tiers: `docs/SETUP.md`.

## Development stage: prototype

Learn quickly and scale effort to maturity/risk; never skip data integrity, correctness, privacy or security.
Keep native/BRU controls, Dynamic Type roles, token colors and word labels.
Workflow stability, testing effort and release gates: `docs/DEVELOPMENT.md`; that policy takes precedence over general advice to fix unrelated flaws. Commands and runner limits: `docs/SETUP.md`.
Documentation/tooling-only work runs relevant checks. App changes run the unit target; run affected workflow UI tests when routes, interactions or stored-data behavior change. Copy/styling needs simulator inspection, not new copy-pinning tests.

## Code search and changes

- Prefer `rg`/`rg --files`, narrow paths/types and contextual reads. Use GitNexus flows/context/impact as required below.
- Use `ast-grep` for syntax patterns and LSP/symbol tools for definitions/references.
- Avoid generated files, build outputs, snapshots, lockfiles and large fixtures unless relevant.
- Preserve unrelated workspace edits and untracked implementation plans; stage exact task-owned paths only.
- Never add a Co-Authored-By trailer.

## Current app contracts

- Tabs: Today, Program, Progress, Library, with independent native navigation stacks and BRU tab controls. Settings is a Today sheet; History opens from Progress → Workouts.
- Logger belongs only to Today's stack. Program/session/Live Activity entry uses `ResumeWorkoutRequest`; Back returns to Today. Tab controls hide in the logger/while editing.
- SchemaV7 is the sole baseline, without the removed historical migration chain. Only confirmed missing migration mappings move incompatible stores aside with SQLite siblings; other open failures preserve the store and offer retry (RM-001).
- Units relabel, never implicitly convert; exercise overrides win. Pattern filtering stays hidden until metadata exists.
- Run simulator tests serially on dedicated devices. DEBUG reset is initial launch only; persistence relaunches omit reset.
- Full program graph, freeze points, time/membership rules, correction transactions and delete rules: `ARCHITECTURE.md`.
- Current results, limitations and acceptance: `docs/ROADMAP.md`. CI artifacts and ignored `.ci/` hold detailed run output.

## Conventions

- `@Observable` + `@State`/`@Bindable`/environment only in new code; no ObservableObject/Published/StateObject/ObservedObject.
- `@Query` directly in views, never mirrored in a view model; transient observable state may be owned by the view.
- One NavigationStack per tab, no parent stack around TabView. Library search fetches every exercise, runs facets through `applyPostFetchFilters(to:)`, then ranks matches with `ExerciseSearch`; keep both out of `#Predicate`, which fails to type-check or translate them. Avoid multi-level optional predicate chains.
- Insert models before assigning relationships. DTOs handle Codable; no Codable on models. Containers go through FitbodModelContainer.
- Preserve logged snapshots; throwing saves restore context and visible saved values on failure.
- Reuse BRU tokens/components and existing helpers. No extra dependencies or persistence framework.
- No CloudKit, accounts or HealthKit in v1; scope changes require a roadmap decision.
- Additional code conventions: `CONVENTIONS.md`; shared UI rules: `docs/design-system/`.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **fitbod** (11905 symbols, 233617 relationships, 219 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/fitbod/context` | Codebase overview, check index freshness |
| `gitnexus://repo/fitbod/clusters` | All functional areas |
| `gitnexus://repo/fitbod/processes` | All execution flows |
| `gitnexus://repo/fitbod/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
