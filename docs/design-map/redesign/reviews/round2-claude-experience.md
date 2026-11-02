# Round 2 review: Experience lens (Claude)

Verification of draft v2 against my round-1 report, then a fresh attack on v2.
Paths starting `redesign/` are in the bundle; every other path is in the repository at 0ef702ea.
Every code claim below was checked in the current source.

## 1. Verdict

Not final as written, with two blockers.
v2 closes all four of my round-1 blockers in the leaves, and the state machine is now coherent: T-REVIEW is gone, a review clears by any route, sheet starts carry the slot, and an empty session is a fix-it state.
Two of those closures rest on premises the source does not support.
The O-2 slot rule is undefined when one session fills two slots of a routine, which the slot picker allows and the glossary's own "PPL ×2" invites, so a double or a swap can move a rotation back by three slots.
O-6 and the Planned cards treat `Block.startDate` as a planned start, but no screen sets it: on a ready block it is the save date, which `BlockLifecycleService` itself calls a "default startDate", so Program would show "PLANNED FOR" a date in the past.
Both fixes are small.
The fix-soon list is mostly leaf-to-leaf contradictions and one flow loss: tapping T-READY's START BLOCK ▸ silently removes the review notice that sits above it.

## 2. Round-1 findings, verified

| Round-1 finding | v2 status | Where |
| --- | --- | --- |
| F-1 Review hero never clears | Closed. The hero is gone; closing the review by any route writes `reviewedAt`. A new loss on the main path is N-3. | `redesign/hierarchy.md:63`, `redesign/today-layouts.md:203-204` |
| F-2 T-REVIEW removes every way to train | Closed. T-READY and T-PICK keep a way to start a workout. | `redesign/today-layouts.md:184`, `redesign/hierarchy.md:45`, `redesign/hierarchy.md:51` |
| F-3 Unslotted alternate starts | Partly closed. O-2 now defaults to "yes", but the rule is undefined for a session in two slots (N-1), and a swap skips a slot silently (N-4). | `redesign/open-decisions.md:10`, `redesign/today-layouts.md:313` |
| F-4 Empty session gets a failing signal | Closed. | `redesign/hierarchy.md:47`, `redesign/today-layouts.md:271-281`, `redesign/today-layouts.md:231`, `redesign/today-layouts.md:314` |
| F-5 Two definitions of done | Closed. | `redesign/hierarchy.md:46`, `redesign/hierarchy.md:54`, `redesign/open-decisions.md:11` |
| F-6 Deload shows full volume | Closed, apart from a duration nit (N-6). | `redesign/hierarchy.md:68`, `redesign/today-layouts.md:61-71`, `redesign/plan.md:18` |
| F-7 Mis-tap cost | Closed. With no sets logged, Discard asks nothing, so the cost is two taps. | `redesign/today-layouts.md:315`, `fitbod/Views/ResumeWorkoutSlab.swift:46` |
| F-8 Volume cue and mislabelled count | Count closed (raw counts); the muscle cue is accepted with a reason, and the reason holds. | `redesign/today-layouts.md:48`, `redesign/review-log.md:80` |
| F-9 "Most recently edited" needs absent data | Partly closed. The replacement field does not mean what the bundle says (N-2). | `redesign/open-decisions.md:14`, `redesign/program-layouts.md:35`, `redesign/program-layouts.md:92` |
| F-10 Tabs disagree after a block ends | Closed. | `redesign/program-layouts.md:109`, `redesign/hierarchy.md:45` |
| F-11 Stale week past the plan | Closed. | `redesign/today-layouts.md:93-104`, `redesign/program-layouts.md:212` |
| F-12 This week misreports, lost TODAY ▸ | Closed. | `redesign/program-layouts.md:23-28`, `redesign/program-layouts.md:58` |
| F-13 P-ACTIVE density | Closed: eight elements. | `redesign/program-layouts.md:57`, `redesign/program-layouts.md:64-65` |
| F-14 Notice count | Closed in the rule, but the leaves disagree on where the one notice shows (N-5). | `redesign/hierarchy.md:19` |
| F-15 390pt fit | Closed for the plan line and the this-week row; the review notice is unspecified (N-7). | `redesign/today-layouts.md:15-16`, `redesign/today-layouts.md:43`, `redesign/today-layouts.md:36` |
| F-16 Copy, glyphs, P-8 | Mostly closed: CANCEL is on the left, "▲" is gone, labels are unified. "×" survives on the advisory row (N-7); "split" is accepted. | `redesign/today-layouts.md:294`, `redesign/today-layouts.md:82` |
| F-17 Removed affordances | Closed. | `redesign/plan.md:17` (CLAUDE.md line), `redesign/today-layouts.md:59`, `redesign/today-layouts.md:306` |
| F-18 Evaluation coverage | Closed: one row per state, counts quoted from the script. | `redesign/evaluation.md:11-27` |
| F-19 P-RESUME restyles the page | Closed in program-layouts.md, contradicted in hierarchy.md (N-5). | `redesign/program-layouts.md:156-168` |

