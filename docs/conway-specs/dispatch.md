# Coordinator playbook

This leaf is for the coordinator, not for workers.
It says how to turn the tickets into Orca tasks, how to run several workers at once in their own worktrees, how to merge their work into `main`, and how to close the run.
The Orca CLI is `/Applications/Orca.app/Contents/Resources/bin/orca`.
Load the version-matched guide with `orca skills get orchestration` before the first command, and check each verb's `--help` before its first use.
Every ticket gets a new worktree, so also read `orca skills get orchestration --reference references/placement-and-remote.md` before the first `worker-start`.

## Terms

- Main checkout: the repo's first worktree, the first line of `git worktree list`.
  The coordinator works there, on `main`, and only the coordinator moves `main`.
- Lane: a seat for one code worker, with its own two simulators and its own DerivedData folder.
  The run has three lanes unless the run log says otherwise.
- Ticket worktree: a new Orca worktree for one attempt, on its own branch from the newest `main`.
  A commit-capable worker commits authorized changes there, and the coordinator merges that branch into `main`.
- Attempt: one original run, retry, verification rerun or docs refresh, with a unique id and an effective brief.
- Live ticket: a ticket with an attempt that is running or not yet safely settled (see "Settle a ticket").
  A reported outcome or orchestration fence does not make its reservations free.
- Safely settled attempt: execution-stop proof and safe cleanup authority are recorded, evidence is archived, authorized cleanup or retention is complete, and the attempt is marked settled/non-live.
- Held file: a file outside a live attempt's effective `owns` list that you let its worker edit.
  It stays held until safe settlement, and no other attempt may edit it meanwhile.
- Exclusive ticket: T42 to T48, including verification reruns and docs refreshes.
  Each one touches many files or runs the full suite, so it runs with no other code worker, on the gate phones.
- No-commit result: an original no-file ticket such as T44, a read-only T44/T45/T46 verification rerun, or a worker that reports "not reproduced".
  It leaves no tracked edits, staging or commits, and reports its tested commit and evidence instead.
  Commit-capable work with no authorized changes also makes no empty commit.

## Preconditions

Do not dispatch anything until every line here is true, and each answer is recorded in [run-log.md](run-log.md):

1. The user approved the workflow exception: workers skip GSD for this run.
   The user approved it on 2026-10-29, together with parallel lanes in worktrees.
2. The user chose an Orca setting for new agent tabs that lets workers build, test, edit and commit without stopping for every prompt.
   Orca has no flag for this; worker tabs follow that setting.
3. `orca status --json` shows Orca running.
4. `git status --porcelain` in the main checkout shows no path except `docs/conway-specs/run-log.md` and the pre-existing paths listed in [worker-rules.md](worker-rules.md).
   Ask the user about any other path.
5. `xcrun simctl list devices` shows the two gate phones, "sw6 iPhone 17e" and "sw6 iPhone 17 Pro Max".
6. `python3 -I capacity_model.py` prints no validation errors.
   A warning that a `new:` file already exists means another effort did part of that ticket, so map it as line 7 says.
7. No other agent, including Codex or another Claude session, is editing the working tree.
   On 2026-10-29 another session was already running this plan with its own Orca run (see "Another session runs the same plan" in [risks.md](risks.md)).
   That effort must be finished or stopped first.
   Its workers run in their own git worktrees, so check all of them, not only the main checkout: `orca worktree ps --json` shows no `working` agent in any other fitbod worktree.
   For each other worktree that `git worktree list` shows, ask the user whether it is still in use, because a finished worktree stays until someone removes it.
   Orca sees only its own machine, so also ask the user whether that effort still runs on another machine.
   List its commits with `git log --oneline 12aad09..HEAD` right before the first dispatch, because it was still committing when this bundle was finished.
   Every ticket it fully fixed is marked `skipped` in the run log, with its commit hashes.

## Set up the run

1. Run `orca orchestration run-create --objective "Finish Milestone 1 (conway plan)" --json`, and record the run id in the run log.
2. Record the run base: the output of `git rev-parse --short HEAD` in the main checkout.
   T44 and Phase 8 compare against it, never against a hash from the plan or the review.
   Also record `git rev-parse --short origin/main`, because `main` can already be ahead of it.
3. Record the lane count: three on a Mac like csaechao4's (12 cores, 48 GB), two on a smaller one.
   Drop to two whenever UI tests start timing out under load, and note it in the run log.
   `capacity_model.py` shows that a fourth lane saves little.
