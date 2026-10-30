# Run log

The coordinator keeps this file current in the main checkout.
Workers never read or edit this live copy; their effective brief and any supplied evidence copy carry what they need.

## Approvals

| Question | Answer | Date |
|---|---|---|
| Workers skip GSD for this run | approved: the user accepted skipping GSD for a new orchestration in worktrees | 2026-10-29 |
| Parallel workers in worktrees | approved: "use multiple agents in parallel and worktrees" | 2026-10-29 |
| Orca setting for new agent tabs | chosen: Orca agentPermissionDefault and nativeChatPermissionMode are `full-access`, so worker tabs build, test, edit and commit without prompts | 2026-10-29 |

## Run setup

Record these when you set up the run, as [dispatch.md](dispatch.md) says.

- Main checkout: `/Users/csaechao4/orca/fitbod` on csaechao4's Mac.
- Lanes: 3.
- Worker agent flags: `--agent copilot`.
- GitNexus mode: `manual` (`gitnexus impact BlockBuilderView` reports "No indexed repositories found").

| Lane | Small phone | Large phone | DerivedData folder | Live ticket |
|---|---|---|---|---|
| gate | "sw6 iPhone 17e" `FF89B400-1160-4818-8436-314B014D2614` | "sw6 iPhone 17 Pro Max" `69E32D56-148D-40A7-9D1B-543F6878B1D1` | `fitbod-conway-gate` |  |
| L1 | "sw6-L1 iPhone 17e" `D0B5079C-B4ED-463B-AE2C-01D0FF469435` | "sw6-L1 iPhone 17 Pro Max" `A74927B1-3476-4659-9AAD-E6CABA6A9902` | `fitbod-conway-L1` | T03 |
| L2 | "sw6-L2 iPhone 17e" `5615455C-A8B6-4129-9E3B-53A7F161D758` | "sw6-L2 iPhone 17 Pro Max" `D305B715-794C-4BEB-B49E-89368B415E7E` | `fitbod-conway-L2` | T04 |
| L3 | "sw6-L3 iPhone 17e" `C4F388E4-0731-49C1-9AEB-30FF32EBE64E` | "sw6-L3 iPhone 17 Pro Max" `1505840C-CEEF-428C-B65D-C0B988A88465` | `fitbod-conway-L3` | T08 |

The DerivedData folders live in `~/Library/Developer/Xcode/DerivedData/`.

## Orca run

