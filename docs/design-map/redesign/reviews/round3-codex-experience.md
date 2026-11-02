# Round 3 Codex experience review

## Verdict

Not final as written: four blockers remain in workout selection, Program's action states, and the representation of a second workout on the same day.
The completed paper review also records ten fix-soon findings and the verification limits under Not reached.
The review is of the proposal, not a running implementation, and no build or tests have been run.
Proposal citations below use `docs/design-map/redesign/` as their root and repository citations use the repository root.

## Blockers, ranked by blast radius

### **B3-1. The sheet's NEXT rule is undefined on rest days and disagrees with DONE on fixed-weekly days**

**Trigger:** A fixed-weekly block is on a rest day, or the lifter finishes Thursday's scheduled Push A and opens Start another workout.
**Mechanism:** The sheet chooses and marks the resolver's next slot, but the unchanged fixed-weekly resolver returns `.restDay` on a rest day and returns Thursday's Push A again after it is finished, whereas T-DONE names Saturday's Pull A as next.
**Blast radius:** T-REST and fixed-weekly T-DONE lose a consistent recommendation precisely when the lifter takes their alternate-start action, failing criteria 1, 2 and 4.
**Smallest fix:** Specify the sheet anchor separately for each scheduling mode: use the rotation resolver for rotation, and resolve the next eligible training date for fixed-weekly after completion or on a rest day, with an explicit slot-selection rule for repeated templates.
**Evidence:** `today-layouts.md:138`, `today-layouts.md:171`, `today-layouts.md:322`, `today-layouts.md:325`, `hierarchy.md:55`, `fitbod/Periodization/TodayResolver.swift:168`, `fitbod/Periodization/TodayResolver.swift:170`, `fitbod/Periodization/TodayResolver.swift:178`.
**Severity:** blocks finalization.

### **B3-2. Program's new start controls do not inherit the workout and repair guards**

**Trigger:** A rotation workout is already open when the lifter visits Program, the scheduled session is empty, an off-plan Arms workout is open while Push A is scheduled today, or a standalone workout is open over P-EMPTY or P-ROUTINE.
**Mechanism:** P-RESUME hides only TODAY ▸, leaving the rotation NEXT ▸ action unspecified, and the weekday rule marks the planned row IN PROGRESS without checking which workout is open.
The Program start rules also omit the empty-session repair condition that now correctly replaces Today's Start button.
P-RESUME is defined over any Program state, but only START BLOCK is demoted, leaving the signal New routine and New block controls of other underlying states without a demotion rule.
**Blast radius:** P-RESUME and P-ACTIVE can advertise a different workout while one is open, label an unstarted session as in progress, or offer a start that cannot succeed, failing criteria 1, 2 and 4.
The existing starter rejects concurrent workouts, so this is a misleading action and state problem rather than a verified duplicate-workout data-loss claim.
**Smallest fix:** Apply one eligibility rule to TODAY ▸ and NEXT ▸, identify the actual open workout in the row, replace an empty scheduled session's start with the same repair route used by T-FIX, and demote every underlying creation CTA while Resume owns the signal.
**Evidence:** `program-layouts.md:58`, `program-layouts.md:75`, `program-layouts.md:80`, `program-layouts.md:165`, `program-layouts.md:166`, `program-layouts.md:167`, `hierarchy.md:47`, `hierarchy.md:85`, `hierarchy.md:102`, `hierarchy.md:103`, `hierarchy.md:106`, `fitbod/Routines/WorkoutStarter.swift:35`, `fitbod/Routines/WorkoutStarter.swift:47`.
**Severity:** blocks finalization.

### **B3-3. The second workout's row and destination are unspecified**

**Trigger:** The lifter completes Push A and then a second workout on Thursday, using T-DONE's Start another workout.
**Mechanism:** Program specifies seven rows, each with one workout name, duration and direct workout destination, but also promises to list logged workouts on the day they happened.
It never chooses between multiple workout rows within a day and an aggregate row with a picker, nor says which workout T-DONE opens after the second finish.
**Blast radius:** P-ACTIVE's weekly history and T-DONE can hide one of the day's workouts or open an unspecified one, failing criteria 3 and 4.
**Smallest fix:** Keep seven day groups with one child row per counted workout, and define T-DONE as the most recently completed eligible workout with an explicit route to the day's other workouts.
**Evidence:** `program-layouts.md:23`, `program-layouts.md:24`, `program-layouts.md:58`, `today-layouts.md:141`, `today-layouts.md:147`, `hierarchy.md:45`, `hierarchy.md:87`.
**Severity:** blocks finalization.

### **B3-4. Previewing a session before starting still loses the rotation slot**

**Trigger:** A rotation lifter taps the new Exercises → View link, checks the prescription, and taps Start workout in Session detail.
**Mechanism:** The new View route opens the existing SessionTemplateDetailView, whose Start still calls WorkoutStarter without a slot, while the revised sheet and hero preserve slots.
The resolver ignores that finished workout as an anchor, so the same planned session is offered again even though the plan declares D-19 closed.
**Blast radius:** T-TODAY, T-PICK and the empty-session repair route retain two different scheduling outcomes for starting the same session, failing criteria 1 and 2.
**Smallest fix:** Carry the chosen slot through Session detail when opened from a scheduled or suggested session, and use the same slot-selection policy for Program's preview-and-start route.
**Evidence:** `today-layouts.md:45`, `today-layouts.md:236`, `today-layouts.md:286`, `functionality-map.md:40`, `plan.md:52`, `fitbod/Routines/SessionTemplateDetailView.swift:210`, `fitbod/Routines/SessionTemplateDetailView.swift:211`, `fitbod/Periodization/TodayResolver.swift:124`.
**Severity:** blocks finalization.