4. Create each lane's two phones once, on the iOS 27.0 runtime, for example `xcrun simctl create "sw6-L1 iPhone 17e" "iPhone 17e" com.apple.CoreSimulator.SimRuntime.iOS-27-0`.
   Do the same for "iPhone 17 Pro Max", for every lane, and record each name and id in the run log.
   Lane `n` builds into `~/Library/Developer/Xcode/DerivedData/fitbod-conway-L<n>`.
5. The gate phones build into `~/Library/Developer/Xcode/DerivedData/fitbod-conway-gate`.
   Gates and exclusive tickets use them, and nothing else does.
6. Record the GitNexus mode.
   It is `index` when `gitnexus impact BlockBuilderView --direction upstream --repo fitbod` finds the symbol, and `manual` when it does not.
   On csaechao4's Mac it is `manual`, because GitNexus's Swift parser does not load there.
   In `manual` mode, nobody runs `gitnexus analyze`, because it rewrites `.gitignore` and skill files.
7. Record the worker agent flags.
   On csaechao4's Mac, use `--agent copilot`, as the quick-task run there does; Orca takes no model or effort flag for Copilot.
   Where Claude Code is set up, use `--agent claude --model claude-opus-5-5 --effort medium`, which the tickets were sized for.

## Choose what starts next

Whenever a lane is free, start the lowest-numbered ticket that passes every check:

- Its status is `todo`, and every dependency is `done` or `skipped`.
- Its phase is open: every ticket of each earlier phase is `done` or `skipped`, and every gate after those phases passed.
- None of its effective brief's `owns` paths, with `new:` removed, is owned or held by any live attempt, including one pending settlement.
- No exclusive ticket is live.
  An exclusive ticket also needs every other attempt to be safely settled, and nothing else starts while it waits for them.

You do T31 yourself, in the main checkout, as soon as Phase 2 opens, and it takes no lane.
A worker in a new worktree could not see the uncommitted design files or the home folders it searches (see "Design export checks").
Fill every free lane before you wait again.
The hotspot list from `capacity_model.py` shows which tickets will wait for each other's files.

## Start one ticket

Prepare an effective brief before checking ownership or reserving a lane, including for gate workers.
It names the local base ticket, mode (`original`, `retry`, `verification-rerun` or `docs-refresh`), unique attempt id, base/tested commit, unique evidence output folder, explicit input bindings, effective ownership, permitted actions and scoped acceptance.
Only explicitly named rerun/refresh fields override the base ticket and generic commit instructions; protected paths, safety rules and every other applicable constraint remain in force.
Original work and its retries retain the original implementation and acceptance requirements.
The stored task spec is only an invariant loader; the authoritative attempt metadata lives in the worktree-local `docs/conway-specs/evidence/attempt-brief.md`.
Reject a missing, contradictory or launch/worktree-mismatched brief or input; never fall back to an old spec, cached prompt or previous brief.

1. Pick a free lane, or the gate phones for an exclusive ticket.
2. Create a fresh attempt worktree from the newest `main` with `orca worktree create --repo path:<main checkout> --name conway-<attempt id in lower case> --base-branch main --json`.
   `--base-branch main` matters: the local `main` holds every merged ticket, and the repo's default base may be `origin/main`, which does not until Phase 8.
3. Check that `git -C <worktree> rev-parse HEAD` equals `git rev-parse main`.
   If it does not, do not start a worker; recreate only a confirmed-unused worktree with safe cleanup authority, or resolve uncertainty through "Settle a ticket".
