# Round 3 Codex feasibility review of draft v4

## Verdict

Sections written before the stall cite draft v4 (e403d287); sections written after it cite draft v5 (8fd223ed).

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

## Draft v5 continuation

This continuation reviews the working tree observed at `13a70a34e3ab24bf95e9bbfc49ada253b24e266c`, containing draft v5 from `8fd223ed`.
The earlier v4 verdict and findings above are preserved as historical results, and the final verdict below supersedes them.
The application source and test files checked here are unchanged from the original source baseline.

### Verification of the three v4 findings

| Finding | V5 result | Evidence |
| --- | --- | --- |
| B-F1 | Closed at proposal level: the tuple now includes every live routine, standalone usable templates from a flat query, all finished workouts, and pending review eligibility by the existing helper's rule. | `plan.md:17`; `plan.md:35`; `fitbod/Models/SessionTemplate.swift:42`; `fitbod/Periodization/BlockReviewView.swift:630`. |
| B-F2 | Closed at proposal level: no-block NEXT now skips empty sessions, can be nil for a routine, and selection searches only routines with a NEXT before falling back to a standalone session. | `plan.md:19`; `today-layouts.md:250`; `today-layouts.md:251`; `today-layouts.md:252`; `today-layouts.md:365`; `today-layouts.md:368`; `hierarchy.md:58`. |
| F-F1 | Closed at proposal level: a shared presenter retains the reviewed block, owns the dismissal write and retry message, and is used by both entry points, with first-write, repeat-write, failure and relaunch checks specified. | `plan.md:33`; `plan.md:36`; `today-layouts.md:225`; `today-layouts.md:226`; `risks.md:34`. |

Runtime execution remains unverified because no build or tests were run.

### Ten closure checks, spec item 1

These checks assess the current leaves, rather than treating the older resolution text in the log as the current specification.

| Claim | Closure in draft v5 | Leaf and source evidence |
| --- | --- | --- |
| B-1 | Closed for hero precedence, pending-review eligibility, acknowledgement and recap ordering: review is a notice, T-DONE precedes T-READY, and the shared presenter now owns failure feedback. | `review-log.md:255`; `hierarchy.md:44`; `hierarchy.md:45`; `hierarchy.md:46`; `hierarchy.md:69`; `plan.md:33`; `fitbod/Periodization/BlockReviewView.swift:630`. |
| B-2 | Closed at the proposal boundary: StartSlot supplies slots to hero, sheet and detail starts, including no-block starts, and counted workouts are assigned by startedAt. | `review-log.md:256`; `plan.md:19`; `hierarchy.md:54`; `today-layouts.md:254`; `today-layouts.md:377`; `fitbod/Sessions/SessionFactory.swift:153`; `fitbod/Periodization/TodayResolver.swift:124`. |
| B-3 | Closed: the selection fields exist, and neither an edited-at field nor a planned-start attribute is required. | `review-log.md:257`; `open-decisions.md:14`; `today-layouts.md:252`; `fitbod/Models/Block.swift:58`; `fitbod/Models/SessionTemplate.swift:47`. |
| B-4 | Closed: the empty scheduled session has a repair state before T-TODAY, no-block selection skips empty slots, and routine rows with no exercises cannot start. | `review-log.md:258`; `hierarchy.md:47`; `hierarchy.md:50`; `today-layouts.md:250`; `today-layouts.md:372`; `plan.md:19`. |
| B-5 | Structural closure confirmed: CREATE BLOCK and Program's staged sheets stay in place, and today.root replaces the removed loaded signal; the exhaustive test inventory remains the coverage pass's assigned item and is not re-reported here. | `review-log.md:259`; `plan.md:17`; `plan.md:21`; `program-layouts.md:242`; `fitbod/Periodization/ProgramView.swift:233`; `fitbod/Periodization/ProgramView.swift:243`. |
| B2-1 | Closed for repeated templates in one routine: choose NEXT if it matches, otherwise scan forward with wrapping, while retaining candidate slots under one displayed session row. | `review-log.md:185`; `plan.md:19`; `today-layouts.md:367`; `fitbod/Models/SplitSessionSlot.swift:39`; `fitbod/Periodization/TodayResolver.swift:135`. |
| B2-2 | Closed: Created replaces Saved and planned-start language, the ready order has an id tie-break, and the date describes draft creation until lifecycle start overwrites it. | `review-log.md:186`; `open-decisions.md:14`; `program-layouts.md:59`; `program-layouts.md:121`; `fitbod/Periodization/BlockDraft.swift:19`; `fitbod/Periodization/BlockDraft.swift:80`; `fitbod/Periodization/BlockDraft.swift:151`; `fitbod/Periodization/BlockLifecycleService.swift:101`. |
| F2-2 | Closed for working-set counts: the helper preserves the existing branch, warm-up counts are removed, and v5 additionally threads the calendar into the start pipeline. | `review-log.md:193`; `plan.md:18`; `fitbod/Sessions/SessionFactory.swift:188`; `fitbod/Sessions/SessionFactory.swift:256`; `fitbod/Sessions/SessionFactory.swift:290`. |
| F2-9 | Closed: the row filters by counted-workout identities, uses a calendar-derived week window, and invalidates on finished IDs plus week start. | `review-log.md:200`; `plan.md:20`; `fitbod/Fatigue/FatigueModel.swift:306`; `fitbod/Fatigue/FatigueModel.swift:311`; `fitbod/Sessions/SessionSetActions.swift:145`; `fitbod/Fatigue/MondayAtMidnight.swift:23`. |
| F2-10 | Origin compatibility and idempotent acknowledgement are closed; the revised relaunch expectation still needs the correction recorded under the v5 test check below. | `review-log.md:201`; `plan.md:33`; `fitbod/Periodization/BlockReviewView.swift:32`; `fitbod/Periodization/BlockBuilderView.swift:14`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:40`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:53`. |