## Fix soon, ranked by blast radius

### **F3-1. T-FIRST conflates a fresh store with unfinished routines and experienced standalone-session users**

**Trigger:** A saved routine contains only an empty session, or a returning lifter keeps all usable sessions outside routines.
**Mechanism:** Both cases satisfy T-FIRST's no-usable-routine condition, so BUILD YOUR FIRST ROUTINE and + NEW ROUTINE dominate even when the right next action is repairing an existing session or starting an existing one.
The standalone-session ghost repairs reachability but leaves the five-second answer wrong.
**Blast radius:** T-FIRST and P-ROUTINE misdirect interrupted setup and routine-free training, failing criteria 1, 4 and 5.
**Smallest fix:** Distinguish a genuinely empty store, an existing incomplete routine, and usable standalone sessions, promoting Continue routine, Add exercises, or Choose a session as appropriate.
**Evidence:** `hierarchy.md:51`, `hierarchy.md:52`, `hierarchy.md:103`, `today-layouts.md:248`, `today-layouts.md:253`, `today-layouts.md:255`, `functionality-map.md:42`.
**Severity:** fix soon.

### **F3-2. Oldest saved is a reproducible order, but not evidence of the next training block**

**Trigger:** The lifter saves a later specialization block before a nearer base block, saves two blocks with the same name and visible metadata on the same day, or revisits same-name annual blocks with identical month/day ranges.
**Mechanism:** O-6 promotes creation order as the next action, and a Saved Oct 3 caption cannot distinguish same-day alternatives.
The selected slab omits even that date, while ties by name leave identical timestamps and names without a final tie-break rule.
Saved also suggests the latest save, but the stored value originates when the draft is created, is copied back when editing, and is not refreshed on later saves.
**Blast radius:** T-READY and P-PLANNED can emphasize the wrong intended block and make alternatives difficult to identify, while Past blocks omits the year needed for some repeated annual plans, failing criteria 1 and 4.
**Smallest fix:** When several ready blocks exist, make choosing the block explicit or provide a visible change-selection route beside the proposed block, give every candidate including the selected slab a distinguishing identifier or sufficiently precise date, and label the timestamp as creation rather than implying a recent save.
No planned-start schema change is needed merely to avoid presenting an arbitrary order as the lifter's intent.
Include the year when Past blocks would otherwise show indistinguishable date ranges.
**Evidence:** `open-decisions.md:14`, `open-decisions.md:22`, `today-layouts.md:181`, `today-layouts.md:195`, `program-layouts.md:35`, `program-layouts.md:90`, `program-layouts.md:104`, `program-layouts.md:177`, `program-layouts.md:184`, `fitbod/Periodization/BlockDraft.swift:19`, `fitbod/Periodization/BlockDraft.swift:80`, `fitbod/Periodization/BlockDraft.swift:151`.
**Severity:** fix soon.

### **F3-3. Other sessions can be started but have no specified preview or repair route**

**Trigger:** The lifter wants to inspect or edit a session in the sheet's Other sessions group, or that session has no exercises.
**Mechanism:** Rows now start immediately, empty rows do nothing, and the replacement detail route is Program → routine → session, which does not exist for a session belonging to no live routine.
**Blast radius:** The new standalone-session path covers starting but not choosing safely or repairing the saved session, failing criteria 2 and 4.
**Smallest fix:** Retain an explicit detail/edit affordance for Other sessions, and let empty rows open that repair route instead of becoming inert.
**Evidence:** `today-layouts.md:320`, `today-layouts.md:321`, `today-layouts.md:326`, `today-layouts.md:328`, `functionality-map.md:40`, `functionality-map.md:41`.
**Severity:** fix soon.

### **F3-4. The evaluation claims improvements that its paths do not support**

**Trigger:** A lifter trains on a fixed-weekly rest day, or ends a block after finishing its final workout with a ready block waiting.
**Mechanism:** The evaluation says rest-day starts improve from four taps to two, but current Today already renders the inline picker whenever no session is scheduled, with a direct Start button.
The one-tap claim for starting the ready block after an ending also needs a qualification because T-DONE now takes Today and the start is on Program.
Previewing a non-hero routine session on a rest or no-block day goes from the current inline row's one tap to Program → routine → session, three taps from Today, but that daily selection job is absent from the two-tap claim.
The evaluation also says recaps stay on Progress while the plan explicitly leaves the approved recap history screen unbuilt by this bundle.
**Blast radius:** The review understates an everyday extra tap and the common end-of-block path, weakening criterion 2's claimed verification.
**Smallest fix:** Record the rest-day path as one tap to two, count the Program tab switch when T-DONE wins, include preview-before-start in the job table, and mark recap history as a separate approved dependency rather than an existing replacement.
**Evidence:** `evaluation.md:40`, `evaluation.md:42`, `evaluation.md:49`, `evaluation.md:56`, `hierarchy.md:56`, `today-layouts.md:197`, `today-layouts.md:328`, `plan.md:54`, `fitbod/Views/TodayView.swift:194`, `fitbod/Views/TodaySessionPicker.swift:78`, `fitbod/Views/TodaySessionPicker.swift:96`.
**Severity:** fix soon.

