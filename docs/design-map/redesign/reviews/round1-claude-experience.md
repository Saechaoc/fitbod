# Round 1 review: Experience lens (Claude)

Reviewer lens: information architecture, visual hierarchy and the brief's criteria.
Paths starting `redesign/` are in the proposal folder; every other path is in the repository at HEAD.
All code claims were checked against the current source, not the GitNexus index.

## 1. Verdict

No, the proposal cannot be finalized as written.
Its Today state machine rests on a false premise: a block review is not marked reviewed on dismiss, so the T-REVIEW hero, which outranks T-READY and T-PICK, never clears unless the lifter creates a new block.
The same precedence also leaves a lifter whose block just ended with no way to start a workout from Today.
Separately, the proposal routes every alternate start through the unslotted path, which widens D-19 (a "with the redesign" row) instead of closing it, so second sessions and swapped sessions never move a rotation block.
A routine with one empty session puts a failing signal button in the hero and strands a rotation block, and no state covers it.
The hierarchy itself (plan line, one hero, volume behind one row, Now slab on Program) is sound, and the remaining findings are fixable without changing its shape.

## 2. Findings, worst first

### F-1 **The T-REVIEW hero never clears, so it hides the ready block and the session suggestion for good**

- Trigger: a block ends (End block, or a swap) and the lifter opens its review, reads it, and goes back or taps Plan custom.
- Mechanism: the proposal says dismissing the review marks it reviewed "as now", but today `reviewedAt` is written only by "Start next ▸", which also opens a new block builder from a template; Back and "Plan custom" call `dismiss()` only.
  T-REVIEW sits above T-READY and T-PICK in the precedence table, so after any dismiss other than Start next, Today shows T-REVIEW again on every appear.
  The only way out creates an extra block, which recreates D-25 (a new block made while a ready one waits).
  R-3 names this exact risk and closes it with the same false premise.
  The pending-review notice for a block that ended while another is active has the same problem, and `pendingReviewBlocks` returns nothing while any block is active, so that notice also needs a query the proposal does not name.
- Blast radius: Today in every state after a block ends; the ready block's START BLOCK ▸ on Today never appears; the evaluation's "Start the ready block after one ends: 4 → 1" is false; the swap path (the common way to change blocks) leaves a notice that cannot be cleared.
- Smallest fix: state that opening the review, or tapping REVIEW BLOCK ▸, writes `reviewedAt` (via `BlockReviewStatistics.acknowledge`) on any dismiss, list that as a Phase 2 change to BlockReviewView, add "review opened → T-READY" to R-3's tests, and specify the pending-review query for the active-block case.
- Evidence: `redesign/today-layouts.md:184`, `redesign/today-layouts.md:86`, `redesign/hierarchy.md:44-45`, `redesign/risks.md:10`, `redesign/evaluation.md:28`, `fitbod/Periodization/BlockReviewView.swift:349-357`, `fitbod/Periodization/BlockReviewView.swift:393`, `fitbod/Periodization/BlockReviewView.swift:635`, `fitbod/Periodization/BlockReviewView.swift:655`, `docs/design-map/audit.md:39` (D-25).
- Severity: blocks finalization.

### F-2 **T-REVIEW removes every way to start a workout from Today**

- Trigger: a block has ended, its review is pending, and the lifter is at the gym to train.
- Mechanism: T-REVIEW's hero holds REVIEW BLOCK ▸ and PLAN NEXT BLOCK ›, and its "also on the page" is only the this-week row; there is no "Start a workout instead ›" row as T-READY has.
  The signal is the review, which is not the action a lifter at the gym wants.
  Because of F-1 this state can last for days.
  Its ghost "Plan next block ›" opens the New block flow even when a ready block exists, which is D-25 again.
- Blast radius: every workout on the days between a block ending and the review being cleared; the lifter must go to Program › routine › session › Start, the unslotted path from D-19.
- Smallest fix: give T-REVIEW the same "Start a workout instead ›" ghost row as T-READY, and when a ready block exists make the ghost read "Start Summer Block ›" (or demote the review to a notice row above T-READY, as the active-block case already does).
- Evidence: `redesign/hierarchy.md:44`, `redesign/today-layouts.md:169-185`, `redesign/today-layouts.md:160`, `redesign/tradeoffs.md:17`.
- Severity: blocks finalization.