4. Bind each dependency input from a ledger-selected accepted AND safely settled producer archive in the main checkout to the stable local alias its unchanged consumer ticket reads.
   Record its role, source attempt/archive, acceptance/settlement, tested commit, delivery commit or none, exact required files and worktree-relative destination in the brief and ledger.
   Copy those files into fresh aliases in EACH consumer worktree; verify source provenance/commits and every required source and copied file before launch, not merely nonempty folders.
   Missing files, mismatched provenance, failed/rejected or unsettled dependency attempts block launch; never select by directory recency, rename/overwrite original archives or use external symlinks.
   All `evidence/...` aliases below are under that worktree's `docs/conway-specs/`.
   - T32, T33 and T43 bind `evidence/T31/export-diff.md`; if it names a newer export, also bind every required snapshot file under `evidence/T31/export/`.
   - T41 binds `evidence/T40/notes.md` and `evidence/T40/delete-paths.md`; T47 binds `evidence/T40/closeout-statement.md`.
     For failed T40 followed by accepted/settled T40-r2, copy the required T40-r2 files to local `evidence/T40/` in BOTH consumers; main's T40 and T40-r2 archives remain intact, and failed T40 is not accepted input.
   - T47 also binds T41's backup results, the latest accepted/settled T44/T45 reports and captures, and the accepted full T46 tour, including implementation retries, plus applicable accepted/settled per-pair reruns.
     Enumerate every required report/capture file; partial reruns never replace full-tour coverage.
   - Exception: an original T46 retry binds its OWN safely settled failed attempt to local `evidence/T46/`, explicitly labeled `failed/resume`, not accepted dependency evidence.
     Reuse coverage only when `findings.md`, `notes.md` and every capture for the recorded completed configurations are present.
     If no configuration completed or that coverage is incomplete, preserve the failed archive, omit the resume binding and restart the full tour from its first configuration.
     Otherwise preserve that input and carry only its coverage files into the retry's distinct output before resuming, never its archived brief.

   For T47 and T48, copy the live run log to `<worktree>/docs/conway-specs/evidence/run-log.md` as a coordinator snapshot with source/run/time provenance, not accepted producer evidence.
   Resolve paths before checking that input alias roots, the fixed brief/run-log files and the new output folder stay inside the worktree and are pairwise disjoint: reject escaping paths and equal/ancestor/descendant collisions.
   Reserve `<output folder>/attempt-brief.md` for settlement's archived brief, never worker output.
   Git ignores the evidence folder, so nothing reaches a new worktree unless you copy it.
   Workers stay inside their worktree, because Copilot CLI asks before it changes files outside its folder, and nobody is there to answer.
5. Before EVERY launch, including native retries, persist a fresh coordinator-written `docs/conway-specs/evidence/attempt-brief.md` in that fresh worktree using the sole template below.
   Check its attempt/base, worktree/branch, mode, failure note, output and validated bindings against the intended ledger launch; make the brief and all input copies, including the run-log snapshot, worker-read-only and immutable throughout execution.
   Never dispatch an unchanged implementation ticket as a verification rerun or narrow refresh contract.
6. For a new task, store ONLY this invariant loader: `orca orchestration task-create --run <run id> --task-title "<id> <title>" --spec "In this worker's worktree, read docs/conway-specs/worker-rules.md, then docs/conway-specs/evidence/attempt-brief.md, then the local base ticket file named in that brief. Follow the rules and brief; stop on missing or mismatched inputs." --json`.
   Do not concatenate the brief or ticket into the spec or embed attempt-specific data; native failed/stopped retries skip task-create as "Retry" says.
   Pass no `--deps`: you create a task only when its dependencies are done or skipped, the ledger is the dependency record, and a skipped ticket has no task to name.
   The ledger's Task id column holds the ticket's latest task; when a retry gets a new task, move the old id to Notes.
7. Start the worker in that worktree with `orca orchestration worker-start --task <task id> --worktree path:<worktree> <agent flags> --json`, adding `--retry-of` only as "Retry" permits.
   The call exits 0 only when the worker is ready.
8. Record the brief, attempt id, lane, task id, dispatch id, worktree path and branch in the run log.
   `git worktree list` shows the branch.

The sole on-disk brief template, written to `docs/conway-specs/evidence/attempt-brief.md` with the brackets filled in:

- Bundle: `docs/conway-specs/` in your worktree.
- Read `worker-rules.md` in the bundle before this brief, then read the named base ticket from this worktree.
- Base ticket: `<id and worktree-relative path>`; mode: `<mode>`; unique attempt id: `<id, such as T45-r2>`.
- Launch worktree/branch: `<absolute worktree root and branch>`.
- Base/tested commit at dispatch: `<hash>`; record the actual tested commit in your result if authorized work changes it.
- What went wrong last time: `<prior dispatch and failure/rejection note, or none>`.
- Effective `owns`: `<exact paths, preserving any new: prefixes, or []>`.
- Permitted actions and explicit overridden base-ticket fields: `<implementation, read-only verification or scoped document edits>`.
- Scoped acceptance and required evidence: `<checks, runs or exact screen/configuration pairs and output files>`.
- Your unique evidence output folder is `docs/conway-specs/evidence/<attempt id>/` in your worktree.
  Never overwrite a prior attempt's evidence.