### **F3-5. Several leaves still give incompatible labels, examples and confirmation rules**

**Trigger:** An implementer follows the state table, wireframe and functionality map for the same case.
**Mechanism:** T-READY names Spring Block while P-PLANNED names Summer Block despite claiming the same choice; T-PICK retains a 3 work subline while the new universal subline rule requires sets × rep range; Program's map preserves an always-confirming discard while its layout adopts Today's conditional confirmation.
T-FIRST also says nothing else and calls its ghost the one exception while the global review rule adds a pending-review notice.
The new untrained-muscles row uses a detail chevron for an in-place expansion, contrary to the glyph table's expand/collapse marks.
Additional conflicts around creation scope, review tap counts, ready-card actions, budget claims and review origin are enumerated in the leaf cross-check below.
**Blast radius:** The promised shared vocabulary and state behavior can diverge between the two tabs, failing criteria 1 and 4.
**Smallest fix:** Use one fixture for the ready-block pair, update the T-PICK example, make the discard rule explicit in both leaves, state T-FIRST's review-notice exception, and use ▾/▴ for the expanding muscle row.
**Evidence:** `today-layouts.md:181` versus `program-layouts.md:90` and `program-layouts.md:108`; `today-layouts.md:226` versus `today-layouts.md:46` and `functionality-map.md:29`; `functionality-map.md:66` versus `program-layouts.md:164` and `hierarchy.md:44`; `today-layouts.md:259` versus `today-layouts.md:206`; `today-layouts.md:336` versus `docs/design-system/iconography.md:11` and `docs/design-system/iconography.md:19`.
**Severity:** fix soon.

### **F3-6. Draft-only Program has no defined primary task**

**Trigger:** The lifter has saved an incomplete block, with no active or ready block.
**Mechanism:** P-PLANNED includes draft-only data but defines its signal and first slab entirely through a ready block that does not exist.
Naming the missing piece on a card helps diagnosis without specifying the draft-only hierarchy or the next action, and the evaluation verifies only the ready variant.
**Blast radius:** Interrupted block setup has an unverified five-second answer and empty-state hierarchy, failing criteria 1 and 4.
**Smallest fix:** Add a P-PLANNED draft-only variant that makes Continue block the explicit next action and names the missing routine, session or phase beneath it.
**Evidence:** `hierarchy.md:104`, `program-layouts.md:83`, `program-layouts.md:96`, `program-layouts.md:104`, `evaluation.md:24`, `evaluation.md:61`.
**Severity:** fix soon.

### **F3-7. The no-block sheet advances the same cycle without the skip disclosure**

**Trigger:** With no block, a PPL ×2 lifter finishes Push A, sees Pull A suggested, then chooses Push A again for a second workout.
**Mechanism:** The two-slot rule selects the next occurrence of Push A and moves the suggestion beyond the intervening Pull A and Legs A slots, but the skips subline is restricted to rotation blocks.
**Blast radius:** T-PICK and no-block T-DONE can move their next-session recommendation past unperformed sessions without telling the lifter, failing criteria 1 and 2.
**Smallest fix:** Show the same skip disclosure whenever a sheet selection advances the suggestion across intervening slots, including no-block starts, and explicitly include NEXT but exclude the chosen slot from the displayed range.
**Evidence:** `today-layouts.md:234`, `today-layouts.md:323`, `today-layouts.md:325`, `open-decisions.md:10`.
**Severity:** fix soon.

### **F3-8. The skip warning has no safe wrapping contract**

**Trigger:** A session sheet row names two longer skipped sessions, or the lifter increases text size.
**Mechanism:** The example subline already uses about 342pt of the nominal 358pt width at labelSmall, before any extra row inset, and the sheet has no rule preserving the warning through wrapping or truncation.
Because tapping immediately starts the selected workout, losing the end of this line loses the only advance warning of skipped slots.
The large-text plan-line rule also needs to override the earlier fixed 56pt height, rather than placing a two-line name and the position inside it.
**Blast radius:** Sheet choices with real session names lack a verified readable consequence, and large-text plan rows have an unresolved height contract, affecting criteria 2 and 5.
Rendered clipping is unverified; the default short example is not proven to overflow.
**Smallest fix:** Make row heights content-driven with a 44pt minimum, allow the skip warning to wrap in full, and state that 56pt is only the plan line's default-size minimum.
**Evidence:** `today-layouts.md:3`, `today-layouts.md:43`, `today-layouts.md:307`, `today-layouts.md:325`, `today-layouts.md:341`, `today-layouts.md:345`, `docs/design-system/typography.md:34`, `docs/design-system/interaction.md:7`.
**Severity:** fix soon.

### **F3-9. The one-tap Volume entry does not name its destination**

**Trigger:** A lifter previously used Today's muscle bars to choose an additional session and now looks for that analysis.
**Mechanism:** The bars move behind a row labeled THIS WEEK with workout and set counts, so the only Today entry does not say Volume or muscles and can equally suggest a weekly workout list.
**Blast radius:** T-TODAY, T-DONE and T-PICK retain technical reachability but do not establish discoverability of detailed training analysis, leaving criterion 3 unproven.
Actual user confusion is unverified because no usability study or running prototype was evaluated.
**Smallest fix:** Name the destination in the existing row, for example WEEKLY VOLUME, while retaining its counts and chevron.
**Evidence:** `today-layouts.md:48`, `today-layouts.md:332`, `today-layouts.md:335`, `evaluation.md:53`, `functionality-map.md:47`.
**Severity:** fix soon.

