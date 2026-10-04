# Core screens — design and interaction spec (milestone 1)

Visual designs live on the Claude Design canvas ("Fitbod · Chalkline design
system", 13 phone boards at 390 × 844). This document is the behavioral
spec the SwiftUI implementation follows. Screenshots of the real app on the
smallest and largest iPhone, at default and accessibility text sizes, are
in [`docs/verification/ci/`](../verification/ci/) (see
[../verification.md](../verification.md)).

Navigation: five tabs — **Today · Routines · Library · History · Settings** —
each with its own `NavigationStack` (re-tapping a tab pops it to root). The
active workout is a full-screen cover above the tabs. Routes are typed
(`AppRoute`: routine, exercise, exercise history, workout summary).

Conventions used below: **[primary]** is the single accent action;
identifiers in `code` are the accessibility identifiers the UI tests use.

---

## 1. Today

Purpose: the one-tap way back into training.

| State | Content |
|---|---|
| First launch | "No routines yet" empty state → **New routine** (switches to Routines and opens the builder). |
| Populated | Date overline · quick start list (routine name, "4 exercises · 14 sets · last done Tue") with a **Start** button each (`today.start.<name>`) · THIS WEEK tiles (workouts, sets, volume) · LAST WORKOUT card (`today.lastWorkout`, opens its summary). |
| Workout in progress | Iron **resume card** at the top: "In progress", routine name, Elapsed / Sets / Rest metrics, progress bar, **Resume workout** [primary] (`today.resume`), **Discard workout** (`today.discard`, confirmed). Quick start buttons then explain "Finish or discard … before starting another." |

## 2. Exercise library

Purpose: find any lift in a couple of keystrokes; filter like a lifter.

- **Header (sticky):** search field (`library.search`, prompt "Search 702
  exercises"), filter chips **Muscle ▾**, **Equipment ▾**, **Custom**, and
  **Clear** when anything is active.
- **Search:** live, 150 ms debounce, SwiftData predicate on the indexed
  canonical name.
- **Filters:** Muscle and Equipment open a sheet (medium → large detent)
  with multi-select rows (`filter.option.<Name>`), **Clear**, **Done**.
  Multi-select *within* a facet is OR; facets combine with AND. Selected
  chips turn ink with the first value and "+N".
- **Result line** (`library.resultCount`): always states the count and the
  active filters — "4 exercises · Chest · Barbell".
- **Rows** (`exercise.row`): name (wraps, never truncates) + "Equipment ·
  primary muscles", CUSTOM tag for your own. Sectioned A–Z.
- **Empty:** with a query → "No match for “zercher good morning”" +
  **Create “Zercher Good Morning”** [primary] (opens the editor pre-filled)
  + **Clear filters** if filters are on. Without a query → **Clear filters**.
- **+** (toolbar, `library.addCustom`) → new custom exercise.

### Exercise detail
Hero panel (name, equipment / mechanic / level tags, stimulus bars per
muscle) · **YOUR HISTORY**: last / best set / estimated 1RM tiles, the five
most recent sessions, **See all** → full intent-split history · HOW TO
(instructions) · Prescription settings (smallest increment, bar weight,
unit override) · **Copy as custom exercise** for built-ins · **Edit** for
custom exercises.

### Custom exercise editor
Name (required) · Equipment chips · Mechanic (segmented) · Muscles with
stimulus weight (≥ 1 primary at ≥ 50 %) · optional photo · **Delete** (edit
mode, explains the effect on history and routines first).

| State | Behavior |
|---|---|
| Editing | **Save** always enabled; Cancel asks "Discard changes?" only when dirty. |
| Validation error | Save with problems → summary banner (`custom.errorSummary`, "Fix 2 things to save this exercise."), inline errors under the name and muscles, error haptic, VoiceOver announcement. Errors clear as they are fixed. |
| Delete | Logged workouts keep their sets and show "Removed exercise"; routine lines using it are removed; the library entry is deleted. |

## 3. Routines

| State | Content |
|---|---|
| Empty | "No routines yet" + what a routine is + **New routine** [primary]. |
| Populated | Sections per folder ("All routines" when there are no folders, else folders + Unfiled). Row (`routine.row.<name>`) opens the detail; **Start** (`routine.start.<name>`) starts immediately. Swipe: Delete (confirmed: "Past workouts from this routine stay in History."), Duplicate. Long-press: Start, Edit, Duplicate, Move…, Delete. |
| Workout in progress | Resume card at the top. |

**+** menu (`routines.add`): New routine · New folder.

### Routine detail
Display title, notes, ruled exercise table (# · Exercise · Target
"3 × 4–6 @ RPE 8 · rest 3:00"), toolbar **Edit** (`routine.edit`) and ⋯
(Duplicate, Move to folder…, Delete), thumb-zone **Start workout** [primary]
(`routine.startWorkout`).

### Routine builder (new / edit)

- **Name** (prominent field, `builder.name`), **Exercises** (ordered
  cards), **Notes**.
- **Add exercises** (`builder.addExercises`) opens the library as a
  multi-select sheet; exercises are appended in tap order with sensible
  defaults (barbell compound → strength 3 × 4–6 @ RPE 8, rest 3:00; else
  hypertrophy 3 × 8–12, rest 1:30 / 3:00), and the first new one opens
  expanded.
- **Exercise card** (`builder.exercise.<i>`): collapsed = "3 × 4–6 · RPE 8 ·
  rest 3:00"; expanded = steppers for **Sets** (1–10), **Reps** low/high
  (kept ordered), **Target RPE** (Off, 6–10 by 0.5), **Rest** (0:00–10:00 by
  15 s), Intent, Progression, and Advanced (tempo, partials, auto warm-up,
  per-set overrides). ⋯ menu: Move up / Move down, Duplicate, superset,
  Warm-up settings…, Remove.
- **Reorder** (`builder.reorder`) switches the list to drag handles.

| State | Behavior |
|---|---|
| Validation error | Save with no name / no exercises → summary banner (`builder.errorSummary`), inline name error, "Add at least one exercise." under the list, error haptic, VoiceOver announcement. |
| Dirty cancel | "Discard changes?" → Discard / Keep editing. |
| Saved | Sheet closes; the routine is in the list. Editing a routine never changes past workouts (they are snapshots). |

## 4. Active workout (full-screen cover)

Purpose: fast, one-handed, honest set logging.

**Layout (top → bottom):** toolbar (**⌄** minimize `workout.minimize`, ⋯
`workout.options`: Workout notes / Discard workout, **Finish**
`workout.finish`) · iron header panel (routine snapshot name
`workout.title`, Elapsed · Sets n/m · Volume, progress) · one card per
exercise · **Add exercise** · **Finish workout** · rest dock (when running).

**Exercise card:** index badge, name, prescription line ("Strength · 3 ×
4–6 · RPE 8 · rest 3:00"), "Prescribed 225 lb ⓘ" (opens *Why this
weight?*), ⋯ menu (Swap exercise, Pinned note, Plate math, Skip warm-ups,
Remove from workout). Warm-up rows (W1, W2…) come first with **Skip
warm-ups**; then the ruled column labels **SET · PREVIOUS · LB · REPS · RPE**
and the working sets; **Add set** (`exercise.<i>.addSet`) copies the last
weight.

**Set row** (`set.<e>.<i>`):

| Part | Behavior |
|---|---|
| Set number | Accent when it is the next set. |
| Previous (`.previous`) | Last time's set at the same position for the same exercise **and intent**, from an earlier workout ("225 × 5 @8", "BW × 12"). Tap copies weight × reps into the open set. "—" when there is none. |
| Weight (`.weight`) / Reps (`.reps`) | Numeric fields (decimal pad; signed for bodyweight lifts, where "BW" is the placeholder). Values save on every keystroke. Keyboard toolbar: **Next** (weight → reps → next set) · **Done**. |
| RPE (`.rpe`) | Menu 10 … 6 by 0.5, "No RPE". |
| ✓ (`.complete`, 48 pt) | Completes the set. Again → reopens it for editing. |

| State | Behavior |
|---|---|
| Open / next | Sunken fields; the next set has an accent ring on ✓. |
| Validation error | ✓ on a set without reps (or without weight on a loaded lift) → nothing is saved; danger ring on the missing field, "Enter reps to complete set 2." (`.error`), error haptic, VoiceOver announcement, focus jumps to the field. |
| Completed | Row tints `complete`, filled ink ✓, success haptic, set saved immediately, **rest starts**. Later open sets of the exercise that have no weight yet take the logged weight, so the next set needs only reps (not for bodyweight lifts, where 0 means bodyweight). |
| Delete | Swipe left → Delete set. Long-press → set type, note, edit, delete. |
| Large text | When the row can't fit on one line it stacks into labelled lines ("SET 2" + previous / LB + REPS / RPE + ✓) and the column labels collapse to "SETS". |

**Rest timer:** completing a working set starts rest for the exercise's
prescribed time. The dock (`rest.dock`) steps aside while a number is being
typed (it would cover the focused row on small iPhones) and shows "Rest ·
Barbell Squat",
the countdown (`rest.remaining`), **−15** / **+15** / **Skip**; past zero it
counts up in accent ("Rest done +0:18") with one success haptic and the
button becomes **Done**. Tapping the countdown opens the rest sheet (big
countdown, "Total 3:15 · ends 6:42 PM", presets 1:00 / 1:30 / 2:00 / 2:30 /
3:00 / 5:00, ±15 s). VoiceOver: swipe up/down on the countdown adjusts by
15 s.

*Timing guarantee:* rest is computed from an absolute deadline
(`startedAt + target`). It is persisted on every change, so backgrounding,
locking the phone, or the app being killed never resets it; on relaunch the
dock shows the correct remaining (or overtime) value. A timer that ended
more than 15 minutes ago is dropped. A lock-screen notification and Live
Activity fire at the deadline on device.

**Resume:** minimizing (⌄) keeps the workout; Today and Routines show the
resume card. Killing the app and reopening it presents the workout again
automatically, with every typed value, completed set and the rest timer.

**Finish:** **Finish** → "Finish workout?" with "2 sets logged · 32:14.
1 unfinished set will be removed." → **Finish workout** / Keep logging. With
no completed sets the dialog offers **Discard workout** instead. Finishing
drops sets that were never completed (and exercises with none), stamps the
duration and shows the summary.

**Discard:** ⋯ → Discard workout → "All sets logged in this workout will be
deleted. Your routine is not affected."

## 5. Workout summary

Iron hero: "✓ Workout complete", routine name (`summary.title`), date ·
start–end time, Time / Sets (`summary.sets`) / Reps / Volume. Notes. Per
exercise: every set ("2 sets · 225×5, 225×5"), the best set, and the change
versus the last time this exercise was done at the same intent ("+5 lb",
"+2 reps", "Same as last", "First time"; accent when it is a gain). **Done** [primary] (`summary.done`)
returns to the tabs. From History the same screen has ⋯ → Delete workout.

## 6. History

Finished workouts, newest first, grouped by week ("THIS WEEK", "LAST WEEK",
"SEP 15 – SEP 21" + "3 workouts · 41 sets"). Row (`history.row`): day
number, routine name **as it was when logged**, "1 h 9 min · 14 sets ·
16,940 lb". Tap → summary. Empty: "No workouts yet" → Go to routines.

## 7. Settings

Units (lb / kg), week starts Monday, smart-progression defaults (plate
inventory, default increment, sets before calibrating), and **Component
gallery** (Chalkline tokens and components rendered live).

---

## Cross-cutting rules

- **Persistence:** local SwiftData store only; every confirmed action saves
  immediately. Workouts are snapshots of the routine at start time.
- **Haptics:** success on set complete and on rest done; error on any
  rejected save/complete.
- **VoiceOver:** every icon-only control is labelled; set fields read
  "Set 2 weight, lb — 225"; validation errors are announced.
- **Dynamic Type:** all text scales; rows stack instead of truncating; no
  fixed-height text containers.
- **Small iPhones:** primary actions stay reachable (thumb-zone bars, rest
  dock above the home indicator); verified on iPhone SE (3rd generation).