I found no closure claimed in `review-log.md` that is absent from the leaves.
Two claims overstate: B-3's "same-name blocks read apart" (N-2) and B-2's "a double or a swap moves a rotation block" (N-1, N-4).

## 3. Findings on draft v2, worst first

### N-1 **The O-2 slot rule is undefined when a session fills two slots, so a rotation can jump backwards**

- Trigger: a rotation routine that reuses a session, such as PPL ×2 built as Push A, Pull A, Legs A, Push A, Pull A, Legs A; the lifter is at slot 3 and trains Push A from the sheet, as a double or a swap.
- Mechanism: the slot picker lists every unarchived session, including ones already in the routine, so one SessionTemplate can sit in two slots (`SplitDetailView.swift:780`, `:815-817`).
  The sheet inherits the picker's grouping, which lists sessions in slot order (`TodaySessionPicker.swift:37-42`), so Push A appears twice.
  v2 says a row "whose session is a slot of the active block's routine starts with that slot" without saying which slot.
  If the first Push A row passes slot 0, the resolver's anchor becomes slot 0 and tomorrow's session is Pull A at slot 1, which repeats half the cycle (`TodayResolver.swift:124-140`).
  Only one row carries the "NEXT" tag, so the lifter has no cue telling the two Push A rows apart.
- Blast radius: every double and swap on a routine that reuses sessions; the wrong session appears the next day, and Program's rotation strip shows the wrong LOGGED dates.
  This is the shape the CLAUDE.md glossary uses as its example routine.
- Smallest fix: the sheet lists slots, not sessions, and each row passes its own slot; when one session fills several slots, show it once, passing the first of its slots at or after the resolver's next slot (wrapping).
  Add one `TodayStateTests` case for a session in two slots.
- Evidence: `redesign/today-layouts.md:297-313`, `redesign/open-decisions.md:10`, `fitbod/Periodization/SplitDetailView.swift:780`, `fitbod/Views/TodaySessionPicker.swift:37-42`, `fitbod/Periodization/TodayResolver.swift:124-140`, `CLAUDE.md` (glossary: "PPL ×2").
- Severity: blocks finalization.

### N-2 **"Starts Jun 30" and "PLANNED FOR JUN 30" show a date nobody planned**

- Trigger: any ready block on Program, and the choice of which ready block takes Today's START BLOCK ▸.
- Mechanism: no screen edits `startDate`; the builder has no date control, a draft is created with `startDate = .now`, and saving writes that value back (`BlockDraft.swift:19`, `:151`).
  `BlockLifecycleService.start` overwrites it with the start time (`BlockLifecycleService.swift:101`), and that file's own comment calls a never-started block's value a "default startDate" (`:39`).
  On a ready block saved on Oct 3 and viewed on Nov 1, the P-PLANNED slab reads "PLANNED FOR OCT 3", a date in the past.
  O-6's "earliest planned start" is therefore "oldest saved", and two same-name blocks saved the same day still read alike.
- Blast radius: the P-PLANNED hero, every Planned card, Today's T-READY choice, and the B-3 claim that same-name blocks read apart.
- Smallest fix: drop "Starts" and "PLANNED FOR", and show "Saved Oct 3" muted; keep O-6's ordering but describe it as "oldest saved, then name".
  A real planned start is a schema change and belongs in open-decisions.md.
- Evidence: `redesign/program-layouts.md:35`, `redesign/program-layouts.md:59`, `redesign/program-layouts.md:92`, `redesign/hierarchy.md:86`, `redesign/open-decisions.md:14`, `redesign/review-log.md:42`, `fitbod/Periodization/BlockDraft.swift:19`, `fitbod/Periodization/BlockDraft.swift:151`, `fitbod/Periodization/BlockLifecycleService.swift:39`, `fitbod/Periodization/BlockLifecycleService.swift:101`.
- Severity: blocks finalization.

### N-3 **Tapping START BLOCK ▸ makes the review notice above it disappear for good**

- Trigger: the day after a block ends, a ready block waits; T-READY shows "Summer Block finished · Review ›" above START BLOCK ▸, and the lifter taps the signal.
- Mechanism: the review notice is fed by `pendingReviewBlocks`, which returns nothing once any block is active (`BlockReviewView.swift:635`).
  The signal button therefore ends the review's visibility, and after that the review is reachable only in four taps through Past blocks.
  Today's build shows the review sheet first in this exact case.
  Ending one block and starting the next is the most common transition, so O-5's "price" lands on the main path, not an edge case.
  evaluation.md lists "Open the review right after a block ends: 1" without saying that the signal on the same screen removes it.
