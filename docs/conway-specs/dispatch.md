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
- Ticket worktree: a new Orca worktree for one ticket, on its own branch from the newest `main`.
  Its worker commits there, and the coordinator merges that branch into `main`.
- Live ticket: a ticket whose worker is running, or whose result you have not settled yet (see "Settle a ticket").
- Held file: a file outside a live ticket's `owns` list that you let its worker edit.
  It stays held until you settle that ticket, and no other ticket may edit it meanwhile.
- Exclusive ticket: T42 to T48, and the reruns of T44, T45, T46 and T47.
  Each one touches many files or runs the full suite, so it runs with no other code worker, on the gate phones.
- No-commit result: a ticket whose Ownership section says it changes no repo file, such as T44 and its reruns, or a worker that reports "not reproduced".
  It must leave no commit behind.

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
- None of its `owns` paths, with `new:` removed, is owned or held by a live ticket.
- No exclusive ticket is live.
  An exclusive ticket also needs every other code worker to be finished, and nothing else starts while it waits for them.

You do T31 yourself, in the main checkout, as soon as Phase 2 opens, and it takes no lane.
A worker in a new worktree could not see the uncommitted design files or the home folders it searches (see "Design export checks").
Fill every free lane before you wait again.
The hotspot list from `capacity_model.py` shows which tickets will wait for each other's files.

## Start one ticket

1. Pick a free lane, or the gate phones for an exclusive ticket.
2. Create the ticket worktree from the newest `main` with `orca worktree create --repo path:<main checkout> --name conway-<id in lower case> --base-branch main --json`.
   `--base-branch main` matters: the local `main` holds every merged ticket, and the repo's default base may be `origin/main`, which does not until Phase 8.
3. Check that `git -C <worktree> rev-parse HEAD` equals `git rev-parse main`.
   If it does not, remove the worktree and create it again.
4. Copy into `<worktree>/docs/conway-specs/evidence/` every earlier evidence folder the ticket reads, and check that none is missing or empty:
   - T32, T33 and T43 read T31's folder, which holds `export-diff.md` and any export snapshot.
   - T41 reads T40's folder.
   - T47 reads the folders of T40 and T41, and the latest folders of T44, T45 and T46, reruns included.
   - A T46 retry reads its failed attempt's folder, copied in as `T46`.

   For T47 and T48, also copy the live run log to `<worktree>/docs/conway-specs/evidence/run-log.md`, because they need its ledger, removed controls and evidence folder names.
   Git ignores the evidence folder, so nothing reaches a new worktree unless you copy it.
   Workers stay inside their worktree, because Copilot CLI asks before it changes files outside its folder, and nobody is there to answer.
5. Build the spec text: the task header below, then the full ticket file.
6. Create the task with `orca orchestration task-create --run <run id> --task-title "<id> <title>" --spec "<spec text>" --json`.
   Pass no `--deps`: you create a task only when its dependencies are done or skipped, the ledger is the dependency record, and a skipped ticket has no task to name.
   The ledger's Task id column holds the ticket's latest task; when a retry gets a new task, move the old id to Notes.
7. Start the worker in that worktree with `orca orchestration worker-start --task <task id> --worktree path:<worktree> <agent flags> --json`.
   The call exits 0 only when the worker is ready.
8. Record the lane, the task id, the dispatch id, the worktree path and its branch in the run log.
   `git worktree list` shows the branch.

The task header, with the brackets filled in:

- Bundle: `docs/conway-specs/` in your worktree.
- Read `worker-rules.md` in the bundle before anything else, because it is part of this spec.
- Your evidence folder is `docs/conway-specs/evidence/<id>/` in your worktree.
- Run base: `<run base>`.
- Run log copy: `docs/conway-specs/evidence/run-log.md` for T47 and T48, or "none".
  Read that copy, not the older `docs/conway-specs/run-log.md` in your worktree.
- Lane: <L1, L2, L3 or gate>.
  Small phone: "<name>" `<id>`.
  Large phone: "<name>" `<id>`.
  DerivedData: `<path>`.
- GitNexus mode: <index or manual>.
- Workflow exception: the user approved skipping GSD for this run on 2026-10-29.
- Live tickets beside you, and the files they own or hold: <list, or "none">.
- Shared test helpers so far: <the helper list from the run log>.
- Notes from earlier tickets that touch your files: <any, or "none">.
- Review items already fixed outside this run: <items with commit hashes, or "none">.

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
- When a worker asks to edit a file outside its `owns` list, say yes only if no live ticket owns or holds that file.
  Once you say yes, the file is held by that ticket; list it in the run log under "Held files".