- Input bindings: `<role: accepted dependency or failed/resume; worktree-relative alias -> source attempt/archive; acceptance/settlement; tested commit; delivery commit or none; exact required files, or none>`.
- Run base: `<run base>`.
- Run log copy: `docs/conway-specs/evidence/run-log.md` for T47 and T48, or "none"; coordinator snapshot provenance: `<source path, run id and snapshot time, or none>`.
  Read that copy, not the older `docs/conway-specs/run-log.md` in your worktree.
- Lane: <L1, L2, L3 or gate>.
  Small phone: "<name>" `<id>`.
  Large phone: "<name>" `<id>`.
  DerivedData: `<path>`.
- GitNexus mode: <index or manual>.
- Workflow exception: the user approved skipping GSD for this run on 2026-10-29.
- Live tickets beside you, and the files they own or hold: <list, or "none">.
- Shared test helpers so far: <the helper list from the run log>.
- Test performance: follow `docs/test-performance-guide.md` as worker-rules' Test performance section says, with the test command from its Build and test section.
- Notes from earlier tickets that touch your files: <any, or "none">.
- Review items already fixed outside this run: <items with commit hashes, or "none">.

Use these mode-specific contracts when filling the brief:

- T44, T45 and T46 `verification-rerun` briefs set effective `owns: []` and permit evidence-only output, with no tracked edits, staging, commits, edit grants or DEBUG-helper authoring.
  Explicitly replace implementation, repro-authoring and ownership instructions with the read-only actions below.
- T44 retains its full verification runs, failure/flakiness investigation and `report.md` requirements.
- T45 runs the existing three AX3/light suites on both phones and the existing journey at default text/dark on both phones, with their screenshots and run counts.
  It also runs the existing relaunch-persistence checks for sets, remaining rest time and finished-workout history at default text/light on both phones.
  Its scoped acceptance is complete run evidence and truthful findings, not new assertions, scroll/reveal steps or app/test fixes.
- T46 lists every requested `(screen, phone, text size, appearance)` pair explicitly.
  Its acceptance requires exactly those captures, their findings and screenshot notes, using T46's filename and severity conventions.
  An unreachable requested screen requires a P1 finding and attempted-state screenshot evidence for that pair, never silent omission or a claim that it passed.
  No 264-image requirement or test/helper authoring applies to this rerun.
  The original T46 and its implementation retries still owe the full 33-screen, eight-configuration, 264-image tour and its resumption requirements.
  Keep earlier folders and record new per-pair coverage, tested commit and pass/finding/unreachable state so a partial rerun never replaces the entire tour.
- Complete verification evidence can be accepted even when it reports failed checks; it is not proof that those checks passed.
  Missing runs or required evidence fail acceptance, and needed app/test fixes, including blocking flaky tests, become separate tickets.
- T47 `docs-refresh` briefs list the exact permitted paths from `docs/VERIFICATION.md`, `docs/MILESTONE-1-CLOSEOUT.md`, `docs/MILESTONE-1-AUDIT.md` and `docs/verification/BASELINE-20261003.md`, plus each explicitly named cited screenshot under `docs/verification/`.
  Their effective `owns` is that exact list, and acceptance checks the refreshed claims, counts, links and open flags against the supplied evidence.
- T48 `docs-refresh` briefs set effective `owns` to only `.lavish/milestone-1-closeout.html` and replace the original Change, Repro first and Observable acceptance with review-page-only work.
  Acceptance requires that the local, unpublished page mirror the refreshed closeout docs, with its source evidence recorded in notes.
  This refresh does not inherit gallery/test implementation, product-doc or changelog-draft work.
- T47 and T48 refreshes are commit-capable, not read-only verification.
  Commit authorized document/image changes when present, with no empty commit when already current.

## Supervise

Each `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json` returns one delivery: the oldest batch of messages from every lane.
Orca replays that batch until you acknowledge it, and newer messages wait behind it.

1. Handle every message in the batch, in order.
   Answer questions as below, and check, merge or retry, and settle each `worker_done` as the next sections say.
2. Then acknowledge the delivery once, with `orca orchestration check --ack <delivery id>`.
   The ack covers the whole batch, so never ack before every message in it is handled.
3. Start the next tickets, then wait again.

Answering questions:

- Answer with `orca orchestration reply --id <message id> --body "<answer>" --json`.
  Answer from [decisions.md](decisions.md) and [tradeoffs.md](tradeoffs.md).
  Ask the user only about a product decision that neither file covers, record the answer in both the run log and the right leaf, and commit the leaf as "Bundle changes" says.
- Before answering an edit ask, match its ticket, attempt, dispatch and message id to a still-live requester that has not ended, been superseded or been fenced.
  Do not grant while its execution or settlement state is uncertain.
  A verification rerun cannot gain edit permission, and a docs refresh cannot expand its explicit path scope through an ask or the gate exception.
- For an eligible edit-capable requester, say yes to a permitted file outside its effective `owns` only if no live attempt owns or holds that path.
  Record the grant under "Held files" with the requester and message identities before sending permission.
- If another live ticket owns or holds the file, reply "wait".
  When the worker asks again, do not reply: record its normalized path, requester attempt/dispatch, message id and wait order under "Held files".
  The ask stays pending after you acknowledge the batch, and "Settle a ticket" answers it when the file is freed.
- If two workers would end up waiting on each other, tell the later one to stop with outcome `failed`.
  A stop request or reported failure does not free anything; preserve both waits until the later attempt safely settles.
  Only then hand off its owned and held files, and retry after the other one merges.
- Exclusive tickets run with no other code worker, but still follow their effective brief's ownership and action limits.

When workers go quiet:

- After three empty waits in a row, run `orca orchestration worker-list --run <run id> --include-remote --json` to see whether the workers are alive.
- If a worker is stuck or gone, load `orca skills get orchestration --reference references/recovery-and-cleanup.md` before you act.
  Idle, timeout and missing heartbeats are not execution-stop proof; use the settlement guard below.
- In `worker-list`, a settled ticket whose terminal you closed shows `unverifiable` with `requiresAction: true` and no next action; that is expected, so ignore those rows.

## Accept or reject a worker_done

Match `worker_done` to its attempt and effective brief.
First get the stop proof in "Settle a ticket" step 2, including the terminal close for a `retained` receipt, so nothing in the worktree changes while you check it.
While that proof is pending, record the `worker_done` as pending in the run log, acknowledge its batch as usual, and come back to it after later waits.
While any `worker_done` is pending, wait with `--timeout-ms 120000` instead of 900000, so a finished ticket's lane does not sit idle until another lane sends a message.
Then check all of this in that worktree:

1. `git -C <worktree> log --format=%H%n%B main..HEAD` shows the ticket's commits, which name the ticket and have no `Co-Authored-By` line.
   For a no-commit result, it shows nothing.
2. For a ticket with a commit, `git -C <worktree> diff --stat main...HEAD` lists only files its effective brief permits, including authorized held files.
   Original work/retries retain applicable Ownership and DEBUG-helper allowances under worker-rules; gate placement never widens a rerun or refresh brief.
   A verification rerun has no tracked diff or commits, and a docs refresh changes only its explicit document/image paths.
   It lists nothing under `fitbod/Models/` or `fitbod/Persistence/` unless the ticket says so.
3. `git -C <worktree> status --porcelain` matches the worker's `status-before.txt`.
4. The attempt's evidence folder has the files [worker-rules.md](worker-rules.md) and its effective acceptance require, with the actual tested commit and truthful results.
   If the ticket saves screenshots, open at least one yourself.
   Read the Test performance list in `notes.md`, and check each new or changed test against section 6 of [the test performance guide](../test-performance-guide.md).
5. For an L ticket with a repro test, or any result you doubt, rerun the repro test once on one of the ticket's phones, with the test command from worker-rules' Build and test.

If a check fails, record the rejection and enter settlement, then follow Retry only after safe settlement completes.
If every check passes, merge authorized commits or accept the no-commit evidence, but mark the ticket `done` only after safe settlement.
For a no-commit result, record the tested commit, attempt and evidence location, not a fabricated delivery commit.

## Merge

Meet the execution-stop proof and cleanup-authority guard in "Settle a ticket" before rebasing or merging, while retaining the attempt's reservations until settlement completes.

1. If `git merge-base --is-ancestor main <branch>` succeeds, the branch already sits on the newest `main`.
   Otherwise, run `git -C <worktree> rebase main`.
   If that stops on a conflict, run `git -C <worktree> rebase --abort`, reject the result, settle the ticket, and follow Retry.
   If it is clean, build the app from the worktree with the ticket's large phone and DerivedData, except that a docs refresh repeats its scoped documentation checks instead.
   Treat a failed build or scoped check as a failed acceptance check.