- Blast radius: the block review, the app's block-level analysis (brief criterion 3), for nearly every block that is followed by a planned one.
- Smallest fix: keep the notice until the review is opened or dismissed with ×, even while the next block is active, for the latest-ended block only.
  That is O-5's "other way" plus a dismiss, and it changes the `pendingReviewBlocks` contract and `BlockReviewTriggerTests`.
  The cheaper option is to make START BLOCK ▸ on T-READY open the review first when one is pending, which needs no query change.
- Evidence: `redesign/today-layouts.md:173-189`, `redesign/hierarchy.md:65`, `redesign/open-decisions.md:13`, `redesign/evaluation.md:43`, `redesign/evaluation.md:71`, `fitbod/Periodization/BlockReviewView.swift:635`, `fitbod/Views/TodayView.swift:375`.
- Severity: fix soon.

### N-4 **A swap in a rotation silently skips the session it replaced**

- Trigger: a rotation block schedules Push A (slot 0), and the lifter trains Pull A (slot 1) instead because the bench is taken.
- Mechanism: under O-2 the sheet starts Pull A with slot 1, the anchor moves to slot 1, and the resolver returns Legs A next; Push A drops out of this cycle.
  The lifter only sees it afterwards, in T-DONE's "NEXT UP: LEGS A"; the sheet row gave no warning.
  This is coherent rotation semantics, but the proposal calls swaps safe without saying it.
- Blast radius: rotation blocks, every out-of-order day; muscle groups are skipped for a whole cycle.
- Smallest fix: give sheet rows of the active routine that are not NEXT a muted subline, "Skips Push A", and state the behaviour in O-2.
- Evidence: `redesign/open-decisions.md:10`, `redesign/today-layouts.md:299`, `redesign/today-layouts.md:313`, `fitbod/Periodization/TodayResolver.swift:133-140`.
- Severity: fix soon.

### N-5 **The leaves contradict each other on the notice, P-RESUME, the ACTIVE chip and the Phase 1 Program**