### **F3-10. The stat-strip removal overstates the case against the existing readouts**

**Trigger:** A returning lifter looks for their day streak or all-time workout count after the redesign.
**Mechanism:** The streak is deleted everywhere on the claim that it resets on every rest day, but the implementation accepts yesterday as the start of a live streak and can preserve a run of consecutive training days.
The capability map replaces the all-time count's history link without specifying where its numeric readout now lives.
**Blast radius:** Frequent users lose established progress readouts without a verified replacement or a sound universal argument that they lack value, weakening criterion 5's removal rationale.
Whether another existing screen already exposes the same all-time readout is unverified in this review.
**Smallest fix:** Correct the streak description and explicitly either retain the existing readouts on Progress or record their removal as a product tradeoff, with the all-time number's destination named if it remains.
**Evidence:** `tradeoffs.md:14`, `open-decisions.md:9`, `functionality-map.md:19`, `functionality-map.md:20`, `fitbod/Views/TodayView.swift:490`, `fitbod/Views/TodayView.swift:492`, `bru-screens/today.jsx:12`, `bru-screens/today.jsx:15`.
**Severity:** fix soon.

## Ten closure claims checked

These are closure judgments about the written design, not assertions that unbuilt behavior or unrun tests pass.

| Claim in review-log | Does v3 close it? | Leaf evidence and remaining defect |
| --- | --- | --- |
| B-1, review blocks the next action (`review-log.md:107`) | Yes, with the stated visibility limitation. | The notice replaces the hero, clears on every dismissal, and covers T-DONE too at `today-layouts.md:206` and `today-layouts.md:210`; `hierarchy.md:66` explicitly accepts hiding it when a new block starts. |
| B-2, alternate starts and done semantics (`review-log.md:108`) | Partly. | The hero and sheet carry slots at `today-layouts.md:236` and `today-layouts.md:322`, and the done predicate is unified at `hierarchy.md:45`; preview-then-start still loses the slot in B3-4, and fixed-weekly NEXT remains undefined in B3-1. |
| B-3, ordering depends on nonexistent timestamps (`review-log.md:109`) | The schema problem is closed; the claimed identity improvement is not. | `today-layouts.md:195` uses stored `startDate`, and `today-layouts.md:235` uses `SessionTemplate.updatedAt`; same-name alternatives and inferred intent remain F3-2. |
| B-4, an empty scheduled session offers a failing Start (`review-log.md:110`) | Closed on Today, incomplete across the redesign. | T-FIX and the sheet's disabled empty rows are explicit at `hierarchy.md:47` and `today-layouts.md:326`; Program's new starts do not inherit that repair rule, as B3-2 records. |
| B-5, creation flow and test contract disrupted (`review-log.md:111`) | Closed at the proposal level. | `program-layouts.md:200` keeps CREATE BLOCK and the sheets in Program; `plan.md:17` names the replacement loaded identifier and affected suites, and `plan.md:21` preserves the card accessibility labels; runtime and suite completeness are unverified because no tests were run. |
| B2-1, a repeated session chooses the wrong rotation slot (`review-log.md:37`) | Closed for the sheet's rotation anchor. | `today-layouts.md:322` chooses NEXT when it matches, otherwise the first matching slot forward with wrapping; the remaining preview route is B3-4, and the rule's fixed-weekly application is B3-1. |
| B2-2, a save date is presented as a planned start (`review-log.md:38`) | The false planned-start claim is removed; identity and priority are only partly closed. | `program-layouts.md:35` says Saved and `program-layouts.md:104` names oldest-saved ordering; dropping the date from the selected slab at `program-layouts.md:89` weakens comparison, as F3-2 records. |
| F-5, weekly rows misreport off-plan workouts (`review-log.md:121`) | Partly. | `program-layouts.md:58` includes off-plan logs and makes TODAY actionable, but two workouts on one day and an off-plan open workout remain unspecified or mislabeled in B3-3 and B3-2. |
| F2-8, a ready block hides today's finished workout (`review-log.md:51`) | Yes. | `hierarchy.md:45` precedes `hierarchy.md:46`, and `today-layouts.md:197` names the Program fallback; the evaluation's tap count still needs F3-4. |
| F2-12, standalone sessions are unreachable (`review-log.md:55`) | Start reachability is closed; the entire job is not. | `today-layouts.md:255` exposes the sheet and `today-layouts.md:320` includes Other sessions; inappropriate primary emphasis and missing preview or repair remain F3-1 and F3-3. |

## Precedence scenarios checked

The following walks assume no corrupt or simultaneously active blocks, and distinguish a block that has ended from one whose planned duration has elapsed.

