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
- Live ticket: a ticket that is dispatched and not yet merged, skipped or abandoned.
- Held file: a file outside a live ticket's `owns` list that you let its worker edit.
  It stays held until that ticket merges, and no other ticket may edit it meanwhile.
- Exclusive ticket: T42 to T48, and the reruns of T44 and T45.
  Each one touches many files or runs the full suite, so it runs with no other code worker, on the gate phones.

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

T31 needs no simulator and edits no repo file, so it takes no lane; start it as soon as Phase 2 opens.
Fill every free lane before you wait again.
The hotspot list from `capacity_model.py` shows which tickets will wait for each other's files.

## Start one ticket

1. Pick a free lane, or the gate phones for an exclusive ticket.
2. Create the ticket worktree from the newest `main` with `orca worktree create --repo path:<main checkout> --name conway-<id in lower case> --base-branch main --json`.
   `--base-branch main` matters: the local `main` holds every merged ticket, and the repo's default base may be `origin/main`, which does not until Phase 8.
3. Check that `git -C <worktree> rev-parse HEAD` equals `git rev-parse main`.
   If it does not, remove the worktree and create it again.
4. Copy into `<worktree>/docs/conway-specs/evidence/` every earlier evidence folder the ticket reads: T31's for T32 and T43, T40's for T41 and T47, and the latest T44, T45 and T46 folders, reruns included, for T47.
   Workers stay inside their worktree, because Copilot CLI asks before it changes files outside its folder, and nobody is there to answer.
5. Build the spec text: the task header below, then the full ticket file.
6. Create the task with `orca orchestration task-create --run <run id> --task-title "<id> <title>" --spec "<spec text>" --deps '<JSON array of the Orca task ids of its dependencies>' --json`.
7. Start the worker in that worktree with `orca orchestration worker-start --task <task id> --worktree path:<worktree> <agent flags> --json`.
   The call exits 0 only when the worker is ready.
8. Record the lane, the task id, the dispatch id, the worktree path and its branch in the run log.
   `git worktree list` shows the branch.

The task header, with the brackets filled in:

- Bundle: `docs/conway-specs/` in your worktree.
- Read `worker-rules.md` in the bundle before anything else, because it is part of this spec.
- Your evidence folder is `docs/conway-specs/evidence/<id>/` in your worktree.
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

- Wait with `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json`.
  Messages from every lane arrive in one queue; handle them in order.
- Answer each question with `orca orchestration reply --id <message id>`.
  Answer from [decisions.md](decisions.md) and [tradeoffs.md](tradeoffs.md).
  Ask the user only about a product decision that neither file covers, and record the answer in both the run log and the right leaf.
- When a worker asks to edit a file outside its `owns` list, say yes only if no live ticket owns or holds that file.
  Once you say yes, the file is held by that ticket; list it in the run log under "Held files".
- If another live ticket owns or holds the file, reply "wait".
  When the worker asks again, acknowledge that delivery without replying, and note the ask's message id under "Held files" in the run log.
  Orca keeps the ask pending, and Merge step 6 says when to answer it.
  If two workers would end up waiting on each other, tell the later one to stop with outcome `failed`, and retry it after the other merges.
- Exclusive tickets run with no other code worker, so their workers follow their ticket's Ownership section without asking.
- After three empty waits in a row, run `orca orchestration worker-list --run <run id> --include-remote --json` to see whether the workers are alive.
- If a worker is stuck or gone, load `orca skills get orchestration --reference references/recovery-and-cleanup.md` before you act.

## Accept or reject a worker_done

Check all of this in the ticket worktree before you accept:

1. `git -C <worktree> log --format=%H%n%B main..HEAD` shows the ticket's commits, which name the ticket and have no `Co-Authored-By` line.
2. `git -C <worktree> diff --stat main...HEAD` lists only files from the ticket's `owns` list, the files it holds, and new DEBUG seed files next to `fitbod/App/DemoWorkoutSeed.swift`.
   For an exclusive ticket, it may also list any file its Ownership section allows.
   It lists nothing under `fitbod/Models/` or `fitbod/Persistence/` unless the ticket says so.
3. `git -C <worktree> status --porcelain` matches the worker's `status-before.txt`.
4. The evidence folder in the worktree has every file [worker-rules.md](worker-rules.md) lists.
   Open at least one screenshot yourself.
5. For an L ticket, or any result you doubt, rerun the repro test once on one of the ticket's phones.

If a check fails, follow Retry.
Otherwise, merge.

## Merge