- Trigger: building any of these states from the leaves.
- Mechanism:
  - hierarchy.md says "The notice row is independent of the hero", but the state table and today-layouts.md show the review notice only on T-READY, T-PICK and T-FIRST, and T-RESUME has "No notice row".
    The result is that on T-DONE without a block (a block ended after today's workout, with no ready block), `pendingReviewBlocks` returns a block and no notice shows until tomorrow.
  - hierarchy.md says the resume banner changes nothing else on Program, while program-layouts.md turns START BLOCK ▸ into an ink button, hides TODAY ▸ and shows "IN PROGRESS", and hierarchy.md itself turns the ACTIVE chip ink.
  - hierarchy.md defines the ACTIVE chip as "filled signal", but no v2 wireframe draws an ACTIVE chip, and program-layouts.md says P-ACTIVE has nothing orange.
  - evaluation.md gives P-ACTIVE the next action "TODAY ▸ in This week", but This week is Phase 2, so the Phase 1 P-ACTIVE has no forward action at all.
  - hierarchy.md defines T-DONE's rotation next line as "the slot after the finished one", which is undefined after a workout from "Other sessions"; the resolver's next slot is the correct source, as O-3 says.
- Blast radius: T-DONE, T-RESUME, P-RESUME and P-ACTIVE in Phase 1; `TodayStateTests` cannot be written from leaves that disagree.
- Smallest fix: in hierarchy.md, say "the review notice shows on every state without an active block except T-RESUME", and add it to T-DONE's row.
  Reword P-RESUME as "the banner takes the signal; START BLOCK ▸ goes ink and TODAY ▸ reads IN PROGRESS".
  Delete the ACTIVE-chip sentence or name where the chip appears.
  Mark P-ACTIVE's TODAY ▸ "Phase 2" in evaluation.md.
  Say "the resolver's next slot" in hierarchy.md:55.
- Evidence: `redesign/hierarchy.md:40`, `redesign/hierarchy.md:46`, `redesign/hierarchy.md:55`, `redesign/hierarchy.md:83`, `redesign/hierarchy.md:125-126`, `redesign/today-layouts.md:125`, `redesign/today-layouts.md:198`, `redesign/program-layouts.md:58`, `redesign/program-layouts.md:65`, `redesign/program-layouts.md:166-168`, `redesign/evaluation.md:25`, `redesign/open-decisions.md:11`.
- Severity: fix soon.

### N-6 **T-READY outranks T-DONE and T-PICK every day a ready block waits**

- Trigger: no active block, a ready block saved for later, and the lifter keeps training without a block until a chosen day.
- Mechanism: T-READY wins whenever a ready block exists, so START BLOCK ▸ is the signal every day.
  The suggested session sits behind "Start a workout instead ›" (two taps instead of one), and after a workout T-DONE never shows.
  Because there is no planned start date (N-2), the app cannot tell "start now" from "start next Monday".
- Blast radius: Today for as long as a ready block waits; a lifter may start the block early by accident just to clear the screen.
- Smallest fix: on a day with a finished workout, let T-DONE outrank T-READY, with "Start Summer Block ›" as its ghost.
  Otherwise, state the cost in tradeoffs.md and accept it.
- Evidence: `redesign/hierarchy.md:45-46`, `redesign/hierarchy.md:56`, `redesign/today-layouts.md:184`.
- Severity: fix soon.

### N-7 **Copy and fit details**

- Trigger: reading the final copy.
- Mechanism:
  - The advisory row keeps "×" for dismiss, which the glyph table reserves for "times"; the current banner draws "✕", which the table does not list either.
  - The review notice puts the block name and "FINISHED" on one 11pt mono line with "REVIEW ›", with no truncation rule; a 25-character name overflows 358pt.
  - The deload wireframe shows "~20 MIN" for 5 sets, but the hero's formula, `setCount * 3 + 2`, gives about 17.
- Blast radius: the advisory row, T-READY, T-PICK and T-FIRST with a long block name, and the deload hero.
- Smallest fix: "DISMISS" as a text button with `.bruHitArea()`, or add a close glyph to the table; give the name `lineLimit(1)` with tail truncation and keep "REVIEW ›" whole; write "~17 MIN".
- Evidence: `redesign/today-layouts.md:82`, `redesign/hierarchy.md:62`, `redesign/today-layouts.md:198`, `redesign/today-layouts.md:61`, `docs/design-system/iconography.md:15`, `fitbod/Fatigue/DeloadAdvisoryBanner.swift:80`, `fitbod/Views/BlackSlabCTA.swift:58`, `docs/design-system/typography.md:34`.
- Severity: fix soon.

## 4. Walks requested by the brief

- The day after a block ends, with a ready block waiting: T-READY with the review notice and START BLOCK ▸; correct, apart from N-3.
  With no ready block: T-PICK with the notice and the suggestion, which is correct.
- A rest day with a ready block waiting: a rest day exists only under an active block, so Today shows T-REST and the ready block stays on Program; that is correct.
  With no active block there are no rest days, and T-READY applies (N-6).
- A finished workout followed by a second session: T-DONE, then "Start another workout ›", and the sheet marks the resolver's next slot NEXT; tapping it starts with that slot and the rotation moves one slot, which is correct.
  It breaks only for repeated sessions (N-1) and out-of-order picks (N-4).
- One-notice rule: it holds, because the deload notice needs an active block and the review notice needs none.
  The review is not reachable on T-DONE without a block or on T-RESUME (N-5), and it vanishes on START BLOCK ▸ (N-3).
- 390pt: the two-line plan line ("WEEK 12 OF 12 · INTENSIFICATION" is 31 characters, about 242pt) and "THIS WEEK · 2 workouts · 20 sets" fit; the review notice does not have a rule (N-7).
- Glossary: no "Split" or "SessionTemplate" appears in copy except the accepted gym word "split".
  "workout", "session", "routine" and "block" are used as the glossary defines them.

## 5. Accepted-with-reason items

- "A routine is your split" holds: "split" is the gym word, and the glossary bans the code name.
  The user's brief says "never Split", so the user should confirm it, but I would not block on it.
- The this-week row without a muscle cue holds: early in the week most muscles are under MEV, and Volume is one tap away.
- P-RESUME over budget holds, because the banner is transient.
- No drafts on Today holds.
- Older unreviewed blocks reachable only from Past blocks holds for legacy stores, but N-3 shows the same limit hitting the main path, which the acceptance does not cover.
- "CREATE BLOCK" under "+ New block" holds.

## 6. Checked and found correct

- Review cleared by any route via `acknowledge`.
- T-REVIEW removal and T-READY leading on both tabs.
- Raw this-week counts in a `.task(id:)`.
- Deload counts through one helper shared with `SessionFactory`, and the advisory hidden in a deload phase.
- T-FIX empty-session variant; T-PICK and the sheet skipping empty sessions.
- T-DONE on `startedAt` with the environment calendar.
- T-PICK slot without a block ignored by later blocks (`SessionFactory.swift:153` sets `block` from the active block; the anchor filters by block).
- Mis-tap cost of two taps.
- The two-line plan line and its 390pt fit.
- CANCEL in the sheet's left slot (P-8).
- The CLAUDE.md history baseline update in step 1.1.
- P-ACTIVE at eight elements; one example week across the leaves.
- End block dialog naming the consequence (P-9).
- T-ATTACH leading to END BLOCK.
