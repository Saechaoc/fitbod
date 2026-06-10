# Program Graph Spec — Sessions, Routines, Blocks

**Date:** 2026-06-10
**Status:** Approved design, pre-planning
**Supersedes:** `spec.md` (2026-05-28) in this directory. That spec's template/instance
block split, per-attachment volume/intensity payloads, and multi-routine day mapping are
replaced by the model below. Its UX sections (name field, preset section, phase rows)
have already shipped.

---

## 1. Terminology

UI terms are pinned by the user. Code names diverge where collision or migration
hazard forces it. This table is the glossary; add it to CLAUDE.md.

| UI term | Code entity | Meaning |
|---|---|---|
| Session | `SessionTemplate` | One workout template (Push A: exercises + base prescription) |
| Routine | `Split` | The split bundling sessions (PPL ×2, Upper/Lower) |
| Block | `Block` | The schedule running one routine through weeks and phases |
| (history) | `Session` | A logged workout instance. Unchanged. Never user-facing as "Session" in template contexts |

Each layer adds exactly one concern: exercises+prescription → bundling+order → scheduling+phases.

## 2. Core model

Everything is graph edges by reference — links are never copies or claims:

- A `SessionTemplate` can belong to many `Split`s (and twice to the same one).
- A `Split` can be attached to many `Block`s simultaneously (active, queued, draft) or none.
- **The only exclusivity rule in the system: one block active at a time** (`Block.isActive`).

Two freeze points break the live-reference rule, deliberately:

1. **Log time** — logged workouts snapshot prescription at completion (already shipped:
   copy-at-log-time architecture rule). V5 adds `Session.templateName: String?` so a
   nullified template ref never strips names from history rows.
2. **Block end** — `archivedConfigJSON` written once, in the same save that sets
   `endDate`. Progress and DONE-block views read the archive, never live templates.

## 3. Schema V5

### Renames (call-graph rename via gitnexus, custom migration stage)

| V4 | V5 |
|---|---|
| `Routine` | `SessionTemplate` |
| `RoutineExerciseTemplate` | `SessionExerciseTemplate` |
| `Session.routine` | `Session.template` |

The split entity is named `Split`, **not** `Routine`, for two reasons: (a) SwiftData
inferred migration matches entities by name — reusing `Routine` would carry V4
template rows into the V5 split entity as ghosts unless a purge loop is perfect;
(b) git archaeology stays unambiguous — pre-V5 `Routine` always means template,
`Split` always means split.

### New entities

```
Split
  id: UUID (.unique)
  name: String
  createdAt: Date
  isArchived: Bool = false
  slots: [SplitSessionSlot]   // cascade on delete

SplitSessionSlot
  split: Split                // inverse of Split.slots
  sessionTemplate: SessionTemplate
  position: Int               // explicit order; SwiftData to-many is unordered
```

- Duplicate templates in one split are free (PPL ×2 = 6 slots, 3 templates).
- Positions stay contiguous via reindex-on-write. `#Unique` on (split, position)
  as belt-and-suspenders (iOS 26 target — available).

### Block changes

```
Block (existing fields kept: id, name, startDate, endDate?, notes?, isActive,
       reviewedAt?, phases, sessions)
  - routines: [Routine]?            // REMOVED (old direct template attachment)
  + split: Split?                   // nil while draft; inverse Split.blocks (to-many)
  + schedulingMode: SchedulingMode  // .rotation | .fixedWeekly, default .rotation
  + trainingDays: [Int]             // Calendar weekday numbers (1=Sun…7=Sat), default []
  + archivedConfigJSON: String?     // freeze #2, written once at block end
```

### Logged Session changes

```
Session
  ~ template: SessionTemplate?      // renamed from routine; nullify on template delete
  + slot: SplitSessionSlot?         // which slot launched this workout; nil = ad-hoc
  + templateName: String?           // snapshot at log time (freeze #1 insurance)
```