### Builder case removal, spec item 2g

Confirmed: TodayView's line 206 is its only template-case setter, while line 267 still sets edit for the Block overview reached on Today's stack.
Evidence: `fitbod/Views/TodayView.swift:206`; `fitbod/Views/TodayView.swift:267`; `plan.md:19`.

Removing the case also removes two readers, the builder sheet's template switch arm and the enum's template id arm, while retaining the sheet and edit arm.
Evidence: `fitbod/Views/TodayView.swift:298`; `fitbod/Views/TodayView.swift:301`; `fitbod/Views/TodayView.swift:707`; `fitbod/Views/TodayView.swift:712`.

The review's Start next builder is independent state, so the removal does not delete that entry point.
Evidence: `fitbod/Periodization/BlockReviewView.swift:26`; `fitbod/Periodization/BlockReviewView.swift:76`; `fitbod/Periodization/BlockReviewView.swift:357`.

No additional finding.

### Volume routing, spec item 2h

The new route registrations do not conflict with ProgressHomeView's existing ExerciseProgressRoute, ProgressHomeRoute or session-history destinations, and RootView already forwards its Progress path binding without adding another stack.
Evidence: `plan.md:20`; `fitbod/Progress/ProgressHomeView.swift:55`; `fitbod/Progress/ProgressHomeView.swift:104`; `fitbod/Progress/ProgressHomeView.swift:122`; `fitbod/Progress/ProgressHomeView.swift:128`; `fitbod/App/RootView.swift:374`.

VolumeScreen must forward the presenting stack's NavigationPath binding to FatigueSurfaceView, whose default constant binding is only a convenience and whose muscle taps append to that binding.
Retain Today's existing MuscleSlugRoute destination, add the Progress registration at its stack root, and keep VolumeScreen as a pushed child without another NavigationStack.
Evidence: `fitbod/Fatigue/FatigueSurfaceView.swift:54`; `fitbod/Fatigue/FatigueSurfaceView.swift:59`; `fitbod/Fatigue/FatigueSurfaceView.swift:304`; `fitbod/Views/TodayView.swift:248`; `CLAUDE.md:79`.

Progress-tab retap will continue to clear the same path, including the added Volume and muscle-detail entries.
Evidence: `fitbod/App/RootView.swift:179`; `fitbod/App/RootView.swift:184`.

**V5-F1: The moved advisory-ring calculation omits the caller's enabled-setting gate.**