| Scenario | Result under the written precedence | Remaining experience defect |
| --- | --- | --- |
| Day after a block ends | Without an open workout or a new finished workout today, T-READY wins if a ready block exists, otherwise T-PICK or T-FIRST; a pending review remains a notice under `hierarchy.md:44`, `hierarchy.md:46`, `hierarchy.md:51`, `hierarchy.md:52` and `hierarchy.md:64`. | No dead end in that chain; selection among ready blocks remains F3-2. |
| Rest day with a ready block waiting | With the current block still active, T-READY cannot match and T-REST wins; ending the current block can expose T-READY, while merely passing the plan's end leaves it active under `hierarchy.md:46`, `hierarchy.md:49` and `today-layouts.md:103`. | The alternate-start sheet has no resolver slot to anchor, B3-1; a waiting block does not silently replace the active one. |
| Finished workout, then a second session | T-DONE exposes Start another workout, the sheet starts it, T-RESUME wins while it is open, and T-DONE returns after completion under `hierarchy.md:44`, `hierarchy.md:45` and `today-layouts.md:321`. | B3-1 affects fixed-weekly recommendations, B3-2 affects Program's open state, and B3-3 leaves the two completed workouts without a defined display rule. |
| Ready block saved on the day of a finished workout | T-DONE wins even with a ready block waiting; Program keeps Start block, and if it is not started Today offers it the next day under `hierarchy.md:56` and `program-layouts.md:108`. | The intended rule is clear; F3-4 corrects its claimed tap cost, and F3-2 concerns which block gets chosen. |
| Usable sessions exist only outside routines | T-FIRST offers the Start a workout ghost; starting leads to T-RESUME, finishing leads to T-DONE, and the next day returns to T-FIRST under `hierarchy.md:44`, `hierarchy.md:45`, `hierarchy.md:52` and `today-layouts.md:255`. | The path is reachable, but F3-1 gives a returning lifter a first-run primary task and F3-3 leaves preview and repair without a route. |

## Review notice checked

The one-notice rule holds because the advisory requires an active block while the review requires none, and both suppress themselves during an open workout (`hierarchy.md:63`, `hierarchy.md:64`).
The unchanged query returns only the latest-ended unreviewed block and returns nothing when any block is active (`fitbod/Periodization/BlockReviewView.swift:635`, `fitbod/Periodization/BlockReviewView.swift:638`, `fitbod/Periodization/BlockReviewView.swift:642`).
Every eligible no-block hero receives the notice, including T-DONE, except T-RESUME, which deliberately defers it while the lifter has an unfinished workout (`today-layouts.md:206`).
Thus visibility is not literally identical to the query's return value during T-RESUME, but the temporary deferral preserves the current workout's priority and does not need another notice.
O-5 is acceptable and is not a blocker: the ready-block start removes the notice, while the explicit Past blocks → block → Review route preserves access to the analysis (`today-layouts.md:198`, `program-layouts.md:185`).
That route costs four taps from Today, including the tab switch, so accepting O-5 must retain the disclosed cost rather than the weaker claim of a review one tap inside Past blocks (`evaluation.md:44`, `hierarchy.md:111`).
The product reason is prioritizing the active workout and keeping reviews findable; the fact that current query tests pin the behavior is not itself a UX justification.
Acknowledging on every dismissal is specified consistently, with a guard against changing the original review date on reopening (`today-layouts.md:210`, `program-layouts.md:187`, `plan.md:33`).

## O-2 slot traces checked

These are paper traces, with zero-based slots `[Push A, Pull A, Legs A, Push A, Pull A, Legs A]` and the same template occupying both occurrences of each name.
The resolver anchors to the latest completed slotted workout in the same block and routine, then advances by one modulo the slot count (`fitbod/Periodization/TodayResolver.swift:108`, `fitbod/Periodization/TodayResolver.swift:124`, `fitbod/Periodization/TodayResolver.swift:136`).

| Action | Slot passed and subsequent suggestion | Judgment |
| --- | --- | --- |
| NEXT is Push A at slot 3; tap Push A | The row passes 3, then the resolver advances to Pull A at 4. | The duplicate-template closure is correct for this route under `today-layouts.md:322`. |
| NEXT is Pull A at 1; choose Push A instead | The row passes 3, skips Pull A at 1 and Legs A at 2, then advances to Pull A at 4. | The sample skips Pull A, Legs A is correct if between means NEXT inclusive and chosen slot exclusive; state those boundaries explicitly in `today-layouts.md:325`. |
| NEXT is Pull A at 4; choose Push A instead | The row passes 0 after wrapping, skips Pull A at 4 and Legs A at 5, then advances to Pull A at 1. | This is forward through the cycle, not a backward jump, under `today-layouts.md:322`. |
| Complete Push A at 0, then choose the displayed NEXT Pull A for a double | The second workout carries 1, and completion advances to Legs A at 2. | The normal double works under `today-layouts.md:322`; T-DONE remains the day's hero under `hierarchy.md:45`. |
| Complete Push A at 0, then choose Push A again | The second workout carries 3, skipping 1 and 2, and advances to Pull A at 4. | The active-block skip disclosure makes the consequence explicit; this is a skip operation, not an exchange of future sessions, under `today-layouts.md:325`. |
| Start Arms outside the active routine | No slot is passed, so the previous block anchor and next scheduled slot remain unchanged. | This matches the written policy and resolver filter at `today-layouts.md:324` and `fitbod/Periodization/TodayResolver.swift:124`. |
| No block, with a routine-backed suggestion | The sheet uses the suggestion's slot as its anchor and passes the chosen slot; the newest finished slotted workout then advances T-PICK. | Normal starts work; a repeat that skips intervening slots lacks disclosure, F3-7, under `today-layouts.md:234`, `today-layouts.md:323` and `today-layouts.md:325`. |
| No block, choose a different routine or a standalone session | A different routine starts from its first matching slot at or after its first slot; a standalone session stays unslotted. | The written fallback is deterministic; an unslotted session cannot advance a routine-based suggestion under `today-layouts.md:234`, `today-layouts.md:323` and `today-layouts.md:324`. |