2. In the main checkout, run `git merge --ff-only <branch>`.
   `main` never gets a merge commit.
3. Settle the ticket as `done`, with its commit on `main`.

## Settle a ticket

Enter settlement for every ending: merged, done without a commit, failed, rejected, stopped, split or abandoned.
A reported ending is not a safely settled attempt.

1. Record the reported outcome separately from settlement state, initially `pending`.
   Before clearing any bookkeeping, snapshot and deduplicate the union of effective `owns` paths with `new:` stripped and all granted held paths, plus the attempt's pending ask identities.
2. Require recorded positive execution-stop proof and safe cleanup authority before destructive cleanup, resource reuse or file handoff.
   The ordinary path is a valid `worker_done` accepted for that attempt, whatever its reported outcome, plus confirmed normal release through `orca orchestration worker-release --dispatch <dispatch id>`.
   A successful command exit alone is not confirmation of release.
   A receipt of `retained` with `processAction: none` is also normal: Orca settled the worker but kept its terminal open, as it did for every Copilot worker in the 2026-10-29 quick-task run.
   Together with the accepted `worker_done`, it counts as confirmed release when `orca orchestration worker-show --dispatch <dispatch id> --json` reports stage `settled` and `orca worktree ps --json` shows the worker's agent in that worktree as `done`.
   Then, before you check, rebase, merge or archive anything, close that agent with `orca terminal close --terminal <worker.agentTerminalHandle from worker-show> --json`; a receipt with `ptyKilled: true` is the stop proof, so the agent cannot start another turn in the worktree.
   If that agent is still `working`, it took on more work after `worker_done`, often because the user typed into it.
   Keep settlement pending, never close it or touch its worktree while it works, and check again after later waits.
   Ask the user only if it is still working 15 minutes after its `worker_done`.
   `worker-abandon` fences orchestration, not necessarily execution; abandonment, idle, timeout and missing heartbeats are not stop proof on their own.
   For abandonment, `release_pending`, `release_unknown` or any uncertainty, keep settlement pending and preserve the worktree, branch, lane, owned/held reservations and pending waits without replies or cancellations.
   Load the version-matched `orca skills get orchestration --reference references/recovery-and-cleanup.md` and follow the receipt's prescribed recovery, recording the receipt, positive stop proof and cleanup authority before resuming.
   Do not substitute blanket force cleanup, retry or lane replacement for unresolved recovery.
3. Archive the attempt's output in the main checkout's unique `docs/conway-specs/evidence/<attempt id>/`, with a byte-for-byte copy of its worktree-local `docs/conway-specs/evidence/attempt-brief.md` as `<attempt id>/attempt-brief.md`, before any authorized removal.
   Verify that the exact frozen brief was preserved, record its archive path, and never reconstruct it from a stored spec or overwrite the reserved filename with worker output.
   Preserve prior attempts and record failed/rejected outcomes in the ledger rather than overwriting evidence folders.
4. Remove the worktree with `orca worktree rm --worktree path:<worktree> --json` only when authorized, then delete its branch with `git branch -d <branch>` only when safe and authorized.
   For useful unmerged work, retain its branch and, if needed to preserve that work, its worktree, and record the reason and authorized disposition for Phase 8.
   A refusal or new uncertainty returns settlement to pending; preserve what remains and follow receipt-directed recovery rather than forcing removal.
5. Once proof, archiving and authorized cleanup or retention are complete, mark the old attempt `settled` and non-live in the ledger before testing file availability.
   Keep its history and record the ticket as `done` for accepted merged work or accepted no-commit evidence, otherwise `failed` with the reason.
   A split parent stays `failed` until Retry's replacement-coverage check passes.
   Record tested versus delivery commits and evidence locations.
   Copy into the run log any HIGH or CRITICAL rating, removed control, new shared helper and out-of-scope finding the worker reports.
6. Only then free its lane and the snapshotted owned-plus-held reservations, and retire its own pending asks without answering them.
   Strike those grant/wait lines with the settlement reference, retaining their history.
