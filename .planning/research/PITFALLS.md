# Pitfalls Research

**Domain:** iOS bodybuilding / weight-training tracker (SwiftUI + SwiftData, local-only, single-user)
**Researched:** 2026-05-10
**Confidence:** HIGH for stack pitfalls (verified against Apple docs and recent community writeups), HIGH for domain pitfalls (cross-referenced RP, RTS, and existing app behaviors)

This file catalogues mistakes that bite *later* — wrong data model decisions that cause rewrites, progression math errors that quietly corrupt user trust, SwiftData gotchas that surface at thousands of rows, and UX patterns that turn a "comprehensive" app into a friction monster. Each pitfall maps to the phase that should prevent it.

## Critical Pitfalls

### Pitfall 1: Collapsing routine template and routine instance into a single model

**What goes wrong:**
The schema uses one `Routine` entity that holds both the *plan* (what you intend to do every Monday) and the *log* (what you actually did on a specific Monday). Edits to the template retroactively rewrite history. Recurring the same routine on a different day overwrites prior performance. The "same routine, different intent" requirement (strength Mon / hypertrophy Thu) becomes structurally impossible — either both sessions share one history (collapse) or you must clone the routine and lose template lineage.

**Why it happens:**
Strong, Hevy, and FitNotes ship a "Routine" that is sort-of both — when you log it, it captures performance but the routine itself is mutable, so edits leak backwards. It looks simpler in the data model walkthrough, and the bug surface only appears once a user has 100+ sessions and starts editing routines.

**How to avoid:**
Three-tier model from day one:
- `Routine` (template) — name, target intent default, ordered list of `ExercisePrescription`
- `WorkoutSession` (instance) — `routine` reference, date, performed list of `LoggedExercise`
- `ExercisePrescription` (template line) vs `LoggedExercise` (instance line) — never share rows

Each `LoggedExercise` captures the *prescribed* values at logging time (snapshot) AND the *actual* values logged. This way the template can be edited freely without rewriting history, and the snapshot tells future analytics what was *asked* vs. what was *done*.

**Warning signs:**
- Editing a routine changes a chart for a session done last month
- Renaming a routine breaks its history listing
- Cloning a routine is the user's workaround for "I want the same exercises with different intent"

**Phase to address:** Data model phase (must be Phase 1, before any logging code)

---

### Pitfall 2: Mixing strength and hypertrophy histories into one chart per exercise

**What goes wrong:**
The user does Bench Press on Monday (strength: 3x5 @ RPE 8) and on Thursday (hypertrophy: 4x10 @ RPE 7). The progress chart picks "top set weight" and produces a sawtooth — Monday peaks high, Thursday dips low — that looks like the user is regressing 50% of the time. e1RM extracted from Thursday's 10-rep set has wider error bars than Monday's 5-rep set, but the chart treats them as comparable points.

**Why it happens:**
Charting libraries plot one series per exercise. Existing apps (Strong, Hevy) do exactly this and accept the sawtooth. The user's explicit complaint about reference apps was "same-routine-different-intent collapses into one history" — so this pitfall is literally the differentiator's failure mode if implemented naively.