Trigger: Deload alerts are disabled, the underlying signals would fire, and Volume is opened from either tab.
Mechanism: The new host is instructed to call DeloadAdvisor.evaluate on appear, but that function checks weekly dismissal and signals rather than deloadAlertEnabled, which Today currently checks before calling it.
Blast radius: Volume can show advisory rings despite the lifter disabling alerts, while the notice row still honors the setting.
Smallest fix: Specify that VolumeScreen reuses the settings guard from refreshAdvisory and passes false when alerts are disabled.
Evidence: `plan.md:20`; `today-layouts.md:382`; `risks.md:29`; `functionality-map.md:17`; `functionality-map.md:47`; `fitbod/Views/TodayView.swift:684`; `fitbod/Fatigue/DeloadAdvisor.swift:124`; `fitbod/Fatigue/DeloadAdvisor.swift:131`; `fitbod/Fatigue/DeloadAdvisor.swift:136`.
Severity: fix soon.

### Program header and popover, spec item 2i

Confirmed: BRUHeaderBar accepts the proposed HeaderAction initializer, whose default isSignal is false, and the caller supplies the existing showingNewPopover action.
Evidence: `program-layouts.md:55`; `plan.md:21`; `fitbod/Design/BRUHeaderBar.swift:54`; `fitbod/Design/BRUHeaderBar.swift:130`; `fitbod/Periodization/ProgramView.swift:133`.

Its action uses bruHitArea with the 44-point minimum, and the header grows into stacked title and actions at accessibility sizes.
Evidence: `fitbod/Design/BRUHeaderBar.swift:202`; `fitbod/Design/BRUHeaderBar.swift:307`; `fitbod/Design/BRUHitArea.swift:19`; `fitbod/Design/BRUMetrics.swift:21`.

Moving the existing onGeometryChange and zIndex modifiers to the entire replacement header preserves the popover's measured top offset and the header action's touch overhang.
Evidence: `fitbod/Periodization/ProgramView.swift:134`; `fitbod/Periodization/ProgramView.swift:137`; `fitbod/Periodization/ProgramView.swift:305`.

Unverified: the advertised fold count and long-name fit require the planned captures, and no runtime measurement was performed.
Evidence: `program-layouts.md:64`; `plan.md:21`.

No additional finding.

### Phase 1 feasibility and conventions, spec item 2a

No Phase 1 step requires a schema change, ObservableObject, a Query-backed view model, or a relationship chain inside Predicate.
This is a source-level feasibility conclusion, not a compilation result.
Evidence: `plan.md:4`; `plan.md:17`; `plan.md:18`; `plan.md:19`; `plan.md:20`; `plan.md:21`; `plan.md:22`; `CLAUDE.md:74`; `CLAUDE.md:75`; `CLAUDE.md:135`.

| Step | Source-level feasibility and required implementation boundary |
| --- | --- |
| 1.1 | The broad Block query supports derivedStatus and the pending-review rule in Swift; flat non-archived Split and SessionTemplate queries use stored Boolean fields, and live-routine membership comes from slot relationships after the fetch; `plan.md:17`, `fitbod/Models/Block.swift:122`, `fitbod/Periodization/ProgramView.swift:97`, `fitbod/Views/TodaySessionPicker.swift:18`, `fitbod/Models/SessionTemplate.swift:48`, `fitbod/Models/SplitSessionSlot.swift:42`. |
| 1.2 | An optional phase input can preserve the factory's set-count branch, and defaulted calendar arguments keep existing callers valid while Today forwards its environment calendar; `plan.md:18`, `fitbod/Sessions/SessionFactory.swift:188`, `fitbod/Sessions/SessionFactory.swift:289`, `fitbod/Routines/WorkoutStarter.swift:29`, `fitbod/Views/TodayView.swift:607`. |
| 1.3 | StartSlot stays pure by accepting resolver results, and the view or tap-time caller performs context reads before selection; storing the routine rather than a slot leaves the existing nullification behavior intact; `plan.md:19`, `fitbod/Periodization/TodayResolver.swift:67`, `fitbod/Models/SplitSessionSlot.swift:45`. |
| 1.4 | The existing main-actor volume helper and route binding suffice without persistent state, subject to V5-F1's setting guard; `plan.md:20`, `fitbod/Fatigue/FatigueModel.swift:305`, `fitbod/Fatigue/FatigueSurfaceView.swift:57`. |
| 1.5 | Program already owns the required blocks, active workouts, live routines, archived routines and navigation path, while ready-block starts can reuse the throwing lifecycle service; origin is transient navigation context rather than a stored field; `plan.md:21`, `fitbod/Periodization/ProgramView.swift:92`, `fitbod/Periodization/ProgramView.swift:97`, `fitbod/Periodization/ProgramView.swift:101`, `fitbod/Periodization/ProgramView.swift:108`, `fitbod/Periodization/ProgramView.swift:111`, `program-layouts.md:123`, `fitbod/Periodization/BlockLifecycleService.swift:75`. |
| 1.6 | The banner already has the active session and callbacks, so a visible discard control can adopt Today's loggedSetCount decision without new persistent state; both immediate and confirmed discard must retain the existing timer cleanup; `plan.md:22`, `fitbod/Sessions/ResumeWorkoutBanner.swift:41`, `fitbod/Sessions/ResumeWorkoutBanner.swift:44`, `fitbod/Sessions/ResumeWorkoutBanner.swift:117`, `fitbod/Views/ResumeWorkoutSlab.swift:126`. |