### F-3 **Every alternate start is unslotted, so doubles and swaps never move a rotation block (D-19 widened, not closed)**

- Trigger: on a rotation block the lifter finishes Push A and trains Pull A the same evening, or chooses Pull A instead of the scheduled Push A.
- Mechanism: the rotation anchor is the latest finished workout in this block with a slot; unslotted workouts are skipped.
  Today, after a finished slotted workout, the hero already shows the next session with a slotted START.
  The proposal replaces that with T-DONE (no start), and every route to a second workout goes through the session sheet, whose rows start unslotted.
  So the evening Pull A does not count, and tomorrow Today offers Pull A again; a lifter who swapped sessions is offered the skipped one again too.
  decisions.md stages D-19 "With the redesign", but the proposal parks it as O-2 with "No" as the default, and routes more starts through the unslotted path than the current build does.
  The rotation strip on Program then shows no LOGGED date for sessions trained from the sheet.
- Blast radius: rotation blocks, every double day, every swapped session, and Program's rotation strip; the wrong session is shown the next day.
- Smallest fix: make the default of O-2 "yes": a sheet row whose session is a slot of the active block's routine starts with that slot (R-5 calls it a one-line change), and on rotation T-DONE make "Start another workout ›" offer "Next up: Pull A" as its first row.
- Evidence: `redesign/open-decisions.md:9`, `redesign/today-layouts.md:273`, `redesign/hierarchy.md:48`, `redesign/tradeoffs.md:20`, `redesign/risks.md:12`, `redesign/program-layouts.md:77`, `fitbod/Periodization/TodayResolver.swift:124`, `fitbod/Views/TodayView.swift:167`, `docs/design-map/audit.md:33` (D-19), `docs/design-map/decisions.md:39`.
- Severity: blocks finalization.

### F-4 **A routine with one empty session gets a signal button that fails, and strands a rotation block**

- Trigger: the active block's routine has a session with no exercises, and the resolver schedules it (or T-PICK suggests it).
- Mechanism: the state table has no row for it, so it falls into T-TODAY with "0 EXERCISES · 0 SETS" and START WORKOUT ▸, which ends in the "Add at least one exercise" alert.
  On a rotation block the empty slot can never be completed, and the sheet's starts are unslotted (F-3), so the rotation can never pass it from Today.
  The proposal handles the empty session only inside the sheet ("does not start").
- Blast radius: T-TODAY and T-PICK on any routine with a half-built session, which is a normal state while building; evaluation.md claims every state is intentional.
- Smallest fix: add a T-FIX variant, "PUSH B HAS NO EXERCISES · Add exercises ▸ (ink) · Choose another session ›", above T-TODAY, and make T-PICK skip empty sessions.
- Evidence: `redesign/hierarchy.md:41-52`, `redesign/today-layouts.md:272`, `redesign/evaluation.md:43`, `fitbod/Views/TodayView.swift:612-613`, `fitbod/Periodization/TodayResolver.swift:124-145`.
- Severity: blocks finalization.

### F-5 **"Done for today" has two definitions**

- Trigger: the lifter trains a session from the sheet (unslotted) on a scheduled day.
- Mechanism: hierarchy.md defines T-DONE as "a workout with a slot finished today", but O-3's default is "any workout finished today, slotted or not".
  Under the first, T-TODAY offers the skipped session again right after the lifter trained; under the second, it shows DONE with "Next: Push A", which is still the session they skipped.
- Blast radius: T-DONE and T-TODAY on every swapped day; the screen_budget and the tests in R-4 cannot be written until one rule wins.
- Smallest fix: pick O-3's default in hierarchy.md and say what "Next" shows after an unslotted workout.
- Evidence: `redesign/hierarchy.md:48`, `redesign/open-decisions.md:10`, `redesign/risks.md:11`.
- Severity: fix soon.

### F-6 **The deload week shows full volume and leans on a false claim**