- If another live ticket owns or holds the file, reply "wait".
  When the worker asks again, do not reply: note the ask's message id under "Held files".
  The ask stays pending after you acknowledge the batch, and "Settle a ticket" answers it when the file is freed.
- If two workers would end up waiting on each other, tell the later one to stop with outcome `failed`.
  Settling it frees its files for the other one; retry it after the other one merges.
- Exclusive tickets run with no other code worker, so their workers follow their ticket's Ownership section without asking.

When workers go quiet:

- After three empty waits in a row, run `orca orchestration worker-list --run <run id> --include-remote --json` to see whether the workers are alive.
- If a worker is stuck or gone, load `orca skills get orchestration --reference references/recovery-and-cleanup.md` before you act.

## Accept or reject a worker_done

Check all of this in the ticket worktree:

1. `git -C <worktree> log --format=%H%n%B main..HEAD` shows the ticket's commits, which name the ticket and have no `Co-Authored-By` line.
   For a no-commit result, it shows nothing.
2. For a ticket with a commit, `git -C <worktree> diff --stat main...HEAD` lists only files from the ticket's `owns` list, the files it holds, and new DEBUG seed files next to `fitbod/App/DemoWorkoutSeed.swift`.
   For an exclusive ticket, it may also list any file its Ownership section allows.
   It lists nothing under `fitbod/Models/` or `fitbod/Persistence/` unless the ticket says so.
3. `git -C <worktree> status --porcelain` matches the worker's `status-before.txt`.
4. The evidence folder has the files [worker-rules.md](worker-rules.md) lists for this kind of ticket, and every file its Observable acceptance names.
   If the ticket saves screenshots, open at least one yourself.
5. For an L ticket with a repro test, or any result you doubt, rerun the repro test once on one of the ticket's phones.

If a check fails, reject the result: settle the ticket, then follow Retry.
If every check passes, merge a ticket with a commit, and settle a no-commit result as `done`.

## Merge

1. If `git merge-base --is-ancestor main <branch>` succeeds, the branch already sits on the newest `main`.
   Otherwise, run `git -C <worktree> rebase main`.
   If that stops on a conflict, run `git -C <worktree> rebase --abort`, reject the result, settle the ticket, and follow Retry.
   If it is clean, build the app from the worktree with the ticket's large phone and DerivedData, and treat a failed build as a failed check.
2. In the main checkout, run `git merge --ff-only <branch>`.
   `main` never gets a merge commit.
3. Settle the ticket as `done`, with its commit on `main`.

## Settle a ticket

Settle every ticket that ends, whatever the ending: merged, done without a commit, failed, rejected, stopped, split or abandoned.

1. Release its worker with `orca orchestration worker-release --dispatch <dispatch id>`, unless you abandoned it.
   Release closes only the worker's terminal.
2. Copy `<worktree>/docs/conway-specs/evidence/<id>/` to the main checkout's `docs/conway-specs/evidence/`: as `<id>/` when the ticket is done, or as `<id>-failed/`, then `<id>-failed-2/`, when it is not.
3. Remove the worktree with `orca worktree rm --worktree path:<worktree> --json`, then delete its branch with `git branch -d <branch>` if it still exists.
   For a ticket that did not merge, keep the branch only if it holds work worth reading, note it in the run log, and delete it with `git branch -D` in Phase 8.
   If a removal refuses, read `git -C <worktree> status` before you force anything, and ask the user when in doubt.
4. Free its lane and every file it holds, and strike its lines under "Held files".
   Strike any ask it left waiting there without answering it, because its worker is gone.
5. For each freed file, answer the oldest pending ask that waits for it with `orca orchestration reply --id <message id> --body yes --json`, and move the file to that worker's ticket under "Held files".
   Later asks for the same file keep waiting.
6. Update the ledger: `done` with the commit on `main`, or `failed` with the reason.
   Copy into the run log any HIGH or CRITICAL rating, removed control, new shared helper and out-of-scope finding the worker reports.

## Retry

- Retry a failed or rejected ticket once, after you settle it, in a new worktree made as "Start one ticket" says, in the same lane and with the same agent flags.
  Add a short "What went wrong last time" note to the spec.