Keep the current date as an explicit evaluation input alongside the calendar, as identified in the pre-stall item 2c, so TodayState and the resolver evaluate the same day.
Evidence: `plan.md:17`; `fitbod/Periodization/TodayResolver.swift:70`; `hierarchy.md:45`.

The derived UI state can use value enums and view-owned State without introducing a view model, and the proposal's native buttons, BRU fonts and 44-point controls fit the foundations that the development guide does not defer.
Evidence: `.claude/rules/swift/patterns.md:25`; `CLAUDE.md:74`; `docs/DEVELOPMENT.md:31`; `today-layouts.md:395`; `program-layouts.md:55`.

No additional Phase 1 blocker was found beyond the previously closed v4 input and selection findings.

### Test spot-checks, spec item 2j

This check covers the changed behavioral expectations and representative retained assertions, excluding the coverage pass's per-step suite inventory and wrong-screen matches.
No suites were executed.

| Spot-check | Result |
| --- | --- |
| Review eligibility and first acknowledgement | The unchanged pending-review helper still matches the active-block and latest-ended-block tests, and adding the nil guard preserves the existing first-write and transaction assertions; `plan.md:33`, `fitbodTests/BlockReviewTriggerTests.swift:105`, `fitbodTests/BlockReviewTriggerTests.swift:128`, `fitbodTests/BlockReviewMathTests.swift:216`, `fitbodTests/BlockReviewMathTests.swift:244`. |
| Stored review marker | BlockReviewedAtTests confirms a direct write can be fetched again, but does not drive sheet dismissal or relaunch, so it does not replace v5's new persistence-boundary checks; `fitbodTests/BlockReviewedAtTests.swift:33`, `fitbodTests/BlockReviewedAtTests.swift:43`, `fitbodTests/BlockReviewedAtTests.swift:50`, `plan.md:33`. |
| Volume routes and retained copy | The existing MuscleSlugRoute value tests and retained Volume headings remain compatible with the move, but do not prove that a new host forwards its navigation binding; `fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift:85`, `fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift:137`, `fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift:216`, `fitbod/Fatigue/FatigueSurfaceView.swift:304`, `plan.md:20`. |
| Block overview's next-day tests | The suite is correctly named, but its future-date assertions express a different contract from StartSlot's current startable slot, as recorded in V5-F3 below; `fitbodTests/BlockOverviewStatesTests.swift:63`, `fitbodTests/BlockOverviewStatesTests.swift:72`, `plan.md:34`. |

**V5-F2: The revised relaunch assertion expects a review that the same journey has already acknowledged.**

Trigger: The lifecycle UI test ends the block, opens the review, closes it with Plan custom, and then relaunches.
Mechanism: Step 2.1 tells the test to expect the notice after relaunch because the review was put off, but under the same step that first close writes reviewedAt and pendingReviewBlocks excludes the block thereafter.
Blast radius: The prescribed lifecycle regression test fails against the intended implementation or encourages an implementation that violates acknowledgement-on-close.
Smallest fix: Keep this journey's ended-block persistence assertion and expect no review notice after the successful close and relaunch, with a separate never-opened-review journey if persistence of an unacknowledged notice also needs coverage.
Evidence: `plan.md:33`; `hierarchy.md:69`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:40`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:53`; `fitbodUITests/BlockLifecycleEntryPointsUITests.swift:58`; `fitbod/Periodization/BlockReviewView.swift:642`; `fitbod/Periodization/BlockReviewView.swift:655`.
Severity: fix soon.