The sheet rule does not cure the preview-and-start bypass in B3-4, and fixed-weekly rest and done days still need the separate anchor rule in B3-1.

## Copy, glyph and 390pt fit checks

The new template, routine, block and logged-workout terms match the pinned glossary; the word split in the explainer describes the gym concept rather than renaming a UI entity (`CLAUDE.md:111`, `CLAUDE.md:112`, `CLAUDE.md:113`, `CLAUDE.md:116`, `today-layouts.md:249`, `program-layouts.md:134`).
CANCEL, DISMISS, sets × reps, the NEXT ▸ start action and ✓ on completed workouts use the intended control words and glyphs; the in-place muscle expansion is the exception recorded in F3-5 (`today-layouts.md:303`, `today-layouts.md:90`, `today-layouts.md:46`, `program-layouts.md:75`, `program-layouts.md:58`, `docs/design-system/iconography.md:12`, `docs/design-system/iconography.md:15`, `docs/design-system/iconography.md:17`, `docs/design-map/decisions.md:60`).
ADD EXERCISES leads to session detail rather than directly into its editor, so the action still needs the detail screen's Edit step; it is a repair path, not a one-tap exercise editor (`today-layouts.md:286`, `fitbod/Routines/SessionTemplateDetailView.swift:48`).

The following are text-width estimates, not rendered captures.
They use the bundled monospaced font's 0.6em advance with the documented 11pt plus 1.2pt tracking for labelSmall, or 13pt without tracking for bodyDefault (`docs/design-system/typography.md:13`, `docs/design-system/typography.md:17`, `docs/design-system/typography.md:32`, `docs/design-system/typography.md:34`).
Exact insets, line heights and UIKit text shaping remain unverified.

| Requested case | Paper-fit judgment |
| --- | --- |
| Two-line plan with a long block name | The name tail-truncates independently, and WEEK 12 OF 12 · INTENSIFICATION is about 241pt, leaving room for the chevron within 358pt; the default solution is credible, while the 56pt height needs the large-text exception in F3-8 (`today-layouts.md:43`, `today-layouts.md:341`). |
| Review notice with a long name | REVIEW › is about 61pt before its hit area and can stay intact while the separate name text truncates; the name's FINISHED suffix may disappear with its tail, but the review action remains readable (`today-layouts.md:208`). |
| This-week row | THIS WEEK is about 69pt and 2 workouts · 20 sets about 155 to 156pt, leaving roughly 133pt for spacing and the chevron; stacking at accessibility sizes is specified (`today-layouts.md:48`, `today-layouts.md:343`). |
| Deload hero with ~17 MIN | The complete caption is about 233 to 234pt, so the requested example has no demonstrated default-width overflow; 5 working sets × 3 + 2 produces the stated 17-minute estimate, without proving actual workout duration (`today-layouts.md:61`, `fitbod/Views/BlackSlabCTA.swift:58`). |
| Sheet subline ending skips Pull A, Legs A | At about 342 to 343pt it fits only with little horizontal slack; longer names require wrapping, and a one-line guarantee is unsupported, as F3-8 records (`today-layouts.md:307`, `today-layouts.md:325`). |

No wireframe establishes a measured 44pt hit area, but the shared-component requirement and proposal's minimum-height rule are explicit; the built default-size captures must verify them (`docs/design-system/interaction.md:7`, `today-layouts.md:345`, `docs/DEVELOPMENT.md:38`).
AX3 layout verification is intentionally deferred until the workflow is stable, so the absence of an AX3 capture is not promoted to a finalization blocker (`docs/DEVELOPMENT.md:64`, `plan.md:47`).

## Saved-date and ready-order check

An older competition block saved for later will lead Today over a newer base block intended for the next workout, because the selection is oldest `startDate` and then name, with no expression of training intent (`today-layouts.md:195`, `open-decisions.md:22`).
Opening and resaving the intended block does not repair that ordering, because edit initialization preserves `startDate` and save writes the same value back (`fitbod/Periodization/BlockDraft.swift:80`, `fitbod/Periodization/BlockDraft.swift:151`).
Saved Oct 3 correctly avoids claiming a planned start, but remains ambiguous about first creation versus most recent save and does not distinguish same-day, same-name, same-routine candidates (`program-layouts.md:35`, `program-layouts.md:59`).
Removing the selected slab's date also removes the only proposed temporal differentiator from the most prominent candidate (`program-layouts.md:89`, `program-layouts.md:90`).
These are the priority and identity defects in F3-2; a new planned-date schema is not required to expose a choice among existing ready blocks.
Past-block dates improve recognition, but the year-free ranges do not prove the claim for repeated annual blocks with the same names and month/day ranges (`program-layouts.md:177`, `program-layouts.md:179`, `program-layouts.md:181`, `program-layouts.md:184`).

## Contradictions found in the leaf cross-check

The table records conflicting contracts or missing variants, including the related implementation-plan clauses where they would reintroduce a leaf defect.
It does not count these again as separate findings.

