# Round 3 Codex feasibility review of draft v4

## Verdict

Not final as written: two verified blockers remain in TodayState's input contract and the no-block NEXT selection rule.
This is an incremental report against the working tree observed at commit `5c186ecd592bca8b14373274c781bc08e10d987b`, following the user's instruction to review v4 rather than the spec's older v3 baseline.
Proposal citations below are relative to `docs/design-map/redesign/`; other citations are relative to the repository root.
No build or test has been run, and only this report is being changed.
The per-step test inventory, seed timestamps, and caller-wording issues assigned to the coverage reviewer are excluded from findings.

## Findings

### Blocks finalization

**B-F1: TodayState's listed inputs cannot distinguish v4's empty, repair, and standalone-session states.**

Trigger: There is no block or workout history, and the store contains either an empty live routine or a usable session template outside every live routine.
Mechanism: Step 1.1 supplies only routines with non-empty sessions, so an empty routine disappears before TodayState can distinguish T-FIX from T-FIRST, while neither that query nor the workout list can discover a never-logged standalone session for T-PICK.
Blast radius: T-FIRST, the no-block T-FIX variant, standalone T-PICK, the Other sessions group, and the alternate-start ghosts on block repair states cannot all be implemented from the declared inputs.
Smallest fix: Pass all non-archived routines plus their derived usable slots, add a flat view-owned query of non-archived SessionTemplate rows, compute membership in live routines in Swift, and pass the resulting standalone templates or a suitable value projection into the pure state function.
Evidence: `plan.md:17`; `plan.md:19`; `hierarchy.md:47`; `hierarchy.md:48`; `hierarchy.md:51`; `hierarchy.md:52`; `today-layouts.md:250`; `today-layouts.md:320`; `fitbod/Views/TodayView.swift:46`; `fitbod/Views/TodayView.swift:56`; `fitbod/Models/SessionTemplate.swift:42`; `fitbod/Models/SessionTemplate.swift:57`.
Severity: blocks finalization.

**B-F2: No-block NEXT and T-PICK disagree when the routine anchor is empty.**

Trigger: With no block, a routine has slots Push, empty Pull, and usable Legs, and its newest finished slotted workout is Push; a stronger case leaves that entire recently used routine empty while another routine still has a usable session.
Mechanism: The hero's rule skips empty sessions after the anchor, but StartSlot's no-block NEXT and the sheet's NEXT table specify the immediate following slot without that skip, and the hero has no fallback when the newest workout's routine has no usable slot at all.
Blast radius: The sheet can mark a disabled Pull row NEXT while the hero offers Legs, and T-PICK can be selected because a usable session exists somewhere without its selection algorithm producing a hero.
Smallest fix: Define one usable-slot selection rule for no-block NEXT and the hero, distinguish a raw history anchor from the selected startable slot, and fall back to the most recently updated eligible routine or standalone template when the anchor's routine has no usable slot.
Evidence: `plan.md:19`; `hierarchy.md:51`; `hierarchy.md:55`; `today-layouts.md:248`; `today-layouts.md:249`; `today-layouts.md:250`; `today-layouts.md:362`; `today-layouts.md:365`; `today-layouts.md:369`; `fitbod/Views/TodaySessionPicker.swift:98`.
Severity: blocks finalization.

### Fix soon

**F-F1: Acknowledge-on-dismiss lacks a failure path after its error surface has closed.**

Trigger: The new acknowledgement save throws after Back, Plan custom, or an interactive dismissal of the review sheet.
Mechanism: Step 2.1 moves that write into the presenter's onDismiss callback, but the only existing error state and message live inside BlockReviewView, which has already closed, and the plan does not assign the new callback an error or retry surface.
Blast radius: Today and the new Block overview review entry can silently fail to remember a review, despite the promise that closing it clears the notice and preserves its first acknowledgement date.
Smallest fix: Retain the dismissed block independently of presentation state, handle the throwing write in the presenter with a visible retry action, leave the notice eligible until persistence succeeds, and cover first acknowledgement, repeated acknowledgement, failure, and relaunch at the persistence boundary.
Evidence: `plan.md:33`; `plan.md:36`; `today-layouts.md:224`; `fitbod/Periodization/BlockReviewView.swift:27`; `fitbod/Periodization/BlockReviewView.swift:57`; `fitbod/Periodization/BlockReviewView.swift:395`; `fitbod/Periodization/BlockReviewView.swift:649`; `docs/DEVELOPMENT.md:23`; `docs/DEVELOPMENT.md:25`.
Severity: fix soon.