- Run id: `run_124e164710df`.
- `origin/main` at setup: `704f5c4`.
- Run base: `dd098af`, recorded 2026-10-29 18:32.
- Coordinator: Copilot CLI session in the main checkout, Orca coordinator handle `term_729baafe-b98a-4370-a4c6-4f450f09a99f`.
- Created 2026-10-29 18:32, after the quick-task run `run_f64c6aa47f95` ended (`a77df21`) and every other fitbod agent showed `done`.
- `main` was 14 commits ahead of `origin/main` at setup: the merges `004bbc8` (a9s, Phase 1B) and `26b2042` (uhg follow-up), plus docs, including the user's playbook fixes `b32a6de` and `dd098af`.
- Other worktrees at setup: `q-261029-a9s` (branch `undine`, agent idle) still holds `c35e0eb` "holding an RPE chip in the session editor sets a decimal target", which is NOT on `main`, plus uncommitted `.planning` notes; `fitbod-verify` (detached `6a2b83e`, another session's verification copy, no terminals). The coordinator leaves both untouched.
- Lane phones created 2026-10-29 on iOS 27.0 (see Run setup). The gate phones were last used by the quick-task run.
- Copilot workers trigger the user's Ponytail review hook (`~/.copilot/hooks/ponytail-review.sh`) at agentStop: one read-only review turn after a file-changing turn, so agents stay `working` for a few minutes after `worker_done`.
- 2026-10-29 18:34: the user's other Copilot session committed `3672f82` on `main` with the user's OK (docs only: `dispatch.md`, `risks.md`, `changelog.md`). `main` moved from the run base `dd098af` to `3672f82`; the run base stays `dd098af`. The coordinator now gets the step 2 stop proof (release, done check, and `orca terminal close` for a `retained` receipt) before the acceptance checks, and ignores settled rows with closed terminals that `worker-list` shows as `unverifiable` with `requiresAction: true` and no next action. Live T01 and T02 branches start at `dd098af` and rebase onto `3672f82` cleanly, because it is docs only.
- 2026-10-29 18:39: the user's other Copilot session committed `1ae54b0` with the user's OK (docs only: `tradeoffs.md` "Visible WHY control" and T09 change 1 now match the WHY placement shipped in `5d234ba`; `dispatch.md` now records a `worker_done` that waits for its stop proof as pending and acknowledges its batch as usual). `main` is at `1ae54b0`; the run base stays `dd098af`.
- 2026-10-29 18:41: the quick-task coordinator's list of review items it already fixed (`/Users/csaechao4/.copilot/session-state/7fa37195-9d3a-4563-8b28-17f69e57b4e2/files/conway-fixed-items.md`) is recorded in the ledger Notes for T03, T04, T05, T06, T08, T09, T25, T33 and T39 and goes into each brief's "Review items already fixed outside this run"; T06 is skipped at the user's OK.
- 2026-10-29 18:52: the user's other Copilot session committed `67fa75a` with the user's OK (docs only: `dispatch.md` and `changelog.md`): while any `worker_done` is pending, the coordinator waits with `--timeout-ms 120000` instead of 900000. The run base stays `dd098af`.
- 2026-10-29 18:55: message `msg_9d50b530e0d0` (re-sent as `msg_bc4d5dc6a43b`) from the user's other session: the user chose the follow-up agent in `q-261029-a9s` to fix the RPE-hold bug as T49, so the coordinator does not dispatch T49 (see the T49 ledger row). The coordinator checked that `67fa75a` exists and that the a9s agent was working on a new prompt before acting on it.
- 2026-10-29 19:05: a coordinator tooling bug (a long inbox wait saved a stale state copy when T02 reported) dropped the T49 records above for about 2 minutes; they were restored before T50 launched, and the helper now reloads state before saving.
- 2026-10-29 22:40: coordinator answer committed in tradeoffs.md "One-tap share": the shipped `@ModelActor` export and backup rendering meets the call's intent (no model object crosses a thread) and stays.

## Ledger

Status is one of: todo, dispatched, done, failed, skipped.
Done means accepted and safely settled: merged delivery commits, accepted evidence-only results with a tested commit, or fully evidenced replacement completion.
A reported outcome is separate from settlement state and never by itself frees resources or satisfies dependencies.

Keep per-attempt history in Notes, including the unique attempt id, mode/effective brief, retry failure note, effective ownership and acceptance, task/dispatch ids, lane and worktree/branch.
Record the fresh worktree-local `docs/conway-specs/evidence/attempt-brief.md` and its exact settlement archive at `docs/conway-specs/evidence/<attempt id>/attempt-brief.md`, plus the unique output folder, base and actual tested commit, and any delivery commit on `main`.
The stored task spec stays an invariant loader; a native failed/stopped retry reuses its task with a fresh brief, while a rejected successful attempt gets a new task.
For each input binding, record its role, local relative alias, source attempt/archive, acceptance and safe-settlement state, tested commit, delivery commit or none, and exact required files validated before launch.
Accepted dependencies must come from ledger-selected accepted/settled archives, not failed/rejected/unsettled attempts or directory recency; preserve all original archives and freeze the brief and local inputs during execution.
For example, accepted/settled T40-r2 supplies T41's local `evidence/T40/{notes.md,delete-paths.md}` and T47's local `evidence/T40/closeout-statement.md`, leaving failed T40 separately archived.
Label an original T46 retry's own safely settled failed source at local `evidence/T46/` as `failed/resume`, never accepted dependency evidence.
Record `evidence/run-log.md` separately as a coordinator snapshot with source path, run id and snapshot time, without inventing producer acceptance or delivery commits.
The Commit column holds delivery commits or replacement commit references, not an invented commit for an evidence-only result.
Notes record reported outcome, acceptance/rejection, settlement `pending` or `settled`, release/recovery receipts, positive execution-stop proof and safe cleanup authority.
While pending, retain the attempt's lane, normalized owned/held reservations and pending-wait records even if its reported outcome is failed or it is fenced.
Snapshot the deduplicated owned-plus-held paths before clearing bookkeeping, and mark the attempt settled/non-live before release or waiter handoff.
Retain previous attempt/task/dispatch identities, evidence and any useful unmerged-work retention decision.

For a split, Notes map the failed parent to every replacement id and map each original acceptance requirement to its replacement commits/evidence.
Children inherit the original phase and prerequisites, never a dependency on the failed parent, and are registered through dispatch.md's new-ticket/index process.
Keep the parent failed and blocking dependents and phase completion until every child is accepted and safely settled and their combined evidence covers the entire original acceptance.
Record that coverage check and accepted delivery/tested commit references, then explicitly mark the parent done without adding dependencies on higher-numbered replacements.

For T46 reruns, record each requested screen/phone/text-size/appearance pair, tested commit, evidence path and pass/finding/unreachable state.
Keep the accepted full-tour evidence, including implementation retries, and prior reruns so T47 can select the newest applicable capture per pair, not mistake a partial rerun for a complete replacement tour.

| Ticket | Phase | Status | Lane | Branch | Task id | Dispatch id | Commit | Notes |
|---|---|---|---|---|---|---|---|---|
| T01 | 1 | done | L1 | `conway-t01` | `task_01ab0f9eb2cf` | `ctx_dd2839a26b6b` | `2a292ba` | T01: original, lane L1, base `dd098af`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t01`; task `task_01ab0f9eb2cf` dispatch `ctx_dd2839a26b6b`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release retained/none + worker-show settled + agent done + terminal close term_9a7ffec0-b0d5-4d48-a6cd-f77c8799e044 ptyKilled (2026-10-29 21:25); brief archived at `docs/conway-specs/evidence/T01/attempt-brief.md`; tested `b2d1429 (on 3a68e23); delivered as 2a292ba after the coordinator rebase onto d806fe2 and a build`; coordinator rebased onto d806fe2 and built (2026-10-29 21:25); accepted: 1 commit in owns (DebugLaunchReset, UITestNavigation, UITestHelpersSelfTests); fitbodTests 1003 + 1 allowed known issue; fitbodUITests 78/78 small, 77/78 large (MilestoneOneJourney delete-step race, 3/3 on rerun); AX3 screenshot checked by the coordinator; coordinator rebased b2d1429 onto d806fe2 and built (L1 large) before the ff merge |
| T02 | 1 | done | L2 | `conway-t02` | `task_c20633f8957f` | `ctx_15eb00628682` | `ef1aa0c` | `Session.loggedSetCount` exists since `4d7e07e` (other effort), and `fitbodTests/LoggedSetCountTests.swift` tests it / T02: original, lane L2, base `dd098af`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t02`; task `task_c20633f8957f` dispatch `ctx_15eb00628682`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release released (processAction closed_agent_terminal) 2026-10-29 19:03; brief archived at `docs/conway-specs/evidence/T02/attempt-brief.md`; tested `ef1aa0c`; accepted: 1 commit in owns, evidence complete, fitbodTests 997 passed + 1 expected failure at ef1aa0c; repro part A not reproduced (fixed by 4d7e07e); orca worktree rm removed the worktree asynchronously and deleted the merged branch `conway-t02` itself |
| T03 | 1 | dispatched | L1 | `conway-t03` | `task_96bf19e06c20` | `ctx_1131bfeec847` |  | todo, trimmed: fixed outside this run: Item 1 in `ba8e0fa`: COPY and EDIT open a filled editor on the first tap (`ExerciseCopyEditSheetUITests`); still open: 19 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) / T03: original, lane L1, base `2a292ba`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t03`; task `task_96bf19e06c20` dispatch `ctx_1131bfeec847`; reported -; settlement pending |
| T04 | 1 | dispatched | L2 | `conway-t04` | `task_e9ff089aee44` | `ctx_816017ff142b` |  | todo, trimmed: fixed outside this run: Item 2 in `4d7e07e`: SKIP works, WARM-UPS SKIPPED has UNDO, and the slab, banner and logger share `Session.loggedSetCount` (`SkipWarmupsUITests`, `LoggedSetCountTests`); check changes 4 to 6 (Discard on an empty finish, Keep logging, plural labels) before dispatch; still open: 25 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) / T04: original, lane L2, base `2a292ba`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t04`; task `task_e9ff089aee44` dispatch `ctx_816017ff142b`; reported -; settlement pending; 2026-10-29 21:40 question msg_46c4dfc94089: answered "A, direct": granted fitbod/Fatigue/SuggestedActionChip.swift and fitbod/App/RootView.swift (both unreserved) plus a new DEBUG seed file next to DemoWorkoutSeed.swift for a reusable stalled-exercise seed (T53 will reuse it); empty Finish offers destructive "Discard workout" that deletes at once from the "Finish workout?" dialog, with a visible "Keep logging"; the menu Discard keeps its "Discard workout?" alert; 2026-10-29 22:23 question msg_5891eaf93d86: granted fitbodUITests/HistoryAndTodayUITests.swift to move its two raw launches to UITestNavigation.launch (reset race exposed by T04 stall seed), as an extra commit naming T04 |
| T05 | 1 | done | L3 | `conway-t05` | `task_fd7c4bb8c4e0` | `ctx_eab861c333e7` | `589fb4f` | todo, trimmed: fixed outside this run: Item 3 in `78625e7`, `6631230` and `10d32fd`: the session editor, custom exercise editor and New Block builder resist swipe-down while they hold unsaved edits, and the session editor's change check (`RoutineDraft.snapshotHash()`) covers every exercise field it saves (`EditorSwipeDismissUITests`, `BlockDraftSnapshotTests`, `RoutineBuilderHeaderPickersTests.snapshotHashRespondsToExerciseEdits`); do not add a second swipe test such as `DirtySheetDismissUITests`; still open: 25 (and the open product question: New Block CANCEL still closes without asking) (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) / T05: original, lane L3, base `2a292ba`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t05`; task `task_fd7c4bb8c4e0` dispatch `ctx_eab861c333e7`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release released (processAction closed_agent_terminal) 2026-10-29 22:32; brief archived at `docs/conway-specs/evidence/T05/attempt-brief.md`; tested `589fb4f`; 2026-10-29 21:33 question msg_a9199c1a35a9: granted fitbodUITests/EditorSwipeDismissUITests.swift (no live reservation); copy call: NEW BLOCK asks "Discard this block?", EDIT BLOCK (same BlockBuilderView cancel()) asks "Discard changes?" like the session editor (RoutineBuilderView.swift:178), both with Discard and a visible "Keep editing", no message (follows tradeoffs.md "Dirty editors and swipe-down": CANCEL asks before it discards); accepted: 1 commit (3 owned files + granted EditorSwipeDismissUITests), repro fails at base for changes 5-6, EditorSwipeDismissUITests + NewBlockModalUITests 8/8 both phones, six guardrail suites pass, fitbodTests 1005 + 1 allowed; coordinator viewed the New Block discard dialog screenshot |
| T06 | 1 | skipped |  |  |  |  | `4dc68fb`, `2529e90` | skipped at the user's OK (2026-10-29): item 5 in `4dc68fb`: min and max target reps are `BRUStepper`s where low never passes high, and the journey test enters numbers like a user (`PrescriptionEditorUITests`, `TargetRepsRangeTests`); item 6 in `2529e90`: one `InlineRPEChipRow` with a NO TARGET chip. Differs from T06 changes 2 and 4 as written: reps step 1 to 50 (`RoutineDraft.maxTargetReps`), not 1 to 30, and Target RPE is whole-number chips plus NO TARGET, not a toggle plus a 0.5 stepper; see New findings F1 (ticket T49) (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) |
| T07 | 1 | skipped |  |  |  |  | `c0f6773`, `2f6a955` | Items 41 and 33 fixed by the other effort: SET 1 NOTE in `c0f6773`, and a local copy that only SAVE writes in `2f6a955`, plus `639ff4e` for the editor layout; `NoteSheetsUITests` covers SAVE, CANCEL and swipe-down for all three sheets on both phones |
| T08 | 1 | dispatched | L3 | `conway-t08` | `task_f8e5374bb635` | `ctx_0beead2ae3c8` |  | todo, trimmed: fixed outside this run: Item 34 in `d936b32`: Export CSV, Export JSON and backup CREATE each open the share sheet on one tap through lazily rendered `Transferable` items that keep the inline errors (`SettingsExportUITests`, `ExportShareItemsTests`); do not add `OneTapShareUITests`; still open: 14 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) / T08: original, lane L3, base `589fb4f`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t08`; task `task_f8e5374bb635` dispatch `ctx_0beead2ae3c8`; reported -; settlement pending; 2026-10-29 22:40 question msg_45fa1f7ecb19: approve all: granted fitbodUITests/SettingsExportUITests.swift (no OneTapShareUITests), 5 s share-sheet wait per the ticket repro, item 34 recorded as not reproduced, @ModelActor threading kept (answer recorded in tradeoffs.md "One-tap share") |
| T09 | 1 | todo |  |  |  |  |  | todo, trimmed: fixed outside this run: Item 4 in `5d234ba`: a visible WHY at the leading end of each set's second line (the RPE-chip line), with a 44pt target and the "Why this weight" VoiceOver action on the weight cell; it ends editing, Use writes the suggested weight, Override focuses the weight field (`WhyThisWeightControlUITests`, `SetRowWhyLayoutTests`). The quick-task run chose this placement because line 1 has only about 18pt free at 390pt; do not move WHY into the weight cell (`1ae54b0` updated T09 change 1 and tradeoffs.md to match); still open: 18 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) |
| T10 | 1 | todo |  |  |  |  |  |  |
| T11 | 1 | todo |  |  |  |  |  |  |
| T12 | 1 | todo |  |  |  |  |  |  |
| T13 | 1 | todo |  |  |  |  |  |  |
| T14 | 1 | todo |  |  |  |  |  |  |
| T15 | 1 | todo |  |  |  |  |  |  |
| T16 | 1 | todo |  |  |  |  |  |  |
| T17 | 1 | todo |  |  |  |  |  |  |
| T18 | 2 | todo |  |  |  |  |  |  |
| T19 | 2 | todo |  |  |  |  |  |  |
| T20 | 2 | todo |  |  |  |  |  |  |
| T21 | 2 | todo |  |  |  |  |  |  |
| T22 | 2 | todo |  |  |  |  |  |  |
| T23 | 2 | todo |  |  |  |  |  |  |
| T24 | 2 | todo |  |  |  |  |  |  |
| T25 | 2 | todo |  |  |  |  |  | todo: fixed outside this run: `3ff4a8a` (quick task `260610-hcv`) already fits New Block phase-card titles at 390-402pt, with a Vision text check in `NewBlockBuilderFidelityTests`; keep it passing; still open: 37, 46 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) |
| T26 | 2 | todo |  |  |  |  |  |  |
| T27 | 2 | todo |  |  |  |  |  |  |
| T28 | 2 | todo |  |  |  |  |  |  |
| T29 | 2 | todo |  |  |  |  |  |  |
| T30 | 2 | todo |  |  |  |  |  |  |
| T31 | 2 | todo |  |  |  |  |  |  |
| T32 | 2 | todo |  |  |  |  |  |  |
| T33 | 2 | todo |  |  |  |  |  | todo, trimmed (or skip after a look): fixed outside this run: Item 42 mostly fixed in `e74c810`: BRU header, bordered editor and both audits; still open are a test that the capsule shows a saved note, the dark and AX3 screenshots, and its hint reads "Shown above this exercise's sets"; the notes suite is `NoteSheetsUITests`; still open: the rest of 42 (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) |
| T34 | 3 | todo |  |  |  |  |  |  |
| T35 | 3 | todo |  |  |  |  |  |  |
| T36 | 3 | todo |  |  |  |  |  |  |
| T37 | 3 | todo |  |  |  |  |  |  |
| T38 | 3 | todo |  |  |  |  |  |  |
| T39 | 4 | todo |  |  |  |  |  | todo, trimmed: fixed outside this run: The session editor's exercise-level min and max reps no longer take typed digits (`4dc68fb`), and `MilestoneOneJourneyUITests` enters numbers like a user; still open: 5 for every other numeric field, including `PerSetOverrideRow.swift` reps and RPE (still `TextField(value:format:)`) (from the quick-task coordinator's list `7fa37195.../files/conway-fixed-items.md`, 2026-10-29) |
| T40 | 4 | todo |  |  |  |  |  |  |
| T41 | 4 | todo |  |  |  |  |  |  |
| T42 | 4 | todo |  |  |  |  |  |  |
| T43 | 5 | todo |  |  |  |  |  |  |
| T44 | 6 | todo |  |  |  |  |  |  |
| T45 | 6 | todo |  |  |  |  |  |  |
| T46 | 6 | todo |  |  |  |  |  |  |
| T47 | 7 | todo |  |  |  |  |  |  |
| T48 | 7 | todo |  |  |  |  |  |  |
| T49 | 1 | done | external (user agent in q-261029-a9s) | `undine` |  |  | `a296af3`, `13fd1b7`, `0d1c1c7` | Finding F1 (coordinator review of `704f5c4..1ae54b0`); ticket and index row committed in `815e3f6`. External, at the user's OK (message `msg_9d50b530e0d0`, re-sent as `msg_bc4d5dc6a43b`, 2026-10-29 18:55): the user's own follow-up agent in worktree `q-261029-a9s` (branch `undine`: `c35e0eb` plus work in progress) has T49 as its spec; the coordinator does not dispatch T49. When that agent shows `done` in `orca worktree ps`, the coordinator treats `main..undine` as the T49 result: T49 acceptance checks, rebase `undine` onto `main`, build, run `PrescriptionEditorUITests`, `SessionLoggerBRUUITests` and `WorkoutLoggerJourneyUITests`, merge with `--ff-only`, and record T49 done with those commits. That worktree and its agent terminal belong to the user and are never closed or removed by the coordinator; it tests on the sw6 gate phones, so no gate runs while it is busy / T49-ext: external, lane external (user agent in q-261029-a9s), base `5b9be27`, worktree `/Users/csaechao4/orca/workspaces/fitbod/q-261029-a9s`; task `None` dispatch `None`; reported -; settlement settled; stop proof: user agent shown done by orca worktree ps and worktree clean before the coordinator rebased (2026-10-29 21:27); user-owned terminal not closed; brief archived at `docs/conway-specs/evidence/T49-ext/ (no attempt-brief.md: the coordinator wrote no brief for the external agent)attempt-brief.md`; tested `0d1c1c7`; user-owned agent; uses the sw6 gate phones; never close or remove its worktree or terminal; 2026-10-29 21:10: the user agent shows done; main..undine = c35e0eb, c25645e, 2144768 (Chris Saechao, no Co-Authored-By; c35e0eb predates T49 and does not name it). Its diff also touches SetRow.swift, SetTypeChip.swift, DecimalRPEPickerSheet.swift, two copy tests, PrescriptionEditorUITests and fitbodUITests/WorkoutUITestNavigation.swift, which live T01 owns, so the coordinator reserves every changed path for T49 and merges only after T01 settles. Interaction change reported by the agent: the logger set-type menu now belongs to the chip, and a working set changes type by tapping its set label (S1); verified at 0d1c1c7 on the gate large phone: app and widget build, fitbodTests 1005 + 1 expected failure, the four RPE-related UI suites 15/15; ff-merged undine into main |
| T50 | 1 | done | L2 | `conway-t50` | `task_9fcad9a0088b` | `ctx_ed1930e138dc` | `f9c79b7` | Finding F2 (T02 out-of-scope note); ticket and index row committed in `71da731` / T50: original, lane L2, base `71da731`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t50`; task `task_9fcad9a0088b` dispatch `ctx_ed1930e138dc`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release released (processAction closed_agent_terminal) 2026-10-29 19:22; brief archived at `docs/conway-specs/evidence/T50/attempt-brief.md`; tested `f9c79b7`; accepted: 1 commit in owns, post-filter (not #Predicate) completedAt checks, 3 repro tests fail then pass, fitbodTests 1000/1001 (allowed known issue) at f9c79b7 |
| T51 | 1 | done | L2 | `conway-t51` | `task_c70ad5d54bc7` | `ctx_d14ce6d1e50d` | `c0027aa` | Finding F3 (T50 out-of-scope note); ticket and index row committed in `4a0237d` / T51: original, lane L2, base `4a0237d`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t51`; task `task_c70ad5d54bc7` dispatch `ctx_d14ce6d1e50d`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release released (processAction closed_agent_terminal) 2026-10-29 19:38; brief archived at `docs/conway-specs/evidence/T51/attempt-brief.md`; tested `c0027aa`; 2026-10-29 19:29 question msg_8f0ab87dad8f: evaluate never calls hasRPECreep (only suggestedAction does); coordinator answered yes: test via evaluate then suggestedAction as the card does, keep hasRPECreep private, include the empty in-progress workout edge case; accepted: 1 commit in owns, completedAt guards in Swift post-filters, 3 repro tests fail then pass, PlateauDetectorTests and SuggestedActionTests unchanged and passing, fitbodTests 1003 + 1 allowed known issue at c0027aa |
| T52 | 1 | done | L2 | `conway-t52` | `task_e1b8395372b8` | `ctx_6d1c7f852bf8` | `d806fe2` | Finding F4 (T51 out-of-scope note); ticket committed in `3a68e23` / T52: original, lane L2, base `3a68e23`, worktree `/Users/csaechao4/orca/workspaces/fitbod/conway-t52`; task `task_e1b8395372b8` dispatch `ctx_6d1c7f852bf8`; reported succeeded; settlement settled; stop proof: accepted worker_done + worker-release released (processAction closed_agent_terminal) 2026-10-29 20:03; brief archived at `docs/conway-specs/evidence/T52/attempt-brief.md`; tested `d806fe2`; 2026-10-29 19:45 question msg_07858f45daf4: coordinator chose option A: hasRPECreep skips exactly what evaluate skips (no defined top-set e1RM: no logged working set, or sets the e1RM formula ignores, all over 10 reps or 0 kg), with a test for the second case; accepted: 1 commit in owns, creep window skips workouts without a top set like evaluate (option A), repro fails then passes, plateau suites 22/22, fitbodTests 1005 + 1 allowed known issue at d806fe2 |
| T53 | 1 | todo |  |  |  |  |  | Finding F6 (T51 out-of-scope note); ticket committed in `3a68e23` |

## Phase gates

| Gate | Date | Tests | Passed | Failed | Expected failures | Duration | Widget build |
|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |

## Shared test helpers

Workers list new helpers in their notes, and the coordinator copies them here for later on-disk attempt briefs.

- T01 (`2a292ba`), all static members of `UITestNavigation` in `fitbodUITests/UITestNavigation.swift`: `launch(_:textSize:)` (adds `-fitbod-reset-signal`, pins portrait, warms the first reset launch, fails unless a reset launch reports a fresh store; existing `launch(freshStore)`/`launch(seededWorkout)` unchanged), `relaunch(_:textSize:)` (no reset flag, for persistence), `storeFreshness(in:)`, `assertFreshStore(in:)`, `resetFlag`/`resetSignalFlag`
- T01: `TextSize` (`.default`, `.ax3` via `-UIPreferredContentSizeCategoryName`, for one launch), `Appearance` (`.light`, `.dark`; screenshot-name token only, appearance is set with `simctl ui`), `saveScreenshot(_:_:textSize:appearance:)` (keepAlways, named `<ticket>-<screen>-<phone>-<text size>-<appearance>`)
- T01: frame checks `assertNoOverlap`, `assertInside`, `assertNotTallerThanWide`, `assertTapTarget(_:minimum:)`, `assertHeight(_:atMost:)`, each with a `...Problem` twin that returns the message or nil
- T01: pixel checks `RGB` (`init(hex:)`, `distance(to:)`), `color(at:in:)` and `assertColor(at:in:is:tolerance:)` (default tolerance 8 per channel); gestures `swipeSheetDown(in:)`, `topSheet(in:)`, `swipeBack(in:)` (edge swipe from 1pt inside the left edge)
- Earlier (on `main` before the run): `UITestNavigation.step(_:to:)` and `tapStepper(_:increment:)` for BRUStepper (`4dc68fb`), and `UITestNavigation.dragSheetDown(from:in:)` plus `XCUIElementQuery.labeled(_:)` in `fitbodUITests/SheetUITestNavigation.swift` (`10d32fd`)

## Held files

Granted files outside a live attempt's effective `owns` list, plus pending file asks, as [dispatch.md](dispatch.md) says.
Each grant or wait names the normalized path, ticket, unique requester attempt, dispatch id and ask message id; waits also record their order.
Owned paths remain reservations too, even when there are no grants here.
On safe settlement, first mark the old attempt non-live, then release the normalized union of its effective owned and granted held paths and retire only its own pending asks.
Strike those lines with the settlement reference rather than erasing their history.
For each freed path, recheck all remaining live reservations and grant only the oldest eligible pending ask from the same still-live requester attempt, recording its new hold before replying.
Never grant to ended, superseded or fenced attempts, and preserve uncertain/fenced wait records without replies or cancellation until recovery resolves their safety state.
Later eligible asks keep waiting, and no path is handed off while any live attempt still reserves it.

- ~~grant `fitbodUITests/EditorSwipeDismissUITests.swift`: ticket T05, attempt T05, dispatch `ctx_eab861c333e7`, message `msg_a9199c1a35a9`, order 1, 2026-10-29 21:34~~ (settled T05 2026-10-29 22:32)
- grant `fitbod/Fatigue/SuggestedActionChip.swift`: ticket T04, attempt T04, dispatch `ctx_816017ff142b`, message `msg_46c4dfc94089`, order 2, 2026-10-29 21:39
- grant `fitbod/App/RootView.swift`: ticket T04, attempt T04, dispatch `ctx_816017ff142b`, message `msg_46c4dfc94089`, order 3, 2026-10-29 21:39
- grant `fitbodUITests/HistoryAndTodayUITests.swift`: ticket T04, attempt T04, dispatch `ctx_816017ff142b`, message `msg_5891eaf93d86`, order 4, 2026-10-29 22:22
- grant `fitbodUITests/SettingsExportUITests.swift`: ticket T08, attempt T08, dispatch `ctx_0beead2ae3c8`, message `msg_45fa1f7ecb19`, order 5, 2026-10-29 22:38

## HIGH and CRITICAL impact ratings

- T01: `UITestNavigation.launch` rated HIGH (manual mode): test-only, used by about 19 UI suites; both full UI runs covered it.

## Removed controls

Each one also has a line in `docs/ROADMAP.md`.

- None yet.

## New findings

Each one becomes a ticket from T49 on.

- F1 (coordinator review of `704f5c4..1ae54b0`, 2026-10-29): holding an RPE chip never opens the decimal picker, so a half-step target such as 8.5 cannot be set. The chip `Button` in `fitbod/Sessions/InlineRPEChipRow.swift` swallows `.onLongPressGesture`, and in the session editor the card-wide `.contextMenu` in `fitbod/Routines/RoutineExerciseCard.swift` takes the hold; `Int(rpe ?? -1) == value` also shows a stored 8.5 as chip "8", and a tap saves 8.0. Before `2529e90` the editor's RPE field took decimals. A fix exists only on branch `undine` as `c35e0eb` (title-row menu plus a simultaneous long press), not on `main`; the a9s backlog note says the logger's set-type menu also takes the hold. T36 assumes the long press works. Ticket T49 (`815e3f6`).
- F2 (T02 out-of-scope note, read from code and not tested): `SessionExerciseCard.currentExplanation()` calls `SessionFactory.lastSessionWorkingReps` without excluding the current unfinished workout, so the WHY sheet's bump decision may read today's logged reps instead of the last finished workout's. Ticket T50 (`71da731`).
- F3 (T50 out-of-scope note, read from code and not tested): `PlateauDetector.evaluate` and its private `hasRPECreep` count the workout in progress in the stall window. Ticket T51.
- F4 (T51 out-of-scope note, read from code): `PlateauDetector.hasRPECreep` treats a finished workout with no logged set for the exercise as a 0 kg pick that suppresses RPE creep, while `evaluate` skips such workouts. Ticket T52.
- F5 (T51 out-of-scope note, read from code): `FatigueModel.weeklyVolume` counts unfinished workouts for the Branch 1 `.addVolume` check. Not ticketed (coordinator call, flagged to the user): weekly volume is a running total of completed work, likely shared with the volume views, so leaving the workout in progress out of the add-volume check is a product decision.
- F6 (T51 out-of-scope note, read from code): `SessionExerciseCard` gives `StallBadge` the global plateau window size instead of `Exercise.plateauWindowOverride`. Ticket T53.
- F7 (T01 out-of-scope): `fitbodUITestsLaunchTests` leaves the phones in landscape after it runs.
- F8 (T01 out-of-scope): `MilestoneOneJourneyUITests` has a delete-step race ("Missing button: Delete" after a full swipe); it failed once on the large phone and passed 3/3 on rerun, and timed out once on the small phone at base.
- F9 (T01 out-of-scope): at AX3 the Today header cuts the date to "THU · OCT…" (seen in `T01-today-empty-small-ax3-light.png`).
- F10 (T01 out-of-scope): no pushed screen tried so far has a working edge swipe back; T18 owns that (items 35 and 43), so no new ticket.
- F11 (coordinator, from T04 question msg_5891eaf93d86): UI suites that launch with a raw `XCUIApplication().launch()` / `app.launch()` (15 suite files at `0d1c1c7`, the launch helper `UITestNavigation.swift` excluded: DeloadAdvisoryBannerUITests, fitbodUITests, fitbodUITestsLaunchTests, HistoryAndTodayUITests, MilestoneOneJourneyUITests, MuscleVolumeTargetEditorUITests, NewBlockModalUITests, PerMuscleDetailUITests, Phase5BRUSmokeUITests, PlateCalculatorSheetBRUUITests, SessionHistoryBRUUITests, VolumeBarsUITests, WeeklyRecapUITests, WorkoutLoggerJourneyUITests, WorkoutSwapJourneyUITests; some may relaunch on purpose without a reset) can lose `-fitbod-reset-store` on the first launch in a test process (the reset race T01 works around) and read the previous suite's store; T04's stall seed makes such leftovers differ from the demo seed, so full-suite gates may show flakes. Watch gate 1.
- F12 (T05 out-of-scope): "+ New superset" in the session editor saves a SupersetGroup at once, so Discard leaves an empty group behind.
- F13 (T05 out-of-scope): Today's "Start a block" opens a "Blank Block" with no phases while the bottom button says "NAME FIRST" (also seen with a name set and 0 phases in `T05-new-block-discard-dialog-small-default-light-fix-589fb4f.png`); T11 owns New Block's two saves and their labels.
- F14 (T05 out-of-scope): cancel-role buttons remain in the session editor's ••• dialog, the Archive dialogs, the unreachable "Apply Preset?" dialog and the logger's "Keep logging" (T04 owns the logger dialogs, T20 the archive dialog).
- F15 (T05 out-of-scope): an intermittent simulator keyboard stall once made a typing test take 5m 46s.