| Conflict | Evidence on both sides | Disposition |
| --- | --- | --- |
| The two ready heroes select different example blocks while claiming one shared selection. | `today-layouts.md:181` names Spring with PPL; `program-layouts.md:90` names Summer with Upper Lower, and `program-layouts.md:108` promises the same block. | F3-5, use one fixture. |
| T-PICK retains 3 work instead of the universal prescription subline. | `today-layouts.md:226` versus `today-layouts.md:46` and `functionality-map.md:29`. | F3-5, update the stale row. |
| Program's discard confirmation is both unchanged from always-confirm and shared with Today's conditional rule. | `functionality-map.md:66` versus `program-layouts.md:164` and `hierarchy.md:44`. | F3-5, explicitly share the logged-set condition and document the empty-workout exception to `docs/design-system/interaction.md:28`. |
| T-FIRST's only exception is its standalone-start ghost, but it also carries a review notice. | `today-layouts.md:259` and `today-layouts.md:260` versus `today-layouts.md:206` and `hierarchy.md:52`. | F3-5, list both exceptions. |
| P-RESUME applies over any state but its layout covers only active and planned pages and only demotes Start block. | `hierarchy.md:106` versus `program-layouts.md:165` and `program-layouts.md:167`; creation remains signal under `hierarchy.md:102`, `hierarchy.md:103` and `hierarchy.md:107`. | B3-2, define the overlay for every underlying state. |
| The rotation start remains defined while the open-workout suppression names only the weekday start. | `program-layouts.md:80` versus `program-layouts.md:166` and `hierarchy.md:106`. | B3-2, suppress both NEXT and TODAY while resuming. |
| Draft-only data matches P-PLANNED but cannot supply its ready slab or signal. | `hierarchy.md:104` versus `program-layouts.md:104` and `evaluation.md:24`. | F3-6, add the missing variant. |
| The sheet's NEXT is today's resolver slot while T-DONE and T-REST use the next training date. | `today-layouts.md:322` versus `hierarchy.md:55` and `today-layouts.md:171`. | B3-1, define fixed-weekly anchoring separately. |
| A day must expose its logged workouts but has only one specified name and destination. | `hierarchy.md:87` versus `program-layouts.md:58`, combined with the supported second workout at `today-layouts.md:141`. | B3-3, define day groups and their child destinations. |
| Every ready card appears to gain Start block, but only the selected slab does. | `hierarchy.md:88` versus `program-layouts.md:105`. | Clarify that the selected ready slab alone gains the direct start. |
| The header is the only creation entry in non-empty states, although routine-only Program has another one. | `program-layouts.md:56` versus `program-layouts.md:116` and `hierarchy.md:103`. | Say which empty sections intentionally retain their own creation CTA. |
| Review is one tap inside Past blocks, but the list opens overview before Review. | `hierarchy.md:111` versus `program-layouts.md:185` and `evaluation.md:44`. | Preserve the actual two taps after entering the list. |
| Today never creates a block is unqualified in two leaves but has a review-sheet exception. | `hierarchy.md:27` and `functionality-map.md:44` versus `today-layouts.md:212` and `functionality-map.md:53`. | Qualify the wording with the existing O-12 exception. |
| Recaps allegedly remain on Progress, while the recap history screen is still an external dependency. | `evaluation.md:56` versus `plan.md:54`. | F3-4, name the unbuilt dependency. |
| No state is over budget follows an explicit statement that two states exceed it. | `evaluation.md:70` versus `evaluation.md:69`. | Say no unaccepted state is over the chosen paper budget. |
| The review-step acceptance promises Start block after ending, even if a workout finished today. | `plan.md:33` versus `hierarchy.md:56` and `today-layouts.md:197`. | Qualify the acceptance case by the absence of a counted workout started today. |
| Shared Block overview should pass the presenting tab, but its plan hard-codes Program. | `program-layouts.md:186` and `functionality-map.md:88` versus `plan.md:36`; Today's overview route is retained at `functionality-map.md:53`. | Pass the actual origin so a review reached from Today does not send its builder back to a mislabeled tab. |

## Accepted-with-reason items rechecked

| Accepted item | Judgment |
| --- | --- |
| Explaining a routine through the gym word split | Accept, because the visible entity remains Routine and the sentence explains it rather than introducing a competing product noun (`review-log.md:146`, `CLAUDE.md:112`, `today-layouts.md:249`). |
| No muscle cue in the this-week row | Accept the compact row and the one-tap Volume destination, while treating the claim about when lifters need muscle detail as an untested product assumption (`review-log.md:147`, `tradeoffs.md:12`, `today-layouts.md:335`). |
| Ten elements on transient P-RESUME | Accept the temporary count, but not the incomplete overlay rules in B3-2; a count exception does not excuse competing actions or the wrong session marked in progress (`review-log.md:148`, `hierarchy.md:106`, `program-layouts.md:166`). |
| Draft blocks remain off Today | Accept the planning boundary, provided Program actually handles draft-only continuation as F3-6 requires (`review-log.md:149`, `today-layouts.md:196`, `hierarchy.md:104`). |
| Older unreviewed blocks in a legacy store live only in Past blocks | Accept the explicit historical route and latest-ended query scope; O-5's current-work priority also applies here (`review-log.md:150`, `program-layouts.md:185`, `fitbod/Periodization/BlockReviewView.swift:638`). |
| CREATE BLOCK under + New block | Accept the ordinary action/title pairing; retaining it is coherent even without treating source-pinning tests as product requirements (`review-log.md:151`, `program-layouts.md:200`). |
| Starting a ready block removes its preceding review notice | Accept for the reasons recorded in the review-notice check, with the four-tap return path disclosed (`review-log.md:61`, `evaluation.md:44`). |
| T-READY outranks T-PICK | Accept when the lifter intends that ready block next; F3-2 remains because oldest-created is not evidence of intent among multiple candidates, while the alternate-workout route prevents a dead end (`review-log.md:62`, `hierarchy.md:57`, `today-layouts.md:187`). |
| Phase 1 P-ACTIVE offers only Open | Accept for a planning tab whose stated next task is opening the active block; the lack of an orange CTA alone does not make the action unclear (`review-log.md:63`, `hierarchy.md:78`, `evaluation.md:25`). |

