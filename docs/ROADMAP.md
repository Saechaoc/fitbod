# Fitbod roadmap

This is the sole actionable plan for priorities, unfinished work, product decisions and acceptance criteria. Update the owning RM entry when scope, status, relationships or evidence changes; preserve stable RM anchors and original finding IDs. Technical contracts live in [ARCHITECTURE.md](../ARCHITECTURE.md); [design-map](design-map/) is dated evidence and approved design input.

Routine flow is **Planned → Active → Done**. The agent implements, runs risk-appropriate checks and updates docs; routine personal sign-off is not a gate. Use **Implemented; verification pending** when implementation is finished but a required external observation is unavailable. Name what remains unproven and block only work that actually requires it. Continue independent planning/development. A failed relevant check stays open; archive placement alone never proves acceptance.

**Requires** means a real prerequisite to the stated scope. **Scheduled after** records chosen delivery order, not a technical dependency. **Verify when** names a stability/release/integration trigger. Conditional requirements apply only to the named delivery. The title and “Done when” define outcome/observable acceptance; “Scope / sequence” names included deliveries, order and exclusions. Evidence separates shipped baseline from unverified remainder. Broad legacy entries have bounded deliveries or explicitly triggered follow-ups; do not leave them indefinitely “Partial”.

Reconciled 2026-11-08 against `ba27f304` and the existing working tree. Historical app test results below were not rerun for this documentation change. P1 protects core workout/data; P2 improves workflows; P3 is polish/optional expansion. Resolve correctness, privacy/security and data-integrity risks before extending affected paths; unrelated work can continue. Prove populated backup/recovery before schema-changing work and load provenance before mixed-unit analytics.

Keep concise commands/results/limitations with their RM owner. Logs/screenshots belong in CI artifacts or ignored local output. Finished substantial implementation plans move to [archive/features](archive/features/) with a historical banner, scope/build/results and RM backlink; no new backlog, tracker, report archive or personal approval process.

## Active work

