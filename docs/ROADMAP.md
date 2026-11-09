# Fitbod roadmap

This is the sole actionable plan for priorities, unfinished work, product decisions and acceptance criteria. Update the owning RM entry when scope, status, relationships or evidence changes; preserve stable RM anchors and original finding IDs. Technical contracts live in [ARCHITECTURE.md](../ARCHITECTURE.md); [design-map](design-map/) is dated evidence and approved design input.

Routine flow is **Planned → Active → Done**. The agent implements, runs risk-appropriate checks and updates docs; routine personal sign-off is not a gate. Use **Implemented; verification pending** when implementation is finished but a required external observation is unavailable. Name what remains unproven and block only work that actually requires it. Continue independent planning/development. A failed relevant check stays open; archive placement alone never proves acceptance.

**Requires** means a real prerequisite to the stated scope. **Scheduled after** records chosen delivery order, not a technical dependency. **Verify when** names a stability/release/integration trigger. Conditional requirements apply only to the named delivery. The title and “Done when” define outcome/observable acceptance; “Scope / sequence” names included deliveries, order and exclusions. Evidence separates shipped baseline from unverified remainder. Broad legacy entries have bounded deliveries or explicitly triggered follow-ups; do not leave them indefinitely “Partial”.

Reconciled 2026-11-08 against `ba27f304` and the existing working tree. Historical app test results below were not rerun for this documentation change. P1 protects core workout/data; P2 improves workflows; P3 is polish/optional expansion. Resolve correctness, privacy/security and data-integrity risks before extending affected paths; unrelated work can continue. Prove populated backup/recovery before schema-changing work and load provenance before mixed-unit analytics.

Keep concise commands/results/limitations with their RM owner. Logs/screenshots belong in CI artifacts or ignored local output. Finished substantial implementation plans move to [archive/features](archive/features/) with a historical banner, scope/build/results and RM backlink; no new backlog, tracker, report archive or personal approval process.

## Active work