- Trigger: the active block is in a deload phase.
- Mechanism: the proposal drops the deload banner because "the exercise sublines already show the deload's reduced set counts", but LiftListRow and BlackSlabCTA read the template's raw `targetSets`; nothing on Today applies the phase's volume multiplier.
  The wireframe itself shows "15 SETS" in both the normal and the deload hero, beside "DELOAD WEEK · LIGHTER SETS".
  Whether the "Consider a deload" notice is suppressed during a planned deload is not specified, and I could not confirm it in `DeloadAdvisor` (unverified), so the page may say both "Deload" and "Consider a deload".
- Blast radius: T-TODAY in every deload week; the one week where the numbers matter most shows the wrong numbers with the only warning reduced to a muted caption.
- Smallest fix: either compute the hero and subline counts with the phase's `volumeMultiplier`, or keep a deload line in the hero until they do; state that the advisory notice is hidden while the phase is deload.
- Evidence: `redesign/today-layouts.md:56-64`, `redesign/hierarchy.md:63`, `fitbod/Views/LiftListRow.swift:50-56`, `fitbod/Views/BlackSlabCTA.swift:52-53`, `fitbod/Views/TodayView.swift:102-105`.
- Severity: fix soon.

### F-7 **A mis-tap in the session sheet costs more than R-12 says and changes the hero**

- Trigger: the lifter taps the wrong row in the session sheet, where rows start a workout on tap with no confirmation.
- Mechanism: R-12 and today-layouts say "a workout with no sets discards without a prompt and the logger's back returns to Today".
  The logger's ‹ only dismisses; the workout stays open, so Today flips to T-RESUME for the wrong session and the planned session disappears until the lifter taps Discard.
  Discarding with no sets otherwise goes through the Finish dialog's "Discard workout".
- Blast radius: every sheet start; at least three taps plus a wrong hero, not two.
- Smallest fix: make the sheet rows open a one-line confirm or keep START ▸ per row, or specify that leaving the logger with zero logged sets deletes the workout, and correct R-12.
- Evidence: `redesign/today-layouts.md:271`, `redesign/risks.md:19`, `redesign/tradeoffs.md:15`, `fitbod/Sessions/SessionLoggerView.swift:250`, `fitbod/Sessions/SessionLoggerView.swift:160-162`.
- Severity: fix soon.

### F-8 **Muscle volume leaves Today without the one fact that steers a session choice, and the replacement row mislabels its number**

- Trigger: mid-week, the lifter decides which session to run or whether to add a session.
- Mechanism: RP-style muscle-volume tracking is a stated pillar of the product, and the proposal reduces it on Today to "46 sets · +12 vs last week".
  That total is the stimulus-weighted sum, which is fractional, while the hero's "15 SETS" is a raw count, so one word means two numbers on one screen.
  The row says nothing about which muscles are under MEV, which is what the bars answered.
  The session sheet, where the choice is made, carries no volume cue either.
- Blast radius: T-TODAY, T-REST, T-DONE and the sheet; the analysis is one tap away but the decision cue is gone.
- Smallest fix: make the this-week row read "This week · 3 muscles under MEV ›" (or append it), and label the total "46 weighted sets" or show raw sets.
- Evidence: `redesign/hierarchy.md:23`, `redesign/hierarchy.md:30-34`, `redesign/today-layouts.md:47`, `fitbod/Fatigue/FatigueSurfaceView.swift:126`, `fitbod/Fatigue/FatigueSurfaceView.swift:209`, `CLAUDE.md` (Project: "RP-style muscle-volume tracking").
- Severity: fix soon.

### F-9 **"Most recently edited" ready block needs data the model does not have**

- Trigger: two ready blocks exist with nothing active.
- Mechanism: T-READY and P-PLANNED pick the hero block "by most recent edit", but `Block` has no modified date; its stored dates are `startDate`, `endDate` and `reviewedAt`.
  That contradicts the tradeoff "No data-model change in Phases 1 and 2".
  With two ready blocks of the same name, the hero and the Planned card read the same, and nothing tells them apart.
