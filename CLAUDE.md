<!-- GSD:project-start source:PROJECT.md -->
## Project

**Fitbod**

A personal iOS app for comprehensive, detail-rich weight training tracking — built for one serious lifter (the developer) who finds existing apps (Strong, Hevy, Jefit, FitNotes, Fitbod) shallow on routine building, prescription, periodization, and progress visualization. It treats lifting like a discipline: per-exercise prescription, user-selectable smart progression, defined training blocks, auto warm-up ramps, and RP-style muscle-volume tracking.

**Core Value:** **Granular, prescriptive workout sessions** — every set in a session is intentionally specified (intent, target reps, target RPE, smart-progressed weight) rather than a replay of last time, and progress is visible at the resolution serious lifters actually train at.

### Constraints

- **Tech stack** — SwiftUI + SwiftData (locked by the existing Xcode template; no good reason to swap)
- **Platform** — iOS only (no Android, no web)
- **Persistence** — Local-only SwiftData for v1; no backend, no auth, no cloud sync
- **User scale** — Single user (the developer); no multi-tenant concerns
- **Hardware** — Phone-only v1; no Apple Watch, no external sensors, no VBT hardware
- **Distribution** — Personal install via Xcode; no App Store, no TestFlight required for v1
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Stack

Swift 6 (strict concurrency) · SwiftUI · SwiftData (local-only) · iOS 26.4 target
Swift Charts for all data charts; Canvas for the muscle heatmap body silhouette
Swift Testing for unit tests; XCTest for UI tests only (Apple-confirmed gap — no `XCUIApplication` support)
Exercise catalog: vendored free-exercise-db JSON (public domain, ~800 exercises), seeded on first launch, strength/powerlifting/olympic/strongman categories only

Full rationale, alternatives, sources, install: docs/STACK-RESEARCH.md
<!-- GSD:stack-end -->

## Development stage: prototype

We are still shaping workflows and visual design, so speed of learning comes first.
Build the simplest working version, scale tests and polish to the change's maturity and risk, and never skip data integrity, correctness, privacy or security.
Keep cheap accessibility foundations (native controls, BRU type and color roles, word labels); defer VoiceOver refinement, per-screen AX3 fixes and full two-phone runs until a workflow is stable.
Details, deferral triggers and release-readiness conditions: `docs/DEVELOPMENT.md`.
In this repo that guide takes precedence over general user-level guidance to fix every unrelated flaw or to ignore development cost.

## Code Search Rules

- Prefer `rg` over `grep`.
- Prefer `rg --files` or `fd` over `find`.
- Start with narrow searches using file types and path filters.
- Use `rg -n -C 2` for context instead of reading whole files.
- Use `rg -l` to identify candidate files before reading.
- Use `ast-grep` for syntax patterns, annotations, function calls, imports, hooks, exception handlers, and refactor candidates.
- Use LSP/Serena tools for definitions, references, and symbol-level reads.
- Do not search `node_modules`, build outputs, generated files, snapshots, lockfiles, coverage, or large fixtures unless explicitly relevant.
- When a search returns many results, refine the query instead of reading all matches.

## Milestone 1 baseline

- Tabs: Today, Program, Progress, Library. Native tab containment preserves
  each navigation stack; BRU supplies the visible tab controls. Settings is a
  sheet from Today. History opens from Today → Sessions or Progress → Workouts.
- The tab bar hides in the logger and while the keyboard is visible.
- At accessibility text sizes, headers separate titles/actions, tabs use two
  columns, Today statistics stack, and logger inputs stack with 44pt targets.
- SchemaV7 is the sole baseline. Incompatible stores are moved aside with
  SQLite siblings, not migrated. The former schema history is preserved on
  `archive/frozen-schema-history`.
- Units relabel stored numbers without converting them; exercise overrides
  win. Do not describe a canonical converted store or add implicit conversion.
- Keep Pattern filtering hidden until catalog pattern metadata exists.
- Run simulator tests serially on dedicated devices. DEBUG reset is initial
  launch only; persistence journeys must relaunch without reset.
- Current evidence, limitations and product decisions: `docs/VERIFICATION.md`,
  `docs/MILESTONE-1-CLOSEOUT.md`, `docs/ROADMAP.md`.

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

### State & Reactivity
- `@Observable` + `@State`/`@Bindable`/`.environment(_:)` only. Never `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` in new code.
- `@Query` directly in views. Never wrapped in a view model — SwiftUI dependency tracking breaks.
- View models: `@Observable` class owned by `@State`, holding only non-persistent UI state.

### Navigation
- One `NavigationStack` per tab. Never wrap `TabView` in a parent `NavigationStack`.
- Exercise library: `.searchable` with `Predicate<Exercise>` driving `@Query`; compose filters in predicate, not in memory.