- If the worker's outcome was `failed`, start the retry with `orca orchestration worker-start --task <task id> --retry-of <dispatch id> --worktree path:<new worktree> <agent flags> --json`.
- If the worker reported `succeeded` but you rejected the result, create a new task for the retry and start it without `--retry-of`.
  Orca accepts `--retry-of` only for a failed or stopped attempt, and refuses a succeeded one with `task_not_startable`.
- After a second failure, split the ticket into smaller tickets or take it yourself, and say so in the run log.
- A T46 retry continues from the first configuration that has no section in `findings.md` yet, from the folder that "Start one ticket" copies in.

## Phase gates

A gate runs when every ticket of its phase is `done` or `skipped`, so no worker is live.
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
It passes with zero unexpected failures; the one known issue is allowed.
Record the counts and the duration in the run log.
If a gate fails, write a fix ticket in the same phase, dispatch it, and run the gate again.

## Design export checks

- You do T31 yourself, in the main checkout, and write its evidence to `<main checkout>/docs/conway-specs/evidence/T31/`.
  If it finds a newer export, it copies the export into `evidence/T31/export/`, so T32, T33 and T43 get a copy that stands alone; record the export's source path in the run log.
- T31 runs before T32 and T33.
  If it finds a newer export, T32 and T33 build from it.
- Before Phase 5, repeat the T31 check yourself.
  If no newer export exists, mark T43 skipped with the reason "no newer export".
- Before Phase 6, repeat the check once more, and report the result in the final report.

## New findings

- T46's `findings.md` and each worker's out-of-scope notes become tickets T49 and later.
- Use the same front matter and sections as the existing tickets.
  Put each one in the phase where it was found, or in phase 6 for tour findings.
- Add a row for each new ticket to its phase table in [index.md](index.md), then run `python3 -I capacity_model.py`, which fails on any ticket that index.md does not list.
  Add rows to the run log, and commit the new ticket files and index.md as "Bundle changes" says.
- Findings tickets follow the same lane and file rules, so several can run at once.
- After the findings are fixed, rerun T44 and T45, and rerun T46 for every screen and configuration the fixes touched, each as a new exclusive task before Phase 7.
  Give each rerun its own evidence folder, such as `evidence/T44-r2/` or `evidence/T46-r2/`, and record it in the run log.
  T47 reads the latest of each, and uses the newest capture of each screen.

## Bundle changes

- During the run, only you edit the bundle: the run log, new tickets and their index.md rows, and answers you add to decisions.md or tradeoffs.md.
- Commit each of these changes except the run log on `main` as soon as you make it, staged by exact path.
  Workers cannot commit bundle files, new worktrees start from `main`, and Phase 8 pushes only what is committed.
- The run log is committed in Phase 8.

## Phase 8, for the coordinator only

1. Make sure the verification covers the final code.
   The latest T44 `report.md` names the commit it tested.
   If `git diff --stat <that commit>..main -- fitbod FitbodWidgets fitbodTests fitbodUITests` lists any file, as it will after T48 changes the component gallery, run T44 again on the final `main` as a new exclusive task.
   Run T45 again too when a change touches a screen in its journeys.
   Then rerun T47 as `T47-r2`, so its docs cite the new runs, and T48 as `T48-r2`, limited to the review page that mirrors those docs.
   Push only after the latest T44 and T45 evidence matches the final code.
2. Check that no ticket worktree is left: `git worktree list` shows no `conway-` worktree, and `git branch` shows no branch of this run.
   Delete any branch you kept from a failed ticket.
   Shut down the lane phones with `xcrun simctl shutdown <id>`, and leave deleting them to the user.
3. Commit `docs/conway-specs/run-log.md` on `main`, staged by its exact path.
   Then `git status --porcelain` in the main checkout must show nothing; ask the user about any path that is left.
4. In `index` mode, run `gitnexus detect-changes --scope compare --base-ref <run base> --repo fitbod`, and check that the affected flows match the tickets.
   In `manual` mode, check `git diff --stat <run base>..main` against the tickets' `owns` lists instead.
5. Run `git fetch origin`, then check that `origin/main` still equals the value you recorded at setup.
   If it moved, stop and ask the user, because someone else pushed during the run.
6. Review `git log --oneline origin/main..main`.
7. Check that no commit of this run has the trailer: `git log <run base>..main --format=%B` contains no `Co-Authored-By`.
8. Push with `git push origin main`.
   It must be a fast-forward.
   Never force-push, and never push a ticket branch, `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` or `task/codex`; the last three hold the old history with `build/`.
9. Report to the user in plain English: what changed, the evidence, the open flags and the roadmap.