7. For each freed path, recheck every remaining live reservation before considering a handoff, even when the old attempt had no held files.
   Grant only the oldest eligible pending ask whose same requester attempt/dispatch is still live, whose message is still pending, and whose effective brief permits the edit.
   Never grant to an ended, superseded or fenced attempt; preserve uncertain or fenced wait records without replying or cancelling until their safety state is resolved.
   Record the new grant under "Held files" before answering `orca orchestration reply --id <message id> --body yes --json`.
   Later eligible asks keep waiting, and a path still reserved by any live attempt remains unavailable.
8. Once a ticket is `done` or `skipped`, archive it, as the user asked on 2026-10-31.
   Delete its file from `tickets/`, remove its row from [index.md](index.md), and add its id, phase, review items and planned new files to `ARCHIVED` in `capacity_model.py`.
   Run `python3 -I capacity_model.py`, then commit those paths by exact path.
   Its evidence folder and its ledger row stay, and later tickets may still name it.

## Retry

- Retry a failed, stopped or rejected ticket once, only after it safely settles, in a new worktree made as "Start one ticket" says, in the same lane and with the same agent flags.
  An unresolved attempt still reserves its resources and cannot be replaced in that lane.
  Give the retry a unique attempt/evidence folder and retain the failed brief's scope; `retry` mode is for original work, while reattempted verification or refresh keeps its own mode and overrides.
  Write current attempt/base/output/input metadata and a short "What went wrong last time" note into the fresh immutable on-disk brief, never into the stored spec.
- If the worker's outcome was `failed` or `stopped`, reuse its existing task and explicitly skip task-create: `orca orchestration worker-start --task <existing task id> --retry-of <dispatch id> --worktree path:<new worktree> <agent flags> --json`.
  The exact same stored loader reads the new worktree's fresh brief and local base ticket; it does not retain the old attempt's metadata.
- If the worker reported `succeeded` but you rejected the result, create a new task with that same invariant loader and start it without `--retry-of`.
  Orca accepts `--retry-of` only for a failed or stopped attempt, and refuses a succeeded one with `task_not_startable`.
- Installed `task-update` cannot modify specs, and `worker-start --task` and `--spec` are alternatives, not a way to override a reused task's spec.
- After a second failure and safe settlement, split the ticket into smaller tickets or take it yourself, and say so in the run log.
  Register real replacement children through the new-ticket/index process in "New findings", inheriting the parent's phase and prerequisites, never a dependency on the failed parent.
  Record the parent-to-child mapping and each original acceptance requirement's replacement coverage in the parent's Notes.
  Do not add a backwards numeric `depends_on` edge from the original ticket to higher-numbered replacements; this is runtime ledger completion, not a validator change.
  Keep the parent `failed`, blocking dependents and phase completion while any child is unaccepted/unsettled or any original acceptance remains uncovered.
  After all children are accepted and safely settled, verify their combined evidence against the full original acceptance, record their accepted delivery/tested commits and evidence, then explicitly mark the parent `done`.
  One completed child, or all children with a coverage gap, is insufficient.
- A retry of original T46 with a validated resume binding continues from the first configuration not covered by that input; without reusable coverage it starts from the first configuration, and either path still owes full original coverage.
  A scoped verification rerun is not such an implementation retry.

## Phase gates

A gate runs when every ticket of its phase is `done` or `skipped` and no attempt remains live or pending settlement.
A failed split parent blocks it until full replacement acceptance and coverage are recorded.
The next phase opens only after the gate passes.

| Gate | Phase | Tickets |
|---|---|---|
| 1 | 1 | T01 to T17 |
| 2 | 2 | T18 to T33 |
| 3 | 3 | T34 to T38 |
| 4 | 4 | T39 to T42 |
| 5 | 5 | T43, or its skip |

A gate is one full suite on the large gate phone at default text in light mode, plus a widget build.
It runs on `main` in the main checkout, with the gate DerivedData.
It uses the build and test flags from worker-rules' Build and test, so a test that runs past its allowance fails the gate.
It passes with zero unexpected failures; the one known issue is allowed.
Record the counts, the duration and the 20 slowest cases in the run log, as section 5.3 of [the test performance guide](../test-performance-guide.md) tracks them.
If a gate fails, write a fix ticket in the same phase, dispatch it, and run the gate again.
Any helper agent you start for a gate, a rerun or other test work gets the guide and worker-rules' Test performance section in its prompt.

## Design export checks

- You do T31 yourself, in the main checkout, and write its evidence to `<main checkout>/docs/conway-specs/evidence/T31/`.
  If it finds a newer export, it copies the export into `evidence/T31/export/`, so T32, T33 and T43 get a copy that stands alone; record the export's source path in the run log.
