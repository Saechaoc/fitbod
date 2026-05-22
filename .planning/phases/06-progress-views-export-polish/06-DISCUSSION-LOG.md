# Phase 6: Progress Views, Export & Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 6-Progress Views, Export & Polish
**Mode:** `--auto` (autonomous; recommended option auto-selected per gray area; no user prompts)
**Areas discussed:** Progress navigation; e1RM formulas & series; PRs view; Live PR detection; Weekly tonnage; Session comparison; CSV export; JSON export; Backup/restore; Polish scope

> **Dependency note:** Phase 4 mid-planning, Phase 5 not started. Auto-selected decisions reference Phase 4/5 outputs that do not yet exist. Researcher and planner must reconfirm against actual outputs once those phases land.

---

## Area 1 — Progress navigation entry points

| Option | Description | Selected |
|--------|-------------|----------|
| New "Progress" tab in TabView | First-class destination; surfaces cross-exercise views (weekly tonnage, all-PRs) | ✓ |
| Charts nested only under ExerciseDetailView | Discoverable but no cross-exercise surface | |
| Modal sheet from session summary | Lightweight but not browsable | |

**Auto-selected:** New Progress tab (D-01). Per-exercise chart additionally deep-linked from ExerciseDetailView and ExerciseHistoryView (D-02). Each tab keeps its own NavigationPath per PROJECT.md (D-03).

---

## Area 2 — e1RM formulas and chart series

| Option | Description | Selected |
|--------|-------------|----------|
| Brzycki ≤6, Epley 6–10, suppress >10 | Literal ROADMAP success criterion #1 | ✓ |
| Single formula across ranges (Epley) | Simpler, but inaccurate at low reps | |
| Lombardi / O'Conner alternatives | Edge cases without enough corroboration | |

**Auto-selected:** D-04 — `OneRepMax.estimate(weight:reps:) -> Double?` returning nil for `reps > 10`. Top-set defined by highest e1RM in working sets (D-05); all-set-avg = arithmetic mean (D-06). Series toggle + intent-split via stroke style (D-07).

---

## Area 3 — PRs view

| Option | Description | Selected |
|--------|-------------|----------|
| Weight + Reps + Volume + e1RM, intent + rep-range bucketed | Matches ROADMAP success criterion #2 | ✓ |
| Weight + e1RM only | Simpler but loses rep-PR granularity | |
| All-time single PR per exercise | Loses intent and rep-range separation | |

**Auto-selected:** D-10..D-13. PRs computed on-demand from `SetEntry` history; no denormalized PR entity.

---

## Area 4 — Live PR detection (PROG-08)

| Option | Description | Selected |
|--------|-------------|----------|
| In-session capsule banner, multi-PR stacked into one chip row | Matches Phase 2 voice (no exclamation points) | ✓ |
| Full-screen celebratory modal | Wrong voice for this app | |
| Silent log + post-session summary | Misses real-time delight | |

**Auto-selected:** D-14..D-17. Session-state cached PR table, `.success` haptic, auto-dismiss at 5s or next save.

---

## Area 5 — Weekly tonnage slicing

| Option | Description | Selected |
|--------|-------------|----------|
| Three filter chip rows (time, block phase, muscle) with stacked-bar muscle mode | Matches ROADMAP success criterion #3 | ✓ |
| Single segmented picker | Loses multi-dimensional slicing | |
| Free-form filter sheet | Too heavy for the surface | |

**Auto-selected:** D-18..D-21. `MuscleVolumeProvider` protocol abstracts Phase 5 dependency; block-phase chips disabled until Phase 4 ships.

---

## Area 6 — Session comparison matching

| Option | Description | Selected |
|--------|-------------|----------|
| Same routine + same intent + ≤14 day window | Forgiving but specific | ✓ |
| Strict last-7-day same-routine | Fails for users with non-weekly schedules | |
| User-picks comparison session | Adds friction; data is the source of truth | |

**Auto-selected:** D-22..D-24. Empty-state copy "no comparable prior session".

---

## Area 7 — CSV export schema

| Option | Description | Selected |
|--------|-------------|----------|
| One row per SetEntry with 23 columns (session→exercise→set joins) | Matches ROADMAP success criterion #4 verbatim | ✓ |
| One row per session (nested JSON in cell) | Defeats CSV's purpose | |
| Three separate CSVs (sessions / exercises / sets) | Forces user to join externally | |

**Auto-selected:** D-25..D-27. UTF-8 BOM for Excel compatibility; ISO-8601 UTC timestamps.

---

## Area 8 — JSON export shape

| Option | Description | Selected |
|--------|-------------|----------|
| Schema-versioned envelope + Codable DTOs (not @Model classes) | Stable schema independent of SwiftData internals | ✓ |
| Direct @Model encoding | Couples export to SwiftData internals | |
| Per-entity files in a ZIP | Useful only for partial export; deferred | |

**Auto-selected:** D-28..D-29.

---

## Area 9 — Backup / restore mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| `.fitbodbackup` ZIP (manifest + store.json + images/) | Self-describing, single-file shareable via AirDrop / Files / iCloud Drive | ✓ |
| Single JSON file (no images) | Loses custom-exercise images | |
| Apple Files coordinator with raw store copy | Fragile across SwiftData versions | |

**Auto-selected:** D-30..D-33. Includes pre-restore side-file safety copy; exact-schema-match requirement for v1; round-trip Swift Testing acceptance test.

---

## Area 10 — Polish scope

| Option | Description | Selected |
|--------|-------------|----------|
| Empty states + haptics + perf budget; defer onboarding overlays | Lifter-direct voice, no decorative motion | ✓ |
| Add onboarding tour + animated chart entry | Out of v1 scope | |
| Skip polish entirely (functional only) | Phase name is literally "& Polish" | |

**Auto-selected:** D-34..D-37.

---

## Claude's Discretion

- Chart styling specifics (line weight, point size, axis density) → UI-SPEC for Phase 6
- Filter chip form factor (horizontal scroll vs wrapped) → UI-SPEC
- Progress tab home layout (list vs grid vs hybrid card) → UI-SPEC
- File organization for `CSVFile` / `JSONFile` Transferable types → planner choice
- PR table eagerness (per-session vs per-tab-load) → planner profile-driven
- ZIP implementation (Compression framework vs minimal zip writer) → planner picks simplest UTI-conforming option

## Deferred Ideas

- Automated/scheduled backups (v2)
- CloudKit sync (out of v1, PROJECT.md)
- Per-muscle PR records (v2)
- Velocity-based progress (v2+, no hardware)
- Animated chart entry / scrubber (defer)
- Body-silhouette heatmap (Phase 5)
- Weekly recap surface (Phase 5)
- Plateau-stall flag rendering (read-only consumer of Phase 5 signal)
- Custom filtered exports (v2)
- Schema-migration on restore (v2 once schema versions accumulate)
- PR confetti (off-brand)