[RM-006](#rm-006)'s six slices and Lane B ([RM-001](#rm-001)–[RM-005](#rm-005)) are Done.
The next Today/volume delivery is [RM-010](#rm-010); its RM-006 and RM-003 prerequisites are complete.
Keep exclusive simulator use during each run and reuse existing devices across lanes; see [local simulator reuse](SETUP.md#local-simulator-reuse).
Each slice lands on `main` when its local checks pass ([RM-053](#rm-053)).
Move the next bounded outcome here when its implementation starts; a phone-pending feature does not occupy an active slot.

## Next

This is the ordered dependency-ready queue; feature definitions below retain the full conditional sequence. Ready work in independent streams may continue while another feature awaits input.

| Order | Ready outcome | Boundary |
|---|---|---|
| 1 | [RM-010](#rm-010) Today week board, full volume behind it | Lane A; active 2026-11-11. |
| 2 | [RM-019](#rm-019) stalled exercises outside a workout | Independent analytics stream; [RM-020](#rm-020) past recaps follows, then broader analytics. |

After RM-001, [RM-029](#rm-029) populated recovery proof takes priority over schema-changing work. Preserve the approved Today/Program order: **RM-006 → RM-010 → RM-011 → RM-012 → RM-013 → RM-014 → RM-015 → RM-016 → RM-017 → RM-018**. Successors enter this queue as preceding work lands; planning may proceed meanwhile. Authoring, catalog, logging and calculator deliveries use their actual conditional prerequisites below, not the whole redesign as a gate.

## Needs input or device verification

Only the named observation/decision is unavailable; this section does not pause unrelated work.

| Owner | Missing input or proof | What depends on it |
|---|---|---|
| [RM-007](#rm-007), FT-19 | Exact repeated prompt text/owner on phone, then allow/deny/Focus reproduction | Identifying/fixing that prompt and its release acceptance. |
| [RM-008](#rm-008), FT-20 | Lock Screen/Island rendering, rest adjustment/expiry/end on installed build | Closing widget rendering/lifecycle acceptance; implementation plan is archived. |
| [RM-045](#rm-045), FT-16 | Small-phone heatmap reach and calf taps on both sizes; the iOS 26.7 bottom band is fixed | Closing clipping acceptance; RM-010 development can proceed. |
| [RM-046](#rm-046), FT-21 | Installed dark/tinted icon observation | Closing icon acceptance or deciding an observed mismatch remedy. |
| [RM-036](#rm-036)–[RM-041](#rm-041) | First-log PRs, rep-miss threshold, aggregate labels, adherence, applied per-set targets and stack attribution | Only behavior each decision changes; existing semantics remain. |
| [RM-021](#rm-021) | Provenance/legacy-data design | Stored unit changes. |
| [RM-063](#rm-063) | The first MetricKit report on the phone, shared from Settings | Closing RM-063; it would also show whether [RM-024](#rm-024)'s phone exits are memory kills. |
| [RM-053](#rm-053) | One nightly run on `main` that starts on its own, due 2026-11-12 at 11:17 UTC | Closing RM-053. |
| [RM-022](#rm-022), [RM-062](#rm-062) | Seed 7 and grouped-list checks on the phone (logged names in History, Low Cable Triceps Extension listed, "side lateral raise" found, Bench Press folded into one line) | Closing the families and grouped-list slices; the coverage fill and treadmill tracking can proceed. |
| [RM-066](#rm-066) | On the phone: a machine picked for Hack Squat (Machine) is still there after a relaunch; the store already opens in place with this build | Closing RM-066; nothing else waits on it. |

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
| [RM-005](#rm-005) | P1 · Done | Locale-safe load entry, unique positive plate additions and shared tempo validation; unit/failure/relaunch, 390pt and full-suite evidence in RM-005. | Units still relabel; correction/completion rules unchanged. |
| [RM-004](#rm-004) | P1 · Done | Photo metadata removed at pick/save/upgrade/export/restore; original-preserving failures and pre-delete validation verified. Evidence in RM-004. | Static photos, full pixel dimensions within decode bounds; no schema change. |
| [RM-003](#rm-003) | P1 · Done | Both volume screens render missing targets without model writes; explicit creation rolls back and retries. Hosted before/after, units and 390pt route evidence in RM-003. | Unblocks RM-010; no schema or fatigue-math change. |
| [RM-002](#rm-002) | P1 · Done | Failed slot additions/resets roll back and explain retry; superset drafts save with the session and Discard writes nothing. Unit/failure/relaunch evidence in RM-002. | Schema unchanged. |
| [RM-001](#rm-001) | P1 · Done | Preserve unclassified store-open failures, retry, and rollback partial moves; disk/unit/relaunch and 390pt evidence in RM-001. | No schema change; populated recovery proof remains RM-029. |
| [RM-006](#rm-006) | P1 · Done | StartSlot/shared starts, session sheet and all Today states; six slices, unit/full UI and 390pt evidence in RM-006; [plan/results](archive/features/today-session-sheet-and-state-slabs.md). | Retains the live Program template route until RM-011; broader AX/device checks at stability. |
| [RM-043](#rm-043) | P3 · Done | Completion policy, bounded roadmap/dependency semantics, current setup/widget docs and selected plan archives. Verification in RM-043; [plan/results](archive/features/development-workflow.md). | Documentation only; no app-runtime claim. |
| [RM-064](#rm-064) | P3 · Done | SwiftLint enforces the BRU and `CONVENTIONS.md` bans in an edit hook and both `scripts/test.sh` tiers; 163 source-reading tests deleted, unit target 1,383 → 1,220 and passing. Evidence in RM-064. | Lint only; no app behavior change. |
| [RM-065](#rm-065) | P1 · Done | Three delts with RP landmarks, audited muscle credits in `muscles.json` (seed 8), the week's total as working sets logged, and NOT TRAINED for an untrained muscle everywhere. Unit, full UI, 390pt and phone-store evidence in RM-065. | [RM-038](#rm-038) decision; [RM-022](#rm-022) adds a profile with each new family. |
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
Steps 1.1–1.3 shipped ([RM-057](#rm-057), [RM-058](#rm-058), [RM-006](#rm-006)); 1.4 ([RM-010](#rm-010)) follows after RM-003.
Resolve data risks in the paths being changed before adding more prototype behavior.
Each redesign step keeps affected tests serial on dedicated simulators and captures its changed 390pt states in light and dark. Broader AX3/two-phone/VoiceOver work returns at stability. For Program changes, keep NewBlockBuilderFidelityTests and ProgramViewFidelityTests in the affected checks; SwiftLint covers the fixed colors AdaptiveColorSourceTests used to catch.

### <a id="rm-001"></a>RM-001 — Preserve a good store when opening fails

**P1 · Done (2026-11-10).** `FitbodModelContainer.make` used to treat every failed on-disk open as incompatibility, move the store aside and start an empty one.
It now moves a store aside only when Core Data reports that it cannot infer a migration (NSCocoaErrorDomain 134140).
Every other failed open leaves the store files in place and shows the [retry screen](../fitbod/App/StoreOpenFailedView.swift), whose Try again button opens the same store.
**Done when:** distinguish incompatibility from transient access/I/O failures; a good store stays in place on transient failure, a recoverable error explains retry, and retry preserves workouts. Keep incompatible-store recovery, SQLite siblings, seed stamps and partial move failures covered by disk-backed tests.
**Scope / sequence:** Classify open failures → preserve files/retry → test disk recovery, SQLite siblings and seed stamps. Catalog repair and schema evolution are excluded.
**Requires:** None.
**Evidence:** `6a1dad30` (2026-11-09), iPhone 17 simulator, iOS 26.5, Xcode 26.5.
Before the fix, an unreadable `default.store` (`chmod 000`; Core Data NSCocoaErrorDomain 257, SwiftData `loadIssueModelContainer`, the same error an incompatible schema gives) was moved to `IncompatibleStores/`, and the app opened empty on "Build your first routine" with its 2 workouts and 36 sets in the moved copy.
On the fixed build the same damage shows the retry screen with "NSCocoaErrorDomain 257", moves nothing and keeps the seed stamps; once the file is readable, Try again opens Today with the seeded workout.
`IncompatibleStoreRecoveryTests`, 7 of 7 passed, 3 of which fail on the old factory: an incompatible store is moved with `-shm`, `-wal` and `_SUPPORT` and its stamps cleared; an unreadable store (257), an unreadable `-shm` or `-wal` (256, SQLite 14), an overwritten store (259, SQLite 26) and an additive migration on a read-only file (134110, SQLite 8) stay in place with their stamps and reopen with their rows; a partial move is put back whole.
`scripts/test.sh fast` with `FITBOD_TEST_DEVICE` set to that simulator: 1,268 tests, 1,267 passed, 1 expected failure; `ReseedRelaunchUITests` and `MilestoneOneJourneyUITests` passed 2 of 2.
Limits: SQLite 4618 was not reproduced; it is `SQLITE_IOERR_SHMOPEN` (the `-shm` file did not open), not a short read, and the unreadable `-shm` test is the nearest case.
A corrupt store stays on the retry screen instead of being moved aside.
So does a store whose migration Core Data can infer but SwiftData cannot apply; a probe with a new unique constraint over duplicate rows gave 134110, SQLite 8 and left the store unchanged.
Review/rebase on 2026-11-10: no blocking findings; `f4548033` applies the implementation on `e1393913`. The unit target passed 1,301 tests with one expected failure, including all disk recovery cases; `ReseedRelaunchUITests` and `MilestoneOneJourneyUITests` passed 2/2 (`fast-20261110-075944`, iPhone 17/iOS 26.5). Reproduced a real `chmod 000` failure at 390pt/default text, inspected light/dark retry captures, restored permissions and relaunched into the same seeded workout; nothing moved aside. GitNexus change scope matches bootstrap/container/tests/docs. The retry button itself still has manual rather than committed UI-test evidence; no physical-phone failure injection was attempted.
**References:** [container](../fitbod/Persistence/FitbodModelContainer.swift), [recovery tests](../fitbodTests/Persistence/IncompatibleStoreRecoveryTests.swift); step-1.2 run `full-20261107-074201`, SQLite error 4618, in the retired `261106-he2` summary.

### <a id="rm-002"></a>RM-002 — Failed writes preserve work and explain retry

**P1 · Done (2026-11-10).** D-08, D-20, D-59 and D-153: slot addition and resets roll back failed saves and explain retry; new supersets stay in the draft until the session saves.
**Done when:** these paths show actionable errors, roll back pending mutations and permit later saves. Discarding a session editor leaves no orphan superset. Test failures through the real mutation paths; preserve shipped lifecycle/finish/history rollback (D-01/D-02/D-155).
**Scope / sequence:** Deliver separately: slot addition (D-08), plate/volume resets (D-20/D-59), then superset creation/discard (D-153). For each, inject a failed save and prove rollback/error/retry before advancing. Shipped lifecycle/history rollback stays the baseline; no unrelated editor redesign.
**Requires:** None; preserve shipped rollback contracts.
**Evidence:** Slot addition D-08 is complete (2026-11-10): the picker saves through `appendSessionSlot`, keeps itself open and explains retry on failure. The regression injects a failed save through that real mutation, verifies positions/relationships and persisted counts are restored, then retries successfully. Unit target: 1,302 passed, one expected failure; `SlottedSessionDeleteUITests` passed 2/2 (`fast-20261110-080520`, iPhone 17/iOS 26.5). Plate/volume resets D-20/D-59 are complete: each reset reports failure and rolls back all changed values/flags together; injected failures through both real reset functions leave no pending edits, preserve a fresh reader’s saved values, and retry successfully. Unit target: 1,304 passed, one expected failure (`fast-20261110-081049`). Superset creation/discard D-153 is complete: new group IDs stay in `RoutineDraft`, unused groups are omitted, and session/group rows save together. Injected failure leaves saved rows unchanged and keeps the draft for a successful retry. The unit target passed 1,307 tests with one expected failure (`fast-20261110-081520`). `SessionEditorRowsUITests` passed 2/2 at 390pt/default/light (`fast-20261110-081641`), including Discard without a stored group, then Save/relaunch with the group preserved; the saved sheet capture was inspected. No schema change. Reset-failure presentation is wired to the same thrown errors tested in units; it has no separate UI fault-injection test.
**References:** [D-08](design-map/audit.md#d-08), [slot picker](../fitbod/Periodization/SplitDetailView.swift), [supersets](../fitbod/Routines/SupersetAssignmentSheet.swift), [plates](../fitbod/Settings/PlateInventoryEditor.swift), [targets](../fitbod/Settings/MuscleVolumeTargetEditor.swift); `c3214985`, `dcd3cfcb`.

### <a id="rm-003"></a>RM-003 — Rendering missing volume targets never writes models

**P1 · Done (2026-11-10).** Both volume views render immutable landmark values from stored targets or RP defaults; neither creates fallback models. Calendar arithmetic remains unchanged.
**Done when:** prove missing-target rendering inserts/changes no persisted object or relationship; use immutable fallbacks where needed. Explicit target creation stays validated and reports errors. Cover surface and muscle detail.
**Scope / sequence:** Reproduce missing targets → replace render-time models → prove surface/detail render without writes. No fatigue-math or target-editor redesign.
**Requires:** None.
**Evidence:** The hosted 390pt regression failed on both original views (`fast-20261110-082250`): surface rendering inserted seven target models and detail inserted one. After the fix both screens leave `hasChanges`, inserted models, muscle relationships and persisted target counts unchanged. Explicit creation uses one validated RP target, reports a failed save, rolls it back and retries without duplicates. The unit target passed 1,309 tests with one expected failure (`fast-20261110-082418`); `PerMuscleDetailUITests` passed 1/1 at 390pt/default/light (`fast-20261110-082537`). SchemaV7, stored fields and fatigue math are unchanged.
**References:** [volume surface](../fitbod/Fatigue/FatigueSurfaceView.swift), [muscle detail](../fitbod/Fatigue/PerMuscleDetailView.swift), [shipped calendar work](#rm-061).

### <a id="rm-004"></a>RM-004 — Custom photos do not carry location into backups

**P1 · Done (2026-11-10).** D-111: picked, saved, upgraded, exported and restored exercise photos carry sanitized pixels rather than source metadata.
**Done when:** reproduce with a geotagged photo; persist/export the intended image without location/unnecessary metadata, preserve orientation, and test the stored/backed-up result. Define how existing photos are sanitized without losing them.
**Scope / sequence:** Reproduce metadata leakage → sanitize new and existing photos safely → inspect stored/exported bytes. Preserve the original until replacement succeeds; no photo-library expansion.
**Requires:** None.
**Evidence:** A real geotagged JPEG fixture reproduced GPS leakage in backup bytes (`fast-20261110-083624`). Implementation sanitizes pixels at pick/save/export/restore and upgrades existing stored photos; failed replacements preserve originals. Static photos keep their pixel dimensions with orientation/mirroring baked into PNG pixels, subject to a 64MP/16,384px decode bound; the existing backup image-entry names stay compatible. All eight rotations/mirrors preserve the four-color fixture; GPS, camera/date/city tags are absent, canonical bytes are stable, failed saves keep originals, disk reopen keeps sanitized data, and malformed backup images fail before current workouts are deleted. Final unit target: 1,315 passed, one expected failure (`fast-20261110-125658`); the new photo Retry/Later/remove/Save/relaunch UI check passed at 390pt/default/light in that run. Five existing backup/share/restore UI checks passed (`fast-20261110-084606`). The startup alert proved unreliable during view changes, so failure uses an inline notice; its final 390pt capture was inspected. Camera/library expansion and physical photo picking were excluded. Canonical PNGs are decoded on each launch; optimize only if startup cost is measured.
Rebased onto catalog/schema main `978cb48a`: the unit target recorded 1,325 passed, two fixture-dependent skips and one expected failure, and the photo UI journey passed (`fast-20261110-130422`). The backup journey first failed to find Save in the system Files picker, then passed unchanged in a focused rerun (`fast-20261110-130934`); this intermittent picker failure remains a test limitation. No photo regression was found.
Final integration exposed a request-consumption race after the root notice container changed: starting from Program created a workout but sometimes left Program selected. Root now uses the change event's captured pending value before Today clears the request. `WorkoutExitUITests` passed Program start, resume and Back-to-Today (`fast-20261110-133853`); the unit target had passed with the route fix in `fast-20261110-133424`. The separate tempo-field failure in those runs is resolved and verified in RM-005.
**References:** [D-111](design-map/audit.md#d-111), [photo picker](../fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift).

### <a id="rm-005"></a>RM-005 — Numeric and tempo entry preserve the entered value

**P1 · Done (2026-11-10).** D-32/F355, D-31/D-189 and F383: loads round-trip in the current locale, plate additions require unique positive values, and pasted separators cannot shift tempo parts. T145's empty-part behavior F380 remains intact.
**Done when:** locale-valid weights round-trip without prefix parsing; duplicates cannot create ambiguous plate row IDs; invalid/zero values explain rejection; pasted dashes cannot shift tempo parts. Test actual parsers/save boundaries and preserve signed assistance loads and history-correction validation.
**Scope / sequence:** Deliver locale weight parsing, unique positive plate values, then pasted tempo validation at shared save boundaries. Keep relabel-only units; conversion/provenance is RM-021.
**Requires:** None; current unit semantics suffice.
**Evidence:** Locale load entry is complete (2026-11-10): the shared parser consumes the whole ungrouped decimal, supports localized digits and signed assistance, and leaves correction/completion validation unchanged. The unit target recorded 1,328 passed, two fixture-dependent skips and one expected failure (`fast-20261110-131630`); the existing logger type-over test passed. After correcting its completion-label assertion, the new German-locale journey passed: type `82,5`, log it and relaunch with the same stored load (`fast-20261110-131942`, 390pt/default/light). Its capture was inspected.
Unique positive plates are complete: actual Add mutations reject invalid/zero/duplicate values before writing; injected save failure restores saved bytes/date and permits retry. Legacy duplicate denominations combine counts on read without changing stored bytes; the shared solver bounds its count before integer conversion so tiny positive plates cannot trap. Units recorded 1,332 passed, two fixture-dependent skips and one expected failure; both plate UI checks passed (`fast-20261110-132315`, 390pt/default/light). The German-locale UI rejected zero and duplicate `2,5`, then saved `3,75` and found exactly one row after relaunch; its error capture was inspected.
Tempo validation is complete: the shared join rejects ASCII/Unicode dashes in every part before writing; both editors explain rejection and preserve the prior parts. The logger restores the native text field after its binding change, so rejected text cannot remain visible over a different model value. The extended number-entry journey passed at 390pt/default/light (`fast-20261110-134212`): actual Paste in both editors, unchanged neighboring parts, then log/relaunch with `4-1--` preserved. Both error captures were inspected.
Final combined verification, based on `d963df40` plus the final tempo source: `scripts/test.sh full` passed all 98 UI tests and 1,332 unit tests, with two fixture-dependent StoreRehearsal skips and one expected failure (`full-20261110-134446`, iPhone 17/iOS 26.5, two serial shards). The widget built; all 1,433 enumerated cases ran with none missing/repeated/unfinished and no UI idle-wait stalls. Documentation checker/self-test and token contrast checks passed, with the existing five-unreferenced-image warning. This verifies RM-006 and Lane B together; broader AX3/two-phone/physical VoiceOver remains with the stability/release owners.
**Device deployment (2026-11-10):** the `e22a1edd` install could not run because the Mac could not reach the phone; this work reached the phone with the `9cc46f54` install recorded under [RM-062](#rm-062).
**References:** [D-31](design-map/audit.md#d-31), [D-32](design-map/audit.md#d-32), [D-189](design-map/audit.md#d-189), [tempo](../fitbod/Sessions/TempoEntryRow.swift); F355/F380/F383.

### <a id="rm-006"></a>RM-006 — Redesign 1.3: session sheet, StartSlot and state slabs

**P1 · Done (2026-11-10).** The approved [Today layouts](design-map/redesign/today-layouts.md) and [hierarchy](design-map/redesign/hierarchy.md), with the live Program template-route exception below. The [implementation plan/results](archive/features/today-session-sheet-and-state-slabs.md) are archived; this entry owns current scope and acceptance. GSD/executor and capture-commit mandates in the old notes are retired.
**Done when:**

- One pure `StartSlot` rule serves hero, session sheet, Program and session detail. Rotation NEXT is the resolver's next slot; weekday NEXT is today's slot before a counted workout, otherwise the next training day's slot. No-block NEXT advances from the newest finished slotted workout, skips empty sessions and wraps.
- A twice-slotted session passes NEXT when it matches, otherwise the first matching slot after NEXT. Outside-routine starts are unslotted. Rotation/no-block rows explain skipped sessions; weekday rows skip nothing. Detail computes at tap time so deleting a slot cannot leave a stale start.
- The sheet has CANCEL, one start-on-tap row per distinct routine session, NEXT only on a usable row, disabled empty rows, and Other sessions opening detail. Rows fit content with 44pt minimum targets.
- T-PICK suggests the eligible routine holding the newest finished slotted workout, otherwise the one holding the most recently updated usable session, otherwise a standalone session. A fresh store gives T-FIRST; an empty routine gives no-block T-FIX. Block repair/T-ATTACH retain another-session access when any usable session exists.
- T-DONE lists every counted workout started today, newest first, and outranks T-READY. Its final slab is paper on paper in both appearances (FT-15). T-REST says REST DAY. T-READY starts the oldest ready block in one tap, shows creation date/ready count and reports failure.
- Remove obsolete Today block-creation/empty-session placeholders, StartBlockCTA and unused conflict presentation. Keep `BlockBuilderRoute.template` while Program's template cards still call it; migrate that caller with RM-011. Preserve the logger's Today route (O-16). Another session takes two taps from T-TODAY; mistaken start costs Back then Discard.
- Test state/slot precedence and starts through sheet/detail, including duplicate/deleted slots, two no-block starts, standalone/empty routines and two done workouts. Add ready/empty/done seeds with all finished-today timestamps between local midnight and launch. Run affected factory/resolver/start/journey checks and inspect 390pt/default/light states.

**Scope / sequence:** Pure slot/state rules → shared starter/detail/Program callers → sheet/slabs → seeds and affected checks. SchemaV7 unchanged; volume summary RM-010, review RM-013 and next-day lines RM-014 are excluded.
**Requires:** [RM-057](#rm-057), [RM-058](#rm-058). Resolve RM-001–RM-005 where the changed path relies on those safeguards; unrelated work continues.
**Scheduled after:** Shipped steps 1.1–1.2.
**Verify when:** Affected logic/UI starts and 390pt light/dark states at implementation; broader AX/phone checks at stability.
**Evidence:** All six implementation slices are complete; validation and limits are recorded below.
Slice 1 of 6, seeds (2026-11-09): `TodayStatesSeed` adds `-fitbod-seed-today-ready`, `-empty`, `-done`, `-rest`, `-attach` and `-pick`, so every Today state opens from a launch argument; T-TODAY, T-RESUME and T-FIRST had seeds already.
`TodayStatesSeedTests` checks each seed against `TodayState.resolve`, and that done-today holds one minute after midnight.
Unit target: 1,267 tests, 1,266 passed, 1 expected failure (iPhone 17, iOS 26.5).
Before-captures of all nine states at 390pt, light and dark, are in the ignored `.ci/shots/`.
Nothing visible changed.
They show what the later slices replace: an empty scheduled session still draws a startable hero, T-DONE shows only the newest workout on a dark slab, and T-REST and T-ATTACH both read "No workout scheduled".
Slice 2 of 6, StartSlot rules (2026-11-09): the pure `StartSlot` holds NEXT for rotation, weekly and no-block starts, the slot a start credits, the skipped-session list and the no-block suggestion, and `TodayState.pick` carries that suggestion.
`StartSlotTests` (16 tests) covers each rule; its block cases run through the real `TodayResolver`.
Unit target: 1,284 tests, 1,283 passed, 1 expected failure (iPhone 17, iOS 26.5).
Nothing visible changed: no start asks `StartSlot` yet (slice 3), and T-PICK at 390pt matches its before-capture.
Still open for the slab slice: no-block T-FIX names the newest routine, where the layout names the routine holding the most recently updated session first.
Slice 3 of 6, shared starts (2026-11-09): every start calls `WorkoutStarter.start(_:in:)` with the routine it came from, and `StartSlot` picks the slot at the tap; session detail takes the routine it was opened from, on Today and on the routine screen.
A session slotted twice no longer moves the rotation backwards: `WorkoutStarterTests.startOfASessionSlottedTwice` credits slot 4, and under the old first-slot rule it failed with slot 1.
The same suite covers a start from another routine or none while a block runs (unslotted, still in the block), two no-block starts in a row, and a slot removed after its screen opened.
Unit target: 1,290 tests, 1,289 passed, 1 expected failure. UI: `MilestoneOneJourneyUITests`, `BlockLifecycleEntryPointsUITests`, `TodayHeroUITests`, `SessionHistoryBRUUITests` and `WorkoutExitUITests`, 12 of 12 passed (iPhone 17, iOS 26.5).
A no-block start from Today's list or a routine's session now takes a slot in its routine; nothing on screen changed.
Slice 4 of 6, session sheet and T-PICK hero (2026-11-09, based on `ca3ec867`): with no block, Today leads with the suggested session, its exercises and a Choose another session row.
`SessionSheetContent` lists each routine's sessions once, marks at most one usable NEXT, explains skipped sessions, disables empty routine sessions and puts standalone sessions under Other sessions; routine rows start immediately and Other sessions rows open detail.
Eight content tests cover no-block/rotation/weekly rules, duplicate slots, empty sessions, other routines, standalone sessions and row summaries; `ProgramFixtures` shares the existing slot-test builders.
The review removes the dead `upNext(done:)` parameter and tests the Other sessions tap, return and subsequent routine-row start.
Unit target after the final code edits: 1,298 tests, 1,297 passed, 1 expected failure (`scripts/test.sh fast`, iPhone 17, iOS 26.5; `fast-20261109-142347`).
UI: `MilestoneOneJourneyUITests` and `TodayHeroUITests` passed 4 of 4 after the fixes (`scripts/test.sh fast -only-testing:fitbodUITests/MilestoneOneJourneyUITests -only-testing:fitbodUITests/TodayHeroUITests`, iPhone 17 shard 2, iOS 26.5; `fast-20261109-142452`). The other seven affected classes passed 25 of 25 in `fast-20261109-140437`, including ArchiveRoutineUITests.
The earlier journey failure was during Library search: its scroll helper asked a zero-size hidden ScrollView for hittability, before reaching Today. The helper now rejects empty frames; the completed-workout state still has its inline picker in this slice, so that step needed no migration. Documentation checker/self-test passed, with the existing warning for five unreferenced images.
The saved hero and sheet captures were inspected at 390pt/default text in light and dark. The sheet title wraps to two readable lines; long routine names and AX3 were not checked. Empty workout remained in the sheet at this checkpoint; slices 5 and 6 were pending.
Slices 5 and 6 (implemented 2026-11-09, verified 2026-11-10): Today renders the resolved state directly; DONE lists each counted workout with History's PR counts on paper, READY shows creation/count and Retry/Open failure actions, and rest/repair/attach/first-run states have their intended actions.
The no-block repair target now follows the newest session edit, then the newest routine, with deterministic ties. Obsolete inline/block pickers, Today block creation, empty starts and conflict presentation are removed. A second start resumes the current workout; the author/log/relaunch/history and correction tests use the retained routes.
Scope correction from caller inspection: `BlockBuilderRoute.template` is live in `ProgramTemplateSection`; keep it until RM-011 migrates those cards. No Program template capability is removed in this Today delivery.
Validation on the final app source, based on `0b1ac37e`: `scripts/test.sh fast` passed 1,291/1,292 unit tests with one expected failure (`fast-20261109-150446`). The full tier (`full-20261109-150847`) ran all 1,384 enumerated tests with no missing/repeated tests and built the widget: units passed, 91/92 UI tests passed, and the only failure expected the removed No active block placeholder. After updating that assertion, `BlockLifecycleEntryPointsUITests` passed 2/2 (`fast-20261110-073135`). After the final READY Open-button touch-area correction, the unit target and all six state-route tests passed: 1,297 passed, one expected failure (`fast-20261110-074553`), including an Open tap near the control’s top edge. All 92 UI tests therefore have passing evidence, including ready Retry/Open/relaunch, two done summaries, repair/alternate-start/discard, and the authored persistence journey.
Integrated onto current main `7615f5f4` after the workout-progression merge: migrated its two retired `startEmpty` test callers to unplanned-session fixtures. Units passed 1,298 with one expected failure and state routes passed 6/6 (`fast-20261110-075330`). The journey caught a scroll-view index race during Library sheet dismissal; binding containers by accessibility identity fixed it, and the full author/log/relaunch/finish/history/second-start journey passed (`fast-20261110-075704`). The earlier full run remains the full-suite evidence; the combined version received these focused integration checks.
Captured nine Today states at 390pt/default text in light/dark and inspected the changed first/done/ready/rest/repair/attach states. The sheet route also passed at 390pt in both appearances on 2026-11-10 (`fast-20261110-073611`, `fast-20261110-073648`), with captures confirming the empty-workout row is gone. Artifacts remain ignored local output. The sheet's two-line title is readable; long names, AX3 and physical VoiceOver stay with RM-044/RM-047 at workflow stability.
**References:** D-19/D-24/D-25/D-162–D-165, redesign R-4/R-5/R-10/R-12/R-19/R-23/R-25; [TodayState](../fitbod/Views/TodayState.swift), [sheet](../fitbod/Views/SessionSheet.swift), [session detail](../fitbod/Routines/SessionTemplateDetailView.swift), [O-2/O-3/O-6](#rm-042).

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
**Done when:** the live countdown and bar render on Lock Screen and compact/expanded Dynamic Island; background, adjustment, expiry and workout end update/clean up one activity.
**Reproduction:** with music playing, log a set, lock and inspect card/Island. Adjust −15s/+15s, let a rest expire, background during rest and finish. If blank, capture model, iOS/build and foreground state. App termination, denial and duplicates also belong to RM-047.
**Scope / sequence:** Completed implementation: widget resource membership/font registration. Remaining delivery is phone rendering/lifecycle proof; an observed defect returns to Active. Prompt identification stays RM-007.
**Requires:** Physical iPhone/current installed build for remaining proof; RM-007 is a separate investigation.
**Verify when:** With music/rest on the installed phone: Lock Screen/Island, adjustment, expiry and end. Bundle inspection proves resources only.
**Evidence:** 2026-11-09 defect fix (branch `fix/rest-timer-live-activity`): the countdown and bar were strings computed from `Date.now`, which ActivityKit never re-renders, so they froze; the exercise name truncated beside the hero digits.
The widget now uses `Text(timerInterval:)` and `ProgressView(timerInterval:)` (minimal slot too) and shows no exercise name (user decision).
Simulator (iPhone 17, iOS 26.5): Island read 2:57 then 2:53, Lock Screen 2:15 then 2:11 with the bar draining, no name. Unit target passed (1264 tests).
Open: the same check on the locked phone, plus adjustment, expiry and end. In dark appearance the card renders paper with ink text, because the ink/paper tokens flip; not changed here.
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

### <a id="rm-010"></a>RM-010 — Redesign 1.4: Today week board, full volume behind it

**P1 · Active: Today week board.** Progress → Volume, muscle routes, neck detail, bar chevrons and map caption shipped early for FT-17/18 (`d89992fb`).
**Decision (2026-11-11, user, Lavish review):** Today is a quick snapshot. The per-muscle MEV/MAV/MRV surface leaves Today; a week board replaces the planned VOLUME THIS WEEK row. It shows seven day tiles (each day's counted workout name and working sets; today outlined; REST on a rest day, LIVE with an open workout) and the week's totals, and opens Volume. In a block it sits under the plan line; without one it heads itself "This week · Nov 9–15". The exercise list previews three with a Show all row. First visit offers Start workout (an empty workout) first and "Plan a routine or block" second, reversing RM-006's removal of the empty start for that state only. Kept: the BRU header bar. Left out: a Recovery tab and recovery-generated workouts (no generator or exercise templates exist; a new tab needs its own roadmap decision).
**Done when:** The board counts finished counted workouts and their `countsAsWork` sets in the user's calendar week, excludes open/empty workouts and refreshes on finished-workout changes, History corrections, activation and day change. Volume is one tap from Today and Progress on each tab's own stack. Volume evaluates advice on appear; shared evaluator gates `deloadAlertEnabled` for both tabs. Tests cover counts/calendar/alerts-off.
**Scope / sequence:** `TodayWeek` model and board → remove Today full surface, Volume route → three-exercise preview → first-visit empty start → UI test migration and 390pt inspection. Existing Progress Volume stays; physical clipping is RM-045.
**Requires:** Shared counted-workout rules; [RM-003](#rm-003) before extending affected volume rendering.
**Scheduled after:** [RM-006](#rm-006).
**Verify when:** Counts/routes/advice-off at implementation; [RM-045](#rm-045) physical reach remains separate.
**Evidence (2026-11-11, uncommitted):** Unit target plus `TodayStateRoutesUITests` and `PerMuscleDetailUITests`: 1,224 tests, 1,221 passed, 0 failed, 2 skipped, 1 expected failure (`fast-20261111-093400`, iPhone 17 iOS 26.5), including `TodayWeekTests` (5) and the restored empty-start test. The other affected UI classes (MilestoneOneJourney, SessionHistoryBRU, TodayHero, BlockLifecycleEntryPoints, BlockWeekCounts, WorkoutExit) passed in `fast-20261111-092624`. 390pt light/dark captures inspected for ready, first-visit, rest, a Sunday-start week with a finished workout, and the deload notice. Open: the Show all row (no seed has more than three exercises), a phone install, and the Volume advice/alerts-off gating, which this slice does not change.
**References:** [Today layouts](design-map/redesign/today-layouts.md), D-131, redesign R-7/R-21; [board](../fitbod/Views/TodayWeekBoard.swift), [week](../fitbod/Views/TodayWeek.swift), [Progress](../fitbod/Progress/ProgressHomeView.swift), [advisor](../fitbod/Fatigue/DeloadAdvisor.swift).

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

**P1 · Active: complete catalog (user decision 2026-11-10).** Stable-ID incremental import exists; FT-05 Single-Leg Kneeling Leg Curl (hamstrings/machine) shipped at seed v3 (`0892c2cf`).
Seed v4 adds `curation.json`, a local overlay keyed by upstream ID; it retags 39 bodyweight and 6 weighted-bodyweight moves whose upstream equipment was blank or "other", so dips, chins, muscle-ups and inverted rows log at zero added weight.
Seed v5 carries tracking through the same overlay: 9 holds and carries log a time and the band-assisted pull-up logs assistance; it also retags the 20 Smith machine rows and Bodyweight Flyes, and gives EZ-bar and medicine-ball rows their own equipment.
Seed v6 imports nine cardio rows by opt-in under the names people use (Stair Climber, Stepmill, Elliptical, Treadmill Run, Treadmill Walk, Stationary Bike, Recumbent Bike, Rowing Machine, Jump Rope), with aliases and no muscles; `exercises.json` is the upstream file byte for byte again, the 28 local rows live in `additions.json`, and `ExerciseCatalog` resolves the three seed files for the importer and the seed checks alike.
**Decisions (2026-11-10):** one exercise per implement, grouped under a family with equipment variants ("Triceps Extension (Cable)") plus colloquial aliases; curate existing rows in place (rename, retag, hide obscure rows, never delete or re-point history); cardio and timed moves arrive with [RM-062](#rm-062).
**Machines (2026-11-10):** a brand machine is its own exercise row, not a choice on a logged workout, so comparable history stays exercise plus session intent (ARCHITECTURE.md) and per-machine increment/bar/unit settings stay on `Exercise`. `Exercise` gains optional brand and loading type (plate-loaded, stack, cable) beside family/variant/aliases/hidden, delivered through `curation.json`; Panatta rows keep their IDs and placard names and gain a family and brand. The brand picker offers Hammer Strength, Life Fitness, Cybex, Precor, Nautilus, Matrix, HOIST, Freemotion, Technogym, Arsenal Strength, Panatta and Other; no per-brand machine rows are pre-seeded except Arsenal from the user's gym floor, and CustomExerciseEditor gains brand and family pickers. Upstream "Leverage" rows become the generic plate-loaded variants. A first-time variant may take an estimated starting weight from a family sibling, marked as an estimate.
**Superseded (2026-11-11):** [RM-066](#rm-066) names a machine's maker and model on the logged workout instead of in the library.
No exercise gets a brand from now on, the custom editor's brand row is gone, and seed 9 hides the 27 Panatta rows, which keep their stored brand for the workouts that used them.
**Decisions (2026-11-11):** the user asked for every Arsenal Strength machine: a search of the maker's catalog found 58, kept with their sources and exclusions in ignored `.ci/catalog-table/arsenal-machines.json` for the coverage fill.
The sibling starting weight is approved, and the family picker gets a search field.
The agent's call on order inside a family: the standard version, the row with no variant label, comes first, then every other row A to Z by its shown title, custom exercises included.
Each new family needs its muscle credits in `muscles.json` ([RM-065](#rm-065)).
**Coverage check (2026-11-11):** seed 7's 172 families already hold every family line of the plan's coverage outline (129 lines; its estimate of about 250 families was wrong), so the fill adds no new family.
Three outline names become aliases of rows the catalog has: "hike" (Outdoor Walk), "yates row" (Row (Barbell, Underhand)) and "squat clean" (Clean).
The Arsenal Strength draft is 58 rows in 26 families (44 plate-loaded, 14 stack): two-move machines are two rows, five multi-use stations and the Smith machine are left out, and two machines get their own muscle credits.
It waited for the user's marks and approval on a [review page](https://claude.ai/artifact/8vjPN9dtdc1x2qEWpLxaYJ); its sources are in ignored `.ci/catalog-table/slice8/`.
Superseded the same day by [RM-066](#rm-066): the Arsenal machines are 53 models the machine picker suggests, not library rows, so the draft and its review are dropped.
**Done when:** every common exercise and its colloquial names are findable; updates preserve customs, stable IDs, edited stimuli and historical links; a seed validator rejects duplicates, variants without a family, load-tracked rows without equipment and colliding aliases. Curate pattern/grip metadata before exposing filters.
**Scope / sequence:** (1) bodyweight equipment overlay, done; (2) RM-062 fields and tracking in the logger, done; (3) cardio: a row outside the strength categories imports only when `curation.json` lists it, local rows move to `additions.json`, done; (4) RM-062 set duration, done; (5) word-prefix search over name, family, aliases and brand, replacing the substring predicate, done; (6) rename preparation (stimulus table, debug seeds and tests keyed by stable ID, empty logged-name snapshots backfilled), done; families, aliases, brand/loading, hidden rows and the trap bar and plate equipment (seed 7), done; the grouped Library/picker and the custom editor's family and brand pickers, done; (7) coverage fill: three search words, a search field in the family picker and the order inside a family (the Arsenal Strength machines moved to [RM-066](#rm-066)); (8) a first-time variant's starting weight estimated from a family sibling with the same equipment and loading (approved 2026-11-11). Damaged-store repair stays RM-009.
**Requires:** Existing importer. [RM-004](#rm-004) before extending custom-photo persistence; [RM-009](#rm-009) only for damaged-store recovery, not healthy-store curation.
**Evidence:** Slice 1: `BodyweightSetUITests` reproduced the disabled Done on Parallel Bar Dip, then passed after the overlay; `SeedTests.curationRetagsBodyweightMoves` checks overlay IDs and equipment; unit target 1,311 tests passed (1 known issue); `ReseedRelaunchUITests` and `WorkoutSwapJourneyUITests` passed.
Seed v5: `SeedTests.curationRetagsBodyweightMoves` checks every overlay ID, equipment and tracking value against the bundled rows, and the seeded Plank, Farmer's Walk, Band Assisted Pull-Up, Smith Machine Squat and EZ-Bar Curl; the logger results are under [RM-062](#rm-062). Seed v6: `ExerciseCatalogTests` (2 tests) checks that every overlay ID, equipment and tracking value exists, that no ID is used twice, that `exercises.json` holds no local row and that only listed rows leave the strength categories (corrected 2026-11-10: this line also claimed a name and alias collision check, which did not exist until the families slice); `SeedTests.cardioAddsNoMuscleVolume` seeds Stair Climber with its name, alias, tracking and no muscles, and a logged cardio set adds no weekly muscle volume. The logger and editor results are under [RM-062](#rm-062).
Master table (draft, 2026-11-10): all 712 catalog rows are sorted into 172 families with 572 visible rows (114 new, 11 more upstream rows to import) and 265 hidden duplicates and oddities, each with a reason. The user approved it on 2026-11-10 with three marks: hide Treadmill (Run) and the proposed Treadmill (Incline Walk), and rename Treadmill (Walk) to "Treadmill"; their note asks for speed and incline, a decision under [RM-062](#rm-062).
Seed 7 brings the approved table into the seed with the three marks applied (570 listed rows, 113 new, 266 hidden); the draft and its builder stay in ignored `.ci/catalog-table/`.
Seed 7 also settles the sleds, battle ropes and rows tagged "other": sled moves have the sled equipment, and the 6 listed rows left on "other" equipment (Atlas Stone, Battle Ropes, Cycling, Tire Flip, Yoke, Grip) log reps or a time.
Remaining slices have no acceptance yet.
Slice 6 (search, 2026-11-10): Library and picker search runs in memory after the facets (`ExerciseSearch`).
Every query word must start a word of the row's name, family, aliases, brand or equipment, in any order; punctuation, case, accents, plurals, joined words ("pullup") and the short forms db, bb, kb and bw are read.
A whole name or alias ranks first, then names that start with the query or its first word, then the rest by name; a row found only through an alias shows it ("Matches “stairmaster”").
Unit target 1,370 passed (1 known issue), including `ExerciseSearchTests` (5) and `FilterStatePredicateTests` running the in-memory pipeline.
Full tier 1,473 passed with no failure, 103 of them UI tests, including `LibrarySearchUITests`: "stairmaster" finds Stair Climber and shows the alias, and "press bench barbell medium" finds the medium-grip bench press.
The first full run failed `ReseedRelaunchUITests`, which expected "1 match" for the bench press's full name, a search that now also finds the incline bench; it now checks that exactly one row carries that name.
That run also failed `TimedSetUITests` on a lost digit, fixed under [RM-062](#rm-062).
Not on the phone yet (2026-11-10): at landing (`fc8197f5`) the Mac listed the phone as unavailable, so Xcode found no destination; reconnect and unlock it, then run the [phone installer](SETUP.md#captures-and-phone-installs) from current main.
Inspected at 390pt, light mode: an alias match in the Library and in the swap picker, a search in any word order, a long result list, the empty state and the cleared list; the empty-state heading now quotes the search with curly quotes like the alias line.
The test that every curated name, family and alias finds its row moves to the families slice, which seeds them.
Rename preparation (2026-11-10): the curated stimulus weights, the debug seeds and their tests find catalog rows by `externalID`, so the renames to come cannot break them.
The weights used to be keyed by name, and only 18 of their 57 lifts matched a catalog row; 56 match now, and Pendlay Row arrives with the families.
So on the first launch after this change, the 38 newly matched lifts take their curated muscle weights unless the lifter edited one, and weekly muscle volume, which reads those weights live, changes for every week that includes them.
A seed now gives each workout logged before name snapshots (2026-10-02) its exercise's name before it writes any rename; `SeedTests.reseedKeepsLoggedNames` renames the bench under such a workout and fails when that step runs after the rename.
Unit target 1,374 passed (1 known issue); full tier 1,477 passed with no failure, 103 of them UI tests.
Open for this slice: VoiceOver, larger text and dark mode are unchecked, and search speed over the whole catalog is unmeasured on the phone.
Families (seed 7, 2026-11-10): the master table the user approved is in the seed.
388 rows get a new name, 353 of them in the family-and-variant form such as "Bench Press (Barbell)", and every listed row is in one of 172 families.
Seed 7 hides 266 duplicates and oddities and adds 124 rows: 113 local rows, 9 plyometric moves and 2 cardio rows.
67 machines have their loading (plate-loaded or stack), the 27 Panatta rows their brand, and 7 plate moves the new `plate` equipment.
The name of a hidden duplicate and the earlier name of a renamed row are aliases of the row that stays (399 aliases keep an earlier name), unless that name now belongs to another row or family: "Air Bike" now names the cardio machine, and the upstream crunch of that name is "Bicycle Crunch".
The Library and every picker drop hidden rows in `FilterState.applyPostFetchFilters(to:)`, and a seed keeps a hidden row listed while a routine or a logged workout uses it.
`SeedTests.hiddenRowsInUseStayListed` (a logged and a planned row stay listed, an unused one hides) and `FilterStatePredicateTests.hiddenRowsAreNeverListed` check both, and each failed when its rule was removed.
`ExerciseCatalogTests.visibleRows` is the seed validator: it fails on two listed rows with one name, a listed row with no family, a load tracked on `other` equipment, a hidden row named like a listed one, a family with no listed row, and an alias in two families or naming another family.
Planted faults (a misspelled brand, two listed rows with one name, an alias naming another family) made the catalog tests fail.
`CatalogSearchTermTests` searches 355 everyday terms, every family name and alias, and every renamed row's upstream name, and expects the right family or row in the first five results; before the earlier names became aliases it listed upstream names that no longer found their row, such as "Barbell Squat".
`BackupCatalogFieldsTests.restoreClearsTheSeedStamp` also checks that a seed gives restored rows their family, variant, brand and loading; it failed when the importer left those fields alone on rows it already had.
Seed 7 rehearsed on a copy of the phone's store, starting from seed 3: exercises went from 704 to 837, and the 43 sets, the 14 logged exercises with their History names and the custom exercise were unchanged.
Of the 13 exercises in the lifter's history, 11 get a new name, and Low Cable Triceps Extension, which seed 7 hides, stays listed because a workout uses it.
Inspected at 390pt, light mode: the Library (570 exercises), searches by a long name, by a hidden row's name and by "plate", a new row's page without an instructions section, the equipment filter and the editor's equipment list with Plate, the logger and the swap picker with the longest name on two lines, and Progress with the new names.
Unit target 1,378 passed (1 known issue); full tier 1,481 passed with no failure, 103 of them UI tests; after three small review fixes the unit target passed again.
Open for the families slice: VoiceOver, larger text and dark mode are unchecked.
Installed on the phone on 2026-11-10 (`9bdd9b87`) after a fresh copy of its store (23:18) and a rehearsal of seed 7 on that copy, starting from seed 6: exercises went from 714 to 838, and the 5 workouts, 22 logged exercises, 67 sets, the routine's 8 exercises and both custom exercises were unchanged; 19 of the 22 exercises in History get a new name.
Verify on the phone: open Fitbod once so seed 7 runs, then check that History shows past workouts under their logged names, that Library lists Low Cable Triceps Extension, and that "side lateral raise" finds "Lateral Raise (Dumbbell)".
Grouped list (2026-11-10): without a search, the Library and every picker fold two or more listed rows of one family into a family line ("Bench Press", "22 variants", ▾) that opens in place to its variants, each indented under it by its short label ("Barbell"); VoiceOver still reads the full name.
A family counts only the rows that pass the facets, and a family left with one listed row shows that row itself; collapsed, the list has 172 lines instead of 570 rows, and a search stays a flat list, best first.
The custom exercise editor picks a family from the store's families and, for a machine, cable, Smith machine or cardio machine, a brand (the `MachineBrand` list, None or Other); a copy keeps its source's family and brand, and a brand on other equipment is dropped at save.
`LibraryLinesTests` (3) checks the folding, the sections and the standard version first; `CustomExerciseDraftTests.familyAndBrand` checks that both fields save on create and update, that a barbell drops the brand and that both make the draft dirty.
`CustomExerciseEditorBRUUITests.testMachineJoinsItsFamilyWithItsBrand` picks Hammer Strength and Chest Press, saves, opens the Chest Press line to the new exercise and finds both values after a relaunch.
[RM-066](#rm-066) later removed the brand row; these tests are now `CustomExerciseDraftTests.family` and `CustomExerciseEditorBRUUITests.testMachineJoinsItsFamily`.
Inspected at 390pt, light mode: the collapsed list, Bench Press and Chest Press opened (long Panatta labels on two lines), the Cable facet with family lines and single rows, the swap picker opened, and the editor with its family and brand lists.
Beside the approved mock-ups for the Library, the picker and the custom exercise editor, the only new differences are the family line, the short variant labels and the Family and Brand rows, all chosen in the plan; the design-map screen files already list the older differences.
Before the rebase onto `main`, the unit target passed 1,382 (1 known issue) and the full tier 1,486 with no failure, 104 of them UI tests.
After the rebase (RM-063, RM-064, RM-053) and the review's fixes (two helpers made private, two comments), SwiftLint found nothing, the unit target passed 1,221 (1 known issue) and the Library, editor and swap UI suites passed all 9 of their tests.
Installed on the phone on 2026-11-11 (`1cb90b5a`) after a fresh copy of its store (00:09) that matched the 23:18 copy, so seed 7 has not run there yet and the earlier rehearsal still covers it.
Verify on the phone: once seed 7 has run, check that the Library folds Bench Press into one line that opens to its variants, and that a new machine exercise can pick a family (its brand row is gone since [RM-066](#rm-066)).
Open for the grouped list: VoiceOver, larger text and dark mode are unchecked; once a family line scrolls away, its variants show only their short labels and the indent; the Library screens in the design map wait until the workflow is stable.
**References:** LIB-01–06/FT-05; [importer](../fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift), [seed source](../fitbod/Resources/ExerciseSeed/SOURCE.md).

### <a id="rm-062"></a>RM-062 — Tracking types, cardio and set duration

**P1 · Implemented; verification pending (user decision 2026-11-10).** Since slice 3 the logger, History, Edit workout and routines handle timed holds and carries and assisted reps. Since slice 4 nine cardio rows log a time with a level or a distance, and a custom exercise picks what its sets record. Since slice 5 a load set records how long it took, from the rest before it or a START tap, and the logger and History show each exercise's time.
Unproven: the phone checks under Evidence.
**Decision (user, 2026-11-11):** a treadmill set records its time and the treadmill's own settings, speed and incline; distance is a nice-to-have, so it shows derived from speed and time.
That adds a tracking type and set fields, an additive change to SchemaV7 that this entry's store rehearsal covers before and after.
**Done when:** each exercise has a tracking type (weight × reps, reps with optional load, assisted reps stored as a negative weight, time, time + distance, time + level); distance is stored in meters and converted for display; the logger shows matching columns and validates by type; every set records its duration automatically (it starts at the end of the rest before it, a skip, or a START tap; editable), and the logger and History show exercise time ("8 × 10 · 3:00"); tonnage, e1RM, PRs and progression ignore non-load sets; export and backup carry the new fields and older backups still restore.
**Scope / sequence:** Additive default-valued fields on `Exercise` and `SetEntry` in SchemaV7 → validation/columns → export/backup → set-duration capture and totals → treadmill speed and incline (decision 2026-11-11).
**Requires:** The store rehearsal (`scripts/rehearse-store.sh`) on a copy of the phone's store, passing before the model change and again after it, with the pre-change backup restoring into the new build; first run recorded under [RM-029](#rm-029). Old-shape stores opening in place and a backup round trip of the new fields stay in the unit suite.
**Evidence:** Slice 2 (fields, 2026-11-10): the store rehearsal passed on a copy of the phone's store before the model change and again after it; the copy opened in place with 704 exercises, 4 workouts and 43 sets, every new column at its default, and the pre-change backup restored into the new build to equal data. Unit target 1,319 passed (1 known issue), including an old-shape `Exercise`/`SetEntry` store opening in place, a backup round trip of every new field, a format-2 backup restoring with defaults, a newer format refused, and restore clearing the seed stamp. UI: `BackupRestoreRoutinesUITests`, `ReseedRelaunchUITests`, `SettingsExportUITests`, `WorkoutSwapJourneyUITests`, `CustomExerciseEditorBRUUITests`, `NewRoutineFlowUITests` and `BodyweightSetUITests` passed (14 tests). Slice 2 on the phone (2026-11-10): installed and launched; the store pulled back after the real upgrade passed its integrity check with the same 704 exercises, 4 workouts and 43 sets, every new column at its default and nothing moved aside.
Slice 3 (tracking in the logger, 2026-11-10): unit target 1,351 passed (1 known issue), including `TrackingTests` (19): the completion rule per type, timed offers, no prescription or warm-up ramp for timed and assisted exercises, tonnage/e1RM/records skipping them while counts and the summary include them, load progression reading rep sets only, time and distance text, corrections that judge only changed and added sets in the shape they were logged, a retagged exercise keeping its history, swap, routine defaults, a custom copy keeping its tracking and the timed exercise history.
Full tier 1,450 passed with no failure, 99 of them UI tests, including `TimedSetUITests`: Plank has no reps field, "130" typed logs 1:30 and History shows it after a relaunch.
An earlier full run failed `WorkoutExitUITests` and `NumberEntryUITests.testTempoAndPartialRepsTypeOver`: START WORKOUT from Program started the workout but left Program selected. `main` failed the same way until `d963df40` fixed it, and both pass on the rebased slice.
The full tier ran one commit behind `main`; after the rebase onto `e22a1edd` the unit target (1,351) and `NumberEntryUITests`, `TimedSetUITests` and `WorkoutExitUITests` (8 tests) passed again.
Inspected at 390pt, light mode: timed, timed + weight and assisted logger rows, the summary, History, Edit workout (changed time, added set), exercise detail and history, the routine editor and both equipment lists.
Fixed on the way: the "Done" column heading shrank in a card without the Effort column, and `UITestNavigation.loggerSpan` read the keyboard's frame while it slid away.
Open for this slice: VoiceOver, larger text and dark mode are unchecked.
Verify on the phone, which has this slice since the slice 4 install: log a Plank set and confirm History shows its time.
Slice 4 (cardio, 2026-11-10): unit target 1,356 passed (1 known issue), including the catalog and seed checks under [RM-022](#rm-022), a cardio draft saving with no muscle, a custom exercise storing a tracking choice only when it differs from its equipment's, the mechanic filter leaving cardio out, and a distance or level shown in the locale it is typed in.
Full tier 1,457 passed with no failure, 101 of them UI tests, including `TimedSetUITests` (Stair Climber logs 20:00 at level 8 and History shows it after a relaunch) and `CustomExerciseEditorBRUUITests` (a cardio machine saves with no muscle and keeps its picked tracking after a relaunch).
Inspected at 390pt, light mode: the Stair Climber and Treadmill Run cards (TIME with LEVEL or MILES), the summary, History and Edit workout, the cardio Library row, both exercise pages (no prescription or plateau settings; a distance unit where one applies) and the editor's Tracks list and cardio state.
A restored older backup, or a custom exercise, with cardio machine equipment and no stored tracking now logs time and distance; the copy of the phone's store has no such exercise.
Seed 6 rehearsed on a copy of the phone's store, starting from seed 3: exercises went from 704 to 713 (the nine cardio rows), and the 43 sets, the 14 logged exercises with their names and the custom exercise were unchanged.
Installed on the phone on 2026-11-10 (`9cc46f54`); the launch from the Mac was refused because the phone was locked.
Open for this slice: a cardio set starts a rest timer like any other set; VoiceOver, larger text and dark mode are unchecked.
Verify when the phone is unlocked: open Fitbod once so seed 6 runs, then confirm that History still shows past workouts and that Library finds Stair Climber.
The store copy pulled from the phone on 2026-11-10 at 23:18 shows that seed 6 ran: it holds 714 exercises, the nine cardio rows among them, and 5 workouts with 67 sets; the check on the phone itself is still open.
Slice 5 (set duration, 2026-11-10): unit target 1,365 passed (1 known issue), including `SetDurationTests` (9): the start rule (a skip during the rest, a set lifted in the overrun and a late tap after it, no rest, a new rest replacing the one that ended), Done storing the start and duration in one save and restoring both when the save fails, START winning over the rest, a re-checked set keeping its time, a start under a second or over an hour leaving the time unknown, a timed set keeping its typed time, the exercise time, and a swap keeping a completed set's time while clearing a pending START.
Full tier 1,467 passed with no failure, 102 of them UI tests, including `SetDurationUITests`: the first set has no time, the set after a skipped rest and the set after START show theirs, a tap corrects one, and the card and the summary show the exercise time.
Inspected at 390pt, light mode: START, the running set time, a completed set's time under its row with and without the effort picker, its editor, the card subline (the time joins the line when it fits and takes its own line when not) and the summary line.
Known limit: a set lifted after resting past the timer, including an exercise's first set after the walk to it, gets a time that includes the extra rest; tapping its time corrects it.
Open for this slice: VoiceOver, larger text, dark mode and the phone are unchecked.
Verify on the phone: log two bench sets with a rest between them, confirm the second shows its time, and confirm History shows the exercise time.
Fixed on the way (time entry, 2026-11-10): the three time fields (a timed set in the logger, a set's time correction and Edit workout) put their colons in while digits were typed, by rewriting the text from `onChange`.
A digit typed just after that rewrite could show in the field and never reach its text, so "13000" typed fast saved 13:00 or 1:30: `TimedSetUITests` failed this way once in a full run, and a throwaway UI loop lost a digit in 4 of 40 rounds.
SwiftUI draws a changed text only on a later pass, the window in which the digit is lost, so the fields now show the digits as typed and the colons once editing ends, and each logger keystroke writes its time at once.
The loop then lost no digit in 30 rounds per field, screenshots showed the typed digits while typing and the time after DONE, and seven digits now read as no time instead of silently losing one.
`TimedSetUITests` types the stair climber's time ten times; the full tier under [RM-022](#rm-022) slice 6 includes it.

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
**Evidence:** Exercise-level weight guidance and the compact effort control shipped in `fd5f6938` (PR #2) and are verified. The logger shows the rep target and starting-weight prompt when there is no load to suggest. The suggestion stays available after logging, weight fields accept direct edits during calibration, and effort expands within the set being rated. Updated checks cover restoring the frozen weight, editing a calibration load directly, and recording a half-step effort after logging. On 2026-11-09, f4df0713 built; its unit run failed only a plural copy rule this branch broke and the stale `.planning/ROADMAP.md` audit; the 11 affected logger UI classes passed 29 of 29 on iPhone 17; a 390pt iPhone 17e default-text light pass showed aligned columns, Use replacing a weight still being typed, and the keyboard closing before Calculation details. Review fixes then corrected that copy, kept an open set's effort rating out of the logged orange, moved the rule that a 0 suggestion offers no Use into one tested `PrescriptionExplanation.suggestedWeight`, removed the sheet's unused Use/Override path and set-type label, and added `WeightCellSeedingTests` for a logged 0 lb set; the stale audit test is deleted, as 99ef6bec removed the file it read. Closed 2026-11-09 on `fd5f6938`: the unit target passed (1,265 tests, 1,264 passed, 1 expected failure; iPhone 17, iOS 26.5).
On a 390pt iPhone 17e at default text in light mode, an open set's effort rating drew in ink, not the logged orange, and the calculation sheet's header showed the recommendation, weight, reps and RPE with no set-type label and no Use or Override.

**Weight and rep offers: Done (2026-11-10, PR #3).** Pending working sets offer both inputs from the programmed block, current-workout performance, or the last finished matching-intent workout. A new lift in an empty workout waits for the first completed set. Double progression can add a rep within the programmed range and resets reps after a load increase. Review fixed RPE/hybrid targets changing when only the load was edited, and current-workout actual reps being clamped to the program range. Entered values win per field; completion saves accepted offers together. Completed sets keep their original lift after a swap. Regression checks cover save retries, accepted offers across relaunch, and a swapped workout across disk-store reopen.
**One history fetch per card render (2026-11-10).** After a phone debug run was killed for memory, the logger's per-render prescription reads an exercise's logs once (`PreviousMatchingIntent.logs(of:)`) for both the last-workout offers and the progression history, instead of two identical fetches; the test-only `fetchHistoryPoints`/`lastSessionWorkingReps` wrappers are gone. The kill did not reproduce on the iPhone 15 Pro Max simulator (49-61 MB through a seeded workout, rest timer and edits), and the phone kept no jetsam report, so the cause stays open until a phone run shows which screen grows. The fetch still runs on every render.
**Verification:** `911999a1` passed `scripts/test.sh full` on 2026-11-10: 1,392 enumerated and run exactly once, 1,391 passed, one existing expected failure, no failures/skips. This includes all 87 UI checks on two serial iPhone 17/iOS 26.5 shards at default text/light, plus the app/test and widget builds. On 2026-11-09, the same source changes passed the unit target and both CalibratingWeight UI tests on iPhone 17e/iOS 26.5 (1,307 tests, 1,306 passed, one expected failure); 390pt/default-text/light captures showed aligned inputs and persisted acceptance. Documentation checker/self-test, token contrast and diff checks passed; the existing five-unreferenced-captures warning remains. Physical/dark/AX3 acceptance stays with RM-044/RM-047/RM-048; CI is not a merge gate under RM-053.

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
**Evidence:** 2026-11-10 rehearsal on a copy of the iPhone 15 Pro Max store, code at `aef18229` (`scripts/rehearse-store.sh`, `StoreRehearsalTests`): the copy opened in place through `FitbodModelContainer.make` with nothing moved aside; SwiftData row counts equal the SQLite table counts (704 exercises, 2,117 stimuli, 4 workouts, 14 logged exercises, 43 sets, 4 plate inventories, 17 muscles and 17 targets, 1 settings row); a backup of it restored into a second, empty on-disk store and the two export documents were equal entity by entity. Limits: the second store was in the simulator test host, not on a second phone; that store holds no routines, splits or blocks, so those rest on the `BackupRoutinesRoundTripTests` fixtures. No passing acceptance is recorded for hostile, corrupt or interrupted input, pre-restore recovery or truthful backup state.
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
**2026-11-11 bounded maintenance — Done for the rest-state slice ([PR #4](https://github.com/Saechaoc/fitbod/pull/4)):** `RestTimerEngine` holds its running fields in one private value; public reads, callers, deadline persistence, rounding and side effects stay the same. Characterization/before-and-after unit runs: 1,214 tests each, 0 failures. Full run: 1,318 tests (104 UI), 0 failures, 2 skips and 1 expected failure; all enumerated tests ran once, both UI shards had 0 idle-wait stalls, widget build passed. Timer-file line coverage 142/148 (95.95%) → 149/155 (96.13%); changed commands stay at 100%. SwiftLint, whitespace, documentation checker/self-test and complete GitNexus change analysis passed (docs retain one existing image warning). No formatter/mutation gate is configured; physical notification/Live Activity rendering was not checked. Other RM-034 work remains deferred.
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
**Decision (user, 2026-11-11):** the week's total on Today and Progress (WORKING SETS · THIS WEEK and VS LAST WK) counts the working sets logged, each once, while the muscle bars keep stimulus-weighted sets; shipped with [RM-065](#rm-065).
The agent's call: a set of an exercise that trains no muscle, such as cardio, is not counted, because the total heads the muscle volume and cardio adds none.
The weekly recap's WORKING SETS counts the same sets; the recap's other aggregates still need a choice.
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

- **Scope:** personal local-only SwiftUI/SwiftData iPhone lifting app, Swift 6/iOS 26.4. No accounts/backend/analytics, commercial distribution, Android/web, Watch, HealthKit, external sensors/VBT, social, nutrition/sleep or form-video analysis in v1; cardio and timed-exercise logging entered scope 2026-11-10 ([RM-062](#rm-062)). Session-level intent/progression supersedes original per-exercise intent (PIVOT-01–05); retain exercise targets/four progression strategies.
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
- F352 resolved by documentation correction (2026-11-09): `Exercise` has no archive flag; architecture/conventions now require `ExerciseDeletion.delete` to clear history/template links before deleting. Library guidance also matched `FilterState`: search in the SwiftData predicate, facets after fetching through `applyPostFetchFilters(to:)`. No app behavior changed. Since RM-022 slice 6 (2026-11-10) search runs in memory after the facets (`ExerciseSearch`), and `FilterStatePredicateTests.facetsRunOverEveryRow` pins the fetch of every row.
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
**Evidence:** Historical simulator/asset evidence below. 2026-11-11, iPhone 15 Pro Max (430pt), iOS 26.7.2, dark mode: an 83pt black band covered the bottom of every tab, hiding the lower heatmap above the tab bar. A view dump on the phone found a `ScrollEdgeEffectView` that iOS 26.7 lays over the hidden system tab bar's area; iOS 26.5 simulators do not add it, so they never showed the band. `RootView` now hides the bottom scroll edge effect on the tab container; the user confirmed on that phone that the band is gone. Unit 1,209/1,212 (0 failed) and `WorkoutExitUITests` passed. Still unproven: calf taps on the large phone and the small-phone pass.
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

**P3 · Implemented; verification pending (2026-11-11): the push and manual runs passed their checks, but the first nightly run never started; one must start on its own.**
Local checks stay the delivery policy, and CI gates nothing.
**Done when:** choose/verify main/release triggers or explicitly adopt local/manual evidence as policy here.
For the 2026-11-10 triggers: one push run on `main` is green, one manual run with the UI suite finishes inside the 120-minute limit, and one nightly run starts on its own and finishes inside it.
**Decision (user, 2026-11-09):** local evidence is the policy for `main`.
A slice lands on `main` and is pushed when the unit target and its affected UI classes pass locally; the full tier runs once per feature, before its last slice merges ([policy](DEVELOPMENT.md#scale-effort-to-the-change)).
No pull request is needed per slice, and CI gates nothing.
**CI decision (user, 2026-11-10):** CI also runs on `main` pushes and nightly, and only reports.
Every push to `main` or `claude/**` and every pull request builds and runs the unit tests, about 13 minutes on the runner.
The UI suite runs once, on the large iPhone, only in the nightly run (11:17 UTC) and in manual runs; it takes about 75 minutes, so those runs finish in about 90, inside the 120-minute limit.
The small-phone UI step returns at release readiness ([RM-048](#rm-048)).
SwiftLint reports Fitbod's own rules ([RM-064](#rm-064)) as annotations and never fails the job.
**Local simulator decision (user, 2026-11-10):** Reuse existing dedicated test
devices across worktrees and sequential unit/UI/capture runs by default.
One or two booted devices usually suffice; use more when concurrency,
isolation or required model/runtime coverage needs them. There is no hard
device limit. A device has one run at a time because verification resets app
data; wait or use another dedicated device when it is busy. Shut down idle
extras. Separate DerivedData remains per worktree.
[Setup](SETUP.md#local-simulator-reuse) replaces the former per-task device
allocation; scripts do not enforce exclusivity.
**Scope / sequence:** Choose delivery trigger policy → implement chosen triggers → observe expected CI run. No CI performance redesign.
Not included: porting CI to `scripts/test.sh`, sharding on the 3-core runner, and skipping nights with no commits.
**Requires:** None; the choice is made.
**Verify when:** The nightly run due on 2026-11-12 at 11:17 UTC; it must start on its own and finish inside the limit.
**Evidence:** The user chose this on 2026-11-09. The last green CI run took 37 minutes (2026-10-04), and the PR #2 run was cancelled at the workflow's 120-minute limit. The workflow file did not change for that decision, and why that run hung was not investigated.
Workflow change (2026-11-10): only `.github/workflows/ios.yml` changed, and `scripts/ci/ios-ci.sh` did not.
The UI step now runs only in nightly and manual runs, the small-phone step is gone, and the last step fails the run only when a step that ran did not pass.
Push run (2026-11-10, `c72a40cd`): [run 42983128958](https://github.com/Saechaoc/fitbod/actions/runs/42983128958) passed in 14 minutes.
SwiftLint found no violations, the unit target ran 1,220 (1,217 passed, 2 skipped, 1 expected failure, none failed), and the UI step was skipped.
Manual run (2026-11-11, `90806f52`): [run 42986732910](https://github.com/Saechaoc/fitbod/actions/runs/42986732910) finished in 90 minutes: 3 for the build, 10 for the unit tests and 75 for the UI suite.
It ran on iPhone 17 Pro Max/iOS 26.5 with Xcode 26.6; the unit target ran 1,224 (1,221 passed, 2 skipped, 1 expected failure, none failed), and 103 of the 104 UI tests passed.
One UI test failed, so the run is marked failed: in `CustomExerciseEditorBRUUITests.testCardioSavesWithoutAMuscleAndKeepsItsTracking`, the name field read "T62 Arc Traine" after the test typed "T62 Arc Trainer".
On the Mac its class ran three times on iPhone 17/iOS 26.5, and all nine test runs passed, so the test fails only on GitHub's runner; the helper change and its runner results are in [RM-054](#rm-054).
At 90 minutes, the UI suite has about 30 minutes to grow before the nightly run reaches the limit.
Nightly run (2026-11-11): the first one, due at 11:00 UTC, never started, though the workflow was active on the default branch.
GitHub can drop scheduled runs at the top of an hour, so the cron moved to 11:17 UTC.
The CI summary now names the small phone only when its UI suite ran; before, it named a phone no step used.
**Simulator policy checks (2026-11-10):** `check_map.py --self-test`,
`check_map.py` and `git diff --check` passed; the checker reported five existing
unreferenced screenshots. Documentation only; no app tests rerun.
**References:** [workflow](../.github/workflows/ios.yml), [CI script](../scripts/ci/ios-ci.sh), original CI flag.

### <a id="rm-054"></a>RM-054 — Kept tests fail honestly/stay fast

**P2 · Planned follow-ups; T119 baseline shipped.** Preserve F374/F377 best-effort hosted assertions, T134's deferred activate/dead-branch/hosting merge (F317/F328), and helper/runner issues.
**Done when:** missing host trees report unavailable/failure, not unchecked passes; eliminate order-dependent activation. Consolidate duplicate logger reveal span (Phase-1B item 4); fix topSheet/stepper when real callers need it (F22/F42/F86/F376). Keep data-case budgets per guide/document exceptions F388; address backup/defaults litter affecting runs, isolate defaults, investigate hangs/snap-back apart from app failures.
T110-ext recorded an AX3 editor hang on the small iOS 26.5 phone: scroll EDIT PRESCRIPTION past Rest, then query controls; the main thread did not idle for 30 seconds. It also failed at base `3428ffea`, independent of the override removal (`496906a7`). Recheck that path when the editor stabilizes; the retired SessionEditorPolishUITests suite need not return.
**Scope / sequence:** On a kept-test reproduction: fix fail-honestly/activation → necessary shared helpers → compare timing. F317/F328 hosting merge, duplicate reveal, defaults/litter return when their callers block iteration; no wholesale UI-suite restoration.
**Requires:** Kept-test/helper reproduction or iteration-blocking slowdown.
**Verify when:** On retained-test failures, necessary helper changes or iteration-blocking slowdowns.
**Evidence:** No passing acceptance is recorded for remaining scope; historical references do not close it.
Typing helper (2026-11-11): in manual CI [run 42986732910](https://github.com/Saechaoc/fitbod/actions/runs/42986732910), `CustomExerciseEditorBRUUITests.testCardioSavesWithoutAMuscleAndKeepsItsTracking` typed "T62 Arc Trainer" and return in one go, and the field held "T62 Arc Traine".
It did not fail that way again in 55 runs on the Mac, including with the keyboard daemon or the whole simulator slowed, or in 30 runs on GitHub's runner ([run 43047416342](https://github.com/Saechaoc/fitbod/actions/runs/43047416342)).
`UITestNavigation.type` now presses return only once the field shows the whole text, which removes the race between the last letter and return; whether that race caused the failure is unproven.
With the change, the 16 UI classes that type through the helper passed on the Mac, 48 of 48, and the test passed 30 of 30 runs on the runner ([run 43047179496](https://github.com/Saechaoc/fitbod/actions/runs/43047179496)).
Open, runner only: in one of the 30 runs with the old helper, the same test failed after a relaunch, when the Library tab button left the accessibility tree just after `UITestNavigation.selectTab` tapped it; XCUITest's check for interrupting alerts had taken 10 seconds before the tap.
**References:** F17/F20/F22/F35/F42/F82/F86/F135/F150/F164/F180/F202/F208/F218/F239/F241/F263/F271/F299/F349/F374–379/F381/F386/F388; [guide](test-performance-guide.md), [helpers](../fitbodUITests/UITestNavigation.swift)/[logger helpers](../fitbodUITests/WorkoutUITestNavigation.swift).

### <a id="rm-063"></a>RM-063 - MetricKit reports shared from Settings

**P2 · Implemented; verification pending (user decision 2026-11-10).**
The app saves each MetricKit report as a JSON file and keeps the newest 30.
Settings → Diagnostics → Share reports shares them as files.
Unproven: a real report on the phone.
**Done when:** a report MetricKit delivered on the phone is shared from Settings and opens as JSON.
**Scope / sequence:** `DiagnosticsStore` saves metrics and diagnostics payloads to `Application Support/Diagnostics/` → one Settings row shares them, or reads "None yet" and cannot be tapped.
Not included: a launch-argument seed, a UI test, payload parsing or a viewer screen.
**Requires:** None.
**Verify when:** The first report reaches the phone, about a day after an install.
For one sooner, run the app from Xcode on the phone and choose Debug → Simulate MetricKit Payloads.
**Evidence:** 2026-11-10: the unit target and `SettingsExportUITests` passed on iPhone 17/iOS 26.5 (1,387 run: 1,384 passed, 2 skipped, 1 expected failure, none failed).
`DiagnosticsStoreTests` checks that 31 saves keep the newest 30, newest first, and that two reports saved in the same millisecond both stay.
At 390pt (iPhone 17e, default text, light) the empty row reads "None yet", muted and without "›", and a tap does nothing.
With three sample reports in the app's container it reads "3 reports ›", and one tap opens the share sheet with 3 documents and Save to Files.
Installed on the iPhone 15 Pro Max with `scripts/phone.sh` the same evening, over the existing app and its data.
**Limits:** MetricKit gives exit reasons and peak memory per day, plus the stacks of crashes and hangs, but no stack for a memory kill.
It does show whether exits are memory kills, which [RM-024](#rm-024)'s phone run could not tell.
The files stay on the phone until the lifter shares them.
**References:** [store](../fitbod/App/DiagnosticsStore.swift), [Settings](../fitbod/Settings/SettingsView.swift), [test](../fitbodTests/DiagnosticsStoreTests.swift).

### <a id="rm-064"></a>RM-064 - Lint rules replace the source-reading tests

**P3 · Done (2026-11-10).**
SwiftLint checks Fitbod's own rules on each file an agent edits and before every `scripts/test.sh` run, and the tests that only matched text in `.swift` source are gone.
**Done when:** `swiftlint lint` is clean on `main`; a planted violation of each rule group is reported by the edit hook and stops `scripts/test.sh`; a token in a comment or a test file stays silent; and the tests whose only assertions match text in `.swift` source are gone, with the unit target passing.
**Scope / sequence:** SwiftLint with only Fitbod's own rules (`.swiftlint.yml`), a Claude edit hook (`scripts/lint-hook.sh`) and a lint step in both `scripts/test.sh` tiers → delete the source-reading tests.
No default style rules, no baseline and no pre-commit block; CI only reports ([RM-053](#rm-053)).
Add a rule only when a mistake repeats.
**Requires:** None.
**Evidence:** Lint (2026-11-10): SwiftLint 0.65.1 lints `fitbod/` and `FitbodWidgets/` clean in 0.4 s.
The rules are the five BRU audit suites' regexes with their scopes, `AdaptiveColorSourceTests`' fixed-RGB check and the `CONVENTIONS.md` bans.
They apply app-wide where code had no hit, everywhere but `BlockBuilderView.swift` for SF Symbols and rounded shapes, and only in the named files for `Picker(`, `.toolbar`, `Stepper(`, `Divider()` and `Section(`.
Of 23 planted cases, every rule group was reported by the hook and by the whole-tree lint that `scripts/test.sh` runs, which then exited 1 before building.
Tokens in comments, in `BlockBuilderView.swift`, outside a scoped file, in a test file and in non-app Swift stayed silent.
The unit target passed through the new step: 1,383 run, 1,380 passed, 2 skipped, 1 expected failure.
Test removal (2026-11-10): 23 files of source-reading tests were deleted, and 51 such tests were cut from 13 files that also test app behavior.
The unit target went from 1,383 tests to 1,220, a drop of 163: the 112 tests in the deleted files plus the 51 cut tests.
It passed on iPhone 17/iOS 26.5: 1,217 passed, 2 skipped, 1 expected failure, none failed.
Four route tests now run under `MuscleSlugRoute` and the font license check under `Font licenses`; the Program font test now reads the app bundle, not the source.
Kept on purpose: tests that run app code, read fixtures or guard stored data, and the two rule checks that parse string literals, `UICopyRulesTests` and `ExerciseDisplayNameSourceTests`.
Review fixes (2026-11-11): one test now checks that every `BRUFace` loads at launch under its PostScript name, and no test registers a font by hand, which had hidden a missing `UIAppFonts` line.
It replaced the Program font test and three `BRUFoundationsTests` font tests, one of which counted a fixed list and could not fail.
The license test now checks that each font in the built app ships with its family's OFL file, so it covers all four licenses and any new font.
Nine `BRUPrimitivesTests` that could only fail at build time were deleted, with the unused `HeaderSlot.empty`.
With Geist's `UIAppFonts` line and license file removed, both tests failed; restored, the unit target passed on iPhone 17/iOS 26.5: 1,212 run, 1,209 passed, 2 skipped, 1 expected failure, none failed.
**References:** [rules](../.swiftlint.yml), [hook](../scripts/lint-hook.sh), [test tiers](SETUP.md#test-tiers).

### <a id="rm-065"></a>RM-065 - Correct muscle credit: three delts and audited exercise tags

**P1 · Done (user report and decisions 2026-11-11).**
Landed in `13d04db9`.
On a copy of the phone's store, Today showed Shoulders at 18 sets with "NEAR MRV — DELOAD" after a push day and a pull day, while lats and middle back showed 3 sets each.
The app counted front, side and rear delts as one muscle, so presses, lateral raises, upright rows, rear delt flies and face pulls all filled one bar.
Upstream tags added wrong credit: lat pulldowns credited shoulders, the band-assisted pull-up credited abs and not biceps, and the hack squat and hip thrust credited calves.
The curated weights for 57 lifts never removed an upstream row, so those wrong rows stayed even on curated lifts.
**Decisions (2026-11-11):** Shoulders becomes Front, Side and Rear Delts with RP's landmarks; the week's total on Today and Progress counts the working sets logged, not muscle shares ([RM-038](#rm-038)).
**Done when:** every listed exercise but cardio takes its muscles from `muscles.json`, one profile per family with overrides for the variants that train the muscles differently; a seed makes each catalog exercise's stimulus rows match its credits exactly and moves a custom exercise's shoulders credit to a delt; the volume bars, heatmap, targets and muscle pickers show the three delts; the week's total counts sets; the phone's own week reads sensibly after the seed.
**Scope / sequence:** Muscle list and landmarks → `muscles.json` and exact stimulus rows in the importer, replacing `StimulusWeightTable` and its seeder → retire the shoulders muscle → heatmap → the week's total → seed 8, with the library splash shown while a seed runs, because the seed now deletes rows that Today reads.
The credit rules are in `fitbod/Resources/ExerciseSeed/SOURCE.md`; [RM-022](#rm-022) adds a profile with each new family.
**Requires:** None; the schema is unchanged.
**Evidence:** Reproduction (2026-11-11): the phone's store copy from 00:09, opened in the 390pt simulator with no reset, showed Shoulders 18 "NEAR MRV — DELOAD", Lats 3, Middle Back 3 and "56" working sets this week; the 35 sets actually logged include two band-assisted pull-up sets typed as warm-ups, which correctly do not count.
After (2026-11-11), the same store copy with this build: seeds 7 and 8 ran behind the library splash.
The store then had 19 muscles and 19 targets, no shoulders muscle, the same 5 workouts and 67 sets, and 838 exercises (714 before; none deleted).
Today read 35 working sets, +23 vs last week (12 sets, the leg day), with Side Delts 6 (under MEV), Rear Delts 7, Front Delts 5, Chest 8, Triceps 7, Biceps 7, Middle Back 5, Traps 4, Lats 3, Forearms 2, Abdominals 3 and Calves 1; each equals the store's working sets times its exercise's credits.
The capture also showed an older fault: the heatmap colored a muscle with no sets this week as under MEV, and its detail screen chipped UNDER MEV, while its bar read NOT TRAINED.
Both now read NOT TRAINED, through one chip rule for the bar and the detail screen and no heatmap zone for an untrained muscle; VoiceOver reads "Not trained" on the bar too.
Full tier (2026-11-11, two simulators): 1,326 of 1,326 enumerated tests ran, 1,323 passed, 0 failed, 2 skipped, 1 expected failure; lint clean; the widget build succeeded.
A review then made the weekly recap's WORKING SETS count the same sets as Today, corrected the restore notes that said a re-seed deletes nothing, and added a test that a seed is pending until the importer runs; afterwards the unit target and WeeklyRecapUITests passed (1,226 tests: 1,223 passed, 0 failed, 2 skipped, 1 expected failure).
Rollback point: a copy of the phone's store from 07:57, after seed 7 ran there (838 exercises, 17 muscles, 5 workouts, 67 sets), in ignored `.ci/phone-store/`.
On the phone (2026-11-11): a build with this change reached it between 08:20 and 08:50, when `main` ended at `fe123665`, and seed 8 ran there.
The store copy pulled at 08:50 passed its integrity check and held 19 muscles with the three delts and no shoulders, 19 targets, 838 exercises and the same 5 workouts and 67 sets.
Its week reads 35 working sets against 12, with the same muscle numbers as the rehearsal above.

### <a id="rm-066"></a>RM-066 - Machine profiles: the machine is named in the workout, not in the library

**P2 · Implemented; verification pending (user decision 2026-11-11).**
The user asked for "a hybrid of Option B with optional machine profiles": a clean library of exercises, with the maker and model of a machine named, optionally, on the workout.
Under [RM-022](#rm-022)'s 2026-11-10 decision every brand machine would have been its own exercise row, and the 58 Arsenal Strength rows were waiting for review; the user's objection was that a hack squat is one exercise, done on any number of machines.
**Decisions (2026-11-11):** a machine is a `MachineProfile` with an optional maker and model, and a logged exercise points at the machine it was done on; a pick changes only that workout's log, never the exercise.
Loads compare only within one machine, and logs with no machine are a group of their own.
A machine with no matching workout of its own shows the latest one on another machine for reference only: no load, progression or offer carries over.
The machine is one compact line on the card, only for equipment that takes a machine, and a new log starts on the exercise's last machine.
Progress charts, volume, tonnage, counts, the weekly recap and the PR list stay exercise-level aggregates.
Seed 9 hides the 27 Panatta rows; their models and 53 Arsenal Strength models form a bundled list that the picker suggests for `machine` equipment.
**Done when:** a machine can be named, changed or cleared on a logged exercise in a few taps, with no new required step; a maker, a model and a custom name all work; the default is the last machine used; Last time, the prescription, offers, PRs, the stall check and Compare read one machine; History and the summary name the machine, and History filters by it; a switch partway through keeps finished sets on the machine they were done on; an existing store opens in place with every workout; backups carry machines, and older backups still restore.
**Scope / sequence:** model and additive schema → per-machine readers and the default → the card line, the picker and the switch question → History, the summary, the workout detail and Compare → backup format 4 and the CSV column → seed 9 and the machine list, with the custom editor's brand row removed.
**Requires:** Nothing in code.
[RM-029](#rm-029)'s populated recovery proof is still Planned; this schema change went ahead at the user's request, as an additive change SwiftData migrates in place, rehearsed on a copy of the phone's store, with that copy as the rollback.
**Evidence:** The 390pt tour found one bug: after a switch, the new machine's card offered the Panatta set's 140 × 8.
Offers now read only the same machine (`WorkoutSetSuggestions.precedingExerciseSet`), and `MachineProfileTests.switchKeepsTheFinishedSets` checks it.
An audit of every comparable-performance reader found Compare still matching by exercise alone, so a week on another machine showed as a load change; Compare now groups each exercise by machine (`MachineProfileTests.compareReadsOneMachine`).
The review then fixed three more.
A machine named with its maker typed into the name is the known machine that shows the same name (`MachineProfileTests.names`).
An exercise added again partway through a workout starts on that workout's machine (`MachineProfileTests.newLogStartsOnTheLastMachine`).
A Compare row whose last-week value comes from another day than the header's shows that day, since each machine compares with its own last workout.
`MachineProfileTests` (13 tests) covers names, the default, Last time, the prescription, PRs, the stall check, Compare, a correction, a switch, a swap with undo, History, the picker's lists and the machine list.
`IncompatibleStoreRecoveryTests.preMachineStoreOpensInPlace` opens a store written without the machine field; `BackupCatalogFieldsTests` round-trips a machine and refuses a backup that names a missing one.
`MachinePickerUITests` swaps in Hack Squat (Machine), picks the known Panatta, logs a set, switches to a new "Gym 2 hack" while keeping that set on the Panatta, and finds the machine in the summary after a relaunch.
Inspected at 390pt (fitbod-17e, light mode, default text): a barbell card with no machine line, the line on a machine card and on a cable card, the picker with known models and with none, the new-machine form, the maker list, the switch question, two cards after a switch, the note when a machine has no workout of its own, the summary, History's machine strip and filter, and Compare with two machines.
After the review fixes, at 390pt: a swap starts on the last machine used, an exercise added again starts on the workout's newer machine with its note, and a Compare row from another day shows that day.
The full tier before the review fixes ran 1,331 tests with 0 failures (2 skips, 1 expected failure), with lint clean and the widget build passing.
Checks after the review fixes: the unit target ran 1,226 tests with 0 failures (2 skips, 1 expected failure), and the five affected UI suites passed their 16 tests.
After the rebase onto the rest-timer refactor ([PR #4](https://github.com/Saechaoc/fitbod/pull/4)), the unit target passed 1,229 tests, and 70 UI tests had passed with no failure when a second full run was stopped as redundant.
The 390pt tour after the review fixes also showed the machine note calling Gym 2 hack new on its second card in the same workout; it would do the same for a machine used before only at another intent, since LAST TIME reads only finished workouts at the workout's intent.
The note now reads only "LAST TIME shows <machine>, and its loads don't carry over.", and the tour passed at 390pt with it.
Rehearsed on a copy of the phone's store pulled 2026-11-11 (5 workouts, 22 logged exercises, 67 sets): it opened in place with every row and survived a backup round trip; no logged exercise uses a Panatta row that seed 9 hides.
On the phone (2026-11-11, `0dbc3c7c` plus a throwaway hook that only added a routine): the store opened in place, gained the machine table, and still held its 5 workouts, 67 sets and 838 exercises in a copy pulled after the launch; the copy pulled before the install is the rollback.
**Open:** on the phone, a machine picked for Hack Squat (Machine) is still there after a relaunch.
VoiceOver, larger text, dark mode and the 430pt phone are unchecked.
Not built: a plate step, bar or sled weight per machine (a machine uses its exercise's settings); changing a past workout's machine in Edit workout; renaming, merging or deleting a machine (a machine no log uses stays in the store and in backups, unlisted); a machine stored on a routine.
The PR list ranks an exercise's best sets across machines without naming each set's machine.
A first workout on a new machine sets PRs on it, as a first workout of an exercise does today; [RM-036](#rm-036) owns that rule.
**References:** [model](../fitbod/Models/MachineProfile.swift), [rules](../fitbod/Sessions/SessionMachine.swift), [picker](../fitbod/Sessions/MachinePickerSheet.swift), [machine list](../fitbod/Resources/Machines/machine-models.json), [contracts](../ARCHITECTURE.md#snapshots-and-corrections).