**How to avoid:**
- Store `intent` (strength / hypertrophy / endurance / power) on every `LoggedExercise`
- Default chart view splits series by intent — two lines on the same axes, color-coded, with a toggle to overlay or split
- e1RM calculations should annotate confidence: high (1-5 reps), medium (6-8 reps), low (9-12 reps), very low (>12). Render low-confidence points smaller or as semi-transparent
- For "PR" detection, compare intent-matched history only (a strength PR is vs strength sessions, not Thursday's pump work)

**Warning signs:**
- Chart shows visible "every other session is a regression" pattern
- e1RM jumps look stat-significant but are just rep range artifacts
- User asks "why does my bench look like a sine wave"

**Phase to address:** Progress visualization phase, but the data structure (intent column on every LoggedExercise) must land in the data model phase

---

### Pitfall 3: RPE-to-weight back-calculation that ignores per-lifter and per-exercise variance

**What goes wrong:**
The app uses the Tuchscherer RPE chart (5 reps @ RPE 8 = 81.1% of 1RM) globally. For a lifter whose squat sits closer to 78% at the same RPE/rep combo, every prescribed weight is 3-4% too high. Over a mesocycle, the user fails sets that the app insists they should hit. Confidence in the app dies; user falls back to manual entry.

**Why it happens:**
The Tuchscherer table is the de-facto standard and looks authoritative. But it's a population average — individual variance is ±5% common, ±8% extreme. Different lifts have different rep-RPE curves (squat tolerates more reps near max than bench; bench more than deadlift). Most apps just hard-code one chart.

**How to avoid:**
- Treat the canonical RPE chart as a *starting prior*, not ground truth
- Maintain a per-exercise per-lifter regression: after each logged set with RPE, fit the lifter's actual rep/RPE → %1RM curve over a rolling window (last 8-12 weeks)
- When prescribing, use the lifter-specific curve if you have ≥10 data points for that exercise, else fall back to the canonical chart with a "calibrating" badge in the UI
- Always show the prescribed weight as a range, not a single number, until calibration is high confidence (e.g., "182.5-190 lb @ RPE 8, target 8 reps")
- Use Brzycki for 1-6 rep target ranges, Epley for 6-10, average them for the boundary

**Warning signs:**
- User repeatedly hits prescribed weight at a different RPE than asked
- Prescribed weight changes erratically week-to-week (curve fitting on too few points)
- Same exercise prescriptions drift further from reality on lifts that aren't the big-3

**Phase to address:** Progression engine phase. Requires per-exercise calibration data, so don't ship "smart progression" before you have a few weeks of logged sets

---

### Pitfall 4: SwiftData schema versioning skipped on v1

**What goes wrong:**
v1 ships without `VersionedSchema` and `SchemaMigrationPlan`. The first time you rename a property, add a relationship, or change a delete rule, the app crashes on launch for any user with existing data (i.e., you). Lightweight migration fails silently in some cases; in others it succeeds but the database file is now structurally different and downgrade is impossible. You restore from backup, but daily logs since then are lost.

**Why it happens:**
Every SwiftData tutorial demonstrates the happy path without versioning. The documentation gap on migrations is severe. The first migration "just works" — until it doesn't. By the time you need a real migration, the v1 schema is already in production (your phone), and there's no v1 `VersionedSchema` to migrate *from*.

**How to avoid:**
- Day 1: Wrap the v1 schema in `enum SchemaV1: VersionedSchema { ... }` even though there's nothing to migrate yet
- Day 1: Attach a `SchemaMigrationPlan` to the `ModelContainer` with an empty stages array
- Every schema change is `SchemaV2`, `SchemaV3`, etc. with explicit `MigrationStage.lightweight` or `.custom(...)` entries
- Write a test that loads a fixture DB at each prior schema version and verifies migration to current passes
- Before any complex migration (changing a unique constraint, refactoring a relationship), branch a backup of the on-device store

**Warning signs:**
- "I just renamed a property and the app won't launch" mid-development
- The `Item.swift` template model from Xcode is still in the schema (it's not in `SchemaV1` — fix this *before* logging real data)
- Crash logs mention `CoreData: error: -executeFetchRequest`

**Phase to address:** Phase 1 (data model phase). This is the most expensive pitfall to retrofit because it requires reconstructing a past schema version from git history

---

### Pitfall 5: Custom exercise creation with bad muscle mapping silently corrupts volume math

**What goes wrong:**
User adds "Smith Machine Incline Press" as a custom exercise but the muscle mapping form is optional, so they skip it. The exercise now contributes 0 sets to chest, shoulders, or triceps volume. Their weekly chest volume chart shows MEV when they're actually at MAV. They escalate volume on Friday's pec deck, exceed MRV, get injured, blame the app.

**Why it happens:**
Custom exercise UX is usually a "name + equipment + done" form. Muscle mapping is a tedious step users skip. The volume engine then treats unmapped exercises as zero stimulus, which is invisible until it bites.

**How to avoid:**
- Muscle mapping is *required* on custom exercise creation — no save button until at least one primary muscle is set
- Default mapping by template: when user picks "Incline Press" as a base template, prefill primary=chest (upper), secondary=front delts, triceps
- Stimulus weights are required too: primary=1.0, secondary=0.5 by default (RP-style indirect counting). User can adjust but cannot leave blank
- Volume engine flags any custom exercise that hasn't logged any volume to a muscle group as "review required" before counting it toward weekly targets
- Display a "muscle distribution" preview during custom exercise creation — pie chart of where this exercise sends volume

**Warning signs:**
- Weekly volume bars don't add up to what the user manually counts
- A muscle group's volume drops abruptly when a custom exercise replaces a bundled one
- User reports "the chest volume is wrong" after adding a custom variation

**Phase to address:** Volume model phase + custom exercise creation phase (must coordinate)

---

### Pitfall 6: SwiftData ModelContext on the main thread for large operations

**What goes wrong:**
Seeding 1000+ exercises from JSON on first launch freezes the UI for 4-8 seconds. Bulk-importing a backup also freezes. Querying for "all sets for exercise X across all sessions" on the main `@Query` macro pulls 5000 SetEntry rows into memory and hangs. The user thinks the app crashed and force-quits during seed; database is now half-populated.

**Why it happens:**
SwiftData tutorials default to the main thread context. `@Query` runs on the main actor. `ModelContext` is not `Sendable` and cannot be casually shared across actors. The hang is invisible during development with 10 exercises and surfaces only at production data volumes.

**How to avoid:**
- Seed import runs in a `@ModelActor` (background) with explicit `try modelContext.save()` per batch of 100 rows
- Long-running computations (weekly volume aggregation, e1RM history reduction) use a `@ModelActor` that fetches `PersistentIdentifier` lists, hops to the main actor only when handing UI-bound results
- Never pass `PersistentModel` instances across actor boundaries — pass `PersistentIdentifier` and refetch
- Add a non-blocking splash for first-launch seed: "Setting up your exercise library…" with a progress indicator, so a 3-4 second seed feels intentional
- `@Query` on session list view should filter to last N sessions (e.g., 90 days) by default, with explicit "show all" toggle

**Warning signs:**
- "Hangs" in Xcode Organizer or visible UI freezes when scrolling exercise library
- First-launch progress bar that never updates
- `XCTAssert` failures with "Main thread blocked >1s" in instruments

**Phase to address:** Exercise library seeding phase (Phase 2) and any phase introducing bulk operations

---

### Pitfall 7: Filtering the 1000+ exercise library without indexes

**What goes wrong:**
The library screen has filters for muscle, equipment, grip, mechanic, pattern. Each filter change re-runs `@Query` with a predicate. Without indexes, SwiftData walks all 1000 rows, evaluating multiple property comparisons per row. With the search bar (string contains on name + alt names), latency climbs to 200-400ms per keystroke. Typing "bench" feels laggy. Users blame "the iOS app feels slow."

**Why it happens:**
Predicates run in SQLite, but without `#Index` macro hints, SQLite has nothing to seek on. String search via `localizedStandardContains` is especially expensive. Compound filters (muscle AND equipment AND mechanic) multiply the scan cost.

**How to avoid:**
- `#Index<Exercise>(\.primaryMuscleId, \.equipmentId, \.mechanic)` compound index for the common filter combination
- Separate single-property `#Index` on `name` (for prefix/contains search) and `equipmentId` (often-first filter)
- For string search, normalize names at insert time into a `searchKey` lowercase ASCII field, index that, use `contains(searchKey, lowercased())`. Saves accent-folding cost per keystroke
- Order predicate clauses most-restrictive first (equipment narrows more than muscle for most queries; grip narrows fast)
- Debounce search input 150-250ms so typing doesn't fire a query per character

**Warning signs:**
- Library scroll stutters on filter change
- Search feels laggy especially below "bench" or "row" prefixes (high match counts)
- Instruments shows time spent in `SQLite` regex/like evaluation

**Phase to address:** Exercise library phase (Phase 2). Indexes must be in `SchemaV1` — adding them later is a migration

---

### Pitfall 8: Volume model math is right but the UX numbers don't help

**What goes wrong:**
The volume engine correctly aggregates direct + indirect sets per muscle per week with RP-style stimulus weights. The dashboard shows "Chest: 14.5 sets this week, MEV 8, MAV 14, MRV 22." User stares at it. So what? Is 14.5 good? Should I add a set? Is the indirect count from bench presses included? The number is *correct* but doesn't drive a decision.

**Why it happens:**
Fitness app designers love showing numbers. The hard work is in turning numbers into prescriptions. RP's app gets this right by translating volume state into "add a set," "hold," or "deload" verbs. Most clones stop at the bar chart.

**How to avoid:**
- Every muscle volume display answers one question: "What should I do about this?"
- States: Below MEV (yellow "add volume"), MEV-MAV (green "hold or progress"), MAV-MRV (orange "watch fatigue"), >MRV (red "deload soon")
- Volume bars show direct/indirect split visually (two-tone fill) so user can see "11 direct + 3.5 indirect" without doing math
- Adjacent-week comparison ("+2 sets vs last week") is more decision-relevant than absolute count
- Next-session prescription auto-adjusts: if Chest is below MEV mid-week, a hypertrophy session adds a set to a chest exercise (with a toggle in case user wants control)
- Tooltips/long-press on a bar reveals which exercises contributed and how much

**Warning signs:**
- User checks the dashboard, then ignores it
- Numbers add up correctly but user can't articulate what action they suggest
- The bar chart is visually impressive in screenshots but unused in practice

**Phase to address:** Volume/fatigue model phase (after data model + logging exist)

---

### Pitfall 9: Rest timer drifts or stops when phone locks

**What goes wrong:**
User starts a set, taps rest timer, locks phone, puts in pocket. iOS suspends the app after ~30 seconds. The timer either drifts (showing fewer seconds than have elapsed), stops entirely, or fires a notification at the wrong time. User notices their rest is now 5 minutes when prescribed was 3, performance drops, blames programming.

**Why it happens:**
A foreground-only `Timer` stops when the app backgrounds. Background app refresh is throttled. Audio session tricks (silent audio loop) keep the app alive but burn battery and have App Store risks. Naive implementations use a wall-clock `Timer` that doesn't survive backgrounding.

**How to avoid:**
- Store rest start as `Date` (absolute), not as a countdown
- Schedule a `UNUserNotification` at start time + rest duration so the alert fires regardless of app state
- On app foreground, compute remaining = (start + duration) - now and update UI from current state (no drift)
- For optional in-app audio cue when phone is unlocked, use `AVAudioSession` with `.playback` category and `mixWithOthers` — but only as a *cue*, not the timing mechanism
- If user is in a foreground gym session and locks phone, optional `BGProcessingTask` registration can keep aggregation alive, but never rely on it for timing
- Always provide a manual "skip rest" and "add 30s" with single tap

**Warning signs:**
- "My rest timer didn't fire" or "it said 90 seconds when 3 minutes had passed"
- The notification permission was never requested (silent failure mode)
- Battery drain complaints (sign of audio-loop hack)

**Phase to address:** Logging/timer phase. Don't ship logging without correct rest timer behavior — it's the #1 thing users notice

---

### Pitfall 10: Warm-up ramp generation breaks on edge cases

**What goes wrong:**
The warm-up generator computes "first compound, ramp from empty bar to working weight in 3 sets." For a 95 lb working bench (lifter detraining or beginner), it computes 45 / 65 / 85 / 95 — three warm-up sets for a weight where the bar itself is a warm-up. For a deload week prescribed at 60% (e.g., 135 working), it adds warm-ups that nearly equal the working sets. For a unilateral lift (single-arm DB row), it doesn't know to halve weights. For barbell exercises with available plates not matching standard (user only owns 2.5/5/10/25/45), it prescribes weights that can't be loaded.

**Why it happens:**
Warm-up generation is "obvious" until you handle edge cases. The percent-based template assumes working weight >> bar weight, plates are standard, exercise is bilateral barbell, and the session isn't a deload.

**How to avoid:**
- Skip warm-up entirely if working weight < 1.5x bar weight (or bar weight + smallest plate pair)
- Skip warm-up on deload weeks (volume already cut, intensity already low — adding warm-ups defeats deload purpose). Flag this in the UI: "Warm-up skipped — deload week"
- Per-exercise mechanic: unilateral exercises use half-weight conventions; non-barbell exercises (DBs, machines) bypass plate math
- User-configurable plate inventory: app respects available plates per exercise (45/35/25/10/5/2.5 lb standard, custom for fractional/Olympic). Round prescribed weights to loadable
- Maximum 3 ramp sets for working sets up to ~70% of theoretical 1RM; up to 5 for heavier (top sets >85%)
- Allow user to disable warm-up per exercise or per session

**Warning signs:**
- App prescribes "65 lb warm-up" for a 95 lb working weight (warm-ups too dense)
- Warm-ups appear during deload weeks
- Generated weight = 47.5 lb when the user owns no 1.25 lb plates
- Unilateral DB rows show 95 lb warm-ups when working set is 50 lb per hand

**Phase to address:** Prescription/progression phase. Should land *with* exercise library since it depends on knowing equipment + mechanic

---

### Pitfall 11: Deload detection conflicts with manually scheduled blocks

**What goes wrong:**
User has defined a 4-load + 1-deload block. Week 3, the auto-fatigue detector ("consider deload" alert) fires because e1RM dropped 5%. User dismisses or accepts — but now what? If accepted, does week 3 become deload (and the block extends)? Does it skip ahead? If dismissed, does the alert re-fire? Auto and manual deload mechanisms conflict, producing inconsistent block schedules and corrupted weekly prescriptions.

**Why it happens:**
The user explicitly wants both deterministic block-driven deloads AND adaptive fatigue alerts. These are different control loops; without explicit hierarchy, they fight.

**How to avoid:**
- Single source of truth: the block schedule. The fatigue detector emits *suggestions*, not commands
- Suggestion options: "Insert deload now (postpones planned deload by 1 week)," "Insert deload now (replaces planned deload)," "Dismiss (suppress for this block)," "Show me why" (explanation panel)
- Block timeline view shows current week, planned deload, and any inserted deloads with visual distinction (scheduled vs suggested-accepted)
- Detector tracks dismissals — repeated dismissals in one block don't re-alert
- Inserted deloads cascade: rest of block phases shift one week, with a confirmation modal

**Warning signs:**
- User can't tell "what week am I in" of their block
- The same deload alert keeps firing every session
- Block ends one week earlier or later than scheduled with no obvious cause
- User's manual block edits get overwritten by auto-deload insertions

**Phase to address:** Periodization phase (after block definition + fatigue model exist)

---

### Pitfall 12: e1RM chart treats Epley/Brzycki as ground truth

**What goes wrong:**
The chart plots e1RM for every set, computed via Epley. A high-rep AMRAP at moderate weight produces an e1RM 5-15% higher than the user's actual 1RM. The user sees their "bench 1RM" climb to a number they can't lift. Plateau detection fires false positives because real 1RM tests don't match the inflated estimates. Confidence in the metric collapses.

**Why it happens:**
Epley overestimates above 10 reps. Brzycki underestimates above 8 reps. No single formula is accurate across the full rep range. Apps that pick one formula and apply it universally produce systematically biased estimates.

**How to avoid:**
- Use Brzycki for 1-6 rep sets, Epley for 6-10, and either disable e1RM display for >10 reps or label it "low confidence"
- Always combine e1RM with RPE when available: 5 reps @ RPE 8 isn't 1RM — it's roughly the 7-rep max (5 + 2 RIR). Treat that 7RM as the more reliable point and back-compute 1RM via Tuchscherer
- Display e1RM as a range (e.g., 285-305) not a single point on charts. Use min/max from multiple formulas
- For PR tracking, distinguish "estimated 1RM PR" from "true 1RM PR" (the user explicitly tested) with different chart markers
- When chart shows a "new e1RM PR," verify it's from a high-confidence set (1-6 reps with RPE 7-9). High-rep outliers should not register as PRs

**Warning signs:**
- User's e1RM appears 10%+ above what they can actually lift
- The chart's "PR" markers fire on dropset finishers and other inflated estimates
- Trend line slopes up while user feels they're plateauing

**Phase to address:** Progress analytics phase (depends on logging + intent classification)

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skipping `VersionedSchema` in v1 | Saves 30 minutes setup | Every future migration is risky; one rename = potential data loss | Never — wrap v1 schema in `SchemaV1` even when there's no migration yet |
| Single `Routine` model (no template/instance split) | Simpler initial schema | Edits leak into history; differentiator-killing | Never — split from day one even if both feel "the same right now" |
| Hard-coded Tuchscherer RPE table | Easy to implement; works for population averages | 3-8% error on individual lifters' prescriptions; trust erosion | Acceptable as initial seed; must be replaced by per-lifter calibration before claiming "smart progression" |
| Optional muscle mapping on custom exercises | Faster custom exercise UX | Silent volume math corruption; injury risk | Never — make required |
| Using `Item.swift` template model name as a real model | Saves a rename | Inevitable mass-rename later; namespace pollution; muscle memory bugs | Never — delete template `Item.swift` before adding domain models |
| `@Query` without `#Index` on filtered properties | Works at 50 exercises | 300ms lag at 1000; "iOS apps feel slow" complaint | Acceptable for v0 prototype; index before any sustained use |
| Main-thread seed import | Tutorial-clean code | 4-8s UI freeze on first launch | Acceptable during development with <100 rows; switch to `@ModelActor` before bundling 1000+ exercises |
| Single chart per exercise (no intent split) | Simpler analytics | Sawtooth charts; PR confusion; user mistrust | Never — intent split is the differentiator |
| Foreground-only rest timer | Trivial implementation | Stops on lock; ruins the headline feature | Never — use `Date` + scheduled `UNUserNotification` from day one |
| Universal e1RM via Epley | One-line implementation | Inflated PRs at high reps; false plateau alerts | Never as a single number — show range or hide for high-rep sets |
| Skipping warm-up edge case handling (deload, unilateral, plate inventory) | Ship sooner | Wrong prescriptions on the lifts the user cares most about | Acceptable in early prototype; must handle before block periodization phase |
| Loading all sets ever logged into a per-exercise chart | "All your data" feels comprehensive | 5000+ SetEntry rows hang UI; chart unrenderable | Acceptable up to ~3 months of data; aggregate or paginate after |

## Integration Gotchas

Single-user, local-only v1 has no external services in the traditional sense, but bundled data and OS integrations have their own gotchas.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Bundled exercise dataset (wger / free-exercise-db) | Importing names + muscles only, ignoring license, equipment, alt-names | Import full schema with attribution metadata; preserve license; map muscles to your own canonical taxonomy (don't trust raw source field names) |
| Seeding SwiftData from JSON | Running seed on every launch; not handling partial seed (user force-quit during import) | Idempotent seed keyed by version stamp in `UserDefaults`; resume from last successful exercise ID; transactional batches of 100 |
| Bundling a pre-built SwiftData store | WAL mode means store ships with `.wal`/`.shm` sidecar files; missing one corrupts on first read | Use Core Data + manual VACUUM to produce a single SQLite file, or seed from JSON on first launch (simpler, slightly slower) |
| `UNUserNotification` for rest timer | Requesting permission late or not at all; not handling denial | Request permission on first rest timer use with explanation; fall back to in-app banner if denied; don't silently fail |
| Future iCloud sync (out of scope for v1 but constrains v1 schema) | Designing v1 with non-optional properties → can't enable CloudKit later without complex migration | All new properties on models should have default values from the start; relationships should be optional and have inverses, even if v1 doesn't sync |
| Future Apple Watch companion (out of scope but plausible) | Putting business logic in views; making models depend on UIKit | Keep models pure Swift; logic in `@ModelActor`s and plain types; views thin |
| Future HealthKit (explicitly out of scope, but if added) | Storing user weight in two systems with no canonical source | If added, treat HealthKit as authoritative for bodyweight; mirror only |

## Performance Traps

Patterns that work at small scale but fail as the dataset grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `@Query` for all sets ever logged in a per-exercise chart | Chart screen takes 1-3s to render; spinning loader | Filter by date range (e.g., last 6 months default); use `fetchLimit`; aggregate older data into weekly buckets at logging time | ~500-1000 logged sets per exercise (~6-12 months of training) |
| String filtering on `Exercise.name` without normalization | Search lag at 150-300ms per keystroke | Index a normalized `searchKey` (lowercased, ASCII-folded); compute at insert time | Felt at ~500 exercises; bad at 1000+ |
| Loading entire SetEntry history for weekly volume aggregation | Volume dashboard takes 500ms+; UI hangs on dashboard open | Maintain a denormalized `WeeklyVolumeSnapshot` model, updated on session save (eventual consistency) | ~3 months of consistent training (~1500-3000 SetEntry rows) |
| Swift Charts plotting every set point individually | Chart pan/zoom drops frames; resize lag | Aggregate to one point per session for long history views; use new vectorized Plot API (iOS 18+) for very long histories | ~20K points; severe at 100K |
| Cascading deletes on session with hundreds of sets | Deleting a session hangs UI 1-3 seconds | Move delete to `@ModelActor`; show progress; verify cascade rules limit blast radius (delete session shouldn't touch exercise definition) | Sessions with 50+ sets that fan out to history rebuilds |
| Computing e1RM trends on every chart render | Chart re-render is sluggish on every navigation | Cache computed e1RM time series per exercise; invalidate on new set logged | Hits at the same scale as the volume dashboard — 3+ months of data |
| Storing form notes as inline String on every SetEntry vs. external storage | Memory pressure on `@Query` loads; slow scrolling | `@Attribute(.externalStorage)` for any potentially-long text fields | When notes start exceeding a few sentences regularly |
| Not debouncing search input | Library search feels twitchy; battery drain | 150-250ms debounce; cancel in-flight predicates on new keystroke | Immediate at any data scale |
| `LazyVStack` instead of `List` for the exercise library | LazyVStack doesn't free off-screen rows; memory grows | Use `List` for the bundled 1000-exercise library; LazyVStack only for short, decorative scrolls | Memory pressure noticeable at ~500 rendered rows |

## Security Mistakes

Local-only single-user means no auth, no network — but data integrity is still security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| No backup/export mechanism for the user's training history | Data loss on phone replacement / restore failure / corrupted DB | First-class JSON export from settings; ideally an Auto-export to iCloud Drive *file* (not CloudKit) on a schedule; bundle migration tool for cross-iOS-version restore |
| Storing the SwiftData store in `Library/Application Support` without a backup strategy | If iOS aggressively reclaims space, the store could be evicted (rare but documented) | Use `Documents/` for the store or mark explicitly with `excludedFromBackup = false`; user's training history is *not* reproducible data |
| No on-device DB integrity check | Silent corruption from WAL crash during force-quit; missing relationships | On launch, run a lightweight validation pass (counts, orphan checks); auto-restore from last good backup if integrity fails |
| Form notes as free-text with no sanitization in CSV export | Notes containing commas/quotes break exports | Use JSON export as canonical; CSV is convenience-only and properly escaped |
| Hardcoding RPE values 1-10 as raw integers in the schema | Can't extend to half-RPE (8.5) later without migration | Store as `Double` with constraint range, not `Int` |
| No version stamp on the seed import | Re-seeding behavior unclear if user wipes data and reinstalls | Persist seed version in `UserDefaults`; on launch, compare to bundled version; offer "reset library to bundled" in settings |

## UX Pitfalls

Common user experience mistakes specific to a serious-lifter workout tracker.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Logging requires multi-step "Add Set" → modal → save → modal closes | Friction between sets; users abandon mid-session | Inline weight/rep/RPE entry on the active set row; smart defaults from last set; "Log Set" is one tap when nothing changes |
| RPE entry as a numeric keyboard | Slow, error-prone, easy to mistype 7 vs 8 | Horizontal scrolling RPE chip selector with major values (6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10) as default tap targets |
| Weight entry without plate math hint | User does arithmetic for plate loading themselves | After weight entry, show "= bar + 2x45 + 1x10 per side" as subtle hint; tap to switch to "barbell loading" full view |
| No "next set is now" cue when rest timer ends | User loses count between sets while phone is in pocket | Local notification + haptic at timer end; banner persistent until user logs next set |
| Plateau detection that just shows a red flag | User sees alert, doesn't know what to do | Plateau alerts include suggested actions (drop intensity, add volume, deload, try variation) with one-tap to apply |
| Charts that look pretty but answer no question | User stares at them and learns nothing | Every chart has a one-line interpretation ("Top-set weight is up 4.2% over 8 weeks") and a follow-up ("Try +5 lb next session?") |
| Per-set form notes hidden behind a tap | Notes get under-used; lifters don't record cues during rest | Notes field always visible on active set; voice-to-text shortcut for hands-busy entry |
| Block builder requires entering every week explicitly | Building a 12-week block is tedious | Template blocks (PPL 12-week hypertrophy, 5/3/1 cycle, etc.) + macro/meso level edits; auto-fill week 2-N from week 1 |
| Deload weeks that just appear without explanation | User sees "lighter prescriptions," doesn't trust them | Deload weeks have a banner explaining what's reduced (-50% volume, -10% intensity), with one-tap "skip deload" if user feels fresh |
| Default sort orders for exercise lists that don't match workflow | User scrolls past the same exercises every session | Recently used > frequently used > alphabetical; muscle filter sticks across sessions; "favorite" star for quick-add |
| Custom exercise UX hidden in settings | Users don't discover it during workouts | "+" in the exercise picker triggers custom creation inline, returning to the picker with the new exercise selected |
| Intent ("strength" vs "hypertrophy") as a session-level tag | Forces user to pick one for mixed sessions | Per-exercise intent (already in the requirements) — verify the UI exposes this without friction (default from prescription, overridable per session) |

## "Looks Done But Isn't" Checklist

Things that appear complete in a build but are missing critical pieces.

- [ ] **Schema versioning:** Often missing `VersionedSchema` wrapper on v1 — verify `SchemaV1: VersionedSchema` exists with empty migration plan even in initial release
- [ ] **Routine template vs instance:** Often collapsed into one model — verify editing a routine name does NOT change historical session records
- [ ] **Per-exercise intent on logged data:** Often only on prescription, missing on logs — verify `LoggedExercise` carries its own intent snapshot
- [ ] **Custom exercise muscle mapping:** Often optional — verify the form blocks save without ≥1 primary muscle
- [ ] **Rest timer accuracy:** Often "works in foreground" only — verify timer fires correctly with phone locked for 3+ minutes
- [ ] **Warm-up edge cases:** Often correct for "barbell bench at 225" only — verify deload weeks, light weights (<1.5x bar), unilateral lifts, dumbbells, machines
- [ ] **Plate math:** Often assumes standard 45/35/25/10/5/2.5 — verify user can configure available plates per exercise
- [ ] **e1RM confidence display:** Often single number — verify high-rep sets are flagged/hidden, low-confidence ranges shown
- [ ] **Volume aggregation includes indirect:** Often direct-only — verify a chest press contributes to triceps + front delts volume per RP-style weighting
- [ ] **Backup/export:** Often missing — verify JSON export round-trips through import to a fresh install
- [ ] **First-launch seed:** Often blocks UI — verify seed runs on background actor with progress UI
- [ ] **Index macros:** Often forgotten — verify `#Index<Exercise>` covers the common filter combinations
- [ ] **Plateau detection action:** Often a notification, no follow-up — verify alerts include suggested actions, not just flags
- [ ] **Block deload vs auto deload reconciliation:** Often both fire independently — verify which is "source of truth" and how conflicts resolve
- [ ] **Notifications permission for rest timer:** Often requested late or not handled on deny — verify graceful degradation path
- [ ] **CloudKit-compatible model definitions:** Often blocks future iCloud sync — verify all properties optional or default-valued even though v1 is local

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Routine template/instance collapsed in shipped v1 | HIGH | Add `WorkoutSession` model in `SchemaV2`; custom migration copies each Routine's last-N logs into Session rows; mark routines as templates only post-migration; old "instance" history requires data archeology |
| `VersionedSchema` not set up; first migration fails | HIGH | Restore from JSON export backup; manually reconstruct prior schema in code as `SchemaV1` retroactively; replay backup through fresh migration path; lose any data not in last backup |
| Intent not captured on logged sets historically | MEDIUM | Add intent column with default `.unknown`; backfill from session context (date, weight ranges) heuristically; mark all pre-migration logs as `.unknown` in charts (separate series) |
| Custom exercises with bad muscle mapping pollute volume | LOW | Volume engine flags exercises with zero recent stimulus contributions; one-tap "review mapping" surfaces them; user fixes; volume recomputes |
| e1RM history inflated by universal Epley | LOW | Recompute on next chart render with rep-range-aware formula; PR markers re-evaluated; show "history methodology updated" banner once |
| Rest timer drifts after phone lock | LOW | Re-implement using `Date` + scheduled notification; deploy via app update; no data migration needed |
| Volume model wrong (double-counted indirect) | LOW-MEDIUM | Recompute denormalized `WeeklyVolumeSnapshot`s in a background migration on app launch; tag pre-fix data if displayed |
| SwiftData store corrupted (WAL crash) | MEDIUM | Auto-restore from most recent JSON export at launch; manual export prompt if no backup exists; ship integrity check that runs at launch |
| Filter performance degrades at scale | LOW | Add `#Index` in `SchemaV2`; lightweight migration; no data change |
| Deload alerts conflict with manual blocks | LOW | Hierarchy fix: block schedule is canonical; alerts are suggestions only; remove auto-applied deload behavior, replace with confirmation modal |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Routine template/instance collapse | Phase 1 (Data Model) | Edit a routine name; previous session records remain unchanged |
| Mixed-intent histories in one chart | Phase 1 (data model carries intent) + Progress Phase (UI splits) | Same-routine-different-intent on two days produces two distinct chart series |
| SwiftData schema versioning missing | Phase 1 (Data Model) | `SchemaV1` exists; trivial property add → migration runs |
| Custom exercise muscle mapping silently wrong | Phase 2 (Exercise Library + Volume Model) | Custom exercise form rejects save without ≥1 primary muscle |
| RPE-to-weight back-calc ignores variance | Progression Phase (after data exists) | Per-exercise calibration kicks in after N logged sets |
| Main-thread `ModelContext` for bulk ops | Phase 2 (Library Seeding) | First-launch seed completes without UI freeze; instruments shows main thread free |
| Library filter performance | Phase 2 (Exercise Library) | Filter changes < 100ms; search < 100ms at 1000 exercises |
| Volume math correct but UX doesn't help | Volume/Fatigue Phase | Every volume display answers "what should I do about this?" |
| Rest timer drift on lock | Logging Phase | Lock phone, wait 3 minutes, timer fires within ±2s of expected |
| Warm-up ramp edge cases | Prescription Phase | Verify deload weeks, unilateral lifts, custom plate inventories all produce sane ramps |
| Deload schedule conflicts | Periodization Phase | Auto-deload alert never silently overwrites a manually scheduled deload |
| e1RM single-formula chart inflation | Progress Phase | High-rep sets don't trigger PR markers; e1RM shown as range or formula-aware |
| WAL-mode seed bundle corruption | Phase 2 (Library Seeding) | First launch on a clean install seeds successfully via JSON or VACUUM'd SQLite |
| Future iCloud sync blocked by non-optional properties | Phase 1 (Data Model) | All new properties optional or default-valued |
| Backup/export missing | Polish Phase (but data export hooks must be ready earlier) | JSON export → wipe install → import → identical state |

## Sources

### SwiftData and SwiftUI Stack
- [SwiftData schema migration roadmap 2026](https://code-and-cognition.wixsite.com/code-and-cognition-3/post/swiftdata-migration-core-data-2026-roadmap)
- [Schema.Relationship.DeleteRule.cascade — Apple Developer](https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/cascade)
- [An Unauthorized Guide to SwiftData Migrations — Atomic Robot](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [Testing SwiftData Migrations — Anton Begehr](https://medium.com/@abegehr/testing-swiftdata-migrations-7a612da2c91c)
- [SwiftData and the Mystery of Cascading Deletes — Nikolai Nobadi](https://medium.com/@nikolai.nobadi/swiftdata-and-the-mystery-of-cascading-deletes-270530ca3b0c)
- [How to optimize SwiftData performance — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps)
- [SwiftData slow with large data — Apple Forums](https://developer.apple.com/forums/thread/740517)
- [SwiftData vs Realm Performance Comparison — Emerge Tools](https://www.emergetools.com/blog/posts/swiftdata-vs-realm-performance-comparison)
- [Using ModelActor in SwiftData — BrightDigit](https://brightdigit.com/tutorials/swiftdata-modelactor/)
- [Concurrent Programming in SwiftData — fatbobman](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [ModelActor is Just Weird — Massicotte](https://www.massicotte.org/model-actor/)
- [SwiftData Background Tasks — Use Your Loaf](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [@Observable Macro performance — avanderlee](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/)
- [SwiftData @Query best practices 2026 — Mathis Gaignet](https://medium.com/@matgnt/the-art-of-swiftdata-in-2025-from-scattered-pieces-to-a-masterpiece-1fd0cefd8d87)
- [Resilient @Query — Malcolm Hall](https://www.malcolmhall.com/2026/03/13/the-resilient-query-handling-failures-in-swiftdata/)
- [NSManagedObjectID and PersistentIdentifier — fatbobman](https://fatbobman.com/en/posts/nsmanagedobjectid-and-persistentidentifier/)
- [SwiftData CloudKit Rules — fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [Some Quirks of SwiftData with CloudKit — firewhale.io](https://firewhale.io/posts/swift-data-quirks/)
- [SwiftData's Index and Unique macros — Yaacoub](https://yaacoub.github.io/articles/swift-tip/swiftdata-s-new-index-and-unique-macros/)
- [How to pre-populate SwiftData — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-pre-populate-an-app-with-an-existing-swiftdata-database)
- [SwiftUI List Performance — Chandra Welim](https://medium.com/@chandra.welim/swiftui-list-performance-smooth-scrolling-for-10-000-items-c64116dc276f)
- [List or LazyVStack — fatbobman](https://fatbobman.com/en/posts/list-or-lazyvstack/)
- [Swift Charts performance — Apple Developer Forums](https://developer.apple.com/forums/thread/740314)
- [Write-Ahead Logging with Core Data — avanderlee](https://www.avanderlee.com/swift/write-ahead-logging-wal/)
- [How to make transient attributes in SwiftData — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-make-transient-attributes-in-a-swiftdata-model)

### Domain (Lifting / Progression / Volume)
- [Verro e1RM formula — Verro Training](https://www.verrotraining.com/blog/maximize-your-training-accuracy-the-verro-e1rm-formula)
- [Epley vs Brzycki vs Lander — Arvo](https://arvo.guru/resources/one-rep-max-formulas)
- [How to calculate e1RM — Strength Journeys](https://www.strengthjourneys.xyz/articles/how-do-i-calculate-my-e1rm-estimated-one-rep-max)
- [Training Volume Landmarks — RP Strength](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth)
- [Volume Landmarks RP — volume-landmarks-rp-rals](https://volume-landmarks-rp-rals.vercel.app/)
- [RP Training methods — Arvo](https://arvo.guru/resources/methods/rp-training)
- [Tracking Indirect Training Volume — Triage Method](https://triagemethod.com/tracking-indirect-training-volume/)
- [Deload Calculator — Fitness Volt](https://fitnessvolt.com/rpe-training/deload-calculator/)
- [Deloading Practices in Strength Sports — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10948666/)
- [A Practical Approach to Deloading — SHU](https://shura.shu.ac.uk/35313/3/Bell-APracticalApproach(AM).pdf)
- [Integrating Deloading — Delphi Consensus PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10511399/)
- [Ramp-Up Sets — BarBend](https://barbend.com/ramp-up-sets/)
- [Ramp-Up Sets Misunderstood — Terminator Training](https://terminatortraining.com/blogs/ttm-blogs/ramp-up-sets-one-of-the-most-commonly-misunderstood-concepts-in-strength-training)
- [Warmup Calculator — Ramped](https://ramped.app/)
- [Designing a lightweight workout log — George Wang](https://georgewang89.medium.com/designing-a-lightweight-workout-log-bd430039762f)
- [How to design a workout tracker data model — Dittofi](https://www.dittofi.com/learn/how-to-design-a-data-model-for-a-workout-tracking-app)
- [Designing data structure for workouts — 1darrenf](https://1df.co/designing-data-structure-to-track-workouts/)
- [Top Workout Tracking Mistakes — Jefit](https://www.jefit.com/wp/guide/top-workout-tracking-mistakes-and-how-to-avoid-them-for-better-results/)
- [Hevy Sets Per Muscle Group — Hevy](https://www.hevyapp.com/features/sets-per-muscle-group-per-week/)

---
*Pitfalls research for: iOS bodybuilding/weight-training tracker (Fitbod project, SwiftUI + SwiftData, single-user, local-only v1)*
*Researched: 2026-05-10*