`Session.slot` delete rule is **nullify** — deleting a slot (directly or via split-delete
cascade) must never touch logged history. A nullified slot reads as ad-hoc; the resolver
absorbs it. A delete-rule test guards this.

### Block status — derived, not stored

Computed property, evaluated as an **ordered switch** (precedence matters):

```
completed   endDate != nil
active      isActive
ready       split != nil && (mode == .rotation || trainingDays.count == slotCount)
draft       otherwise
```

Transition-site assertions: `isActive ⇒ split != nil ∧ endDate == nil`.

## 4. Lifecycle rules

- **Start** (from card or detail, status == ready): sets `isActive = true`,
  `startDate = .now`. If another block is active, confirm sheet ("Ends *{current}* —
  its config freezes to history"), then **one save** covering all three mutations:
  current.endDate + current.archivedConfigJSON + new.isActive/startDate. No
  zero-or-two-actives crash window.
- **End** (from active block detail): confirm, then endDate + archive in one save.
- **Split swap/attach: gated to draft/ready only.** Hidden on active blocks. Changing
  the split is ending the block — keeps the archive truthful (describes one split).
  Mode flips and trainingDays edits stay live on active blocks.
- **Split deletion:** archive-only from UI (`isArchived`); deny-delete while referenced
  by any non-completed block. Slots cascade on split delete.
- **Session templates:** existing soft-delete via `isArchived` unchanged.

## 5. Today scheduler

Replaces the name-sort heuristic (`TodayView.swift` `todaysRoutine`).

**Unified resolver predicate** (rotation): *the latest **completed** session in this
block whose `slot` is non-nil and whose `slot.split == block.split` → next slot =
`(slot.position + 1) % slotCount` against current positions; no matching session →
slot 0.* Ad-hoc sessions, dead slots, sessions from a previously attached split, and
abandoned in-progress workouts all fall out of the scan identically — skipped, scan
back. Tests assert the predicate, not enumerated cases.

**fixedWeekly:** today's weekday ∈ `trainingDays` → slot at `index(of: weekday in
sorted trainingDays) % slotCount` (mod is the runtime guard for mid-block slot count
drift on a shared split); weekday absent → rest-day empty state (exists). Missed day =
skipped, not shifted. Ready gate requires count equality (§3); day-chip UI shows soft
mismatch ("5 days / 4 sessions") at attach time.

**Edge surfaces:**
- Active block, empty split → fix-it pointer to `SplitDetailView` ("Routine has no
  sessions"), not the rest-day state (which would lie).
- Resume-state (in-progress session) wins the CTA as today (unchanged).

## 6. Archive contract (freeze #2)

`ArchivedBlockConfig` — Codable DTO struct, never `@Model` (project convention).

```json
{
  "v": 1,
  "blockName": "...", "startedAt": "...", "endedAt": "...",
  "mode": "rotation", "trainingDays": [2, 4, 6],
  "phases": [ { "kind": "...", "weeks": 0, /* full BlockPhase field mirror */ } ],
  "split": {
    "name": "...",
    "slots": [ { "position": 0, "sessionName": "...",
                 "exercises": [ { /* full SessionExerciseTemplate prescription mirror */ } ] } ]
  }
}
```

- Written in the same save as `endDate` (no completed-without-archive window).
- `"v": 1` stamped for V6+ readers.
- Pre-V5 completed blocks: backfilled best-effort from post-migration state at
  migration time (drift accepted). **No live-template fallback path in readers, ever.**
- v1 consumer: archived-mode `BlockOverviewScreen` only. Progress charts over
  archives = future phase; contract exists so that phase needs no schema change.

## 7. Migration V4 → V5 (custom stage)

1. `willMigrate`: stash old `Routine` rows and Session→Routine ID pairs as plain
   structs (model objects don't cross the stage boundary).
2. `didMigrate`: create `SessionTemplate` per stashed row; remap `Session.template` refs.
3. Per V4 block with attached templates: auto-create a `Split` named "{block.name}
   split", slots in **name-sorted order** (matches the old weekday heuristic), mode
   `.rotation`. Completed blocks' auto-splits are born `isArchived = true` (history
   doesn't pollute the picker).
4. Backfill `Session.slot` on the active block's last completed session (template's
   index in the name-sorted auto-split) so a mid-block upgrade doesn't reset rotation.
5. Backfill `Session.templateName` from the remapped template's name.
6. Best-effort `archivedConfigJSON` for pre-V5 completed blocks.
7. Old `Routine.block` field dies with the entity.

`SchemaV5MigrationTests` asserts, minimum: ghost-free picker (only auto-splits exist,
archived ones hidden), ref remapping, rotation continuity (point 4), archive backfill
presence, templateName backfill.

## 8. Surfaces

### Program tab (`ProgramView` rebuild)

Empty state (current template design — protected by the 3 copy-guardrail
source-introspection suites) only when zero blocks **and** zero splits. Otherwise:

- **BLOCKS** — status-badged cards (ACTIVE / READY / DRAFT / DONE) from the derived
  switch. Active card shows week + phase progress. DONE: 3 most recent + collapse.
  Tap → `BlockOverviewScreen`. "+ NEW BLOCK" → existing choice/template/builder flow,
  untouched.
- **ROUTINES** — rows "Upper / Lower · 4 sessions" + usage tags listing
  **non-completed** blocks only (live edges only; a finished block is not an editable
  reference). Tap → `SplitDetailView`. "+ NEW ROUTINE" → name + compose.

No top-level session-template list in v1 — templates live inside split detail and the
slot picker.

### `SplitDetailView` (new)

Ordered slot list with drag-reorder (reindex-on-write); add slot via picker over all
`SessionTemplate`s or "new session" → existing builder; remove slot; usage section
listing referencing blocks (non-completed). Shows the freeze-#3 banner when this split
sits on the active block (reorder is as schedule-affecting as a prescription edit).

### `BlockOverviewScreen` (extended)

- **Live modes** (draft/ready/active): split attach/swap (draft/ready only), mode
  picker, trainingDays day-chips (fixedWeekly), Start CTA (ready), End action (active).
- **Archived mode** (completed): rendered from decoded `ArchivedBlockConfig`;
  attach/swap/mode/Start hidden.

### Block builder (New Block screen)

Existing conditional linked-routines band becomes: one split picker + mode +
day-chips. Optional — save without = draft. Any edit here → run all 3 copy-guardrail
suites (standing rule).

### Session template editor

Freeze-#3 banner when the template is reachable via slots → split → active block:
"Part of active block — edits apply to upcoming workouts." Non-blocking.

### Today tab

Only the routine-resolution function changes (§5). `BlockContextBand`, `BlackSlabCTA`,
rest-day empty state, `StartBlockCTA` all stay.

## 9. Tests

- `SchemaV5MigrationTests` (§7 assertions).
- Scheduler suite: the unified predicate across skip / repeat / reorder / ad-hoc /
  swapped-split / abandoned-in-progress; fixedWeekly rest days, count drift, empty
  split, dead slot; **locale test** for trainingDays (Calendar weekday + Monday-first
  locale off-by-one).
- `Session.slot` delete-rule test (nullify, history intact).
- Status-precedence ordered-switch tests + transition assertions.
- The 3 copy-guardrail suites on any New Block edit.
- Swift Testing for all of the above; UI smoke via existing XCTest patterns.

## 10. Build order

Tests for each layer gate the next:

1. **Migration** — V5 schema + custom stage + `SchemaV5MigrationTests`.
2. **Resolver + lifecycle** — scheduler, derived status, start/end one-save
   transactions, delete rules.
3. **Program surfaces** — `ProgramView` rebuild, `SplitDetailView`,
   `BlockOverviewScreen` modes, builder band, freeze-#3 banners, Today wiring.

## 11. Out of scope (v2+)

- Per-phase routine overrides (accumulation on PPL, peak on Upper/Lower).
- Progress charts reading block archives.
- Top-level session-template library.
- Day-slot-level scheduling beyond rotation/fixedWeekly.
