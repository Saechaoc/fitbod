# Coordinator playbook

This leaf is for the coordinator, not for workers.
It says how to turn the tickets into Orca tasks, how to supervise each worker, and how to close the run.
The Orca CLI is `/Applications/Orca.app/Contents/Resources/bin/orca`.
Load the version-matched guide with `orca skills get orchestration` before the first command, and check each verb's `--help` before its first use.

## Preconditions

Do not dispatch anything until every line here is true, and each answer is recorded in [run-log.md](run-log.md):

1. The user approved the workflow exception: workers skip GSD for this run.
2. The user chose an Orca setting for new agent tabs that lets workers build, test, edit and commit without stopping for every prompt.
   Orca has no flag for this; worker tabs follow that setting.
3. `orca status --json` shows Orca running.
4. `git status --porcelain` shows only the pre-existing paths listed in [worker-rules.md](worker-rules.md), plus untracked `.planning/quick/` folders from the other effort.
   Lines for this bundle (`docs/conway-specs/`) and for `.gitignore`, which ignores its evidence, are expected.
   Ask the user about any other path.
5. `xcrun simctl list devices` shows both sw6 phones.
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

## Create the run

Run `orca orchestration run-create --objective "Finish Milestone 1 (conway plan)" --json`, and record the run id in the run log.
Record the run base too: the output of `git rev-parse --short HEAD`.
T44 and Phase 8 compare against it, never against a hash from the plan or the review.

## Dispatch one ticket

Take the lowest-numbered ticket that is not done and whose dependencies are done or skipped.
Only one code worker runs at a time.
T31 is the exception: it may run beside a code worker.

1. Build the spec text: the task header below, then the full ticket file.
2. Create the task with `orca orchestration task-create --run <run id> --task-title "<id> <title>" --spec "<spec text>" --deps '<JSON array of the Orca task ids of its dependencies>' --json`.
3. Start the worker with `orca orchestration worker-start --task <task id> --worktree current --agent claude --model claude-opus-5-5 --effort medium --display-name "<id>" --json`.
   The call exits 0 only when the worker is ready.
4. Record the task id and dispatch id in the run log.

The task header, with the brackets filled in:

- Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/conway-specs`.
- Read `worker-rules.md` in the bundle before anything else, because it is part of this spec.
- Your evidence folder is `evidence/<id>/` in the bundle.
- Workflow exception: the user approved skipping GSD for this run on <date>.
- Shared test helpers so far: <the helper list from the run log>.
- Notes from earlier tickets that touch your files: <any, or "none">.
- Review items already fixed outside this run: <items with commit hashes, or "none">.

## Supervise

- Wait with `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json`.
- Answer each question with `orca orchestration reply --id <message id>`.
  Answer from [decisions.md](decisions.md) and [tradeoffs.md](tradeoffs.md).
  Ask the user only about a product decision that neither file covers, and record the answer in both the run log and the right leaf.
- After three empty waits in a row, run `orca orchestration worker-list --include-remote --json` to see whether the worker is alive.
- If a worker is stuck or gone, load `orca skills get orchestration --reference references/recovery-and-cleanup.md` before you act.

## Accept or reject a worker_done

Check all of this before you accept:

1. `git log -1 --format=%H%n%B` shows a new commit that names the ticket and has no `Co-Authored-By` line.
2. `git show --stat HEAD` lists only files from the ticket's `owns` list, their direct callers, their tests and allowed DEBUG seeds.
   Nothing under `fitbod/Models/` or `fitbod/Persistence/` changed unless the ticket says so.
3. `git status --porcelain` matches the worker's `status-before.txt`.
4. The evidence folder has every file [worker-rules.md](worker-rules.md) lists.
   Open at least one screenshot yourself.
5. For an L ticket, or any result you doubt, rerun the repro test once on one phone.

Then release the worker with `orca orchestration worker-release --dispatch <dispatch id>`, acknowledge the message with `orca orchestration check --ack <delivery id>`, and update the run log.
Copy into the run log any HIGH or CRITICAL rating, removed control, new shared helper and out-of-scope finding the worker reports.

## Retry

- If the outcome is `failed`, or the commit fails your checks, retry once.
  Use `worker-start --task <task id> --retry-of <dispatch id>` with the same placement and agent flags.
  Add a short "What went wrong last time" note to the spec.
- After a second failure, split the ticket into smaller tickets or take it yourself, and say so in the run log.
- A T46 retry continues from the first configuration that has no section in `findings.md` yet.

## Phase gates

After the last ticket of each phase, run the gate before the next phase starts.

| Gate | After |
|---|---|
| 1 | T17 |
| 2 | T33 |
| 3 | T38 |
| 4 | T42 |
| 5 | T43, or its skip |

A gate is one full suite on the large phone at default text in light mode, plus a widget build.
It passes with zero unexpected failures; the one known issue is allowed.
Record the counts and the duration in the run log.
If a gate fails, write a fix ticket and dispatch it before the next phase.

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
- After the findings are fixed, rerun T44 and T45 as new tasks before Phase 7.
  Give each rerun its own evidence folder, such as `evidence/T44-r2/`, and record it in the run log, because T47 reads the latest one.

## Phase 8, for the coordinator only

1. Run `gitnexus detect-changes --scope compare --base-ref <run base> --repo fitbod`, and check that the affected flows match the tickets.
2. Run `git fetch origin`, then check that `origin/main` still equals the run base.
   If it moved, stop and ask the user, because someone else pushed during the run.
3. Review `git log --oneline origin/main..main`.
4. Check that no commit of this run has the trailer: `git log <run base>..main --format=%B` contains no `Co-Authored-By`.
5. Push with `git push origin main`.
   It must be a fast-forward.
   Never force-push, and never push `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` or `task/codex`, because they hold the old history with `build/`.
6. Report to the user in plain English: what changed, the evidence, the open flags and the roadmap.
