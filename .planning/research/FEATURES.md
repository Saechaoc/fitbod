# Feature Research

**Domain:** Personal iOS bodybuilding/weight-training tracker for a serious lifter
**Researched:** 2026-05-10
**Confidence:** HIGH (broad ecosystem of apps inspected; concrete UI/UX patterns identified across Strong, Hevy, Jefit, FitNotes, Fitbod, Boostcamp, Liftin', Progression, RP Hypertrophy, Liftosaur, StrengthLog, Alpha Progression)

This file maps the feature landscape inside the user's already-scoped areas (routines, prescription, progression, periodization, set logging, progress views, fatigue/volume, exercise library). The user already specified the *areas*; the question here is **what details inside those areas matter** and **which adjacent features serious lifters expect that weren't named**.

The framing differs from a typical "what should we build" feature research — this app's stance is **comprehensiveness over simplicity**. So features that other apps call "advanced" are table stakes here, and the differentiation pile is concrete details (tempo per phase, RPE on warm-ups visible vs hidden, etc.) rather than headline capabilities.

---

## Feature Landscape

### Table Stakes (must exist or the app fails its own stance)

These exist in most serious-lifter apps. If the user's app omits them, it fails the "comprehensive" stance because every other app of this caliber has them.

| Feature | Why Expected | Complexity | Notes / Reference Implementation |
|---------|--------------|------------|-------|
| Per-set weight + reps + RPE entry | Core unit of logging; every app in scope does this | LOW | Hevy/Strong/Liftosaur all support; baseline |
| Rest timer with auto-start on set completion | Default behavior in Strong, Hevy, Fitbod; serious lifters never use a separate timer app | LOW | Tap "complete set" → timer starts at exercise's preset rest |
| Rest timer adjustable mid-rest (+15s / -15s buttons) | Hevy and Fitbod both expose ±15s; lifters routinely extend or cut rest based on feel | LOW | Don't just show countdown — show ±15s controls |
| Rest timer continues with lock screen / push notification | Hevy explicitly notes notifications fire even when screen sleeps; lifters lock the phone between sets | LOW | iOS local notification when timer reaches 0; Live Activity (Dynamic Island) is a nice-to-have differentiator |
| Per-exercise "Previous" column shown next to current set inputs | Hevy's "PREVIOUS" column is universally praised; lifters need to beat last session's numbers | LOW | Display weight × reps × RPE from same exercise's last instance, inline with current row |
| Auto-populate set inputs from previous session | Strong, Hevy, FitNotes all pre-fill; lifters tap to confirm or adjust | LOW | Mid-session friction killer if absent |
| Long-press / swipe to reorder exercises in routine | Drag-and-drop reordering is in Strong, Hevy, Workout Maker, FitPros — universal pattern | LOW | iOS native drag handle on list rows |
| Inline exercise search with type-ahead | Universal complaint when missing — "I wish there was a search option"; users delete apps that force scroll-through | LOW | SwiftUI `searchable` on exercise picker |
| Set types: warmup / working / drop / failure | Hevy and Strong both tag sets with visual marker (Hevy uses "W" / "D" / "F" badges in blue/red/orange on set row) | LOW | A single `SetType` enum on the set; visual badge on set row |
| Superset grouping (2+ exercises pair-able) | Hevy, Strong, Fitbod, StrengthLog all support; smart-scroll between paired sets is the better implementation | MEDIUM | "Smart superset scrolling" (Hevy's term) auto-jumps to the paired exercise's next set when one is marked done |
| Workout-level notes + per-exercise notes | Strong's pinned notes ("use 45° incline"), Hevy's routine-vs-session note distinction; serious lifters cue themselves on form, machine settings, plate increments | LOW | Two scopes: persistent (pinned to exercise across all routines) + session-only |
| Exercise library filterable by muscle, equipment, mechanic | Jefit's 1500+ library filterable by movement pattern, equipment, muscle is the bar; FitSW allows multi-select filter | MEDIUM | Multi-facet filter UI: muscle group, equipment, primary muscle, mechanic (compound/isolation) |
| Custom exercise creation (name, muscles, equipment, optional image) | Jefit and FitNotes both allow; serious lifters always have 5-10 niche variations the library lacks (banded SSB squat, plate-loaded chest press machine X) | LOW | Same model as bundled exercises; user-created bit |
| Per-exercise history view (chronological list of all sessions for one lift) | FitNotes, Strong, Hevy all have this; navigating from an exercise into "all my past sets of this" is non-optional | LOW | Reverse-chronological list filtered to one exercise |
| Estimated 1RM trend chart per exercise | Fitbod, FitNotes, Strong (Pro), Jefit, Strive all show e1RM over time; serious lifters obsess over this | LOW | Use Epley by default: `1RM = weight × (1 + reps/30)`; expose Brzycki as alternative |
| Volume PR detection (best total volume for an exercise) | Hevy has "Live PR" notifications; lifters track volume PRs alongside weight PRs and rep PRs | LOW | Compute on save: best 1RM est, best weight × reps for same rep count, best total session volume |
| Plate calculator / barbell loading | Hevy, Bar Is Loaded, RackMath; lifters need "what plates do I need to load 287.5 lb on a 45lb bar?" without doing mental math | LOW | Pluggable: user defines available plates, bar weight; output plate stack visualization |
| Weight unit toggle (lb / kg) globally | Universal feature; some lifters log lower body in kg, upper body in lb (Fitbod treats globally but users requested per-exercise) | LOW | Global default + per-exercise override (Fitbod doesn't yet do override; this is a differentiator) |
| Local data export (CSV at minimum, JSON better) | Strong, FitNotes, Motra all export CSV; "lifters won't trust an app without data export" — single-user app especially | LOW | Export schema: workouts → exercises → sets; CSV + JSON both |
| Local data backup (SwiftData → file → AirDrop / Files app) | Single-user local-only means losing data = catastrophic; needs first-class backup not just iCloud reliance | LOW-MEDIUM | Export full DB snapshot, restore from file |
| Routine duplication / "copy as starting point" | Hevy, Liftosaur both support; lifters iterate on routines week-to-week rather than rebuild | LOW | Right-swipe action or menu option |
| Routine folders / categorization | Hevy explicitly markets folders (group by split, by program, by mesocycle); user has multiple concurrent block phases potentially | LOW | Single-level folder system suffices |
| Plate-by-plate weight increments respecting equipment | If user only has 1.25kg microplates upper body, weight bumps should be 2.5kg not arbitrary | LOW | User settings: smallest increment per equipment type; double-progression and RPE-autoreg round to nearest |

### Differentiators — the "small details that matter"

These are concrete UI/UX details that competitors either lack entirely or implement poorly. Building them is the actual product. These are organized by the user's requirement area.

#### A. Routine builder details

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **One-screen routine editor** (no modal dive to add an exercise) | Strong forces a modal flow: tap +, search, tap exercise, return, configure sets. Hevy is similar. Each context switch loses your place. Inline search-and-add (typeahead at the bottom of the exercise list) is materially faster | MEDIUM | Sticky bottom search bar that, when typed in, surfaces exercises *and* adds the first match on commit |
| **Per-exercise prescription as first-class object** (not buried in set notes) | The user's stance: intent (strength/hypertrophy/conditioning/technique) is a property of the *exercise within the routine*, not just a tag. Surface intent as a chip on the exercise header | MEDIUM | `RoutineExercise` model has `intent: TrainingIntent`, displayed as a colored badge on the row |
| **Target reps as a range, not a single number** (e.g. 6-8, not "8") | Double progression requires ranges. Strong only takes single rep targets. Hevy supports ranges in display but the data model is fuzzy. Make `targetReps` a `ClosedRange<Int>` | LOW | UI: "6–8" with two text fields or a single field that parses ranges |
| **Target RPE as a range too** (e.g. RPE 7-9) | RTS-style autoreg uses RPE ranges; a single target RPE is too brittle | LOW | Mirror target reps' design |
| **Per-set prescription override** (set 1 = 6-8 @ RPE 7, set 2 = 4-6 @ RPE 9) | Almost no app supports per-set prescription within one exercise. Strong/Hevy treat all sets identically. Block-periodized programs frequently prescribe asymmetric sets ("top set + back-off sets") | MEDIUM | `RoutineSet` model, not `RoutineExercise.sets: Int`; each set has own target reps/RPE/weight scheme |
| **Superset visual nesting** (paired exercises rendered with shared left rail / color band) | Hevy uses a thin colored left bar to indicate paired exercises; immediately readable. Strong uses a less clear indented format | LOW | Group exercises in a `SupersetGroup` and render with shared accent color and rail |
| **Tri-sets / giant sets** (3+ exercises in a circuit) | HeavySet, Extreme Fitness support this; Strong is awkward; Hevy supports "as many exercises as you want to a single superset" | LOW | Same model as superset, just N exercises; UI handles 2/3/4+ identically |
| **Drag handle visible on all rows** (not long-press to reveal) | Workout Maker users complained reorder buttons "blend in visually." iOS Files app pattern: always-visible handle on right when in edit mode | LOW | Use SwiftUI's `.draggable` / `EditMode` pattern with visible handle |
| **Auto-populate rest timer per exercise** | Hevy lets user set a default and per-movement override. Don't ask the user to think — pick a sensible default (compound: 3min, isolation: 90s) and let them override | LOW | Heuristic: bilateral barbell/dumbbell compound → 180s, isolation → 90s; user overrides per exercise saves to that exercise globally |
| **Same routine, different intent → separate histories** | Explicit user requirement. Implementation: history queries filter on (exercise × intent), not just exercise | MEDIUM | The exercise has many histories, sliced by intent; UI per-exercise can toggle intent filter |

#### B. Set logging details

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **RPE as a fast-entry chip row** (1-10 buttons inline, not a wheel picker) | Hevy uses a wheel — slow. A horizontal row of 1-10 buttons (or 6-10 + lower as overflow) is one tap. Decimal RPE (8.5) shown as long-press | LOW | 5 visible chips (RPE 6/7/8/9/10), expand for finer grain |
| **Tempo entry as 4-field eccentric/pause/concentric/pause** | Standard 4-1-2-0 notation. Almost no app makes this first-class — usually buried in notes. Make it an optional row on the set with four small numeric fields | MEDIUM | `Tempo` value type: `(eccentric: Int, bottomPause: Int, concentric: Int, topPause: Int)`; computed time-under-tension per rep available for analysis |
| **Form notes field per set (not just per exercise)** | Per-set form notes ("right knee caved on rep 7") are how serious lifters debug their training; per-exercise notes are too coarse | LOW | Small text field on set row, expand-on-tap |
| **Partial-rep tracking** ("8 + 2 partials") | MacroFactor supports partials; almost nothing else does. Bodybuilders use partials as a deliberate technique past failure | LOW | Optional second rep field: `reps: 8, partialReps: 2` |
| **Cluster-set / rest-pause sub-set tracking** | MacroFactor supports rest-pause; Hevy doesn't. A rest-pause set is actually 3 mini-sets with 15-20s rest. Either model as one set with a sub-rep array (8+3+2) or three separate sets with linked metadata | MEDIUM | Sub-rep array: `reps: [8, 3, 2]` for one logical set |
| **Set marked-done state with visual completion** (strike-through / green check) | Hevy's "smart superset scrolling" automatically advances after a set is marked done; the visual completion state matters for at-a-glance pacing | LOW | Marked-done sets visually distinct (muted color, checkmark) |
| **Mid-set exercise swap preserving the routine** | "I planned bench press but the bench is occupied, swap to dumbbell bench for this session only" — Liftosaur does this best. Don't mutate the routine; create a one-session substitution | MEDIUM | `SessionExercise` overrides `RoutineExercise`; routine template stays clean |
| **Add unplanned exercise mid-workout** without breaking the routine | Almost universal; just confirm it adds to the *session* not the routine | LOW | Same model as above |
| **Bodyweight + added weight differentiation** (bodyweight pull-up vs. weighted pull-up) | FitNotes and Strong both handle this; reps-only entry for bodyweight, weight = additional load. Critical for accurate 1RM est | LOW | `ExerciseKind: barbell, dumbbell, machine, bodyweight, weightedBodyweight, cardio`; UI changes per kind |
| **Assisted-machine "negative weight"** (assisted pull-up = -45 lb assist) | Jefit handles this awkwardly. Use signed weight: -45 = 45lb assist, +45 = added load | LOW | One numeric field, sign indicates assist vs. load |

#### C. Smart progression UI

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Recommended weight shown with calculation breakdown** | Fitbod is the cautionary tale: it tells you "use 225" with zero explanation, so users distrust it. Show: "225 lb (based on last session: 215×6 @ RPE 8 → e1RM 250 → today's prescription 5 @ RPE 8 = 87% = 217.5, rounded up)" | MEDIUM | Expandable "Why this weight?" disclosure on the prescription row |
| **Progression model selectable per exercise** | User explicitly wants RPE/RIR autoreg, double progression, block-periodized, hybrid — selectable. Almost no app does this (Liftosaur via scripting, but it's coding). UI: a single picker on the exercise within the routine | MEDIUM | `ProgressionStrategy` enum; each conforms to a "recommend next weight" protocol |
| **Progression preview** before starting workout ("today's targets: 225×5, 220×5, 215×5") | Liftin' surfaces this well; lets the lifter mentally rehearse and adjust beforehand | LOW | Routine-as-instance view shows computed prescribed weights for *this* session |
| **Manual override of recommendation without breaking progression** | Lifter feels under-recovered, overrides 225 → 215. App should accept this and feed into next session's calc (not just ignore the override) | MEDIUM | Recorded performance feeds back regardless of recommendation; recommendation is just a suggestion |
| **Double-progression "you earned the weight bump" notification** | When all working sets hit the top of the rep range, the app surfaces "+5 lb next session" as an explicit moment. Most apps do this silently | LOW | Post-set or post-workout banner |

#### D. Periodization / block UI

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Block timeline visible on home screen** | Boostcamp shows "Week 3 of 5, Accumulation phase" prominently. The lifter knows where they are in the macrocycle. Most apps hide block context entirely | MEDIUM | Top-of-home: phase chip + week N of M + days remaining |
| **Phase color coding** (accumulation = blue, intensification = orange, realization = red, deload = green) | Visual at-a-glance signal; appears on routines, sessions, history entries within that phase | LOW | One color token per phase, consistently applied |
| **Mesocycle navigation (swipe between weeks)** | Boostcamp does this well; tap into a week to see all sessions in it. Critical for "what does my Tuesday look like in week 4?" | MEDIUM | Horizontal week pager; week shows N days of sessions |
| **Deload week visually distinct** (calendar / banner) | RP Hypertrophy and Boostcamp both highlight deload weeks. Volume bars during deload show ~50% reduced targets | LOW | Deload week has different bg tint or banner; volume targets auto-cut |
| **"Consider deload" alert when fatigue signals spike** | Explicit user requirement. Triggers: e1RM drop > X% over Y sessions, RPE creep at same load, missed rep targets across multiple sessions | HIGH | Background heuristics over the last 4-6 sessions of each lift |
| **Phase-end review screen** | At end of a block: total volume, e1RM deltas, PRs hit, recommended next phase. Almost no app does this | MEDIUM | Computed summary of the just-ended block |

#### E. Volume / fatigue heatmap UI

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Per-muscle volume bars with MEV/MAV/MRV bands** | RP Hypertrophy is the inspiration; Hevy shows weekly sets per muscle but no thresholds. Render as a bar with three colored zones (under-MEV = red, MEV-MAV = green, MAV-MRV = yellow, over-MRV = red), current weekly sets as a marker | MEDIUM | Bar widget: zones from user-tuned MEV/MAV/MRV per muscle |
| **Heatmap on body diagram** (front + back anatomical view) | StrengthLog, MuscleSquad, Hevy all have body-map visualizations. Color intensity = sets done this week. Tap a muscle for detail | HIGH | Two SVG/anatomical body views; muscle regions are tap targets |
| **Stimulus weighting** (bench press = 1.0 chest, 0.5 triceps, 0.25 front delt) | Plain "sets per muscle" double-counts. Stimulus weighting is more honest. RP Hypertrophy does this implicitly | MEDIUM | Each exercise has `[Muscle: Float]` map; sets multiply by weight when accumulating |
| **Threshold customization per muscle** (user-tunable MEV/MAV/MRV) | Explicit user requirement. RP defaults are starting points; lifter knows their own quads can take 30 sets/week | LOW | Per-muscle settings table; defaults from RP charts |
| **Weekly recap screen** (auto-shown post-week or on Sunday) | RP Hypertrophy surfaces this; nothing else does well. Shows: muscles hit, muscles undertrained, e1RM movement, sessions logged | MEDIUM | Computed on the fly; surfaced via a tab or post-session card |
| **Frequency tracking** (chest hit 2x this week, glutes 3x) | Distinct from volume — some muscles need frequency, not just volume. Hevy and Liftosaur show frequency | LOW | Count sessions in which the muscle exceeded a minimum-stimulus threshold |

#### F. Progress views — what serious lifters actually look at

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Per-exercise intent split** (strength chart vs. hypertrophy chart for the same lift, on the same screen) | Explicit user requirement. Hevy/Strong show one line for the lift; user wants two lines (or toggleable) | MEDIUM | Time-series chart with intent as a series dimension |
| **Plateau detection signal** (configurable: e.g., e1RM flat ±2% over N sessions = "stalled") | Up Lifting and Progression both have plateau detection but black-box; surface the signal with thresholds. Per-exercise stall indicator | MEDIUM | Rolling regression over last N sessions; visual flag on exercise card |
| **Top-set vs. all-set e1RM tracking** | A top set e1RM and an average e1RM tell different stories. Most apps only track top set. Show both | LOW | Two series on the chart, toggleable |
| **Tonnage per week + per training block** | Hevy and Jefit both show tonnage; show it sliced by week, block phase, and exercise/muscle. Tonnage = total weight × reps lifted | LOW | Aggregated query over sessions; rolling-7-day, current-week, current-block |
| **PR history list** (every PR for an exercise, chronologically: weight PRs, rep PRs, volume PRs, e1RM PRs) | Strong, Hevy show PRs but mixed in feed; a dedicated "all PRs for this lift" view is rare and valuable | LOW | Reverse-chron list of all PR events for an exercise |
| **Session comparison view** (this Monday's session vs. last Monday's same routine) | Almost no app does this. Lifter wants side-by-side: "did I beat last week on every lift?" | MEDIUM | Two-column diff view per exercise |
| **Block summary** (avg RPE, total tonnage, set count per muscle, e1RM movement across all lifts) | Phase-end retrospective. Boostcamp does some of this in its programs view | MEDIUM | Aggregated per block; computed on demand |

#### G. Exercise library details

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Multi-facet filter** (muscle AND equipment AND mechanic AND grip) | Jefit's filter is the bar (movement pattern, equipment, muscle); add grip (overhand, neutral, underhand) and mechanic (compound, isolation) for a serious lifter's needs | MEDIUM | Compound `ExerciseQuery` predicate; UI is multi-select chip stacks |
| **Recent exercises shortcut** (last 10 added) | Adding the same exercises week after week; recents save scrolling | LOW | Cached list updated on use |
| **Favorites / starred exercises** | Jefit has this; lift roster stabilizes around 30-40 exercises for most lifters | LOW | Boolean on `Exercise`; sortable section in picker |
| **Custom exercise inherits muscle mapping from a template** | When creating a custom exercise, base it on an existing one (e.g., "Banded Front Squat" inherits Front Squat's muscle map and equipment) | LOW | "Create variant" entry point on existing exercise |
| **Exercise alias / search synonyms** ("RDL" finds "Romanian Deadlift") | Universal complaint when missing; serious lifters use shorthand | LOW | `aliases: [String]` on `Exercise`; searchable |
| **Bilateral / unilateral tagging** | Single-leg work tracks differently from bilateral; sets per side vs. total sets matters for volume accounting | LOW | Boolean or enum; in custom exercise creation too |
| **Bundled library quality check** (free-exercise-db has 800+ exercises with images; ExerciseDB has 11000+ with gifs/videos) | wger has fewer but cleaner data; free-exercise-db has more entries but inconsistent. Pick one and audit it. Avoid duplicates and bodyweight-only items in the seed | MEDIUM | Engineering decision: one-time import + audit + dedupe pass |

#### H. Auto warm-up ramp

| Feature | Value Proposition | Complexity | Notes / What competitors miss |
|---------|-------------------|------------|-------|
| **Algorithmic ramp** (e.g., 40%×5, 60%×4, 75%×3 → top set) | Hevy, LiftTrack, Strong (Pro) all do this with formulas. User explicitly wants this on first compound only | LOW | Generate sets from working weight; sensible defaults (3 warm-up sets), user-overridable count |
| **Plate-rounded warm-ups** | Calculator output is decimal lb; round to actually-loadable weight based on user's plate set | LOW | Existing plate calc dependency |
| **Skip-warmup option per session** | Already warm from earlier exercise → skip the auto-ramp for this exercise this session | LOW | Toggle in exercise header |
| **Warm-ups don't count toward volume / RPE history** | Universally true — warm-up sets are tagged differently and excluded from e1RM and tonnage calculations | LOW | `SetType.warmup` excluded from aggregations |
| **Pre-fill warmup based on prior session's working weight** | If today is auto-ramping toward 225, take that 225 from the progression model and generate the ramp toward it | LOW | Dependency on progression model output |

### "Small Details That Matter" — dedicated section

Pulled out because the user explicitly named this as the differentiation philosophy. Each is a concrete UI decision that one or more competitors get wrong.

1. **Decimal RPE entry** (RPE 8.5 is real; most apps force integers) — long-press the RPE chip to expose half-points
2. **Rest timer skip-and-log** — sometimes a lifter doesn't need full rest; "skip remaining" should immediately mark the next set ready without making them tap-tap
3. **Default weight increments respect microplates** — if user has 1.25kg plates, recommendations land on .25kg increments, not 2.5kg
4. **e1RM uses Epley by default but offers Brzycki + RTS as options** — different lifters prefer different formulas (Epley overestimates at high reps, Brzycki tracks better at 6+)
5. **Tempo on prescription, not just on logging** — the routine says "3-1-1-0" and the logger shows it as a reminder, not a field to re-enter
6. **Pinned exercise notes** — "Use the 45° incline" appears every time you load that exercise, not just in this session (Strong's "pinned notes" pattern)
7. **Last-time-same-intent shown** — the "previous" column filters to last session with matching intent, so strength-day data doesn't mislead a hypertrophy-day attempt
8. **Set-row inline previous** — show "Last: 225×5 @ 8" in light grey behind the current set's input row (faint placeholder text)
9. **Auto-stop rest timer when you start logging the next set** — entering reps for the next set implies rest is over; cancel the timer (Fitbod-style)
10. **AMRAP set with rep target** — "AMRAP, target 8+" rather than just AMRAP; if you hit fewer than 8, signal that
11. **Failure mark is distinct from rep count** — completing 6 reps to failure and completing 6 reps with 2 in reserve are different data points; tagging matters
12. **Body-part-specific deload depth** — quads might deload 50%, biceps 70%, based on individual MRVs; not one-size-fits-all
13. **Routine "today" instance is editable without mutating the template** — change the routine for this session only without "save changes to template?" interrupt
14. **History entry shows the prescribed vs. actual** — "prescribed 5×5 @ 225; you did 5×5×4×4×3 @ 225" — surface the gap
15. **e1RM trend toleranced** — a single bad session shouldn't crater the trend line; show a smoothed trend alongside raw points
16. **Time-of-day on session entries** — strength performance varies AM/PM; tagging the session time makes the data sliceable
17. **Notes searchable across history** — "find every session where I noted 'right shoulder'"
18. **Plate calculator embedded next to weight entry** — tap weight → see the plates; not a separate screen (Hevy gets close, Strong forces dive)
19. **Failure semantics tracked precisely** — `RIR: 0` and `failure: true` and `partial reps: 3` together describe what really happened
20. **Per-set rest time logged** (not just prescribed) — when the timer runs out, actual rest taken is recorded; allows analysis like "are my rests creeping up as fatigue accumulates?"

### Anti-Features (deliberately NOT built, with reasoning)

These are features other apps include — sometimes prominently — that this app should *explicitly* exclude.

| Feature | Why It's Commonly Built | Why Not Here | Reasoning |
|---------|--------------|-----------------|-------------|
| Cardio tracking (running, cycling, HIIT logging) | "Total fitness" app stance | Scope creep; scope is weight training. Reddit lifters explicitly want strength-only apps; "apps that do both usually do neither well" | User trains lifting; Apple Fitness / Strava handle cardio fine |
| Nutrition / macro tracking | App-suite ambitions | Same scope-creep reasoning; MacroFactor / MFP are best-in-class for this. Building a half-rate version would dilute the core | Single-purpose tool wins |
| Social feed / following / leaderboards / friends | Hevy makes this a pillar; engagement metrics | Personal app, single user. Social pressure incentivizes ego lifting and dishonest RPE | Out of scope per PROJECT.md |
| Streak counter / "don't break the chain" | Gamification engagement hook | Streaks pressure showing up when you should be deloading. Conflicts with the periodization stance | Periodization > streaks |
| XP / level-up / badges / achievements | Universal in beginner apps; some lifters love | Conflicts with the "serious training" stance; PRs are the only achievements that matter and they're real (not earned tokens) | The training is the reward |
| AI workout generator / "AI coach" | Fitbod's core pitch; trend in 2024-2026 | User explicitly criticized Fitbod for "black-box" recommendations and treating users as beginners. User wants *explicit* models he chose, not opaque suggestions | User-selected progression > AI guess |
| Beginner onboarding flow with fitness assessment | Standard pattern (BetterMe, Caliber) | User is the developer and a serious lifter; skip-quiz pattern Liftosaur uses ("only ask things important to start") is the right model. Or no onboarding at all — just open and use | One user, who already knows the domain |
| Workout reminders / push notifications | "Don't forget to work out!" | Adult lifter doesn't need a phone telling him to train. Rest-timer notification is the only push needed | Notifications only for active workouts (rest timer) |
| HealthKit integration | Standard iOS app expectation | Explicitly out of scope per PROJECT.md; v1 has no Apple Health writes/reads. Revisit later | v1 simplicity |
| Apple Watch companion | Standard expectation for "real" gym apps; Liftin' praised for this | Explicitly out of scope per PROJECT.md; phone-only v1. Revisit after core stable | v1 simplicity |
| Velocity-based training / accelerometer features | Cutting-edge; Metric VBT pioneers this | Hardware-dependent (requires phone on bar / external sensor). User excluded all hardware integrations | v1 simplicity |
| Form-check video upload / pose analysis | Trend feature; AI form analysis | Out of scope per PROJECT.md; text notes only. Video processing on-device is non-trivial | v1 simplicity |
| Cloud sync / multi-device | Hevy / Strong / Jefit all do this | Single user, single device for v1. SwiftData local-only. iCloud might come later but not v1 | Per PROJECT.md |
| Account / login / multi-user profiles | Default of cloud-backed apps | Single user (the developer). No auth surface at all | Per PROJECT.md |
| In-app coaching / video instruction per exercise | Sweat, Caliber differentiator | User already knows exercises (serious lifter); per-exercise demo videos would bloat the bundle and screen real estate. Image/text optional, not core | Domain expert user |
| Subscription / monetization / paywall | Standard for App Store apps | Personal app, no commercial path. Not deciding what's "free vs Pro" eliminates a whole design axis | Per PROJECT.md |
| Programs marketplace ("import nSuns / 5/3/1 / PHUL") | Boostcamp's whole pitch (130+ programs) | User builds his own routines from his own knowledge of periodization. Importable templates could be a v1.x addition but not core. Building a marketplace = building a separate app | User is his own programmer |
| Gym check-in / location features | Some apps tag workouts by gym | Single user, single primary gym usually. No value here | Out of scope (no GPS) |
| Body weight / measurements tracking | Hevy / Strong both include | Adjacent to lifting but veers toward "general fitness." Could be a small addition later but not core to v1 | Defer to v1.x if requested |
| Photo progress / physique tracking | Common in bodybuilding apps | Same as above — adjacent, not core to "comprehensive lifting tracker". Photos on iOS already do this | Defer/use Photos |
| Audio cues / voice-counted reps | Some apps have this | Earphones + gym ≠ universal; better to keep audio surface minimal | Out of scope |
| "Today's recommended workout" if user has no routine | Fitbod's default mode | User always has a routine (block periodization implies this). Empty-state suggestion would be misleading | User-driven, not app-driven |

---

## Feature Dependencies

```
[Exercise library] (P1)
    ├──required-by──> [Routine builder] (P1)
    │                       ├──required-by──> [Per-exercise prescription] (P1)
    │                       │                       ├──required-by──> [Smart progression models] (P1)
    │                       │                       │                       └──required-by──> [Block periodization] (P2)
    │                       │                       │                                               └──required-by──> [Deload (scheduled)] (P2)
    │                       │                       │                                                                       └──required-by──> [Deload (fatigue-triggered)] (P3)
    │                       │                       └──required-by──> [Auto warm-up ramp] (P1)
    │                       └──required-by──> [Set logging] (P1)
    │                                               ├──required-by──> [Per-exercise history] (P1)
    │                                               │                       ├──required-by──> [e1RM tracking] (P1)
    │                                               │                       ├──required-by──> [PR detection] (P1)
    │                                               │                       └──required-by──> [Plateau detection] (P2)
    │                                               └──required-by──> [Volume tracking per muscle] (P2)
    │                                                                       ├──required-by──> [MEV/MAV/MRV bars] (P2)
    │                                                                       └──required-by──> [Muscle heatmap] (P2)
    └──required-by──> [Exercise-to-muscle mapping] (P1)
                            └──required-by──> [Volume tracking per muscle] (P2)

[Custom exercise creation] (P2) ──enhances──> [Exercise library]
[Plate calculator] (P1) ──enhances──> [Auto warm-up ramp], [Smart progression models]
[Rest timer] (P1) ──enhances──> [Set logging]
[Routine duplication + folders] (P2) ──enhances──> [Routine builder]
[Tempo tracking] (P2) ──enhances──> [Set logging]
[Partial reps / cluster sets] (P3) ──enhances──> [Set logging]
[Body-map heatmap] (P3) ──enhances──> [Volume tracking per muscle]
[CSV/JSON export] (P1) ──enhances──> [All data]
[Local backup/restore] (P1) ──enhances──> [All data]
```

### Dependency Notes

- **Exercise library is the keystone:** every other feature depends on having well-modeled exercises with muscle mappings. Build this first and audit the seed data; pull from `free-exercise-db` (800 exercises, JSON, public domain) and curate. Avoid `ExerciseDB API` (online, 11000 exercises, but external dep and overwhelming).

- **Per-exercise prescription is the unit of differentiation:** without it, the app is "another Strong." Build the data model with this as the smallest meaningful object — not session-level intent.

- **Smart progression depends on prescription:** the routine defines intent + targets; the progression model reads history filtered by intent and proposes weight. These are tightly coupled.

- **Periodization layers on top of progression:** a "block" is a window of time within which routines have certain phase characteristics. Progression strategy can depend on the active phase.

- **Volume tracking needs accurate muscle mapping per exercise:** the data quality here makes or breaks the MEV/MAV/MRV bars and heatmap. Stimulus weighting (primary/secondary muscle contributions) matters; flat "this exercise hits chest" double-counts chest+triceps lifts.

- **Plateau detection and fatigue-triggered deload both depend on a history of comparable sessions:** these are P2/P3 because they need 4-6+ sessions of data per lift to produce meaningful signals. Building them too early gives noisy alerts.

- **Export and backup are P1 despite seeming infrastructural:** single-user local-only means data loss is fatal. Build export/restore in the same phase as set logging or immediately after.

---

## MVP Definition

### Launch With (v1 — must exist to validate the stance)

These are the irreducible features. Without any of these, the app fails the "comprehensive lifting tracker" premise.

- [ ] Bundled exercise library (1000+, seeded from free-exercise-db with curation) with multi-facet filter (muscle, equipment, mechanic) — *foundation*
- [ ] Custom exercise creation — *the library never has everything*
- [ ] Routine builder: single-screen, drag-reorder, inline-search add, supersets, per-exercise prescription (intent + target reps range + target RPE + scheme) — *core differentiator*
- [ ] Per-exercise prescription as first-class data — *core differentiator*
- [ ] Routine instance vs. template separation (today's session is editable without mutating template) — *explicit user requirement*
- [ ] Set logging: weight, reps, RPE, tempo (optional row), rest timer integration, set type tags (warmup/working/drop/failure), per-set notes — *core logging*
- [ ] Rest timer: auto-start, adjustable ±15s, local notification on lock, skip-to-next-set — *core logging*
- [ ] Plate calculator integrated with weight entry — *core logging*
- [ ] Auto warm-up ramp on first compound (configurable count, plate-rounded) — *explicit user requirement*
- [ ] Smart progression: all four models selectable per exercise (RPE/RIR autoreg, double progression, block-periodized, hybrid) with visible calculation — *explicit user requirement*
- [ ] Per-exercise history with intent split — *explicit user requirement*
- [ ] e1RM tracking with Epley + Brzycki options — *table stakes for serious lifters*
- [ ] PR detection (weight, rep, volume, e1RM) — *table stakes*
- [ ] Previous-set / previous-workout display during logging — *table stakes*
- [ ] Local CSV + JSON export — *single-user data safety*
- [ ] Local backup/restore (full DB to file) — *single-user data safety*
- [ ] Weight unit settings (lb/kg, global + per-exercise override) — *table stakes*

### Add After Validation (v1.x — once core is working)

Features that the user named or implied but can ship in a fast-follow without delaying core validation.

- [ ] User-defined training blocks with phase tagging and length — *explicit user requirement; can be modeled but UI/computation can ship after core logging proves out*
- [ ] Scheduled deload weeks (cuts volume/intensity automatically that week) — *depends on blocks*
- [ ] Block timeline UI on home screen, phase color coding, mesocycle navigation — *visualization on top of block data model*
- [ ] Per-muscle weekly volume tracking with user-tunable MEV/MAV/MRV bands — *requires several weeks of data first to be meaningful*
- [ ] Muscle heatmap (anatomical body view) — *visualization on top of volume model*
- [ ] Plateau detection signal (configurable thresholds) — *needs sessions accumulated to produce signal*
- [ ] Weekly recap screen (auto-shown post-week) — *aggregation over data model*
- [ ] Routine folders and duplication — *organization, valuable once user has 5+ routines*
- [ ] Tonnage per week / per block aggregations — *low complexity once history exists*
- [ ] Session comparison view (this week vs. last week) — *low complexity once history exists*

### Future Consideration (v2+)

- [ ] Fatigue-triggered deload alert ("consider deload") — *requires plateau detection + RPE creep + missed-target heuristics; tune after several blocks of data*
- [ ] Cluster set / rest-pause sub-rep tracking — *advanced technique, niche use; defer until simpler logging proven*
- [ ] Partial-rep tracking — *advanced technique, niche use*
- [ ] Phase-end review / block summary screen — *retrospective; needs multiple completed blocks*
- [ ] Pinned exercise notes / persistent cues — *quality-of-life, low priority until other things settle*
- [ ] Notes searchable across history — *quality-of-life*
- [ ] Time-of-day session tagging + analysis — *quality-of-life*
- [ ] Asymmetric per-set prescription within one exercise (top set + back-offs) — *advanced periodization pattern; valuable but adds data model complexity; defer until per-exercise prescription is proven*
- [ ] iCloud sync (if a 2nd device ever becomes relevant) — *out of scope v1 per PROJECT.md*
- [ ] Apple Watch companion — *out of scope v1 per PROJECT.md*
- [ ] HealthKit integration — *out of scope v1 per PROJECT.md*

---

## Feature Prioritization Matrix

Inside the v1 / v1.x slice, ordered by user value × implementation cost.

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Exercise library + filter | HIGH | MEDIUM | P1 |
| Routine builder (one-screen, drag-reorder, inline search) | HIGH | MEDIUM-HIGH | P1 |
| Per-exercise prescription model | HIGH | MEDIUM | P1 |
| Set logging (weight/reps/RPE/notes) | HIGH | LOW | P1 |
| Rest timer (auto-start, adjustable, notification) | HIGH | LOW | P1 |
| Previous-set inline display | HIGH | LOW | P1 |
| Smart progression — RPE autoreg | HIGH | MEDIUM | P1 |
| Smart progression — double progression | HIGH | LOW | P1 |
| Smart progression — block-periodized | HIGH | MEDIUM-HIGH | P1 |
| Smart progression — hybrid | HIGH | MEDIUM | P1 |
| Auto warm-up ramp | HIGH | LOW | P1 |
| Plate calculator | MEDIUM | LOW | P1 |
| Custom exercise creation | HIGH | LOW | P1 |
| e1RM + PR tracking | HIGH | LOW | P1 |
| Per-exercise history with intent split | HIGH | MEDIUM | P1 |
| Tempo entry (4-field) | MEDIUM | LOW | P1 |
| Set type tags | MEDIUM | LOW | P1 |
| Superset grouping | MEDIUM | MEDIUM | P1 |
| Export CSV/JSON + local backup | HIGH | LOW | P1 |
| Training blocks data model | HIGH | MEDIUM | P2 |
| Scheduled deload | HIGH | MEDIUM | P2 |
| Mesocycle navigation UI | MEDIUM | MEDIUM | P2 |
| Per-muscle volume tracking (MEV/MAV/MRV) | HIGH | HIGH | P2 |
| Muscle heatmap (body view) | MEDIUM | HIGH | P2 |
| Plateau detection | MEDIUM | MEDIUM | P2 |
| Routine folders + duplication | MEDIUM | LOW | P2 |
| Weekly recap | MEDIUM | MEDIUM | P2 |
| Tonnage aggregations | MEDIUM | LOW | P2 |
| Fatigue-triggered deload alert | HIGH | HIGH | P3 |
| Cluster set / rest-pause / partials | LOW | MEDIUM | P3 |
| Session comparison view | MEDIUM | MEDIUM | P3 |
| Block summary | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for v1 launch — the app fails its premise without these
- P2: v1.x — should ship within a few iterations of v1 to fulfill the comprehensive stance
- P3: v2+ — quality-of-life and advanced features that benefit from accumulated data

---

## Competitor Feature Analysis

Concrete reference points: what specific competitors do well or poorly, organized by feature.

| Feature | Reference Apps | What They Do | What's Wrong With Their Approach | Our Approach |
|---------|--------------|--------------|--------------|--------------|
| Routine builder | **Hevy** (best), **Strong** (modal-heavy), **Liftosaur** (text/scriptable) | Hevy: folders, drag-reorder, supersets, set-type tags inline. Strong: cleaner UI but modal-heavy add flow. Liftosaur: text-based program definition (powerful but coder-targeted) | Strong: too many modal dives. Hevy: prescription is set-list with sloppy data model for ranges. Liftosaur: too cognitively heavy for non-coders | Single-screen editor with sticky inline search, per-exercise prescription as first-class chips, target ranges as native types |
| Per-exercise prescription | **None do this well.** Fitbod, Hevy, Strong all treat sets as homogeneous within an exercise | Fitbod has prescribed sets/reps/weight but no intent. Hevy has notes for intent. Strong has nothing | Intent is invisible or buried. Same routine same exercise = same target every day | Intent + target reps range + target RPE + scheme as first-class fields on `RoutineExercise` |
| RPE/RIR autoregulation | **Liftosaur** (via script), **Gravitus** (calculator), **Hevy** (logging only) | Liftosaur computes via Liftoscript. Gravitus has a calculator. Hevy logs RPE but doesn't autoregulate. Strong doesn't even log RPE without workarounds | Either coding-required, calculator-only (not integrated), or just record-keeping | Built-in RPE autoreg as one of four user-selectable models; transparent calculation surfaced |
| Double progression | **Alpha Progression** (built-in), **Liftosaur** (scriptable), **StrengthLog** (manual) | Alpha Progression centers its whole model on this. Liftosaur via script. StrengthLog manual recording, no auto-suggest | Most apps require lifter to track range hits manually | One of four selectable progression models, automatic "you earned the bump" detection |
| Block periodization | **Boostcamp** (templates), **Liftosaur** (scriptable) | Boostcamp's 130+ programs include block-periodized templates with phase progression. Liftosaur via scripts | Boostcamp: import-only (you don't define your own blocks easily). Liftosaur: coding | User-defined blocks with phase chips, scheduled deload, mesocycle nav |
| Auto warm-up ramp | **Hevy** (PRO), **LiftTrack**, **Stronglifts** (built-in), **Strong** (PRO) | Hevy: configurable percentage-based warmup sets added to exercise. LiftTrack: auto-generated based on working weight | Most paywall it (Strong, Hevy); few do plate-rounding to actually-loadable weights | First-class, free, plate-rounded, user-configurable per exercise; skip-toggle |
| Rest timer | **Hevy** (excellent UI), **Fitbod** (excellent UX), **FitNotes** (basic) | Hevy: per-exercise default, ±15s, lock-screen notifications, Live Activity. Fitbod: similar. FitNotes: bare-bones | Some apps' rest timer is afterthought (Strong's free tier is limited) | First-class rest timer per exercise, with skip-and-log-next-set shortcut |
| Set logging | **Hevy** (PREVIOUS column), **Strong** (clean), **MacroFactor** (most fields), **FitNotes** (fastest minimum) | Hevy: previous values shown inline as left column. MacroFactor: tracks every detail (drop sets, RIR, failure, partials). Strong: clean tap-to-log | Hevy good but lacks tempo, lacks partial reps. MacroFactor most comprehensive but UX has friction | Hevy's PREVIOUS column + MacroFactor's depth + first-class tempo + decimal RPE |
| Per-exercise history | **FitNotes** (clean), **Strong** (mixed feed), **Hevy** (good charting) | All show chronological list; Hevy/Strong/Fitbod chart e1RM | None split by intent; same exercise hypertrophy day vs. strength day is one stream | Filterable history with intent split; two-series chart |
| 1RM estimation | Most: **Epley by default** | Strong, FitNotes, Strive, Jefit, Fitbod all use Epley (1RM = weight × (1 + reps/30)) | Single formula; doesn't expose alternatives | Epley default, Brzycki + RTS available; setting per user, formula visible |
| Volume tracking | **Hevy** (sets per muscle, weekly), **Liftosaur** (prescribed + completed), **RP Hypertrophy** (full landmarks) | Hevy: sets per muscle / week as bar chart. Liftosaur: weekly volume per muscle map. RP: full MEV/MAV/MRV with adaptation logic | Hevy: no thresholds. RP: closed system, can't customize landmarks freely | User-tunable MEV/MAV/MRV per muscle, stimulus-weighted, visual bands |
| Muscle heatmap | **StrengthLog**, **MuscleSquad**, **Hevy**, **ChunkItUp**, **GymBook** | StrengthLog: heat map showing trained muscles + set counts. Hevy: blue-highlighted muscle diagram. GymBook: 4 multicolor heatmaps | Often decorative rather than informative; usually doesn't link back to MEV/MAV/MRV bands | Body-map view with intensity = % of MAV, tap-through to volume detail |
| Plateau detection | **Up Lifting**, **Progression** | Up Lifting: detects stagnation, suggests block rotation. Progression: clear stats and charts | Black-box thresholds | Configurable: stalls over N sessions, e1RM delta threshold, user-tunable |
| Deload | **Stronglifts** (auto, on stall), **Fitbod** (auto), **RP Hypertrophy** (feedback-based), **Boostcamp** (scheduled) | Stronglifts cuts weight after consecutive failures. Fitbod adjusts on stall. RP adjusts on pump/soreness/effort feedback. Boostcamp schedules deload weeks in programs | Most are reactive only OR scheduled only — rarely both | Scheduled (block-driven) by default + fatigue-triggered alert (configurable) |
| Custom exercise | **Jefit** (image+equipment+instructions), **FitNotes** (lightweight) | Jefit: custom exercise with image, title, equipment, record type, instructions. FitNotes: name + category | Jefit's flow is heavy but comprehensive | Inherits from existing exercise as template; muscle mapping, equipment, mechanic, bilateral/unilateral, optional image |
| Set types | **Hevy** (warmup/working/drop/failure with badges), **Strong** (tags), **Fitbod** | Hevy: tap set number → menu to mark as W/D/F/normal; blue/red/orange badges. Strong: similar tag UI | Standard implementations; few support custom types | Standard set types as enum; visual badges; AMRAP as additional type |
| Plate calculator | **Bar Is Loaded**, **RackMath**, **Hevy** (built-in), **Strong** (built-in) | Standalone apps vs. integrated. Hevy's plate calculator is in-app | Standalone requires app-switching; some integrated calcs are buried | Inline tap-to-show on weight field |

---

## Confidence Assessment

**Overall: HIGH.** The lifting-app ecosystem is mature with ample public documentation of feature implementations (Hevy in particular publishes detailed help docs for each feature). The differentiators identified are concrete UI/UX-level decisions, not speculation.

| Area | Confidence | Notes |
|------|------------|-------|
| Table-stakes features | HIGH | Cross-verified across 10+ apps; what serious lifters expect is well-documented |
| Routine builder UX | HIGH | Hevy, Strong, Liftosaur, Workout Maker patterns publicly inspected |
| Set logging UX | HIGH | Hevy publishes detailed help docs; pattern is well-established |
| Progression models | HIGH | RPE/RIR, double progression, block periodization, hybrid are all standardized in S&C literature; Liftosaur and Alpha Progression are concrete reference implementations |
| Periodization UI | MEDIUM-HIGH | Boostcamp is the main reference; less industry consensus on "best" UI for block visualization. User defines blocks rather than imports them — fewer apps do this |
| Volume / MEV-MAV-MRV | HIGH | RP Hypertrophy app is the reference; volume landmarks are well-defined; user is following RP framework |
| Muscle heatmap | MEDIUM | Many apps implement it but quality varies wildly; less consensus on "good" implementation |
| Anti-features | HIGH | The user explicitly excluded these in PROJECT.md; ecosystem context confirms these are common scope-creep mistakes |
| Exercise library data sources | HIGH | free-exercise-db (800+, public domain, JSON), wger (open source), ExerciseDB (online API) are well-known options |

---

## Sources

### Apps Researched
- [Hevy app feature documentation](https://www.hevyapp.com/features/) — most comprehensive public feature reference
- [Strong app help center](https://help.strongapp.io/) — tagging, supersets, warmup calculator
- [Liftosaur documentation](https://www.liftosaur.com/docs/docs) — scriptable progression, plain-text programs
- [Jefit overview](https://www.jefit.com/) — large exercise library, custom exercise creation
- [FitNotes app](http://www.fitnotesapp.com/) — minimalist logger, e1RM trend, paper-equivalent stance
- [Fitbod help center](https://help.fitbod.me/) — smart progression, unit of measurement, exercise notes
- [Boostcamp](https://www.boostcamp.app/) — block periodization templates, mesocycle programs
- [RP Hypertrophy app](https://rpstrength.com/pages/hypertrophy-app) — volume landmarks, pump/soreness/effort feedback
- [Progression Workout Tracker](https://apps.apple.com/us/app/progression-workout-tracker/id1090687896) — automatic rep-target progression
- [Liftin' Gym Workout Tracker](https://www.liftinapp.co/) — auto-warmups, training max programming
- [Alpha Progression](https://alphaprogression.com/en) — double progression as primary model
- [StrengthLog](https://www.strengthlog.com/) — RPE/RIR logging, muscle heatmap, free
- [Bar Is Loaded](https://barisloadedapp.com/) — plate calculator pattern
- [MacroFactor Workouts](https://macrofactor.com/workouts/) — most-comprehensive logging (drop sets, RIR, failure, partials)

### Comparison / Review Sources
- [Hevy vs Strong (Setgraph)](https://setgraph.app/ai-blog/hevy-vs-strong) — feature comparison rest timers and supersets
- [Best workout tracker apps tested by lifters (Setgraph)](https://setgraph.app/ai-blog/best-app-for-tracking-workouts)
- [RP Hypertrophy app independent review (Dr. Muscle)](https://dr-muscle.com/rp-hypertrophy-app-review/)
- [Strong app missing features review](https://dr-muscle.com/strong-workout-app-review/)
- [Best strength training apps Reddit (Setgraph)](https://setgraph.app/ai-blog/best-strength-training-app-reddit)
- [Fitbod review (GymGod)](https://gymgod.app/blog/fitbod-review)
- [Liftosaur indie hackers post](https://www.indiehackers.com/post/liftosaur-weightlifting-tracker-app-for-coders-0f2c1d3837)

### Methods / Frameworks
- [RP Strength volume landmarks (MEV/MAV/MRV)](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth)
- [Double progression explained (LiftProof)](https://www.liftproof.app/blog/double-progression-explained)
- [RPE/RIR autoregulation (StrengthLog)](https://www.strengthlog.com/rpe-and-rir-in-strength-training/)
- [Boostcamp block periodization](https://www.boostcamp.app/blogs/block-periodization-olympic-weightlifting)
- [1RM formulas comparison Epley vs Brzycki (Arvo)](https://arvo.guru/resources/one-rep-max-formulas)
- [Tempo notation guide (Trainomi)](https://blog.trainomi.com/en/post/gym-dictionary-tempo)
- [Myo-reps, rest-pause, cluster sets (Macrofactor)](https://help.macrofactorapp.com/en/articles/379-what-are-myo-sets-drop-sets-and-failure-sets)
- [How to Deload (Boostcamp)](https://www.boostcamp.app/blogs/how-to-deload-in-lifting)

### Exercise Data Sources
- [free-exercise-db (GitHub)](https://github.com/yuhonas/free-exercise-db) — 800+ exercises, public domain, JSON (recommended seed)
- [wger (GitHub)](https://github.com/wger-project/wger) — open source, REST API
- [ExerciseDB API](https://www.exercisedb.dev/docs) — 11000+ exercises with gifs (online dep)

### UX / Design References
- [Common UX mistakes in fitness apps (Panacea)](https://www.panacea.digital/2018/10/16/common-ux-ui-mistakes-made-in-fitness-apps/)
- [Fitness app UI/UX mistakes (2V Modules)](https://www.sportfitnessapps.com/blog/5-uiux-mistakes-in-fitness-apps-to-avoid)

---
*Feature research for: personal iOS bodybuilding/lifting tracker (single-user, local-only, hardware-free v1)*
*Researched: 2026-05-10*