Unverified: the new throwing-store and relaunch tests are specified but unwritten, so this review does not claim their runtime success.
Evidence: `plan.md:33`.

### Phase dependencies, spec item 2k

No remaining Phase 1 step requires a Phase 2 feature to be implemented first.
StartSlot's weekday look-ahead now belongs to step 1.3, Volume's routes and advisory input belong to step 1.4, and step 1.5 supplies the origin that the later review entry consumes.
Evidence: `plan.md:19`; `plan.md:20`; `plan.md:21`; `plan.md:34`; `plan.md:36`.

The review notice and independent recap trigger remain one Phase 2 behavior change, while Phase 1 explicitly leaves T-DONE's next line absent and the existing block-creation sheets intact.
Evidence: `plan.md:19`; `plan.md:21`; `plan.md:33`.

The removal of the exercise placeholder depends on step 1.3 within Phase 1, not on Phase 2, so it should land with the state-slab gate that makes the placeholder unreachable.
Evidence: `plan.md:18`; `plan.md:19`; `plan.md:24`.

**V5-F3: The next-day extraction must preserve Block overview's distinct future-date contract.**

Trigger: It is Wednesday in a Monday-Wednesday-Friday block, no workout has been counted today, and Block overview displays the current week's cells.
Mechanism: StartSlot's specified weekday NEXT is today's slot, whereas Block overview's nextTrainingDay excludes today and returns Friday, so directly replacing the latter with NEXT leaves no future cell marked NEXT because the today cell has already returned its own state.
Blast radius: Block overview's NEXT marker can disappear or move incorrectly, and the rotation branch still needs a future calendar date even though rotation NEXT identifies a session slot.
Smallest fix: Retain or move the existing strictly-future date calculation into a separately named StartSlot operation, including its displayed-days boundary, and preserve the current assertions instead of treating them as assertions about today's startable slot.
Evidence: `plan.md:19`; `plan.md:34`; `today-layouts.md:364`; `fitbod/Periodization/BlockOverviewScreen.swift:429`; `fitbod/Periodization/BlockOverviewScreen.swift:442`; `fitbod/Periodization/BlockOverviewScreen.swift:451`; `fitbod/Periodization/BlockOverviewScreen.swift:463`; `fitbodTests/BlockOverviewStatesTests.swift:63`; `fitbodTests/BlockOverviewStatesTests.swift:72`.
Severity: fix soon.

Unverified: StartSlot has not been implemented, so this is an omitted extraction contract rather than an observed regression, and preserving a distinct future-date operation makes the proposed reuse feasible.
Evidence: `plan.md:19`; `plan.md:34`.

### Final ranking and verdict, spec item 3

**Final as written for implementation planning: 0 open blockers and 3 fix-soon findings.**

B-F1, B-F2 and F-F1 are closed at the proposal boundary, and the remaining findings are local guard, extraction-contract and test-expectation corrections rather than missing data or an impossible phase order.
Evidence: `plan.md:17`; `plan.md:19`; `plan.md:20`; `plan.md:33`; `plan.md:34`; `plan.md:36`.

| Rank | Current finding | Severity |
| --- | --- | --- |
| 1 | V5-F1: Preserve deloadAlertEnabled when moving the advisory ring to Volume on either stack. | fix soon |
| 2 | V5-F3: Keep Block overview's strictly future date distinct from the currently startable NEXT slot. | fix soon |
| 3 | V5-F2: Expect no notice after the lifecycle journey acknowledges the review and relaunches. | fix soon |

The historical v4 findings are retained above for provenance and are not included in the current counts.
All requested static-review items are complete, including the ten closure checks and the three v5 closure verifications.
Compilation, test execution and visual measurements remain unverified under the instruction to run no build or tests.

### Checked and correct in v5

- TodayState query ownership and Swift relationship filters.
- B-F1 input coverage.
- B-F2 usable no-block NEXT.
- F-F1 presenter-owned acknowledgement feedback.
- Builder template-case removal.
- Volume route registration.
- Program header and popover measurement.
- Phase 1 dependency order.

## Not reached

None within the requested static review.