No feature implementation is currently active. Documentation reconciliation is complete in [RM-043](#rm-043). Move the selected bounded outcome here when implementation starts; a phone-pending feature does not occupy the active slot.

## Next

This is the ordered dependency-ready queue; feature definitions below retain the full conditional sequence. Ready work in independent streams may continue while another feature awaits input.

| Order | Ready outcome | Boundary |
|---|---|---|
| 1 | [RM-001](#rm-001) preserve good stores on transient open failure | Protects backup/recovery and affected persistence paths. |
| 2 | [RM-002](#rm-002) remaining failed writes | Slot addition, resets and supersets are separate bounded deliveries. |
| 3 | [RM-003](#rm-003) render missing targets without writes | Before extending affected Volume rendering. |
| 4 | [RM-004](#rm-004) strip custom-photo location | Before extending photo/backup paths. |
| 5 | [RM-005](#rm-005) numeric/tempo boundaries | Current relabel-only units suffice; no circular wait for provenance. |
| 6 | [RM-006](#rm-006) session sheet, StartSlot and state slabs | Next approved Today/Program step; [reconciled notes](../.planning/quick/261106-ss3-session-sheet-startslot-and-state-slabs/261106-ss3-PLAN.md). |
| 7 | [RM-019](#rm-019) stalled exercises outside a workout | Independent analytics stream; [RM-020](#rm-020) past recaps follows, then broader analytics. |

After RM-001, [RM-029](#rm-029) populated recovery proof takes priority over schema-changing work. Preserve the approved Today/Program order: **RM-006 → RM-010 → RM-011 → RM-012 → RM-013 → RM-014 → RM-015 → RM-016 → RM-017 → RM-018**. Successors enter this queue as preceding work lands; planning may proceed meanwhile. Authoring, catalog, logging and calculator deliveries use their actual conditional prerequisites below, not the whole redesign as a gate.

## Needs input or device verification

Only the named observation/decision is unavailable; this section does not pause unrelated work.

| Owner | Missing input or proof | What depends on it |
|---|---|---|
| [RM-007](#rm-007), FT-19 | Exact repeated prompt text/owner on phone, then allow/deny/Focus reproduction | Identifying/fixing that prompt and its release acceptance. |
| [RM-008](#rm-008), FT-20 | Lock Screen/Island rendering, rest adjustment/expiry/end on installed build | Closing widget rendering/lifecycle acceptance; implementation plan is archived. |
| [RM-045](#rm-045), FT-16 | Physical small/large phone heatmap reach/calf taps | Closing clipping acceptance; RM-010 development can proceed. |
| [RM-046](#rm-046), FT-21 | Installed dark/tinted icon observation | Closing icon acceptance or deciding an observed mismatch remedy. |
| [RM-036](#rm-036)–[RM-041](#rm-041) | First-log PRs, rep-miss threshold, aggregate labels, adherence, applied per-set targets and stack attribution | Only behavior each decision changes; existing semantics remain. |
| [RM-021](#rm-021), [RM-053](#rm-053) | Provenance/legacy-data design; delivery/CI trigger policy | Stored unit changes; chosen CI policy, respectively. |

Gym ergonomics/stability and [RM-047](#rm-047) physical timer/VoiceOver checks return at workflow stability/release triggers. Request user involvement only for a specific unavailable observation or product choice, with build/reproduction details; routine checks stay with the agent.

## Later

| Outcome owners | Return condition |
|---|---|
| [RM-030](#rm-030), [RM-031](#rm-031) | Authoring/owning workflow stable and a specific approved capability selected; backup proof before schema changes. |
| [RM-032](#rm-032), [RM-033](#rm-033) | Explicit expansion beyond local phone-only v1. |
| [RM-034](#rm-034), [RM-035](#rm-035) | Named path touched/measurably slow, or screen design approved. |
| [RM-044](#rm-044), [RM-047](#rm-047) | Each workflow becomes stable; do not wait for whole-app stability. |
| [RM-048](#rm-048), [RM-049](#rm-049), [RM-051](#rm-051) | Release readiness/milestone close; touched docs update with every feature. |
| [RM-052](#rm-052), [RM-054](#rm-054) | Immediately if blocking iteration; otherwise stability/release or the named test reproduction. |

## Completed

Done covers the bounded implementation, appropriate agent-run checks and updated docs, without routine personal sign-off. Older broad claims without criterion-matched acceptance remain **historically shipped; acceptance unrecorded**; they do not require a whole-app retest. Stability/release/device outcomes stay with their owners.

| ID | Priority / status | Outcome and completion evidence | Dependencies / references |
|---|---|---|---|
| [RM-043](#rm-043) | P3 · Done | Completion policy, bounded roadmap/dependency semantics, current setup/widget docs and selected plan archives. Verification in RM-043; [plan/results](archive/features/development-workflow.md). | Documentation only; no app-runtime claim. |
| <a id="rm-055"></a>RM-055 | P1 · Historically shipped; acceptance unrecorded | Gym day author/start/log/relaunch/finish/history; transactional corrections/frozen WHY/cache invalidation. D-01/D-02 slotted-delete/rollback, D-03/N1 backup routines, D-04 edit screen delivered. Recorded persistence/edit/backup tests; T40 `32c8b65`, T41 `027536d`, rollback refresh `c3214985`. | [history design](design-map/mockups/history-editing.html), [service](../fitbod/Sessions/SessionEditService.swift), [contracts](../ARCHITECTURE.md#snapshots-and-corrections); remaining failed writes RM-002. |
| <a id="rm-056"></a>RM-056 | P1 · Historically shipped; acceptance unrecorded | Block plan/reorder/reschedule/deload/end/archive/review/next delivered 2026-11-05; recorded `RelaunchPersistenceTests.blockRunSurvivesRelaunches` acceptance, `7933e4c3`/`6a67849c`. D-06/D-25/D-40/D-45/D-47/D-96/D-97/D-161/D-166 delivered; new notice/origin remains RM-006/RM-013/RM-016. | [relaunch test](../fitbodTests/RelaunchPersistenceTests.swift); real block stability still open. |
| <a id="rm-057"></a>RM-057 | P1 · Done for step 1.1 | Redesign 1.1 TodayState/plan line/day refresh/oldest-ready/advisory. Removed stat strip/block band/week cells/deload banner/plan-complete note. 23 state tests/captures `a3b3ead4`–`56dc453c`; full run had 5 failures/1 expected, with fixes/remaining risks owned separately; [plan/results](archive/features/today-state-and-plan-line.md); D-159/D-341 elements replaced. R-2/R-4/R-6/R-8/R-13: today.root/Progress history entry, calendar refresh, shared BlockPosition and long-name layout shipped. | [state](../fitbod/Views/TodayState.swift), [position](../fitbod/Periodization/BlockPosition.swift); does not complete 1.3. |
| <a id="rm-058"></a>RM-058 | P1 · Done for step 1.2 | Redesign 1.2 TODAY/NEXT UP hero/shared phase counts/calendar, EXERCISES/View, removed chips/warmup/day counter (R-17). Helper/factory/hero tests and 17e light/dark captures, `0b2a8187`–`3cb65f6b`; focused helper/factory 37/37, starter 21/21, hero 2/2 passed. Full run 1,339/1,342 passed, 2 failures/1 expected; [plan/results](archive/features/today-hero-and-exercises.md). | RM-057; [hero](../fitbod/Views/BlackSlabCTA.swift), [set-count rule](../fitbod/Prescription/PeriodizationEngine.swift); run limits RM-001/RM-048. |
| <a id="rm-059"></a>RM-059 | P1/P2 · Done for listed code scope | FT-01–12/FT-14/15/17/18: logger discard/exercise actions/Today return, one header/catalog addition, carry-forward/LAST TIME/RPE/type/Why/compact sections, dark slabs/one routine action, volume/detail/amber. Commit-specific unit/UI evidence `55c59656`–`d89992fb`/`35ff44f5`; [plan/results](archive/features/playtest-fixes.md); WorkoutExitUITests covers Program start/resume Back. | [logger](../fitbod/Sessions/SessionLoggerView.swift), [set actions](../fitbod/Sessions/SessionSetActions.swift); FT-16/19/20/21 and redesign remainders open. |
| <a id="rm-060"></a>RM-060 | P3 · Done for FT-13 | **FT-13 shipped** `af274c08`: paper BRU finish sheet, set count/elapsed time, signal Finish (Discard if empty), Keep logging. 23 affected tests passed; 430pt content-height capture; [plan/results](archive/features/playtest-fixes.md#finish-confirmation). | [logger](../fitbod/Sessions/SessionLoggerView.swift); no phone-pass claim. |
| <a id="rm-061"></a>RM-061 | P1/P2 · Historically shipped; acceptance unrecorded | One e1RM F332/work-set tonnage rule/shared PR replay F236/export snapshot; calendar DST/week/block math T139/T142 F333/F334/F359/F363. PR/weekly rows open summaries T136/T118 D-15/D-175/D-296. Folder/list/card/row UI deleted, schema folder kept. Swap Undo/Library tab fixes `a91184cd`/`1fe3348e`/`a25ced57`; History delete reveal `3febe870` passed alone. | [e1RM](../fitbod/Prescription/OneRepMaxEstimator.swift), [calendar tests](../fitbodTests/WeekWindowCalendarTests.swift), [snapshot](../fitbod/Export/ExportSnapshot.swift), [PR design](design-map/mockups/pr-workout-detail.html). T143/T119 suite trimming/budgets shipped; release work stays open. |

## Feature definitions

### <a id="current-focus"></a>Core correctness and the next redesign step

Finish one gym day reliably, then running a block, then the approved Today/Program redesign in order: 1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6, followed by phase 2.
Steps 1.1–1.2 shipped ([RM-057](#rm-057), [RM-058](#rm-058)); 1.3 is the next planned redesign step.
Resolve data risks in the paths being changed before adding more prototype behavior.
Each redesign step keeps affected tests serial on dedicated simulators and captures its changed 390pt states in light and dark. Broader AX3/two-phone/VoiceOver work returns at stability. For Program changes, keep NewBlockBuilderFidelityTests, ProgramViewFidelityTests and AdaptiveColorSourceTests in the affected checks.

### <a id="rm-001"></a>RM-001 — Preserve a good store when opening fails

**P1 · Planned.** `FitbodModelContainer.make` catches every on-disk container error as incompatibility and moves the store aside. A transient SQLite short read reproduced this during the step-1.2 relaunch run.
**Done when:** distinguish incompatibility from transient access/I/O failures; a good store stays in place on transient failure, a recoverable error explains retry, and retry preserves workouts. Keep incompatible-store recovery, SQLite siblings, seed stamps and partial move failures covered by disk-backed tests.
**Scope / sequence:** Classify open failures → preserve files/retry → test disk recovery, SQLite siblings and seed stamps. Catalog repair and schema evolution are excluded.
**Requires:** None.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [container](../fitbod/Persistence/FitbodModelContainer.swift), [recovery tests](../fitbodTests/Persistence/IncompatibleStoreRecoveryTests.swift); step-1.2 run `full-20261107-074201`, SQLite error 4618, in the retired `261106-he2` summary.

### <a id="rm-002"></a>RM-002 — Failed writes preserve work and explain retry

**P1 · Planned: remaining write failures.** D-08, D-20, D-59 and D-153 remain: routine-editor errors/shared rollback improved, but slot addition, plate/volume resets and superset creation still contain ignored saves.
**Done when:** these paths show actionable errors, roll back pending mutations and permit later saves. Discarding a session editor leaves no orphan superset. Test failures through the real mutation paths; preserve shipped lifecycle/finish/history rollback (D-01/D-02/D-155).
**Scope / sequence:** Deliver separately: slot addition (D-08), plate/volume resets (D-20/D-59), then superset creation/discard (D-153). For each, inject a failed save and prove rollback/error/retry before advancing. Shipped lifecycle/history rollback stays the baseline; no unrelated editor redesign.
**Requires:** None; preserve shipped rollback contracts.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [D-08](design-map/audit.md#d-08), [slot picker](../fitbod/Periodization/SplitDetailView.swift), [supersets](../fitbod/Routines/SupersetAssignmentSheet.swift), [plates](../fitbod/Settings/PlateInventoryEditor.swift), [targets](../fitbod/Settings/MuscleVolumeTargetEditor.swift); `c3214985`, `dcd3cfcb`.

### <a id="rm-003"></a>RM-003 — Rendering missing volume targets never writes models

**P1 · Planned.** The former volume-boundary/render-audit priority is partly shipped: calendar arithmetic is fixed, but both volume views still construct fallback `MuscleVolumeTarget` models attached to persisted muscles while rendering.
**Done when:** prove missing-target rendering inserts/changes no persisted object or relationship; use immutable fallbacks where needed. Explicit target creation stays validated and reports errors. Cover surface and muscle detail.
**Scope / sequence:** Reproduce missing targets → replace render-time models → prove surface/detail render without writes. No fatigue-math or target-editor redesign.
**Requires:** None.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [volume surface](../fitbod/Fatigue/FatigueSurfaceView.swift), [muscle detail](../fitbod/Fatigue/PerMuscleDetailView.swift), [shipped calendar work](#rm-061).

### <a id="rm-004"></a>RM-004 — Custom photos do not carry location into backups

**P1 · Planned.** D-111 found picked image data, including location metadata, retained in models/backups.
**Done when:** reproduce with a geotagged photo; persist/export the intended image without location/unnecessary metadata, preserve orientation, and test the stored/backed-up result. Define how existing photos are sanitized without losing them.
**Scope / sequence:** Reproduce metadata leakage → sanitize new and existing photos safely → inspect stored/exported bytes. Preserve the original until replacement succeeds; no photo-library expansion.
**Requires:** None.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [D-111](design-map/audit.md#d-111), [photo picker](../fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift).

### <a id="rm-005"></a>RM-005 — Numeric and tempo entry preserve the entered value

**P1 · Planned.** Preserve comma-decimal failures D-32/F355, duplicate/zero plate input D-31/D-189 and pasted tempo separators F383. T145 fixed ordinary empty-part tempo corruption F380.
**Done when:** locale-valid weights round-trip without prefix parsing; duplicates cannot create ambiguous plate row IDs; invalid/zero values explain rejection; pasted dashes cannot shift tempo parts. Test actual parsers/save boundaries and preserve signed assistance loads and history-correction validation.
**Scope / sequence:** Deliver locale weight parsing, unique positive plate values, then pasted tempo validation at shared save boundaries. Keep relabel-only units; conversion/provenance is RM-021.
**Requires:** None; current unit semantics suffice.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [D-31](design-map/audit.md#d-31), [D-32](design-map/audit.md#d-32), [D-189](design-map/audit.md#d-189), [tempo](../fitbod/Sessions/TempoEntryRow.swift); F355/F380/F383.

### <a id="rm-006"></a>RM-006 — Redesign 1.3: session sheet, StartSlot and state slabs

**P1 · Planned.** Implement the approved [Today layouts](design-map/redesign/today-layouts.md) and [hierarchy](design-map/redesign/hierarchy.md). The [reconciled implementation notes](../.planning/quick/261106-ss3-session-sheet-startslot-and-state-slabs/261106-ss3-PLAN.md) are subordinate input; this entry owns scope and status. GSD/executor, capture-commit and full-suite mandates in the old notes are retired.
**Done when:**

- One pure `StartSlot` rule serves hero, session sheet, Program and session detail. Rotation NEXT is the resolver's next slot; weekday NEXT is today's slot before a counted workout, otherwise the next training day's slot. No-block NEXT advances from the newest finished slotted workout, skips empty sessions and wraps.
- A twice-slotted session passes NEXT when it matches, otherwise the first matching slot after NEXT. Outside-routine starts are unslotted. Rotation/no-block rows explain skipped sessions; weekday rows skip nothing. Detail computes at tap time so deleting a slot cannot leave a stale start.
- The sheet has CANCEL, one start-on-tap row per distinct routine session, NEXT only on a usable row, disabled empty rows, and Other sessions opening detail. Rows fit content with 44pt minimum targets.
- T-PICK suggests the eligible routine holding the newest finished slotted workout, otherwise the one holding the most recently updated usable session, otherwise a standalone session. A fresh store gives T-FIRST; an empty routine gives no-block T-FIX. Block repair/T-ATTACH retain another-session access when any usable session exists.
- T-DONE lists every counted workout started today, newest first, and outranks T-READY. Its final slab is paper on paper in both appearances (FT-15); current dark `bruSlab` is interim. T-REST says REST DAY. T-READY starts the oldest ready block in one tap, shows creation date/ready count and reports failure.
- Remove obsolete Today block-creation/empty-session placeholders, StartBlockCTA/template builder case and unused conflict presentation. Preserve the logger's Today route (O-16). Another session takes two taps from T-TODAY; mistaken start costs Back then Discard.
- Test state/slot precedence and starts through sheet/detail, including duplicate/deleted slots, two no-block starts, standalone/empty routines and two done workouts. Add ready/empty/done seeds with all finished-today timestamps between local midnight and launch. Run affected factory/resolver/start/journey checks and inspect 390pt/default/light states.

**Scope / sequence:** Pure slot/state rules → shared starter/detail/Program callers → sheet/slabs → seeds and affected checks. SchemaV7 unchanged; volume summary RM-010, review RM-013 and next-day lines RM-014 are excluded.
**Requires:** [RM-057](#rm-057), [RM-058](#rm-058). Resolve RM-001–RM-005 where the changed path relies on those safeguards; unrelated work continues.
**Scheduled after:** Steps 1.1–1.2 are shipped; next Today/Program implementation.
**Verify when:** Affected logic/UI starts and 390pt light/dark states at implementation; broader AX/phone checks at stability.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-19/D-24/D-25/D-162–D-165, redesign R-4/R-5/R-10/R-12/R-19/R-23/R-25; [TodayState](../fitbod/Views/TodayState.swift), [picker](../fitbod/Views/TodaySessionPicker.swift), [session detail](../fitbod/Routines/SessionTemplateDetailView.swift), [O-2/O-3/O-6](#rm-042).

### <a id="rm-007"></a>RM-007 — FT-19: identify the repeated permission prompt

**P1 playtest / P2 Live Activities release work · Planned; phone reproduction needed.** No phone observation is recorded; the prompt owner remains unknown. Code requests notification alert/sound authorization once and one activity per rest; inspection does not identify the reported “Always Allow” prompt or prove its text legible.
**Done when:** capture exact text/choices/owner; ordinary rests respect authorization, work when denied and do not repeat an answered prompt.
**Reproduction:**

1. On a disposable installation without training data, install current main, start/log a set with Focus off and capture the entire prompt, build and iOS version.
2. Allow it, log another set and record whether it returns.
3. Repeat first use with Focus on, then with Live Activities denied in Settings → Fitbod. In-app rest must work. Back up before replacing a populated installation.
4. If ownership is unclear, immediately collect the phone log on the Mac: `sudo log collect --device --last 1h --output ~/Desktop/fitbod-phone.logarchive` (`--device` takes the one paired phone; `--device-udid` wants the hardware UDID that `xcrun xctrace list devices` prints, not the devicectl identifier, which fails with “Device not configured (6)”; collection needs root). Inspect Fitbod/ActivityKit events locally.

**Scope / sequence:** Capture exact prompt → identify owner → fix a reproduced defect → repeat allow/deny/Focus cases. Existing authorization code does not prove the reported prompt.
**Requires:** Disposable physical iPhone installation and exact prompt observation; no other feature prerequisite.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** FT-19/SESS-04; [activity controller](../fitbod/Sessions/RestTimer/RestTimerActivityController.swift), [release pass](#rm-047).

### <a id="rm-008"></a>RM-008 — FT-20: prove Lock Screen rendering on the phone

**P1 playtest / P2 Live Activities release work · Implemented; verification pending.** Bundle correction shipped in `03199d32`: Assets.car, six fonts and UIAppFonts now reach the widget. Bundle contents were inspected; Debug `3c8478e1` was installed on iPhone 15 Pro Max on 2026-11-08. Mac launch was refused while locked; no human rendering check ran.
**Done when:** exercise/countdown render on Lock Screen and compact/expanded Dynamic Island; background, adjustment, expiry and workout end update/clean up one activity.
**Reproduction:** with music playing, log a set, lock and inspect card/Island. Adjust −15s/+15s, let a rest expire, background during rest and finish. If blank, capture model, iOS/build and foreground state. App termination, denial and duplicates also belong to RM-047.
**Scope / sequence:** Completed implementation: widget resource membership/font registration. Remaining delivery is phone rendering/lifecycle proof; an observed defect returns to Active. Prompt identification stays RM-007.
**Requires:** Physical iPhone/current installed build for remaining proof; RM-007 is a separate investigation.
**Verify when:** With music/rest on the installed phone: Lock Screen/Island, adjustment, expiry and end. Bundle inspection proves resources only.
**Evidence:** Historical build/bundle evidence below; the required phone result remains unproven.
**Archive:** [completed widget implementation](archive/features/playtest-fixes.md#widget-resources-and-device-limits); archive closure does not prove rendering.
**References:** FT-20/SESS-04; [widget](../FitbodWidgets/RestTimerLiveActivity.swift), [resource membership](../fitbod.xcodeproj/project.pbxproj).

### <a id="rm-009"></a>RM-009 — Recover catalogs damaged by the former reseed

**P1 · Planned investigation.** F351 documented dangling exercise links/launch crashes in stores damaged before T128's safe incremental reseed. Fixing future imports did not repair those stores.
**Done when:** reproduce on an untouched copy (seed bump 1→2, `1d5d76f`, or pre-`c0b8d17` test data), identify recoverable history and test a recovery preserving sets, customs and snapshot names. A clean reset is not a repair.
**Scope / sequence:** Work on an untouched damaged-store copy → identify repairable links → test history-preserving recovery. A reset is not recovery; catalog expansion excluded.
**Requires:** Untouched damaged-store copy; [RM-001](#rm-001) safe opening before repair writes to a live store.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** F351; [importer](../fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift), [snapshots](../ARCHITECTURE.md#snapshots-and-corrections).

### Workflow deliveries

Within new analytics screens, the four approved must-have mockups come first: history editing and PR workout detail shipped; stalled exercises and past recaps remain.
Unit provenance and catalog retain their existing P1 priority alongside the approved redesign sequence.

### <a id="rm-010"></a>RM-010 — Redesign 1.4: full volume behind a summary row

**P1 · Planned: Today summary row.** Progress → Volume, muscle routes, neck detail, bar chevrons and map caption shipped early for FT-17/18 (`d89992fb`). Today still needs the compact row/removal of its full surface.
**Done when:** Volume is one tap from Today/Progress, forwarding their stack paths. Today's VOLUME THIS WEEK counts finished counted workouts/their working sets, excludes open/empty workouts and refreshes at the calendar week boundary/activation/day change. Volume evaluates advice on appear; shared evaluator gates `deloadAlertEnabled` for both tabs. Test counts/calendar/alerts-off.
Count outside view rendering, keyed by finished-workout changes and the week start, so Today does not run the full fatigue model on every render. The complete model runs when Volume opens.
**Scope / sequence:** Shared weekly counts/evaluator gating → Today summary → remove Today full surface → week changes/routes. Existing Progress Volume stays; physical clipping is RM-045.
**Requires:** Shared counted-workout rules; [RM-003](#rm-003) before extending affected volume rendering.
**Scheduled after:** [RM-006](#rm-006).
**Verify when:** Counts/routes/advice-off at implementation; [RM-045](#rm-045) physical reach remains separate.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [Today layouts](design-map/redesign/today-layouts.md), D-131, redesign R-7/R-21; [Progress](../fitbod/Progress/ProgressHomeView.swift), [advisor](../fitbod/Fatigue/DeloadAdvisor.swift).

### <a id="rm-011"></a>RM-011 — Redesign 1.5: Program explains Now, Planned and Past

**P1 · Planned.** Follow [Program layouts](design-map/redesign/program-layouts.md).
**Done when:** active block first in a four-line Now slab without cells; ink + New/44pt header preserves popover geometry/z-order. Ready lead uses oldest-created/name/ID, date/count and start errors; drafts-only leads with newest draft/CONTINUE BLOCK. Planned cards use outlined chips/missing pieces; routines use sublines; Past blocks show year across years. Empty Program is routine-first with archive access. Preserve block labels/CREATE BLOCK sheets, move DONE-card tests to Past blocks, pass origin to overview, inspect long names and re-tally budget (P-ACTIVE eight elements above fold).
**Scope / sequence:** Now/ready/draft ordering → Planned/Routines/Past → origins/long names/budget. This week actions and resume/discard remain RM-015/RM-012.
**Requires:** Existing block lifecycle/origin routes and approved Program layouts.
**Scheduled after:** [RM-010](#rm-010).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-125–D-127/D-299–D-304, redesign R-9/R-11/R-23; [Program](../fitbod/Periodization/ProgramView.swift), [budget](design-map/redesign/screen_budget.py).

### <a id="rm-012"></a>RM-012 — Redesign 1.6: visible Program resume/discard

**P1 · Planned.** Paper row with RESUME and visible ghost DISCARD.
**Done when:** no long press; Discard names lost sets and confirms only with logged sets, matching Today. While open, every other Program signal action becomes ink so Resume is the one orange action. Record the empty-discard exception in interaction rules and inspect every underlying state.
**Scope / sequence:** Expose Resume/Discard → reuse Today confirmation → restyle other actions → check each Program state. No logger ownership changes.
**Requires:** Existing Today discard rule.
**Scheduled after:** [RM-011](#rm-011).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-56/D-57/D-126, redesign R-12; [banner](../fitbod/Sessions/ResumeWorkoutBanner.swift), [confirmation rule](design-system/interaction.md#confirmation).

### <a id="rm-013"></a>RM-013 — Redesign 2.1: opt-in review notice

**P2 · Planned: opt-in notice and close acknowledgement.** End/reopen and acknowledgement-on-open shipped; opt-in notice/acknowledgement-on-close remain planned.
**Done when:** replace automatic review with a notice in every no-active-block state except T-RESUME, including T-DONE. Shared presenter retains the opened block through dismissal and acknowledges once, preserving first reviewedAt; failed save keeps notice and says “Couldn't save the review. Open it again to retry.” under the opening row. Start next acknowledges before its builder. Preserve origin/remove unused acknowledge path. Recap presents when due independently; review outranks advisory. Test first/second/failed close and relaunch at the persistence boundary.
**Scope / sequence:** Shared review presenter → close acknowledgement/retry → recap coordination → persistence/relaunch checks. Past-recap browsing and broader analytics excluded.
**Requires:** Existing end/review persistence and rollback; [RM-002](#rm-002) if its changed save path is affected.
**Scheduled after:** [RM-012](#rm-012).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-06/O-4/O-5, redesign R-3/R-18/R-20/R-26; [review](../fitbod/Periodization/BlockReviewView.swift), [hierarchy](design-map/redesign/hierarchy.md), [review tests](../fitbodTests/BlockReviewMathTests.swift).

### <a id="rm-014"></a>RM-014 — Redesign 2.2: next-session/day lines

**P2 · Planned.** T-DONE/T-REST name the same NEXT as the sheet.
**Done when:** weekday uses next training date and its resolved slot; rotation retains NEXT after unslotted workouts. Move overview's next-training-date helper into StartSlot without changing its distinct week-strip NEXT marker. Done has no orange action. Cover rest/trained-today/rotation/overview cases.
**Scope / sequence:** Extract date helper into StartSlot → Done/Rest next lines → compare overview behavior. Preserve overview week-strip semantics; no scheduling-model expansion.
**Requires:** [RM-006](#rm-006) StartSlot.
**Scheduled after:** [RM-013](#rm-013).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** redesign R-27; [Today layouts](design-map/redesign/today-layouts.md), [overview](../fitbod/Periodization/BlockOverviewScreen.swift), TodayResolverTests/BlockOverviewStatesTests.

### <a id="rm-015"></a>RM-015 — Redesign 2.3: Program's This week agrees with Today

**P2 · Planned.** Seven weekday groups or rotation strip use Today's state function, queries and calendar.
**Done when:** each counted workout appears once on its actual day and opens summary; open workout is read-only IN PROGRESS. Planned TODAY/NEXT starts show only in T-TODAY and pass StartSlot; empty sessions open repair detail. Cover off-plan/swapped/rest/two-workout days and T-RESUME/T-DONE/T-FIX.
**Scope / sequence:** Share state/calendar → logged/planned rows → summary/start routes → off-plan/multi-workout checks. No new adherence metric.
**Requires:** [RM-006](#rm-006) shared starts/state, [RM-011](#rm-011) Program surface, [RM-014](#rm-014) next-day rules.
**Scheduled after:** [RM-014](#rm-014).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** redesign R-22/R-24; [Program layouts](design-map/redesign/program-layouts.md), [TodayState](../fitbod/Views/TodayState.swift).

### <a id="rm-016"></a>RM-016 — Redesign 2.4: review origin/end consequences

**P2 · Planned: shared origin and retry.** Review reopening/end-to-review exist; shared close/retry/origin behavior remains.
**Done when:** End explains its consequence; past review opens from Program in three taps and its builder returns to PROGRAM; opening through Today returns to TODAY. Failed acknowledgement appears under the launching row.
**Scope / sequence:** Explain End → carry origin through review/builder → expose close retry → verify return paths. Undo End excluded.
**Requires:** [RM-011](#rm-011) Program origin and [RM-013](#rm-013) close/retry behavior.
**Scheduled after:** [RM-015](#rm-015).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-40; [overview](../fitbod/Periodization/BlockOverviewScreen.swift), [layouts](design-map/redesign/program-layouts.md).

### <a id="rm-017"></a>RM-017 — Redesign 2.5: readable volume without seventeen empty rows

**P2 · Planned: collapsed untrained muscles.** FT-18 amber below-MEV bars/figures/legend shipped; collapsed untrained rows/date label remain.
**Done when:** fresh week shows one expandable “n muscles not trained yet” row and a heatmap date range. Dark 2-of-4 hamstrings, zero, under-target, in-range and landmark ticks read distinctly. Keep muscle routes.
**Scope / sequence:** Collapse untrained rows → date range → inspect landmarks/amber/routes. Aggregate wording waits only where RM-038 changes it; physical clipping stays RM-045.
**Requires:** Existing Volume surface and [RM-003](#rm-003) safe fallback rendering.
**Scheduled after:** [RM-016](#rm-016).
**Verify when:** Collapse/date/routes at implementation; RM-038 wording only where affected.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** FT-18/VOL-04/05; [volume](../fitbod/Fatigue/FatigueSurfaceView.swift).

### <a id="rm-018"></a>RM-018 — Redesign 2.6: empty routine picker offers repair

**P2 · Planned.** PICK A ROUTINE says “No routines yet. + New routine”.
**Done when:** with no routine, + New block reaches + New routine in one tap; builder fidelity/copy/activation checks pass.
**Scope / sequence:** Empty-routine repair action → retain builder draft/return state → builder checks. No full inline creator.
**Requires:** Existing builder/routine creation routes.
**Scheduled after:** [RM-017](#rm-017).
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-162 (picker half); [builder](../fitbod/Periodization/BlockBuilderView.swift).

### <a id="rm-019"></a>RM-019 — Stalled exercises outside a workout

**P2 · Planned.** Build the approved [stalls mockup](design-map/mockups/stalled-exercises.html).
**Done when:** Progress lists stalls with intent, stalled-workout count, last top set and suggested action; rows open charts that also mark stalls. Add-volume/drop-intensity suggestions lead somewhere useful or explain their limitation instead of silent no-ops.
**Scope / sequence:** Reuse plateau results → stall list/chart routes → useful suggestion routes or explained limits. Advice stays non-mutating; broader trends excluded.
**Requires:** Existing plateau math; preserve advisory-only behavior.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-21/PROG-06; [Progress workflow](design-map/workflows/check-progress.md), phase-5 deferred chip routes.

### <a id="rm-020"></a>RM-020 — Reopen past weekly recaps

**P2 · Planned.** Build the approved [recaps mockup](design-map/mockups/all-recaps.html). Deferred out of this redesign, not cancelled.
**Done when:** Progress/recap open a week list with tonnage, working sets and records; rows reopen that week's recap; corrected history updates it. Keep automatic once-weekly sheet per O-4.
**Scope / sequence:** Week-list queries → selected recap → correction refresh and automatic-sheet coexistence. No new review acknowledgement rule.
**Requires:** Existing recap math, counted-week rules and correction invalidation.
**Scheduled after:** [RM-019](#rm-019) in the analytics stream; planning is independent.
**Verify when:** Week selection/correction at implementation; with [RM-013](#rm-013) when presentation coordination changes.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-27/all-recaps/VOL-07; [recap](../fitbod/Fatigue/WeeklyRecapSheet.swift).

### <a id="rm-021"></a>RM-021 — Load provenance before explicit conversion

**P1 · Planned.** Unit changes relabel stored numbers; exercise overrides win. No canonical converted store exists. F157 identifies mixed kg/lb totals.
**Done when:** store each logged load's unit, define explicit conversion/historical interpretation and reconcile history, PRs, calibration, progression, exports and tonnage before offering conversion. Tests protect originals/overrides. Correct misleading canonical-unit copy and explain relabeling.
**Scope / sequence:** Approve provenance/legacy interpretation → prove backup → logged-unit schema → reconcile consumers → explicit conversion only when originals remain safe. No implicit conversion.
**Requires:** Approved provenance/schema/legacy-data decision and [RM-029](#rm-029) populated backup/recovery proof before stored-data changes.
**Verify when:** Populated restore before schema changes; relaunch and all load consumers after changes.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-66/D-71/F157; [unit tests](../fitbodTests/SettingsUnitsIntegrationTests.swift), [contracts](../ARCHITECTURE.md#units-and-aggregates).

### <a id="rm-022"></a>RM-022 — Catalog curation and safe import

**P1 · Planned: next catalog update validation.** Stable-ID incremental import exists; FT-05 Single-Leg Kneeling Leg Curl (hamstrings/machine) shipped at seed v3 (`0892c2cf`). Former 900-record/702-import counts predate it.
**Done when:** updates preserve customs, stable IDs, edited stimuli and historical links; validate duplicates, missing equipment/muscles, natural searches and offline/image fallbacks. Curate pattern/grip metadata before exposing filters. Duration/distance models precede expansion beyond supported lifting types; count alone is not acceptance.
**Scope / sequence:** Next delivery: validate a stable-ID update on a healthy populated store, including customs/stimuli/duplicates/search/image fallbacks. Pattern/grip curation returns before exposing those filters; duration/distance support needs an approved model scope. Damaged-store repair stays RM-009.
**Requires:** Existing importer. [RM-004](#rm-004) before extending custom-photo persistence; [RM-009](#rm-009) only for damaged-store recovery, not healthy-store curation.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** LIB-01–06/FT-05; [importer](../fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift), [seed source](../fitbod/Resources/ExerciseSeed/SOURCE.md).

### <a id="rm-023"></a>RM-023 — Comparable analytics and useful detail routes

**P2 · Planned: comparable detail routes.** Charts, PR replay, comparison, weekly tonnage and PR workout detail exist; richer trends remain.
**Done when:** selected periods/intent/units give comparable series and sparse/empty explanations; phase chips actually filter; Compare appears for eligible histories/describes the real 14-day rule; older lifts and exercise records are reachable from history/chart/detail. Add weekly muscle-set history against landmarks. Reconcile aggregates to sets and resolve overlapping stacks before claiming additive totals.
**Scope / sequence:** Deliver comparable period/intent/sparse routes, then eligible Compare/older-record routes. Mixed-unit series require RM-021; additive stacks require RM-041. Weekly muscle-set history returns after these and stalls/recaps as a separate bounded analytics delivery.
**Requires:** [RM-021](#rm-021) for mixed-unit series; [RM-041](#rm-041) before additive stacks. Neither blocks same-unit navigation fixes.
**Scheduled after:** [RM-019](#rm-019), [RM-020](#rm-020) before broader analytics screens.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** PROG-01–08, D-28/D-48/D-72/D-74–D-80/D-130/D-132/D-134–D-135, F318/F341/F342; [workflow](design-map/workflows/check-progress.md).

### <a id="rm-024"></a>RM-024 — Compact logging preserves context and reach

**P2 · Planned: logging reach/reveal.** FT-06–12 shipped carry-forward, LAST TIME, labelled RPE, type picker, persistent Why, removed inline plates and collapsible exercises.
**Done when:** remeasure current density first; keep 44pt actions, matching-intent history and selected whole/decimal RPE readable; next set remains reachable above keyboard/rest dock. Manual/explicit targets outrank carry-forward; RPE stays fresh. Resolve remaining advance/reveal, finish discoverability and keyboard obstruction; a Live Activity opens the workout today but automatic scrolling to its rested set remains unshipped. AX3 joins when stable.
**Scope / sequence:** Measure a logging/keyboard obstruction → fix shared reveal/advance → verify context/44pt reach. Finish styling shipped in RM-060. Live Activity automatic scrolling returns with its set route; AX3/VoiceOver at stability.
**Requires:** Logging invariants and a reproduced reach/reveal issue.
**Verify when:** 390pt default-text keyboard/rest interactions now; [RM-044](#rm-044) at stability.
**Evidence:** Exercise-level weight guidance and the compact effort control are implemented with verification pending. The logger shows the rep target and starting-weight prompt when there is no load to suggest. The suggestion stays available after logging, weight fields accept direct edits during calibration, and effort expands within the set being rated. Updated checks cover restoring the frozen weight, editing a calibration load directly, and recording a half-step effort after logging. Swift syntax, design-map, and token contrast checks passed. The unit suite, affected logger journeys, and a 390pt default-text light-mode inspection remain open.
**References:** FT-08/FT-09, D-10/D-88–D-93, F19/F356/F357/F382; [weight guidance](../fitbod/Sessions/WorkoutWeightGuidance.swift), [workflow](design-map/workflows/log-a-workout.md), [set actions](../fitbod/Sessions/SessionSetActions.swift).

### <a id="rm-025"></a>RM-025 — Plate calculator from a working set

**P2 · Planned.** Keep standalone calculator/inventory; FT-11 deliberately removed the inline graphic.
**Done when:** logger opens it with set weight/equipment and returns to that set; TARGET accepts typing; equipment switches in-place. Inventory handles actual counts, explains autosave/unit-specific defaults and calculator read-only rows look read-only. A real 225/315 load takes no dozens of taps.
**Scope / sequence:** Repair numeric input → prefill calculator from a set → return to that set → verify equipment/inventory. Keep standalone access; removed inline graphic excluded.
**Requires:** [RM-005](#rm-005) numeric/plate validation. Keep current relabeling; provenance only if conversion is introduced.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-12/D-14/D-114–D-121; [plate workflow](design-map/workflows/plates-and-the-calculator.md), logger-plate-calculator/typed-target/equipment-switch/plate-inventory-saved-note.

### <a id="rm-026"></a>RM-026 — Session/routine authoring without detours

**P2 · Planned.** Superset partners, multi-exercise selection, block/hybrid progression and archived inspection remain.
**Done when:** name supersets' acting exercise/partners/effect in one trip, including unsaved sessions; duplication preserves/confirms unsaved edits; multi-select adds the stated count in order. Progression eligibility reads active graph, not deprecated template.block. Inspect archived routines before restore. Preserve drafts/rollback/snapshots.
**Scope / sequence:** Deliver supersets (partners/effect/unsaved rollback), then unsaved duplication, then ordered multi-select, then graph-based progression eligibility and archived inspection. Each is a bounded authoring delivery; applied per-set targets stay RM-040.
**Requires:** [RM-002](#rm-002) for affected superset/editor writes; [RM-040](#rm-040) only before exposing applied per-set targets.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-09/D-33/D-61–D-63/D-85/D-140–D-142/D-152; [session](design-map/workflows/build-a-session-and-its-prescription.md)/[routine](design-map/workflows/build-a-routine.md) workflows.

### <a id="rm-027"></a>RM-027 — Library/custom flows finish where expected

**P2 · Planned: saved-result navigation.** Creation/edit/copy/search prefill exist; finish filtering, saved-result navigation and image display.
**Done when:** create/copy opens its result, delete returns to Library, custom-only filtering/duplicate-muscle behavior are clear, empty filters offer repair. PATTERN/TEMPO/BAR WT/INCREMENT fields require supported metadata/prescription semantics, not inert controls.
**Scope / sequence:** Deliver create/copy → saved result and delete → Library routes with retry intact. Filters/duplicate-muscle explanations return when those paths are next touched; PATTERN/TEMPO/BAR WT/INCREMENT require catalog/prescription semantics. No inert fields.
**Requires:** [RM-004](#rm-004) for photo writes; catalog/prescription semantics only for fields using them.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** D-51–D-55/D-69–D-70/D-82–D-83/D-94, custom-exercises-filter, T48 field follow-ups; [workflow](design-map/workflows/find-and-create-exercises.md).

### <a id="rm-028"></a>RM-028 — Remaining approved workflow redesign findings

**P2 · Planned.** Deduplicated home for remaining “With the redesign” D-rows. Each dated [audit row](design-map/audit.md) links its RM owner; its problem/evidence defines the outcome, not a second status list.
**Done when:** reproduce each mapped finding on current code and deliver its intended behavior or record an approved supersession here. Apply shared patterns once: 44pt targets P-2, terms P-3, readable signal text P-6, sheet exits P-8, confirmations P-9, BRU controls P-10, real actions P-11, fixing empty states P-12. Include week-start/deload-alert settings (F364: honor Sunday even in a Monday-first region), permission rationale/denial guidance, default targets and block-repair copy. Do not defer data/privacy defects here.
**Scope / sequence:** Select mapped D-rows for the owning workflow before editing → reproduce → shared fix → record that bounded result here. Other rows return on their workflow redesign; do not mark this entry Done with undispositioned findings.
**Requires:** Approved owning-workflow scope and [RM-042](#rm-042) product rules; not every product decision is a prerequisite.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** [patterns](design-map/audit.md#patterns), [dated missing-screen inventory](design-map/missing-screens.md), [workflows](design-map/workflows).

### <a id="rm-029"></a>RM-029 — Populated backup and truthful backup state

**P1 · Planned: recovery proof before schema changes or release reliance.** T41 fixed routines/snapshot names; real populated second-install restore remains unproven.
**Done when:** restore populated backup on another installation and compare entities/slots/sets/history/names; validate corrupt/hostile input before mutation, recover interruptions and retain pre-restore copy. Show last-backup date/time/content, warn about open workouts before Files and explain manual relaunch accurately.
**Scope / sequence:** Prove populated restore on another installation → hostile/corrupt/interrupted input and pre-restore recovery → truthful backup state. New schema/format, automated backup and conversion excluded. Healthy restore does not wait for damaged-catalog repair.
**Requires:** [RM-001](#rm-001) safe open. Healthy populated fixtures suffice; RM-009 only for a restore claiming damaged-catalog repair.
**Scheduled after:** [RM-001](#rm-001), ahead of schema-changing work; independent of the redesign sequence.
**Verify when:** Before schema changes, sole-log reliance or release: populated second installation, corrupt/interrupted cases and recovery.
**Evidence:** No passing acceptance is recorded for the remaining scope; cited commits/tests establish the shipped baseline only.
**References:** EXP-01–04/N1/T41, D-60/D-144–D-146; [workflow](design-map/workflows/settings-units-backup-restore-export.md), [tests](../fitbodTests/Phase6/BackupRoundTripTests.swift).

### Deferred feature details

Deferred stays open until its trigger. Visual work returns at workflow stability/design approval; all release checks return before release readiness.

### <a id="rm-030"></a>RM-030 — Full inline routine creator

**P3 · Deferred.** Modal name/compose shipped; full [inline reference](../bru-screens/create-flows.jsx) remains future work.
**Done when:** create/order/prescribe inline while Cancel leaves no Untitled routine and failure preserves draft.
**Scope / sequence:** After authoring stabilizes: inline create/order/prescribe → preserve Cancel/draft/rollback → verify creation journey. No broader Program redesign.
**Requires:** Stable [RM-026](#rm-026) authoring workflow.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** retired T48/Conway “New routine flow”; [workflow](design-map/workflows/build-a-routine.md).

### <a id="rm-031"></a>RM-031 — Capabilities beyond today's program/backup model

**P3 · Deferred.** Preserve skip markers, undo End block, planned start dates, phase effects beyond current deload cut, per-phase routine overrides, archive charts, standalone template library and finer day/slot scheduling. Backup deferrals: browse pre-restore side files, automated local backups, post-restore notice and DEFLATE if measured archives exceed roughly 5–10 MB.
**Done when:** select a capability with user direction, define schema/compatibility/evidence here, implement without rewriting frozen workouts/archives. Mismatched restore schemas stay rejected until explicitly supported conversion is designed.
**Scope / sequence:** Choose one listed capability → define its bounded outcome/compatibility here → prove backup → implement/test it. All other capabilities stay excluded until individually triggered; no umbrella Done claim.
**Requires:** User-selected scope and stable owning workflow; [RM-029](#rm-029) before schema/backup changes; [RM-040](#rm-040) only for applied target changes.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** original program-graph v2 exclusions/phase-6 backup deferrals/restore-relaunch-notice; [contracts](../ARCHITECTURE.md#program-graph). Historical migration work is superseded, not included.

### <a id="rm-032"></a>RM-032 — Optional sync

**P3 · Deferred; outside v1.**
**Done when:** approve ownership/conflict rules (including whether last-write-wins is acceptable), schema evolution/snapshot immutability; prove offline edits/deletions converge on two devices without losing sets. Local use stays connectivity-independent.
**Scope / sequence:** Approve ownership/conflicts → compatible schema → disconnected edits/deletes and convergence checks. Outside v1; no accounts/networking before the decision.
**Requires:** Explicit scope expansion and [RM-029](#rm-029); approve conflict/ownership rules first.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** retired SYNC-01/02; [scope](#rm-042).

### <a id="rm-033"></a>RM-033 — Optional Watch companion

**P3 · Deferred; outside v1.** Preserve WATCH-01–03: wrist logging, rest haptics and optional heart rate.
**Done when:** authorize the phone/Watch design and prove selected behavior through disconnect/reconnect without duplicate/lost sets; heart rate needs its own privacy/HealthKit decision.
**Scope / sequence:** Approve one wrist workflow → phone ownership/reconnection → prove no duplicate/lost sets. Heart rate/HealthKit is a separate privacy decision.
**Requires:** Stable phone workout and explicit scope expansion; privacy/HealthKit decision for heart rate.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** retired v2 requirements; [scope](#rm-042).

### <a id="rm-034"></a>RM-034 — Conditional maintenance and measured performance

**P3 · Deferred until touched or measurably slow.** Preserve F118/F132/F136/F150/F154/F174/F177/F186/F189/F195/F202/F208/F216/F218/F228/F233/F239/F241/F299/F329/F336/F349/F364/F365/F373/F375/F382/F388; May concerns about large views, repeated helpers, previews and post-fetch history cost.
**Done when:** when named paths block work/a real workout feels slow, measure, fix the shared cause and compare. Preserve validation/error handling during extraction. Confirm callers before removing remaining MesocycleWeekPage/BlockPhaseEditorRow/BlockPickerMenu; do not recreate deleted views.
**Scope / sequence:** When a named path is touched or measured slow: baseline → shared fix/removal → compare. Other cleanup remains deferred; no blanket refactor.
**Requires:** Measured reproduction or a change touching the named path.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** May codebase concerns reconciled here; [test guide](test-performance-guide.md), F21/F68/F89; [shipped cleanup](#rm-061).

### <a id="rm-035"></a>RM-035 — Approved-screen visual/copy polish

**P3 · Deferred until design approved.** Remaining “Polish later” D-rows, readout type, anatomical refinement if feedback requires it and T43 refresh once a newer approved export exists.
**Done when:** resolve mapped outcomes without behavior regressions. T120 (D-13/F258/F260/F261/F345) still needs one-line undo toast, phase/stat/direction stepper labels and reproduction of short slow drags opening phase editors from cards/margins or not scrolling chart. WIP `2ef8ea3`/`conway-t120` was not merged/validated. T127/F295 needs verified thousands grouping, decimals/no-break parts and spoken numbers. D-270's selected-type mark shipped, but the native rounded menu presentation remains polish. Keep F23/F57/F87/F119/F139/F175/F201/F225/F284/F341/F360/F361/F368 for their screen passes.
**Scope / sequence:** Select approved screens/mapped findings → reproduce remaining defects → shared token/copy fixes → inspect. Unapproved/unrelated visual work stays deferred.
**Requires:** Approved design for the affected screen.
**Verify when:** At approved screen implementation; [RM-044](#rm-044) accessibility refinement at stability.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** [audit](design-map/audit.md), [BRU rules](design-system/principles.md); T43/T120/T127, archived New Block flags.

### <a id="decisions"></a>Product decisions

### <a id="rm-036"></a>RM-036 — First-log records or quiet baselines

**P2 · Needs product direction.** First logs establish every intent/rep-range/kind record; PR × 19 counts record kinds, not sets/exercises.
**Done when:** choose celebration semantics and apply consistently to logger/records/summaries/recaps with replay tests.
**Scope / sequence:** Choose first-log celebration → apply consistently to PR consumers → replay boundary histories. Keep current rule until chosen; no broader analytics.
**Requires:** User choice of baseline/celebration semantics.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** baseline-record-state; [PR detector](../fitbod/Progress/PRDetector.swift).

### <a id="rm-037"></a>RM-037 — Which rep misses trigger deload advice

**P2 · Needs product direction.** Locked D-14 counts below range top; alternative is below bottom. Signal 3 requires three finished sessions/excludes live workout.
**Done when:** choose/explain threshold and test boundaries while advice stays non-mutating.
**Scope / sequence:** Choose rep-miss threshold → explain advice → test above/at/below boundaries. Advice stays non-mutating; no automatic deload.
**Requires:** User choice of rep-miss threshold.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** deload-advisory; [advisor](../fitbod/Fatigue/DeloadAdvisor.swift), [boundary tests](../fitbodTests/Fatigue/DeloadAdvisorTests.swift).

### <a id="rm-038"></a>RM-038 — Muscle contributions versus physical set labels

**P2 · Needs product direction for remaining aggregates.** Fatigue total sums weighted muscle contributions; one compound set contributes repeatedly. Redesign 1.4 Today row already specifies physical working sets.
**Done when:** choose muscle-set/physical labels per remaining summary, explain/reconcile them without changing per-muscle stimulus math silently.
**Scope / sequence:** Choose labels per remaining aggregate → reconcile values to physical sets/contributions → check sparse/compound cases. Preserve stimulus math and RM-010's approved physical-set wording.
**Requires:** User choice only for remaining aggregate labels.
**Verify when:** With each aggregate change, including RM-017; does not block RM-010 physical counts.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** muscle-sets-explainer; [fatigue model](../fitbod/Fatigue/FatigueModel.swift).

### <a id="rm-039"></a>RM-039 — Define adherence before displaying it

**P2 · Needs product direction.** History Per week is observed frequency.
**Done when:** define schedule denominator/off-plan/missed-day/no-block semantics, test against the same period; keep frequency wording meanwhile.
**Scope / sequence:** Choose denominator/exceptions → calculate the same history period → no-block/off-plan checks → expose adherence. Frequency stays available meanwhile.
**Requires:** User-defined denominator and schedule semantics.
**Verify when:** Against RM-006/RM-015 scheduling cases before displaying adherence.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** adherence-stat; [history](../fitbod/Sessions/SessionHistoryView.swift).

### <a id="rm-040"></a>RM-040 — Real per-set prescription

**P2 · Planned; model/product input needed.** ROUTINE-03's old complete box was misleading: stored overrides are not applied. T110 hid editing and obsolete PerSetOverrideRow was deleted. Top/back-off intent and per-set reps/RPE remain unshipped.
**Done when:** define per-set target fields beyond current baseline, preserve snapshots and apply them in logger before exposing editing. Test top/back-off/precedence/backup. Do not revive the corrupt unused editor.
**Scope / sequence:** Choose applied per-set targets → prove backup/provenance → snapshot/apply targets → expose authoring. Stored unused overrides/editor are not a shipped feature.
**Requires:** Approved target model/product scope and [RM-029](#rm-029); [RM-021](#rm-021) before overlapping unit/provenance schema changes.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** per-set-prescription/T110/Phase-1B item 1/phase-2.1 model gap; [override model](../fitbod/Models/RoutineExerciseSetOverride.swift).

### <a id="rm-041"></a>RM-041 — Overlapping muscle tonnage stacks

**P2 · Needs product direction.** F342 attributes sets to each primary muscle, so stacks can exceed physical tonnage/previous-best line.
**Done when:** choose attribution, normalization or explicit non-additive labels; reconcile bars/detail/reference lines.
**Scope / sequence:** Choose attribution or explicit non-additive wording → reconcile bars/detail/reference lines → test compound sets. Label-only correction does not require a unit schema; mixed-unit normalization does.
**Requires:** User attribution/wording choice; [RM-021](#rm-021) only for mixed-unit normalization. RM-023 does not block this decision.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** F342; [aggregator](../fitbod/Progress/WeeklyTonnageAggregator.swift).

### <a id="rm-042"></a>RM-042 — Approved product rules

**P1 · Decided; preserve during implementation.** Completion means each affected owner implements/tests these rules, not that every layout already shipped. These approved decisions need no new approval; their owners carry implementation prerequisites.
**Scope / sequence:** preserve approved calls in the owning acceptance/tests as features land. These are product rules, not a claim that all designs shipped.
**Requires:** existing approved decisions; user direction only to change them.
**Evidence:** dated approvals below; implementation evidence stays with each linked owner.

- **Scope:** personal local-only SwiftUI/SwiftData iPhone lifting app, Swift 6/iOS 26.4. No accounts/backend/analytics, commercial distribution, Android/web, Watch, HealthKit, external sensors/VBT, social, nutrition/cardio/sleep or form-video analysis in v1. Session-level intent/progression supersedes original per-exercise intent (PIVOT-01–05); retain exercise targets/four progression strategies.
- **Gym day (2026-11-03):** history edits date/start and set weight/reps/RPE, adds/deletes sets and confirms workout deletion. Shift all timestamps one delta, never future; duration/exercise membership/order/frozen prescription stay. Derived evidence recomputes without a records-moved summary. WHY shows frozen weight/notes live divergence. Technical contracts: [architecture](../ARCHITECTURE.md).
- **Conway decisions 1–9:** one BlockTemplates catalog, including real 4-week 5/3/1; presets replace name/phases and confirm edited phases. Top named draft/bottom ready saves both need a name. Notes SAVE local copy; CANCEL/swipe drop it. Completed work counts, skipped warmups do not; empty finish discards and old empty history stays out of counts/Compare. Archive confirms/restores. Why/Use/Override remain reachable and dismiss/focus keyboard. Baseline PR celebration stays RM-036.
- **Block run (2026-11-05):** never auto-end; training continues after final week. Start/end/handover/attach/swap are rollback-safe single saves. Only draft/ready delete; active end, finished history stays. Start next/Plan custom carry extant unarchived routine/schedule/days; custom uses default phases/no name, recommended its preset. Review EXPORT shares dated block sets with Settings CSV columns. Deload holds last top weight/cuts sets. Remove inert DAYS PER WEEK. Skip/undo/planned start/broader phase effects remain RM-031.

Today/Program O-1–O-14 were approved 2026-11-05, O-15–O-16 on 2026-11-08. Later calls supersede conflicting earlier presentation: newest-ready, Today End action and automatic review.

| Original ID | Approved rule | Owner |
|---|---|---|
| O-1 | Drop day streak/all-time count from Today; history holds totals. | [RM-057](#rm-057), complete |
| O-2 | One NEXT-anchored slot rule for all starts; alternate rotation advances/explains skips, outside-routine unslotted. | [RM-006](#rm-006) |
| O-3 | Any finished counted workout started today gives T-DONE; list all; done outranks ready. | [RM-006](#rm-006) |
| O-4 | Automatic recap once weekly on first appear when due, independent of review; past recaps separate. | [RM-013](#rm-013), [RM-020](#rm-020) |
| O-5 | No pending-review notice with newer active block; Past blocks keeps review reachable. Close acknowledges once; failure keeps retry/notice; review outranks advisory. | [RM-013](#rm-013), [RM-016](#rm-016) |
| O-6 | Oldest-created ready/name/ID leads with date/count; newest-created draft/name/ID leads drafts-only Program; drafts do not change Today. | [RM-006](#rm-006), [RM-011](#rm-011) |
| O-7 | Folders do not ship; keep RoutineFolder schema, delete unwired UI. | [RM-061](#rm-061), UI removed |
| O-8 | Presets only inside + New block → Use preset. | [RM-011](#rm-011) |
| O-9 | This week logged rows open summary; TODAY/NEXT only in T-TODAY; empty sessions repair; open/rest read-only. | [RM-015](#rm-015) |
| O-10 | PLAN COMPLETE line opens overview; End stays there, never automatic. | [RM-057](#rm-057), [RM-016](#rm-016) |
| O-11 | Today exercise rows read-only; View opens session detail. | [RM-058](#rm-058) |
| O-12 | Program plans blocks; Today starts ready only; review's Start next/Plan custom can open builder. | [RM-006](#rm-006), [RM-011](#rm-011) |
| O-13 | Now has no week cells; overview retains them. | [RM-011](#rm-011) |
| O-14 | No planned-start attribute; startDate is creation until actual start. Show Created. | [RM-006](#rm-006), [RM-011](#rm-011) |
| O-15 | Dark slabs use bruSlab/bruOnSlab; final T-DONE paper-on-paper at 1.3. | [RM-059](#rm-059), [RM-006](#rm-006) |
| O-16 | Logger lives on Today; Program/session/Live Activity request it there; Back/swipe lands on Today. | [RM-059](#rm-059), complete |

Four [mockups](design-map/mockups) are approved: history editing/stalls/recaps/PR detail.
Adopt shared P-1/P-2/P-3/P-6/P-8/P-9/P-10/P-11/P-12 fixes.
P-4/P-5 wait for stability; P-7 for polish.
Of 41 missing-screen rows, 40 were redesign scope (must-haves first); restore-relaunch-notice later.
Later decisions remove folders, undefined presets and redundant saves: superseded, not outstanding features.

### <a id="rm-043"></a>RM-043 — Explicit supersessions and reconciliation

**P3 · Done for documentation reconciliation, 2026-11-08; supersessions below remain policy.** Scope: one roadmap, honest completion, independent continuation, corrected entrypoints/setup and selected feature-plan archives. No app behavior changed.
**Sequence / acceptance:** reconcile owners and relationships → update policy/current references → archive finished plans → validate links, anchors, finding ownership and prerequisite cycles. Every original RM and finding ID stays reachable.
**Requires:** none.
**Evidence (2026-11-08, documentation working tree based on `ba27f304`):** `python3 -I docs/design-map/tools/check_map.py --self-test` passed; `bash docs/design-map/tools/check.sh` reported 0 errors and rendered all 18 Mermaid blocks. One pre-existing warning remains: five unreferenced captures. Additional document assertions passed: all 61 original RM anchors and referenced original finding IDs retained, 365 audit/41 missing-screen owners valid, 328 local links/anchors and four archive backlinks valid, no prerequisite or combined scheduling cycles; approved redesign order/backup prerequisites preserved. `git diff --check` passed for task-owned tracked docs. [Archived implementation plan](archive/features/development-workflow.md).
**Review verification (2026-11-09):** corrected exercise deletion/F352 and library-filter guidance against their existing implementations/tests. `python3 -I docs/design-map/tools/check_map.py --self-test`, `python3 -I docs/design-map/tools/check_map.py` and `git diff --check -- ARCHITECTURE.md CLAUDE.md CONVENTIONS.md docs/ROADMAP.md` passed; 0 checker errors, with the existing five-unreferenced-captures warning. App/device tests and Mermaid rendering were not rerun for these wording-only corrections.
**Completion walkthrough:** RM-060/FT-13 is Done for its bounded finish-sheet scope with 23 recorded passing affected tests and its plan archived; no routine personal sign-off is needed. RM-008/FT-20 has completed packaging archived but remains Implemented; verification pending for installed Lock Screen/Island/lifecycle proof. That observation blocks its acceptance and dependent release closure, while RM-006 and independent work can proceed.
**Limits:** no app build/runtime, physical-device behavior or historical app tests rerun for this documentation change. Old broad claims in RM-055/RM-056/RM-061 remain historically shipped; acceptance unrecorded.

- May TrainingBlockTemplate/ActiveTrainingBlock/RoutineBlockAttachment split, attachment payloads/multi-routine mapping are replaced by the live SessionTemplate → Split/slots → Block graph.
- Historical V1–V6/custom V6→V7 migration/backfills/flakes and retroactive GSD/Nyquist reports are retired by sole SchemaV7/current workflow. Future compatibility is RM-031; preserve incompatible stores separately (RM-001).
- Undefined Off-Season/Pre-Meet presets stay removed. Redundant Edit header SAVE, inventory SAVE INVENTORY, calculator •••/footer Save/Done and recap ALL RECAPS placeholders stay removed. Reintroduce working outcomes only through RM-020/RM-025.
- T121/T131/T135 explicitly superseded by T143 removing presentation suites and T119 budgets. Deferred accessibility/retained-test work remains RM-044/RM-054. T123/T129/T133/T134/T140 completed only trimmed correctness/reliability; omitted presentation/VoiceOver/performance remains RM-035/RM-044/RM-054. T06/T07 were skipped because fixes shipped elsewhere.
- Phase-1B backlog: deleted overrides → RM-040; unused CSVFile/JSONFile/FitbodBackupFile Transferable conformance, filename fields and old imports → RM-034 (still present; sharing uses data/URL items); obsolete accessibility wording F32 → corrected here; duplicate scroll helpers → RM-054; RPE hold → shipped T49. Archived quick backlog: RPE heading fixed FT-08; Resume Discard hit area remains RM-028 until verified.
- F352 resolved by documentation correction (2026-11-09): `Exercise` has no archive flag; architecture/conventions now require `ExerciseDeletion.delete` to clear history/template links before deleting. Library guidance also matches `FilterState`: search in the SwiftData predicate, facets after fetching through `applyPostFetchFilters(to:)`, as `FilterStatePredicateTests.facetSelectionDoesNotConstrainSwiftDataFetch` requires. No app behavior changed.
- The stale BRU wiring checklist is superseded by shipped base surfaces (RM-055/RM-061), current approved layouts (RM-006/RM-010–RM-018), remaining authoring/analytics work (RM-023–RM-028) and stable/release checks. Its sample profile data, Settings tab, day-streak bands and old navigation proposals are not requirements. Old INT-W1/INT-W2 end/review/navigation issues and INT-W3 dead advisory were superseded by block lifecycle/cleanup; INT-W4 duplicate export builders was fixed by ExportSnapshot, and INT-W5/historical schema comment debt is retired with that schema history.
- D-110/D-112/D-187 dirty-note confirmation proposals are superseded by the approved local-copy rule: SAVE commits, CANCEL/swipe intentionally discard. D-11 inline-plate behavior was explicitly reversed by FT-11; standalone calculator access remains RM-025.
- Old unchecked PROG-01–05/07/08 and EXP-01/02 contradict shipped chart/export code/tests: baseline RM-055/RM-061; extensions RM-023/RM-029. Pattern/folders/per-exercise intent/per-set overrides are qualified by RM-022/O-7/PIVOT/RM-040.
- All 365 D-findings and 41 missing-screen rows remain dated evidence with one canonical RM link each. Only cited code/commit/test matches close. Redesign A/adversarial V/F findings are covered by RM-006/RM-010–RM-018, including reviewed fixes. Phase 3.1's contingent alternate O-2/O-3 behavior is superseded by approved defaults; 3.2/3.3 dead folder/card cleanup shipped (RM-061).
- Retired redesign A-01–A-07/A-20–A-22 are addressed by RM-057/RM-058 and the remaining slab/volume work RM-006/RM-010. A-08/A-09/A-14/A-15/A-17/A-18 → RM-006; A-10/A-19 → RM-010; A-11/A-12 → RM-017; A-13 → RM-044; A-16 → RM-013/RM-016; A-23–A-30 → RM-011/RM-015; A-31/A-32 → RM-012. Redesign risks R-1/R-16 apply to every affected step: update retained test callers and run GitNexus impact before symbol edits; R-14 follows the prototype policy, without requiring retired presentation suites.
- The 47 milestone review items/N1 fed Conway, which recorded 127 done/19 skipped. Non-superseded skipped tickets stay open: T42 → RM-052; T43/T120/T127 → RM-035; T44/T45 → RM-048; T46/T47/T48 → RM-051; T117/T124/T126/T132/T138 → RM-044 (T138 performance also RM-034). Phase-5/6 manual UAT, phase-9 device UAT and old AX3 journey acceptance remain RM-044/RM-047/RM-048 regardless of phase-complete labels.
- Unassigned Conway findings: damaged stores F351 → RM-009; units F157 → RM-021; records F318 → RM-023; stacks F342 → RM-041; numeric F355/F383 → RM-005; layout/contrast/drag notes → RM-024/RM-035/RM-044; warnings/runners → RM-052/RM-054; cleanup/performance → RM-034. Accepted limits F115 (range equals chosen weight), F224 (zero-weight explanation heuristic), F226 (unordered stimuli sorted by readers), F227 (uppercase XCUI labels), F244 (Foundation hash issue without app-key usage) and F263 (64-character spoken test output) do not promise extra state/dependencies.

Original tracked sources remain in Git at `ba27f304`: superseded roadmap/backlog/STATE/requirements ledgers, handoffs, Conway tickets/run log, design-map decision/implementation plans, playtest reconciliation, historical reviews/research and milestone verification reports. Selected finished substantial feature plans now live in [archive/features](archive/features/); their banners preserve build, scope, results and current RM owners. Other old sources remain recoverable from Git.
Use `git show ba27f304:<old-path>` for wording, F1–F388 and evidence.
The design-map audit keeps original finding details with one RM owner each; update status only here.
Old review/verification folders, research/UI-review collections, milestone reports, Conway run diagnostics, HTML reports, screenshot bundles, duplicate codebase maps and impact logs are retired after reconciliation. Nested redesign reviews/prompts, risk/decision lists, evaluations and historical map changelogs are retired too; their outcomes and criteria belong here. Do not recreate those reports or ledgers as archives; retain only finished substantial feature plans under `docs/archive/features/`.
CI uploads results as 14-day artifacts and no longer commits evidence to a branch. Long-term acceptance and concise results belong in the owning RM entry.
The step-1.3 notes are reconciled against RM-006/O-15/O-16 and current policy; implementation has not started. Unrelated workspace changes are excluded from this documentation result.

### <a id="release-checks"></a>Stability and release verification

Release readiness starts before someone else installs, the app becomes the only training record, or a milestone is called release quality.
See [policy](DEVELOPMENT.md#release-readiness).
All checks below, [RM-029](#rm-029) populated restore and current data risks need evidence.

### <a id="rm-044"></a>RM-044 — Stable-workflow accessibility/layout

**P2 · Deferred until stable; required for release.** Preserve “When stable” D-rows, T117/T124/T126/T132/T138, redesign 3.4 and trimmed presentation checks.
**Done when:** inspect both phones/AX3/dark/Reduce Motion/contrast/44pt targets, then traverse physical VoiceOver. Combine history/PR readouts; announce missing recap/review values; distinguish absent/below-MEV heatmap colors; cover chart/audio/rotor order. T117 needs non-PR row/every chip/stat and true e1RM tie fixture/name (F335). T124 keeps countdown inside ring, ±15s labels 8pt inside borders/52pt height and correct plurals (F272/F273/F276). T126 keeps action target off title (F292). T132 keeps plan/summary parts whole (F306–308). T138 announces PR chips (F324–327), removes stale marks/wrappers and measures/loads stats once as needed. Check routine drag geometry F344, heatmap alternatives D-160, Program modal/return focus and AX4/AX5 plate tabs F289.
**Scope / sequence:** When each workflow stabilizes, run its accessibility/layout/journey pass and fix findings; repeat the release matrix at release readiness. No whole-app gate delays stable-workflow checks.
**Requires:** Approved structure unchanged through two weeks of gym use, no touching product decision, owning redesign implemented. Block stability also needs one whole real block.
**Verify when:** For each workflow as soon as stability triggers, then at release readiness.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** [audit](design-map/audit.md), [accessibility](design-system/accessibility.md), [stability](DEVELOPMENT.md#stages), redesign R-14/R-15, F57/F202/F225/F284/F289/F344/F357/F360/F368.

### <a id="rm-045"></a>RM-045 — FT-16: heatmap reach on small/large phones

**P2 · Implemented; verification pending.** 402pt/430pt simulators show whole figures/calves and bottom rule above tab bar; that does not close phone clipping.
**Done when / reproduction:** current main → Progress → Volume → FRONT/BACK; reach all lower-body regions/clear tab bar and safe area; tap calf on each and open detail. Repeat small 6.1-inch/390pt and large/440pt phone; 390pt simulator adds layout evidence but cannot replace phone pass. Capture clipping with model/width/text size/build.
**Scope / sequence:** Observe front/back/calf reach on both physical sizes → record model/build/text/appearance → fix reproduced clipping. No heatmap redesign.
**Requires:** Physical small/large phones; no prerequisite on completing RM-010.
**Evidence:** Historical simulator/asset evidence below; required physical observation remains unproven.
**References:** FT-16/VOL-05; [figures](../fitbod/Fatigue/BodySilhouetteView.swift).

### <a id="rm-046"></a>RM-046 — FT-21: installed app icons

**P3 · Implemented; verification pending for dark/tinted.** Default white-border correction is Done: the device-rendered icon now has an ink background filling the system mask, with the original BRU artwork preserved.
**Done when / reproduction:** the default icon fills its canvas without a white frame or clipped artwork; capture installed Home Screen icon in dark/tinted appearance, record build and compare [AppIcon](../fitbod/Assets.xcassets/AppIcon.appiconset), one universal 1024 image/no variants. If a remaining mismatch is iOS glass treatment, decide on Icon Composer .icon; that remedy has not shipped.
**Scope / sequence:** Remove baked-in white margin in the generator/regenerate PNG → verify installed default icon → observe installed dark/tinted icons → choose a remedy for any remaining observed mismatch only. No speculative Icon Composer migration.
**Requires:** Installed build and physical appearance observation; branding direction only if mismatched.
**Evidence (2026-11-09, `ba27f304` + working tree):** The supplied Home Screen crop and device-rendered 60pt/@3x image reproduced the 108px paper margin introduced by `1152fde2` on 2026-10-28. Updated `scripts/generate_app_icon.swift` and regenerated its PNG: 1024×1024, no alpha channel; pixel assertions verified all 395,712 margin pixels became opaque ink and every original interior pixel stayed identical. Xcode 26.5 signed Debug app/widget build, strict signature verification and installation passed on iPhone 15 Pro Max/iOS 26.7.2. `devicectl device info appIcon` returned non-placeholder 180×180 and 1024×1024 images with the white frame removed and complete artwork. Documentation checker/self-test and `git diff --check` passed; the existing five-unreferenced-captures warning remains. No unit/UI suites, dark/tinted Home Screen observations or other app-runtime checks ran for this icon-only correction.
**References:** FT-21; [AppIcon asset](../fitbod/Assets.xcassets/AppIcon.appiconset).

### <a id="rm-047"></a>RM-047 — Physical timer/notifications/accessibility

**P2 · Planned; device verification at stability/release.** Simulator trees cannot prove these behaviors.
**Done when:** traverse every workflow with physical VoiceOver; check haptics, notification denial, background/terminated delivery, timer adjustment/expiry, Lock Screen height/tint and compact/minimal/expanded Island cleanup. Check Focus/authorization/no duplicates; record model/iOS/build/results.
**Scope / sequence:** Timer/denial/background/Island checks when that workflow stabilizes; each workflow's VoiceOver pass at its own stability trigger; reconcile all at release. Timer checks do not wait for all of RM-044.
**Requires:** Physical iPhone/current build and the specific workflow ready to test; no all-workflow gate.
**Verify when:** Timer workflow stability for timer/notifications; each workflow stability for VoiceOver; all complete before release.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** SESS-04, phase-2.1 physical QA, phase-5/6 UAT; [timer](../fitbod/Sessions/RestTimer).

### <a id="rm-048"></a>RM-048 — Two-phone suites/authored relaunch journeys

**P2 · Deferred until release readiness.** T44/T45/old milestone acceptance remain open; a full-tier count is not the configuration matrix.
**Done when:** full unit/UI and app/widget builds pass 390pt/440pt, default/AX3, light/dark serially. Author library → routine/prescription → workout/rest → terminate/relaunch without reset → finish/history/correct → relaunch again. Rest uses absolute deadline/lower remaining time. Rerun failures alone; distinguish flake/environment/pass; record commit/configuration/counts/durations/bundles.
**Scope / sequence:** At release readiness: builds → both-phone configuration runs → authored relaunch journey → isolated failure diagnosis. Default/light full-tier counts alone are not the matrix.
**Requires:** Stable workflows and current correctness; resolve [RM-052](#rm-052) diagnostics preventing the run.
**Verify when:** Before release triggers, both sizes/default/AX3/light/dark. The full runner pins default/light; run and record the other configurations explicitly.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** T44/T45; [tiers](SETUP.md), [test runner](../scripts/test.sh). Latest playtest full tier: 1,348/1,350 passed, one expected failure/History delete failure; `3febe870` passed that case alone afterward. No fully green later matrix claimed.

### <a id="rm-049"></a>RM-049 — Deliberate offline journey

**P2 · Planned; verify at release readiness.** Local architecture is not an observed offline run.
**Done when:** networking off, complete catalog/custom → routine → workout/rest/relaunch → history/correction → export/backup; remote images fall back without blocking.
**Scope / sequence:** Disable networking → authored local journey through backup/export → inspect image fallbacks. No network/sync features added.
**Requires:** Existing local journey; [RM-029](#rm-029) for backup/restore acceptance. Catalog expansion is not required.
**Verify when:** At release readiness with networking off.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** [Library workflow](design-map/workflows/find-and-create-exercises.md), [release policy](DEVELOPMENT.md#release-readiness).

### <a id="rm-050"></a>RM-050 — SwiftData hard-delete runtime enforcement

**P2 · Planned platform investigation.** Deny metadata/service guards exist; known-issue test avoids an aborting operation.
**Done when:** reproduce/fix or safely guard runtime hard deletion and prove history intact. Expected failure is not runtime proof.
**Scope / sequence:** Reproduce hard-delete behavior safely → guard/fix shared boundary → prove stored history intact. Keep unlink/archive guards; expected failure cannot close this.
**Requires:** Supported runtime reproducing the issue; preserve service guards.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** T40; [delete rules](../ARCHITECTURE.md#deletion-and-ordering), [ProgramGraphDeleteRuleBehaviorTests](../fitbodTests/Persistence/ProgramGraphInvariantTests.swift).

### <a id="rm-051"></a>RM-051 — Release captures and current docs/gallery

**P3 · Planned; verify at milestone close/release (T46/T47/T48).** Removing old reports does not establish release acceptance.
**Done when:** tour/review milestone screens on both phones/default/AX3/light/dark; keep captures in CI artifacts or ignored local output. Update core behavior/setup/BRU gallery and this roadmap against that build, recording commit/configuration/results and physical/offline/deny limits here. Redesign 3.5 updates touched docs as steps land. Separate historical report pages, screenshot dumps and duplicate acceptance ledgers are superseded by this roadmap.
**Scope / sequence:** Update touched architecture/setup/conventions/design references with every feature. At milestone close/release, refresh gallery/captures and reconcile release evidence for that build. No report archive or acceptance ledger.
**Requires:** Changed feature/build for routine updates. Release closure requires [RM-044](#rm-044), [RM-047](#rm-047), [RM-048](#rm-048).
**Verify when:** Touched references with every feature; complete gallery/capture/matrix reconciliation at milestone close/release.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** T46–48/F362; [tools](design-map/tools), [screens](CORE-SCREENS.md), [evidence workflow](SETUP.md#evidence).

### <a id="rm-052"></a>RM-052 — Clean build/runtime diagnostics

**P3 · Deferred unless blocking.** T42 remains open; widget success is not all-target warning-free proof.
**Done when:** clean-build app/widget/both test targets, record/fix deprecations/isolation warnings and trace negative/non-finite frame warnings rather than suppressing them. Separate LLDB/toolchain issues from app failures.
**Scope / sequence:** Fix diagnostics immediately if blocking; otherwise clean-build all targets and trace runtime warnings when owner stabilizes/release begins. No suppression-only cleanup.
**Requires:** Current toolchain and reproducible diagnostic; no release prerequisite for fixing a blocker.
**Verify when:** Immediately if blocking; otherwise owning-workflow stability/release.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** T42, F41/F113/F188/F238/F255/F343/F371/F379/F385; [setup](SETUP.md), [CI runner](../scripts/ci/ios-ci.sh).

**Phone-signing blocker (2026-11-09, `ba27f304` + working tree): Done.** Set project Debug/Release `DEVELOPMENT_TEAM = EFPQ72E256`; the app, widget and both test targets inherit it with automatic signing. `plutil -lint` and assertions covering all eight target configurations passed. Xcode 26.5 `xcodebuild build` (Debug, connected iPhone 15 Pro Max/iOS 26.7.2) and `codesign --verify --deep --strict` passed; `devicectl device install app` installed `bodybuilding.fitbod` successfully. `build-for-testing` was blocked by the missing `bodybuilding.fitbodUITests.xctrunner` profile and Xcode's “No Accounts” error; generating that profile needs an active Xcode account. No tests or runtime/Lock Screen checks ran on the personal phone; all-target diagnostics and the existing device-verification entries remain open.

### <a id="rm-053"></a>RM-053 — Decide CI coverage for main

**P3 · Planned.** CI includes claude/** pushes, PRs/manual dispatch; direct main pushes do not trigger it.
**Done when:** choose/verify main/release triggers or explicitly adopt local/manual evidence as policy here.
**Scope / sequence:** Choose delivery trigger policy → implement chosen triggers → observe expected CI run. No CI performance redesign.
**Requires:** User delivery-policy choice; no feature dependency.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** [CI](../.github/workflows), original CI flag.

### <a id="rm-054"></a>RM-054 — Kept tests fail honestly/stay fast

**P2 · Planned follow-ups; T119 baseline shipped.** Preserve F374/F377 best-effort hosted assertions, T134's deferred activate/dead-branch/hosting merge (F317/F328), and helper/runner issues.
**Done when:** missing host trees report unavailable/failure, not unchecked passes; eliminate order-dependent activation. Consolidate duplicate logger reveal span (Phase-1B item 4); fix topSheet/stepper when real callers need it (F22/F42/F86/F376). Keep data-case budgets per guide/document exceptions F388; address backup/defaults litter affecting runs, isolate defaults, investigate hangs/snap-back apart from app failures.
T110-ext recorded an AX3 editor hang on the small iOS 26.5 phone: scroll EDIT PRESCRIPTION past Rest, then query controls; the main thread did not idle for 30 seconds. It also failed at base `3428ffea`, independent of the override removal (`496906a7`). Recheck that path when the editor stabilizes; the retired SessionEditorPolishUITests suite need not return.
**Scope / sequence:** On a kept-test reproduction: fix fail-honestly/activation → necessary shared helpers → compare timing. F317/F328 hosting merge, duplicate reveal, defaults/litter return when their callers block iteration; no wholesale UI-suite restoration.
**Requires:** Kept-test/helper reproduction or iteration-blocking slowdown.
**Verify when:** On retained-test failures, necessary helper changes or iteration-blocking slowdowns.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
**References:** F17/F20/F22/F35/F42/F82/F86/F135/F150/F164/F180/F202/F208/F218/F239/F241/F263/F271/F299/F349/F374–379/F381/F386/F388; [guide](test-performance-guide.md), [helpers](../fitbodUITests/UITestNavigation.swift)/[logger helpers](../fitbodUITests/WorkoutUITestNavigation.swift).