1. If `git merge-base --is-ancestor main <branch>` succeeds, the branch already sits on the newest `main`.
   Otherwise, run `git -C <worktree> rebase main`.
   If that stops on a conflict, run `git -C <worktree> rebase --abort`, and retry the ticket as Retry says.
   If it is clean, build the app from the worktree with the ticket's large phone and DerivedData, and treat a failed build as a failed check.
2. In the main checkout, run `git merge --ff-only <branch>`.
   `main` never gets a merge commit.
3. Release the worker with `orca orchestration worker-release --dispatch <dispatch id>`.
   Release closes only the worker's terminal.
4. Copy `<worktree>/docs/conway-specs/evidence/<id>/` to `<main checkout>/docs/conway-specs/evidence/`, so the evidence outlives the worktree.
5. Remove the worktree with `orca worktree rm --worktree path:<worktree> --json`, then delete its branch with `git branch -d <branch>` if it still exists.
   If either one refuses, read `git -C <worktree> status` before you force anything, and ask the user when in doubt.
6. Acknowledge the message with `orca orchestration check --ack <delivery id>`, mark the ticket `done` with its commit on `main`, and free the lane and the ticket's held files.
   Then, for each freed file, answer the oldest pending ask that waits for it with `orca orchestration reply --id <message id> --body yes --json`, and move the file to that worker's ticket under "Held files".
   Later asks for the same file keep waiting.
7. Copy into the run log any HIGH or CRITICAL rating, removed control, new shared helper and out-of-scope finding the worker reports.
8. Start the next tickets before you wait again.

## Retry

- Retry a failed or rejected ticket once, in a new worktree made as "Start one ticket" says, in the same lane and with the same agent flags.
  Add a short "What went wrong last time" note to the spec.
- If the worker's outcome was `failed`, start the retry with `orca orchestration worker-start --task <task id> --retry-of <dispatch id> --worktree path:<new worktree> <agent flags> --json`.
- If the worker reported `succeeded` but you reject the result, because a check failed or its rebase conflicted, create a new task for the retry and start it without `--retry-of`.
  Orca accepts `--retry-of` only for a failed or stopped attempt, and refuses a succeeded one with `task_not_startable`.
  Record both task ids in the run log.
- Before the retry, release the old worker, copy its evidence folder to `<main checkout>/docs/conway-specs/evidence/<id>-failed/`, and remove its worktree.
  Keep its branch only if it holds work worth reading, note it in the run log, and delete it in Phase 8.
- After a second failure, split the ticket into smaller tickets or take it yourself, and say so in the run log.
- A T46 retry continues from the first configuration that has no section in `findings.md` yet, so copy the failed attempt's evidence into the new worktree's `evidence/T46/` before it starts.

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

- T31 runs before T32 and T33.
  If it finds a newer export, T32 and T33 build from it.
- Before Phase 5, repeat the T31 check yourself.
  If no newer export exists, mark T43 skipped with the reason "no newer export".
- Before Phase 6, repeat the check once more, and report the result in the final report.

## New findings

- T46's `findings.md` and each worker's out-of-scope notes become tickets T49 and later.
- Use the same front matter and sections as the existing tickets.
  Put each one in the phase where it was found, or in phase 6 for tour findings.
- Run `python3 -I capacity_model.py` after you add tickets, and add rows to the run log.
- Findings tickets follow the same lane and file rules, so several can run at once.
- After the findings are fixed, rerun T44 and T45 as new exclusive tasks before Phase 7.
  Give each rerun its own evidence folder, such as `evidence/T44-r2/`, and record it in the run log, because T47 reads the latest one.

## Phase 8, for the coordinator only

1. Check that no ticket worktree is left: `git worktree list` shows no `conway-` worktree, and `git branch` shows no branch of this run.
   Delete any branch you kept from a failed ticket.
   Shut down the lane phones with `xcrun simctl shutdown <id>`, and leave deleting them to the user.
2. Commit `docs/conway-specs/run-log.md` on `main`, staged by its exact path.
3. In `index` mode, run `gitnexus detect-changes --scope compare --base-ref <run base> --repo fitbod`, and check that the affected flows match the tickets.
   In `manual` mode, check `git diff --stat <run base>..main` against the tickets' `owns` lists instead.
4. Run `git fetch origin`, then check that `origin/main` still equals the value you recorded at setup.
   If it moved, stop and ask the user, because someone else pushed during the run.
5. Review `git log --oneline origin/main..main`.
6. Check that no commit of this run has the trailer: `git log <run base>..main --format=%B` contains no `Co-Authored-By`.
7. Push with `git push origin main`.
   It must be a fast-forward.
   Never force-push, and never push a ticket branch, `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` or `task/codex`; the last three hold the old history with `build/`.
8. Report to the user in plain English: what changed, the evidence, the open flags and the roadmap.