- Blast radius: T-READY, P-PLANNED and the claim that both tabs agree.
- Smallest fix: choose a rule the model supports (for example, the ready block whose `startDate` is soonest, or none until the lifter picks), and add the start date or week count to the Planned card subline.
- Evidence: `redesign/today-layouts.md:167`, `redesign/program-layouts.md:101`, `redesign/open-decisions.md:13`, `redesign/tradeoffs.md:43`, `fitbod/Models/Block.swift:57-95`.
- Severity: fix soon.

### F-10 **Program and Today disagree on the next action after a block ends**

- Trigger: a block has ended unreviewed and a ready block waits.
- Mechanism: Today shows T-REVIEW (REVIEW BLOCK ▸), while Program shows P-PLANNED with START BLOCK ▸; program-layouts claims "both tabs agree on the next action".
  Program shows no pending review at all.
- Blast radius: the transition between blocks, the moment the relationship between blocks matters most.
- Smallest fix: once F-1 and F-2 are fixed, make T-READY outrank T-REVIEW with the review as a notice row, so both tabs lead with START BLOCK ▸.
- Evidence: `redesign/program-layouts.md:103`, `redesign/hierarchy.md:44-45`, `redesign/hierarchy.md:95`.
- Severity: fix soon.

### F-11 **A block past its plan shows a stale week on both tabs**

- Trigger: the plan's last week has passed and the block is still active (the lifter finishes a week late, or a ready block waits).
- Mechanism: Today's plan line keeps "WEEK 6 OF 6 · PEAK" and Program's Now slab has no plan-complete treatment at all; its "12 DAYS LEFT" has no defined value past the end.
  `endDate` is nil on an active block, so "days left from the block's end date" must be derived from the phases; the proposal does not say how.
  The End block dialog copy in the proposal drops the consequence, which the confirmation rule (P-9, adopted) requires.
- Blast radius: Today's plan line, Program's Now slab and the End block dialog in every overrun.
- Smallest fix: plan line "Spring Block · Plan complete · 9 days over ›"; Now slab shows the same and the End block action; dialog body "Ends Spring Block. Its plan is saved to history and workouts stop counting toward it."
- Evidence: `redesign/today-layouts.md:85-89`, `redesign/program-layouts.md:57`, `redesign/hierarchy.md:113`, `fitbod/Models/Block.swift:59`, `fitbod/Periodization/BlockOverviewScreen.swift:148-151`, `fitbod/Periodization/BlockOverviewScreen.swift:339`, `docs/design-map/decisions.md:57`.
- Severity: fix soon.

### F-12 **Program's This week rows misreport off-plan workouts and lose the mock-up's TODAY ▸**

- Trigger: a weekday block, and a workout trained on a rest day or a session swapped from the sheet.
- Mechanism: weekday rows come from `trainingDays` and slot order, so a Tuesday workout shows as "TUE Rest" and a swapped Wednesday shows the planned session; the proposal never says how unplanned workouts appear.
  The user's own mock-up makes the TODAY row a forward action ("TODAY ▸"); the proposal makes it read-only, so P-ACTIVE has no forward action at all.
  hierarchy.md and program-layouts.md also give different example weeks (Thu Push B today vs Wed Pull A today).
- Blast radius: P-ACTIVE on every week the lifter deviates from the plan; Program loses the mock-up's one action.
- Smallest fix: list logged workouts on the day they happened, even off-plan, and keep the mock-up's TODAY ▸ row as an ink text action that starts the scheduled session.
- Evidence: `redesign/program-layouts.md:23-30`, `redesign/program-layouts.md:58`, `redesign/hierarchy.md:78`, `bru-screens/Fitbod-Session/screens/phase-2--program.png` (THU row "TODAY ▸"), `fitbod/Periodization/TodayResolver.swift:170-172`.
- Severity: fix soon.

### F-13 **P-ACTIVE still shows eleven elements above the fold, with the week told three times**

- Trigger: opening Program with an active block.
- Mechanism: the Now slab carries a label, days left, name, "Week 2 of 6 · Accumulation", "Push Pull Legs · Mon Wed Fri", six week cells and Open ›, then This week repeats the training days row by row.
  The caption, the lit cell and the plan line on Today all say the week; "MON WED FRI" repeats the day rows directly under it; the rotation head repeats the routine name.
  The proposal defers the cut to a five-second read in Phase 1, so evaluation criterion 5 is not met on paper.
  The user's mock-up does this with fewer parts: cells labelled with their phase, and one phase line.