None of these accepted tradeoffs independently adds a blocker.
The four blockers concern missing state contracts and inconsistent start behavior, not a demand to restore every removed element or add a second review notice.

## Mock-up, hierarchy and staging comparison

Moving away from the user's built phase-2 Today is partly justified, because the stat strip, block band and week cells repeat block position before the workout action; collapsing them preserves a direct overview route while giving the training action greater prominence (`bru-screens/today.jsx:18`, `bru-screens/today.jsx:32`, `docs/design-map/screens/today.md:82`, `today-layouts.md:43`).
This is a change to the built baseline, not merely a replacement of an unimplemented drawing, and the current app also added the volume surface below that baseline (`docs/design-map/screens/today.md:80`, `docs/design-map/screens/today.md:86`).
That rationale does not prove that deleting the streak and count, hiding preview, or renaming the route to muscle analysis improves the lifter's job; F3-3, F3-4, F3-9 and F3-10 preserve those objections.

| Element or approved direction | Assessment |
| --- | --- |
| Today week cells and DAY counter | The block position stays on the plan line, the week cells remain one tap away on overview, and rotation keeps its 2 OF 3 position, so these removals preserve the relevant orientation without repeating it above Start (`functionality-map.md:25`, `functionality-map.md:28`, `today-layouts.md:59`). |
| Inline session picker | Moving it behind a ghost reduces competing starts but adds a tap on rest and no-block days and removes direct preview; the claimed blanket improvement is not justified without F3-3 and F3-4 (`tradeoffs.md:16`, `fitbod/Views/TodayView.swift:194`, `today-layouts.md:328`). |
| Program Now slab and routine relationship | Naming the active block, its position and its routine makes the relationship more explicit than the current peer cards and follows the user's active-block hero direction; the existing Program baseline lacks the mock-up's week list (`hierarchy.md:94`, `hierarchy.md:95`, `program-layouts.md:57`, `docs/design-map/screens/program.md:80`). |
| Program This week and Past blocks | Off-plan logs and a direct current-session action improve the planned/logged distinction, but B3-2 and B3-3 must close the open and double-workout cases; Past blocks adds a review route, while F3-2 qualifies the same-name disambiguation claim (`program-layouts.md:58`, `program-layouts.md:184`, `program-layouts.md:185`). |
| Program element budget | Draft v3 records eight elements for P-ACTIVE, not the eleven criticized in round 1, and ten for P-RESUME; those are hand-entered counts, not measured proof of the fold or of a five-second result (`screen_budget.py:3`, `screen_budget.py:32`, `screen_budget.py:35`, `program-layouts.md:64`). |
| Approved history editing | The proposal preserves history and its destination rather than replacing the approved History → workout → Edit flow, but adds the tab switch for all-history access from Today (`functionality-map.md:20`, `docs/design-map/mockups/history-editing.html:176`). |
| Approved stalled-exercise and PR details | The named Progress destinations and workout terminology remain compatible; this review found no replacement of those approved routes in the bundle (`evaluation.md:56`, `docs/design-map/mockups/stalled-exercises.html:156`, `docs/design-map/mockups/pr-workout-detail.html:140`, `docs/design-map/mockups/pr-workout-detail.html:141`). |
| Approved all-recaps | A separate Weekly recaps entry and reopened-week destination are still required by the approved mock-up, so F3-4 rejects calling that surface already retained on Progress (`docs/design-map/decisions.md:9`, `docs/design-map/mockups/all-recaps.html:156`, `docs/design-map/mockups/all-recaps.html:157`, `plan.md:54`). |
| Stage boundaries and BRU foundations | Correct prescription and schedule results, default 390pt usability and shared 44pt targets remain required now; per-screen AX3 and dark-mode verification may wait until stable, so this review does not demand those deferred checks to finalize the paper design (`docs/DEVELOPMENT.md:14`, `docs/DEVELOPMENT.md:36`, `docs/DEVELOPMENT.md:38`, `docs/DEVELOPMENT.md:64`, `docs/DEVELOPMENT.md:65`). |
| User-owned design decisions | The redesign may propose replacing the stat strip and band, but cannot claim that D-159 and D-341 have already changed stage; the design map expressly reserves that change to user confirmation (`docs/design-map/decisions.md:43`, `docs/design-map/decisions.md:45`). |

## Checked and found correct

- T-DONE over T-READY.
- Active-block gate on T-READY.
- One-notice mutual exclusion.
- Review dismissal acknowledgment guard.
- Rotation duplicate-slot selection in the sheet.
- Normal slotted doubles.
- Working-set deload count contract.
- Independent plan-name truncation.
- CANCEL and DISMISS controls.
- Archived-routine entry preservation.
- Plan-complete route to confirmed End block.
- Preserved BRU color and typography roles.

## Not reached

- No requested paper-review item remains unchecked.
- Rendered 390pt and accessibility-size behavior, live five-second usability, exact hit regions, implementation correctness and test outcomes remain unverified; no app build or tests were run, as instructed.
- The existence of an unchanged all-time numeric workout readout elsewhere in the app was not traced beyond the proposal's replacement map, as marked in F3-10.