## Closure checks

Pending the ten requested checks.

## Feasibility checks completed

The proposed broad Block query and flat non-archived Split query with Swift relationship post-filters fit the view-owned Query and predicate restrictions, but their input inventory needs B-F1's correction.
Evidence: `plan.md:17`; `CLAUDE.md:74`; `CLAUDE.md:75`; `CLAUDE.md:135`.

### TodayState inputs, spec item 2c

| Required input | Already available to TodayView? | Query or derivation required |
| --- | --- | --- |
| Open workouts and active block | Yes | Existing flat queries at `fitbod/Views/TodayView.swift:46` and `fitbod/Views/TodayView.swift:52`. |
| Counted workouts started today | Underlying data yes | Filter `allSessions` using the injected date and calendar and the existing counted-workout rule, without a new query; `fitbod/Views/TodayView.swift:56`, `fitbod/Sessions/SessionSetActions.swift:145`. |
| All live routines, including empty ones | No | Add the flat Split query in the view and retain the unfiltered result for T-FIX; the current query is owned by the child picker, `fitbod/Views/TodaySessionPicker.swift:18`, and step 1.1 passes only the usable subset, `plan.md:17`. |
| Standalone non-archived templates and their usable-exercise state | No | Add the flat SessionTemplate query from B-F1 and exclude live-routine membership in Swift; `fitbod/Models/SessionTemplate.swift:48`, `fitbod/Models/SessionTemplate.swift:57`, `today-layouts.md:250`. |
| Ready blocks | No | The proposed broad Block query and Swift derived-status filter suffice without a schema change; `plan.md:17`, `fitbod/Models/Block.swift:122`. |
| Pending review | A cached optional exists, but not an observed all-block input | Use the unchanged pendingReviewBlocks contract when the broad Block query changes; derivedStatus alone is insufficient because the helper excludes future end dates and older unreviewed blocks after the newest block was acknowledged; `fitbod/Views/TodayView.swift:71`, `fitbod/Periodization/BlockReviewView.swift:630`. |
| No-block routine anchors and suggestion | History yes, derived input not listed in the function tuple | Derive from the full finished-workout history, not only today's workouts, and pass the selected anchor or suggestion explicitly; `fitbod/Views/TodayView.swift:56`, `plan.md:17`, `today-layouts.md:248`. |
| Current date, environment calendar, current phase and notice eligibility | Calendar/date injection is new; block/settings/advisory data exists | Keep date and calendar as explicit derivation inputs, resolve in the view, and derive phase from the active block; no persistent field or additional query is needed; `plan.md:17`, `fitbod/Views/TodayView.swift:49`, `fitbod/Views/TodayView.swift:74`, `fitbod/Prescription/PeriodizationEngine.swift:21`. |

No ObservableObject, Query-backed view model, or relationship chain inside Predicate is needed for these inputs.
Evidence: `CLAUDE.md:74`; `CLAUDE.md:75`; `CLAUDE.md:135`.

### Review sheet, spec item 2f

The sheet approach fits BlockReviewView's existing NavigationStack, and guarding acknowledge before its transaction preserves the first reviewedAt date while leaving the current first-write behavior intact.
Evidence: `plan.md:33`; `fitbod/Periodization/BlockReviewView.swift:44`; `fitbod/Periodization/BlockReviewView.swift:649`; `fitbodTests/BlockReviewMathTests.swift:216`.

The origin must be stored and forwarded at the nested builder call currently hard-coded to today, while the dead acknowledgeAndDismiss helper can be removed without changing Plan custom's explicit dismissal.
Evidence: `fitbod/Periodization/BlockReviewView.swift:79`; `fitbod/Periodization/BlockReviewView.swift:349`; `fitbod/Periodization/BlockReviewView.swift:407`; `plan.md:33`.

If the new parameter reuses BlockBuilderView.Origin, keep the new initializer internal or make that type public, because the existing BlockReviewView initializer is public and the existing Origin enum is internal.
Evidence: `fitbod/Periodization/BlockReviewView.swift:32`; `fitbod/Periodization/BlockBuilderView.swift:14`; `fitbod/Periodization/BlockBuilderView.swift:60`.