- Blast radius: P-ACTIVE and P-RESUME, the two states most lifters see on Program.
- Smallest fix: follow the mock-up: cells carry the phase under the week number, drop the "Week 2 of 6" caption and "· MON WED FRI", and drop the routine name from the rotation head.
- Evidence: `redesign/program-layouts.md:15-21`, `redesign/program-layouts.md:71`, `redesign/risks.md:18`, `redesign/evaluation.md:51`, `redesign/screen_budget.py` output ("states over 8 elements above the fold: Program P-ACTIVE, Program P-RESUME"), `bru-screens/Fitbod-Session/screens/phase-2--program.png`.
- Severity: fix soon.

### F-14 **Notice rows: "at most two" against three, with no order**

- Trigger: a peak week with deload signals, a plan past its end, and an unreviewed earlier block.
- Mechanism: hierarchy.md caps notices at two, then adds a third; the wireframe draws all three plus the plan line above the hero, pushing START WORKOUT ▸ to roughly the fifth element, which breaks the proposal's own "two elements before the action" budget.
- Blast radius: T-TODAY in exactly the busy weeks when the lifter most needs the hero first.
- Smallest fix: cap notices at one visible row in priority order (plan complete, review, deload) with "+1 more ›", or move the review notice under the hero.
- Evidence: `redesign/hierarchy.md:19`, `redesign/hierarchy.md:61`, `redesign/today-layouts.md:71-80`.
- Severity: fix soon.

### F-15 **Lines that do not fit 390pt at default size**

- Trigger: realistic names at default text size.
- Mechanism: `labelSmall` is 11pt JetBrains Mono with 1.2 tracking, about 7.8pt per character, so 358pt holds about 44 characters before the chevron.
  "SPRING BLOCK · WEEK 6 OF 6 · INTENSIFICATION" is already 44, and the design map's own block "UPPER HYPERTROPHY" pushes it past; R-8 truncates the block name, the one identifying part.
  The this-week row is drawn as "+12 last" but specified as "+12 vs last week", which does not fit with "THIS WEEK" on one line.
- Blast radius: Today's plan line and this-week row on most real blocks.
- Smallest fix: the proposal's own dialect rules out "W6/6", so put the block name on its own line above "Week 6 of 6 · Intensification" (a two-line row, about 56pt), and write the this-week row as "2 workouts · 46 sets · ↑12" with "vs last week" in the accessibility label.
- Evidence: `redesign/today-layouts.md:15`, `redesign/today-layouts.md:35`, `redesign/today-layouts.md:47`, `redesign/risks.md:15`, `docs/design-system/typography.md:34`, `docs/design-system/iconography.md:16`.
- Severity: fix soon.

### F-16 **Copy breaks the glossary, the glyph table and P-8**

- Trigger: reading the proposal's "final" copy.
- Mechanism: T-FIRST and P-EMPTY keep "A routine is your split", the code name the glossary bans from copy.
  The session sheet closes with "×", which the glyph table reserves for "sets × reps", on the right, while P-8's adopted fix is CANCEL in the header's left slot.
  "▲" in the deload notice is not in the glyph table.
  T-PICK's label is "SUGGESTED" in hierarchy.md and "NEXT UP · PUSH PULL LEGS" in the wireframe, and hierarchy.md says T-PICK lists the other sessions inline while the wireframe uses the sheet.
  "TODAY · THURSDAY", "DONE · THURSDAY" and "REST DAY · FRIDAY" repeat the weekday the header already shows.
- Blast radius: T-FIRST, P-EMPTY, the session sheet, the deload notice and T-PICK.
- Smallest fix: "A routine bundles your sessions, like Push / Pull / Legs."; sheet header with CANCEL left; drop "▲" or use "↓"; one T-PICK label and one T-PICK layout; hero labels "TODAY", "DONE", "REST DAY".
- Evidence: `redesign/today-layouts.md:219`, `redesign/program-layouts.md:129`, `redesign/today-layouts.md:255`, `redesign/today-layouts.md:74`, `redesign/hierarchy.md:51`, `redesign/today-layouts.md:191`, `redesign/today-layouts.md:18`, `fitbod/Views/TodaySessionPicker.swift:110`, `CLAUDE.md` (Architecture glossary: "Never leak code names"), `docs/design-system/iconography.md:15`, `docs/design-map/audit.md` (P-8 fix), `docs/design-map/decisions.md:56`.
- Severity: fix soon.