- T31 runs before T32 and T33.
  If it finds a newer export, T32 and T33 build from it.
- Before Phase 5, repeat the T31 check yourself.
  If no newer export exists, mark T43 skipped with the reason "no newer export".
- Before Phase 6, repeat the check once more, and report the result in the final report.

## New findings

- T44/T45 verification findings, T46's `findings.md` and each worker's out-of-scope notes become tickets T49 and later.
- Use the same front matter and sections as the existing tickets.
  Put each one in the phase where it was found, or in phase 6 for tour findings.
- Add a row for each new ticket to its phase table in [index.md](index.md), then run `python3 -I capacity_model.py`, which fails on any ticket that index.md does not list.
  Add rows to the run log, and commit the new ticket files and index.md as "Bundle changes" says.
- Findings tickets follow the same lane and file rules, so several can run at once.
- After the findings are fixed, rerun T44 and T45, and rerun T46 for every screen and configuration the fixes touched, each as a new exclusive task before Phase 7.
  Dispatch each with the explicit read-only `verification-rerun` brief from "Start one ticket", not the original implementation instructions.
  Record its tested commit, unique evidence folder and scoped coverage in the run log.
  T47 reads the latest T44/T45 evidence and the accepted full tour, including implementation retries, plus per-pair T46 reruns, selecting the newest applicable capture for each screen/phone/text-size/appearance pair.

## Bundle changes

- During the run, only you edit the bundle: the run log, new tickets and their index.md rows, and answers you add to decisions.md or tradeoffs.md.
- A rule change the user asks for gets an entry in changelog.md, and a status message to every live worker that spells it out, because their worktrees hold the old rules.
- Commit each of these changes except the run log on `main` as soon as you make it, staged by exact path.
  Workers cannot commit bundle files, new worktrees start from `main`, and Phase 8 pushes only what is committed.
- The run log is committed in Phase 8.

## Phase 8, for the coordinator only

1. Make sure the verification covers the final code.
   The latest T44 `report.md` names the commit it tested.
   If `git diff --stat <that commit>..main -- fitbod FitbodWidgets fitbodTests fitbodUITests` lists any file, as it will after T48 changes the component gallery, run T44 again on the final `main` with a read-only `verification-rerun` brief.
   Run T45 again too when a change touches a screen in its journeys, and scope any affected T46 pairs as "New findings" says.
   Then dispatch T47 as `T47-r2` with an explicit `docs-refresh` brief listing its permitted docs and cited images, so they cite the new runs.
   Dispatch T48 as `T48-r2` with the review-page-only `docs-refresh` brief, not its original gallery/test work.
   Push only after the latest T44 and T45 evidence matches the final code.
2. Stop Phase 8 cleanup if any attempt is live or pending settlement; preserve its worktree, branch, lane, reservations and waits until receipt-directed recovery proves execution stopped and authorizes cleanup.
   Apply "Settle a ticket" to retained failed work too, archiving useful work before any authorized removal of its worktree or branch.
   Do not force-delete retained branches merely to finish the run.
   Once all authorized cleanup is complete, check that `git worktree list` shows no `conway-` worktree and `git branch` shows no branch of this run.
   Only then shut down the lane phones with `xcrun simctl shutdown <id>`, and leave deleting them to the user.
3. Commit `docs/conway-specs/run-log.md` on `main`, staged by its exact path.
   Then `git status --porcelain` in the main checkout must show nothing; ask the user about any path that is left.
4. In `index` mode, run `gitnexus detect-changes --scope compare --base-ref <run base> --repo fitbod`, and check that the affected flows match the tickets.
   In `manual` mode, check `git diff --stat <run base>..main` against the effective briefs' ownership and authorized grants instead.
5. Run `git fetch origin`, then check that `origin/main` still equals the value you recorded at setup.
   If it moved, stop and ask the user, because someone else pushed during the run.
6. Review `git log --oneline origin/main..main`.
7. Check that no commit of this run has the trailer: `git log <run base>..main --format=%B` contains no `Co-Authored-By`.
8. Push with `git push origin main`.
   It must be a fast-forward.
   Never force-push, and never push a ticket branch, `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` or `task/codex`; the last three hold the old history with `build/`.
9. Report to the user in plain English: what changed, the evidence, the open flags and the roadmap.