### What Not to Use
- No Core Data, Realm, GRDB — SwiftData only.
- No DGCharts or legacy `Charts` SPM name — Swift Charts only.
- No RxSwift / ReactiveSwift / Combine-only architectures.
- No CloudKit / iCloud sync — local-only per PROJECT.md.
- No HealthKit — out of scope, defer to v2+.
- No MVVM view models wrapping `@Query`.

### Testing
- Unit + model tests: Swift Testing (`@Test`, `#expect`) in `fitbodTests/`.
- UI tests: XCTest with `XCUIApplication` in `fitbodUITests/` only.

### SwiftData
- Don't assign relationships in initializers — insert into context first.
- Current baseline: `SchemaV7` only, with recoverable incompatible-store reset;
  do not reintroduce the removed historical migration chain.
- No `Codable` on `@Model` types — decode into DTO structs, map to `@Model` explicitly.
- Cascade: Session→SessionExercise→SetEntry cascade; Split→slots cascade; Exercise→history nullify (soft-delete via `isArchived`). Session.slot + Block.split + Session.template = nullify; SplitSessionSlot.sessionTemplate = deny.

### Charting
- Swift Charts for all data charts. `Canvas` for the muscle heatmap body silhouette.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

### UI ⇔ Code Terminology Glossary (program graph, Schema V7 — pinned)
| UI term | Code entity | Meaning |
|---|---|---|
| Session | `SessionTemplate` | One workout template (Push A: exercises + base prescription) |
| Routine | `Split` | The split bundling sessions (PPL ×2, Upper/Lower) |
| Block | `Block` | The schedule running one routine through weeks and phases |
| (history) | `Session` | A logged workout instance — never user-facing as "Session" in template contexts |

Never leak code names (`Split`, `SessionTemplate`) into UI copy. Authoritative design contract: `.planning/quick/training-block-spec/program-graph-spec.md`.

### Entity Map (Schema V7, 2026-06-11)
| Entity | Role | Key Relationships |
|--------|------|-------------------|
| `Exercise` | Catalog item (seeded from free-exercise-db + user-added customs) | many-to-many `MuscleGroup` (via `ExerciseMuscleStimulus`), many `SessionExerciseTemplate`, many `SessionExercise` |
| `MuscleGroup` | 17 muscles from free-exercise-db | many-to-many `Exercise` via join entity |
| `ExerciseMuscleStimulus` | Join entity: stimulus weight per muscle | belongs-to `Exercise` + `MuscleGroup` |
| `SessionTemplate` | Workout template (UI: "Session"); was `Routine` pre-V7 | one-to-many `SessionExerciseTemplate`; legacy `block` ref DEPRECATED (Phase 8 — prescription resolves via active block; removal needs V8) |
| `SessionExerciseTemplate` | Per-exercise prescription; was `RoutineExercise` pre-V7 | belongs-to `SessionTemplate` + `Exercise`; cascade `RoutineExerciseSetOverride` (name kept — naming debt) |
| `Split` | The split (UI: "Routine") | cascade `slots: [SplitSessionSlot]` (ordered by `position`, contiguity = test invariant, NO `#Unique`); nullify `blocks: [Block]` inverse |
| `SplitSessionSlot` | Ordered join Split↔SessionTemplate | `.deny` on `sessionTemplate` hard-delete while slotted; `position: Int` |
| `Block` | Periodization schedule | `split: Split?` (nullify), `schedulingModeRaw`, `trainingDaysJoined` (write ONLY via `TrainingDaysWriter.sort`), `archivedConfigJSON` (freeze #2, written once by `BlockLifecycleService.end`); status DERIVED: completed → active → ready → draft; `isActive` = the only exclusivity bool |
| `Session` | Logged workout instance | `template: SessionTemplate?` (nullify), `slot: SplitSessionSlot?` (nullify; nil = ad-hoc; rotation anchor), `templateName` snapshot |
| `SessionExercise` / `SetEntry` | Logged exercise / one set — evaluated prescription copied at log time | Session→SessionExercise→SetEntry cascade |
| `MuscleVolumeTarget` | User-tunable MEV/MAV/MRV per muscle | belongs-to `MuscleGroup` |

**Template vs instance:** `SessionExerciseTemplate` is the prescription; `SessionExercise` is what was logged. Copy fields at log time — never project from template at read time. Two freeze points only: log time (prescription snapshot) and block end (`ArchivedBlockConfig`); everything else is live graph edges — the only exclusivity rule is one active block.

**Engine services (Phase 8):** `TodayResolver` (rotation/fixedWeekly resolution → `TodayResolution` enum), `BlockLifecycleService` (one-save start/end/swap, split attach/swap gated to draft/ready, `assertSplitDeletable` conditional deny, `decodeArchive` w/ typed error, NO live-template fallback), `TrainingDaysWriter` (sort-once-at-write, injected Calendar). NO multi-level optional chains inside `#Predicate` — broad predicate + Swift post-filter.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

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