### F-17 **Removed affordances that a serious lifter uses weekly are not all replaced or recorded**

- Trigger: the lifter looks for history, position in the rotation, or a session outside any routine.
- Mechanism: Today's SESSIONS cell is the documented history entry ("History opens from Today → Sessions"), and the proposal removes it without updating that baseline.
  On rotation blocks, dropping "DAY 04 / 28" with no replacement removes where the lifter is in the cycle; "NEXT UP" alone does not say "2 of 3".
  D-24 (staged with the redesign) is not closed: sessions outside a routine still cannot be started, because the sheet keeps the picker's routine grouping.
- Blast radius: Today in all block states; rotation lifters; the first-launch path the evaluation counts at 15 taps.
- Smallest fix: record the CLAUDE.md baseline change in plan.md; add "· 2 of 3" to the rotation hero label; add an "Other sessions" group to the sheet or mark D-24 as out of scope in decisions.md.
- Evidence: `CLAUDE.md:55`, `redesign/functionality-map.md:17`, `redesign/tradeoffs.md:13`, `redesign/today-layouts.md:270`, `fitbod/Views/TodaySessionPicker.swift:18`, `docs/design-map/audit.md:38` (D-24).
- Severity: fix soon.

### F-18 **The evaluation checks only seven of sixteen states and its tap counts disagree with the script**

- Trigger: reading evaluation.md as proof of criterion 1 and 2.
- Mechanism: criterion 1 lists seven states; T-RESUME, T-REVIEW, T-PICK, T-FIX, T-ATTACH, P-ROUTINE, P-PLANNED, P-RESUME and P-PAST are not checked, and T-REVIEW is the one that fails (F-2).
  "End a block whose plan is over" is "1 plus the confirmation" in evaluation.md and "3 -> 2" in screen_budget.py; "Start the ready block after one ends: 1" is false (F-1); "Reopen a finished block's review: 3" omits the tab switch.
- Blast radius: the bundle's claim of having met the brief.
- Smallest fix: one row per state in criterion 1 and one source of truth for tap counts.
- Evidence: `redesign/evaluation.md:8-16`, `redesign/evaluation.md:28-30`, `redesign/screen_budget.py` output.
- Severity: fix soon.

### F-19 **P-RESUME restyles the whole page to move the signal**

- Trigger: a workout is in progress and the lifter opens Program.
- Mechanism: the Now slab flips from ink to paper and the ACTIVE chip and any START BLOCK ▸ change kind, so the page looks different depending on an unrelated open workout, and screen_budget still counts 12 elements above the fold.
- Blast radius: P-RESUME.
- Smallest fix: keep the Now slab ink and make the resume banner a compact paper row with the signal button, so only one element changes.
- Evidence: `redesign/program-layouts.md:148-158`, `redesign/hierarchy.md:118`, `redesign/screen_budget.py` output ("hotspot: Program P-RESUME").
- Severity: fix soon.

## 3. Checked and found correct

- Dropping the day streak (it resets on any rest day: `fitbod/Views/TodayView.swift:472-501`).
- Resolver cases `.session`, `.restDay`, `.emptySplit`, `.noBlock` and their mapping to T-TODAY, T-REST, T-FIX, T-ATTACH.
- Rest days exist only in weekday mode.
- Readiness requires a name, a phase and a routine with a session (R-10).
- Week and phase are calendar-based for rotation blocks too.
- Volume moved to Progress closes D-131.
- Session sheet replaces the four orange START ▸ buttons (one signal).
- T-FIRST and P-EMPTY are routine-first (D-162).
- Past blocks list with date ranges (D-127).
- Visible Discard on the resume banner (D-56, D-57).
- BRUHeaderBar on Program.
- No new colours; dark mode by token.
- Plan line opening Block overview replaces the band, the strip and the week cells on Today.