BlockReviewTriggerTests' exact sheet-wiring assertion changes, while its pending-review eligibility tests still describe the unchanged helper.
Evidence: `fitbodTests/BlockReviewTriggerTests.swift:64`; `fitbodTests/BlockReviewTriggerTests.swift:135`; `fitbodTests/BlockReviewTriggerTests.swift:198`; `plan.md:33`.

The default origin preserves the hosted BlockReviewHeroLayoutTests and BlockReviewPRMarkTests constructors without changing their assertions.
Evidence: `fitbodTests/BlockReviewHeroLayoutTests.swift:105`; `fitbodTests/BlockReviewPRMarkTests.swift:124`; `plan.md:33`.

ArchiveRoutineUITests and BlockLifecycleEntryPointsUITests must explicitly open the notice, and the latter must retain its ended-block relaunch verification while replacing the old expectation that a deferred review reopens automatically.
Evidence: `fitbodUITests/ArchiveRoutineUITests.swift:278`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:38`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:51`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:58`; `plan.md:33`.

The existing BlockReviewAfterEndUITests seed also makes the weekly recap due, so its revised journey must close that recap before tapping the review notice under the new presentation order.
Evidence: `fitbodUITests/BlockReviewAfterEndUITests.swift:58`; `fitbodUITests/BlockReviewAfterEndUITests.swift:75`; `plan.md:33`; `fitbod/Views/TodayView.swift:643`.

The named review suites cover the expected constructors and entry changes, but pure TodayState assertions cannot prove that a dismissal write survives relaunch or that repeated acknowledgement retains the first timestamp.
Evidence: `plan.md:33`; `fitbodTests/BlockReviewMathTests.swift:216`; `docs/DEVELOPMENT.md:23`.

### StartSlot and the session sheet, spec item 2e

For a rotation block, the returned session slot plus the active routine's slots sorted by position are enough to choose the first matching session at or after NEXT and enumerate the skipped interval, without exposing the resolver's historical anchor.
Evidence: `fitbod/Periodization/TodayResolver.swift:124`; `fitbod/Periodization/TodayResolver.swift:135`; `fitbod/Periodization/TodayResolver.swift:142`; `today-layouts.md:364`; `today-layouts.md:367`.

TodaySessionPicker does not currently hold the active block, scheduling mode, date, calendar, counted-workout state, or finished-workout history, and its grouping discards slot identity.
Evidence: `fitbod/Views/TodaySessionPicker.swift:18`; `fitbod/Views/TodaySessionPicker.swift:21`; `fitbod/Views/TodaySessionPicker.swift:37`.

Pass those inputs or precomputed per-routine NEXT results into the sheet, retain each row's candidate slots while deduplicating display templates, and change the start callback to carry the chosen slot.
Evidence: `plan.md:19`; `fitbod/Views/TodaySessionPicker.swift:22`; `fitbod/Views/TodaySessionPicker.swift:25`; `fitbod/Views/TodaySessionPicker.swift:39`.

TodayResolution exposes neither the latest completed workout nor a future weekday slot in its restDay case, so no-block anchors need the parent's full finished history and weekday rest-day starts need a separate resolution for the selected future date.
Evidence: `fitbod/Periodization/TodayResolver.swift:33`; `fitbod/Periodization/TodayResolver.swift:67`; `fitbod/Periodization/TodayResolver.swift:172`; `today-layouts.md:361`; `today-layouts.md:362`.

V4 now places the future-day rule in Phase 1 StartSlot, which closes v3's dependency on the Phase 2 next-line feature.
Evidence: `plan.md:19`; `plan.md:34`.

To keep StartSlot pure, pass the resolver results into it from the view or an orchestration function rather than fetching through ModelContext inside the pure calculation.
Evidence: `plan.md:19`; `fitbod/Periodization/TodayResolver.swift:69`; `fitbod/Periodization/TodayResolver.swift:108`.

Session detail additionally needs the current active block and resolution, its live routine slots, the full relevant finished history, and date/calendar at tap time, because its existing state contains only the template and presentation state.
Evidence: `fitbod/Routines/SessionTemplateDetailView.swift:23`; `fitbod/Routines/SessionTemplateDetailView.swift:31`; `fitbod/Routines/SessionTemplateDetailView.swift:210`; `plan.md:19`.

No change to TodayResolver's output is necessary if those inputs are supplied, but B-F2's eligibility rule must be settled before all routes can share the same NEXT.
Evidence: `fitbod/Periodization/TodayResolver.swift:67`; `plan.md:19`; `today-layouts.md:374`.

### Working-set helper and calendars, spec item 2b

The extraction can preserve generation exactly by accepting BlockPhase? and using the existing deload branch verbatim, including the minimum only in that branch, while retaining scheduledDeloadActive for warm-ups.
Evidence: `plan.md:18`; `fitbod/Sessions/SessionFactory.swift:188`; `fitbod/Sessions/SessionFactory.swift:256`; `fitbod/Sessions/SessionFactory.swift:289`.

Passing scheduledBlockPhase does not require changing the factory's phase calculation, snapshot fields, warm-up ordering, or generated working-set rows.
Evidence: `fitbod/Sessions/SessionFactory.swift:188`; `fitbod/Sessions/SessionFactory.swift:207`; `fitbod/Sessions/SessionFactory.swift:299`.

Calendar parity is conditional rather than guaranteed by a shared count helper.
For a block starting at 2026-10-01 12:00 UTC with one accumulation week followed by deload, at 2026-10-08 00:30 UTC a UTC environment calendar is on day 7 while an America/Los_Angeles factory calendar is still on day 6.
With targetSets 3 and a deload multiplier of 0.5, those inputs yield one hero working set and three generated working sets.
This is a counterexample derived from the calendar-day implementation, not a runtime test.
Evidence: `plan.md:18`; `fitbod/Prescription/PeriodizationEngine.swift:21`; `fitbod/Prescription/PeriodizationEngine.swift:120`; `fitbod/Sessions/SessionFactory.swift:290`.

Unverified: a production divergence between the default SwiftUI calendar and Calendar.current was not established, and no particular day or time zone makes them disagree when both calendars are equivalent.
The proposed equality acceptance should explicitly use equivalent date/calendar inputs, or the start pipeline should accept the same injected calendar if parity under overrides is intended.
Evidence: `plan.md:18`; `fitbod/App/RootView.swift:135`; `fitbod/App/RootView.swift:269`; `fitbod/Prescription/PeriodizationEngine.swift:21`.

### Volume-row calculation, spec item 2d

All named symbols exist with the required callable signatures: FatigueModel.completedWorkingSets(startedFrom:before:in:) is internal and MainActor-isolated, SessionSetActions.countedWorkouts returns a lazy filtered sequence, and mondayAtMidnightForToday accepts both weekStartsMonday and calendar.
Evidence: `fitbod/Fatigue/FatigueModel.swift:305`; `fitbod/Sessions/SessionSetActions.swift:145`; `fitbod/Fatigue/MondayAtMidnight.swift:23`.

Run the calculation on the model context's main actor, use a calendar-derived exclusive week end, and filter returned sets by the identities of the counted workouts in that window.
The wrapper must not assume completedWorkingSets itself excludes open workouts, because its session predicate filters startedAt only.
Evidence: `fitbod/Fatigue/FatigueModel.swift:281`; `fitbod/Fatigue/FatigueModel.swift:311`; `fitbod/Fatigue/FatigueModel.swift:323`; `plan.md:20`.

Finished persistent IDs plus weekStart are sufficient for the current app's immutable finished-workout contract, provided step 1.1's activation and significant-time-change refresh recomputes the key and the user's weekStartsMonday setting is passed through.
Finishing, deleting, and restoring workouts changes the ID set, while ordinary week rollover changes weekStart.
Evidence: `plan.md:17`; `plan.md:20`; `fitbod/Views/TodayView.swift:95`; `fitbod/Sessions/SessionSetActions.swift:163`; `fitbod/Fatigue/MondayAtMidnight.swift:23`.

No visibility change to private fetchWorkingSets is necessary.
Evidence: `fitbod/Fatigue/FatigueModel.swift:276`; `fitbod/Fatigue/FatigueModel.swift:306`.

## Checked and correct

- Broad Block query with derived-status filtering in Swift.
- Flat Split predicate with relationship filtering in Swift.

## Not reached

- Spec item 1: seven blocker closures and three fix-soon closures.
- Spec item 2a: remaining Phase 1 steps and conventions audit.
- Spec item 2g: Today builder template-case removal.
- Spec item 2h: Volume routing on both stacks.
- Spec item 2i: Program header and popover geometry.
- Spec item 2j: limited test spot-checks outside the coverage reviewer's excluded inventory.
- Spec item 2k: remaining Phase 1 dependencies on Phase 2.
- Spec item 3: final ranking and verdict.

