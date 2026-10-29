---
phase: quick-261028-tll
plan: 01
type: execute
wave: 1
depends_on: []
quick_id: 261028-tll
slug: milestone-1-finish-phase-0-restore-the-s
files_modified:
  - fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-01-design.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-02-logger.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-03-authoring.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-04-navigation.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-05-deload.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-06-ui-tests.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-07-docs-reference.txt
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-SUMMARY.md
  - .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-BASELINE.md
  - /Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md
autonomous: false
requirements: [M1-P0-1, M1-P0-2, M1-P0-3, M1-P0-4, M1-P0-5, M1-P0-6]

must_haves:
  truths:
    - "fitbod.xcscheme is identical to HEAD again, so the fitbodUITests TestableReference declares parallelizable = \"NO\" and UI tests run serially"
    - "GitNexus was refreshed with analyze --index-only, and CLAUDE.md, AGENTS.md and the gitnexus skill files were not rewritten"
    - "Before each group commit the GitNexus index was current for HEAD, and detect-changes --scope staged ran on exactly that group's staged paths with its full output saved"
    - "main has exactly seven new commits on 2bb5a91, in order 01-design to 07-docs-reference, each holding exactly its manifest's paths with content identical to backup/m1-worktree-20261028"
    - "Each commit message is the group's commit-plan.md subject, the fixed Codex provenance body and the Claude-Session line, with no Co-Authored-By trailer"
    - "No app, test, widget or project path is left uncommitted, and every excluded path is still uncommitted"
    - "BASELINE.md records the build result, exact unit plus UI test counts and every failure for a serial run of the committed tip on sw6 iPhone 17 Pro Max at default text in light mode"
    - "The review record again contains items 26-47"
    - "Nothing was pushed, so origin/main is unchanged"
  artifacts:
    - path: "fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme"
      provides: "Serial UI-test setting on the fitbodUITests TestableReference"
      contains: 'parallelizable = "NO"'
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-01-design.txt"
      provides: "detect-changes output for group 01"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-02-logger.txt"
      provides: "detect-changes output for group 02"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-03-authoring.txt"
      provides: "detect-changes output for group 03"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-04-navigation.txt"
      provides: "detect-changes output for group 04"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-05-deload.txt"
      provides: "detect-changes output for group 05"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-06-ui-tests.txt"
      provides: "detect-changes output for group 06"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-07-docs-reference.txt"
      provides: "detect-changes output for group 07"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-SUMMARY.md"
      provides: "Commit hashes, risk levels and check results"
      contains: "07-docs-reference"
    - path: ".planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-BASELINE.md"
      provides: "Baseline build result and exact test counts on the committed tip"
      contains: "79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE"
    - path: "/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md"
      provides: "Complete review record, items 1-47"
      contains: "may lose its first typed character"
  key_links:
    - from: "docs/verification/closeout/commit-groups/0*.paths"
      to: "commits 2bb5a91..HEAD"
      via: "git --literal-pathspecs add --pathspec-from-file plus an exact staged-name comparison"
      pattern: "pathspec-from-file"
    - from: "post-commit hook reindex"
      to: "gitnexus detect-changes --scope staged"
      via: "wait until .gitnexus/.reindex.lock is gone, then gitnexus status reports up to date"
      pattern: "\\.gitnexus/\\.reindex\\.lock"
    - from: "backup/m1-worktree-20261028"
      to: "each group commit"
      via: "the diff between the backup and the index or HEAD shares no path with the group's manifest"
      pattern: "backup/m1-worktree-20261028"
    - from: "fitbod.xcscheme parallelizable = \"NO\""
      to: "Task 3 xcodebuild test run"
      via: "serial UI tests together with -parallel-testing-enabled NO"
      pattern: "parallel-testing-enabled NO"
---

# Quick task 261028-tll: Milestone 1 finish, phase 0

<objective>
Finish Phase 0 of the user-approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Restore the serial UI-test scheme setting, refresh the GitNexus index, and commit Codex's seven prepared groups exactly as prepared.
Then, as orchestrator-owned work, record a baseline build and full test run on the committed tip and complete the review record.

Purpose: all milestone work sits uncommitted on top of 2bb5a91.
Committing it in Codex's reviewable groups protects it, and the baseline gives Phases 1-8 exact numbers to compare against.

Output: seven commits on main (not pushed), a restored scheme, seven detect-changes reports, `261028-tll-SUMMARY.md`, `261028-tll-BASELINE.md`, and an updated review record outside the repo.
</objective>

<rules>
These rules override the standard executor workflow for this plan.

1. Do not read `./CLAUDE.md` or `.claude/CLAUDE.md`.
   They exhaust executor context, and every rule you need is in this plan.
2. Start every Bash call with `cd /Users/chrissaechao/Desktop/fitbod &&`, because the shell's working directory resets between calls.
3. `$SCRATCH` means your own session scratchpad directory (the absolute path from your environment).
   Helper scripts, temporary indexes and commit-message files go there.
4. The only commits are the seven group commits in Task 2.
   Make no per-task commit and no docs or metadata commit.
   Do not edit `.planning/STATE.md` or `.planning/ROADMAP.md`, and do not run GSD state or roadmap update commands.
   Everything under `.planning/` stays uncommitted, including this plan, the detect files and the SUMMARY.
5. Never run `git add -A`, `git add .`, `git commit -a`, `git commit <paths>`, `git commit --amend`, `--no-verify`, `git stash`, `git checkout` or `git restore` on files, `git clean`, `git reset --hard` or `git push`.
   Never delete `.git/index.lock` or `.gitnexus/.reindex.lock`.
6. The only allowed index reset is `git reset -q` (index only, working tree untouched), which `check-group.sh` runs after a failed staging check.
7. Use `gitnexus analyze --index-only` only.
   Plain `gitnexus analyze` rewrites CLAUDE.md, AGENTS.md and skill files, and is forbidden.
8. Tasks 1 and 2 run no xcodebuild and no simulator.
   If you ever see xcodebuild output, filter it with `grep -E "error:|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)"`.
9. Deviation rules 1-3 (automatic fixes) do not apply.
   If any check fails, stop and report the failing check, its output (at most 40 lines), `git log --oneline -8` and `git diff --cached --name-only | head -20`.
   Do not improvise a workaround and do not touch the working tree.
10. Commit messages carry no Co-Authored-By trailer.
    The user's CLAUDE.md forbids it and takes precedence over the attribution reminder in your environment.
    Each message ends with the Claude-Session line from the template below.
11. Task 3 belongs to the orchestrator.
    When you reach it, stop and return a checkpoint, and do not run any part of it.
</rules>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Do not load `.planning/STATE.md` (257 KB), ROADMAP.md, PROJECT.md or CLAUDE.md for this plan.
Every fact below was verified read-only by the orchestrator on 2026-10-28.

`docs/verification/closeout/commit-plan.md` is the source of the subjects below.
Its note to finish the VERIFICATION.md checks before committing is superseded by the approved plan: commit first, then run the baseline on the committed tip in Task 3.
Do not run those checks in Tasks 1 and 2.

<interfaces>
Repository and references:

- Repo root: `/Users/chrissaechao/Desktop/fitbod`, branch `main`, starting HEAD `2bb5a91`.
- Backup of the whole working tree (tracked plus untracked, respecting .gitignore): local branch `backup/m1-worktree-20261028` at `4cc8d1b`.
  It is the drift reference for every check below.
  Do not create another backup, and do not move or delete this branch.
- Quick directory (QDIR): `.planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/`
- Scheme: `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme`.
  Its entire diff against HEAD is the removal of `parallelizable = "NO"` from the `fitbodUITests` TestableReference (Xcode dropped it today).
  It is the only changed code or project path outside the manifests.
- GitNexus: global CLI `gitnexus`.
  Commands used: `gitnexus analyze --index-only`, `gitnexus status`, `gitnexus detect-changes --scope staged`.
  A post-commit hook starts a background `gitnexus analyze --index-only` and holds the lock directory `.gitnexus/.reindex.lock` while it runs.
- Code prefixes, which must end up fully committed: `fitbod/`, `fitbodTests/`, `fitbodUITests/`, `FitbodWidgets`, `fitbod.xcodeproj/`.
- Excluded paths: 847 (graphify-out, .planning, bru-screens outside the Fitbod-Session snapshot, .repowise, .claude, AGENTS.md and others).
  They must stay uncommitted.
- `docs/verification/closeout/source-hashes.json`: 137 SHA-256 entries, all matching on 2026-10-28.
- `docs/verification/closeout/commit-manifest.json`: `groups[].message` holds the same seven subjects.

Groups, in commit order (manifests live in `docs/verification/closeout/commit-groups/`; 303 unique paths in total):

| Group | Manifest | Paths | Subject |
| --- | --- | --- | --- |
| 01-design | 01-design.paths | 27 | feat(design): add accessible BRU primitives and native icon |
| 02-logger | 02-logger.paths | 46 | fix(logger): preserve workout data and consistent weight labels |
| 03-authoring | 03-authoring.paths | 19 | feat(authoring): complete native exercise and session workflows |
| 04-navigation | 04-navigation.paths | 20 | feat(navigation): connect history and refine weekly volume |
| 05-deload | 05-deload.paths | 2 | fix(deload): assess missed targets from finished sessions |
| 06-ui-tests | 06-ui-tests.paths | 24 | test(ui): cover current navigation and workout journeys |
| 07-docs-reference | 07-docs-reference.paths | 165 | docs: record milestone evidence and open release flags |

Commit message template (shown for group 01; swap the first line for each group's subject; the file ends with exactly one newline):

```
feat(design): add accessible BRU primitives and native icon

Prepared by Codex on 2026-10-05 as an exact-path group (docs/verification/closeout/commit-plan.md). Committed unchanged after a SHA-256 drift check; verification results are recorded separately.

Claude-Session: https://claude.ai/code/session_01VB2pKGXuLZEuzD4fWeJUgN
```

detect-changes output files: `QDIR/261028-tll-detect-<group>.txt`, for example `QDIR/261028-tll-detect-01-design.txt`.

Simulator (Task 3 only): "sw6 iPhone 17 Pro Max" `79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE`.
Never use any other simulator.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restore the scheme, refresh GitNexus, and pre-flight all seven groups without committing</name>
  <files>fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme, $SCRATCH/wait-gitnexus.sh, $SCRATCH/check-group.sh, $SCRATCH/guard-before.sha256, $SCRATCH/status-before.txt, $SCRATCH/excluded-before.txt</files>
  <action>
Step 1 - Preconditions (approved plan Phase 0 step 1, the backup, is already done: verify it, never recreate it).
`git symbolic-ref --short HEAD` prints `main`.
`git rev-parse HEAD` starts with `2bb5a91`.
`git rev-parse backup/m1-worktree-20261028` starts with `4cc8d1b`.
`git diff --cached --quiet` exits 0, so the index is empty.
Record `git rev-parse origin/main` for the final no-push check.
If `pgrep -x Xcode` finds Xcode running, note it for the SUMMARY, because Xcode can drop the scheme attribute again.
Stop if any of these fails.

Step 2 - Guard snapshot.
Write `shasum -a 256` of `CLAUDE.md`, `AGENTS.md` and every file listed by `rg --files --hidden --no-ignore .claude/skills/gitnexus | LC_ALL=C sort` to `$SCRATCH/guard-before.sha256`.
These are the files a plain `gitnexus analyze` would rewrite.

Step 3 - Restore the scheme (approved plan Phase 0 step 2; CLAUDE.md requires serial simulator runs).
Run `git diff HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme`.
Expect one hunk whose only effect is dropping `parallelizable = "NO"` from the TestableReference whose BuildableReference has `BlueprintName = "fitbodUITests"`.
If the diff shows anything else, stop.
Use the Edit tool to turn the hunk's working-tree lines back into its HEAD lines exactly, with the same attribute order, indentation and position of the closing `>`.
Do not use `git checkout`, `git restore` or `git apply`.
`git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` must then exit 0.

Step 4 - Write two helper scripts with the Write tool.
`$SCRATCH/wait-gitnexus.sh` takes no arguments.
It changes to the repo root and pauses 5 seconds once, so a post-commit hook that just started can create its lock.
It then polls at most 113 times, 5 seconds apart, and exits 0 as soon as `.gitnexus/.reindex.lock` does not exist.
On timeout (about 9.5 minutes, inside the 10-minute shell limit) it prints `TIMEOUT`, `ls -ld .gitnexus/.reindex.lock` and `pgrep -fl gitnexus`, then exits 1.
Run it with a 600000 ms Bash timeout.
If your shell tool refuses a command that sleeps in the foreground, run the same script with run_in_background (or through the Monitor tool if you have it), and continue only after it exits 0.
`$SCRATCH/check-group.sh MANIFEST [TEMP_INDEX]` changes to the repo root.
If TEMP_INDEX is given, it exports `GIT_INDEX_FILE=TEMP_INDEX`, deletes any old file at that path and runs `git read-tree HEAD`, so the real index is never touched.
It then runs these checks in order and fails fast with a one-line reason.
(a) Stage with `git --literal-pathspecs add --pathspec-from-file=MANIFEST`; literal mode stops a bracket or star in a file name from matching other paths.
(b) Write `tr -d '\r' < MANIFEST | LC_ALL=C sort` to `$SCRATCH/expected.txt` and `git diff --cached --name-only --no-renames -z | tr '\0' '\n' | LC_ALL=C sort` to `$SCRATCH/actual.txt`, and require `cmp -s` to succeed (on failure print the first 20 lines of their `diff`).
(c) Require `git diff --cached --check` to exit 0 (on failure print its first 40 lines).
(d) Drift check: `git diff --cached --name-only --no-renames -z backup/m1-worktree-20261028 | tr '\0' '\n' | LC_ALL=C sort | LC_ALL=C comm -12 $SCRATCH/expected.txt -` must print nothing, which proves every staged path is identical to today's backup.
On success it prints `PASS <manifest> <path count>` and exits 0.
On any failure when TEMP_INDEX is not given, it runs `git reset -q` before exiting 1, so the real index is empty again.

Step 5 - Refresh GitNexus (approved plan Phase 0 step 3; `--index-only` per rule 7, which keeps the plan's intent of a fresh index).
Run `bash $SCRATCH/wait-gitnexus.sh`, then `gitnexus analyze --index-only` with a 600000 ms timeout.
If the analysis outlives that limit, rerun it in the background and wait for it to exit.
`gitnexus status` must then report the index up to date.
Copy its exact up-to-date wording into your notes, because Task 2 uses the same wording as its freshness signal.
Hash the guard files again; the result must equal `$SCRATCH/guard-before.sha256`.
If it does not, stop and name the changed files (the backup branch holds their previous content).

Step 6 - Pre-flight every group without touching the real index and without committing.
(a) `jq -r '.groups[].message' docs/verification/closeout/commit-manifest.json` must print exactly the seven subjects of the interfaces table, in order.
Compare with `diff` against a scratch file you write with the Write tool.
(b) SHA-256 drift check: inspect the structure of `docs/verification/closeout/source-hashes.json` with jq, then compare every recorded hash with `shasum -a 256` of its path.
All 137 must match.
This is the check the commit body's "SHA-256 drift check" refers to, so it must run now, right before committing.
(c) For each manifest from 01 to 07: `bash $SCRATCH/check-group.sh docs/verification/closeout/commit-groups/<group>.paths $SCRATCH/preflight.index` must print PASS.
Delete `$SCRATCH/preflight.index` afterwards.
(d) The seven manifests together hold 303 lines and 303 unique paths (`cat ... | tr -d '\r' | LC_ALL=C sort -u | wc -l`).
(e) Size screen: `cat` the seven manifests, strip CR, then `tr '\n' '\0' | xargs -0 stat -f '%z %N' | sort -rn | head -5`.
Stop if any file is over 100 MB (104857600 bytes), which GitHub rejects on the Phase 8 push, and list files over 50 MB as warnings.
(f) Name screen: `rg -i '(^|/)\.env($|\.)|\.(pem|p12|p8|cer|key|mobileprovision)$'` over the seven manifests must print nothing; stop if it prints anything.
(g) Status snapshot: write the paths from `git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' | cut -c4- | LC_ALL=C sort` to `$SCRATCH/status-before.txt`.
Every manifest path must appear in it.
Remove the manifest paths and every path under QDIR, and save the rest as `$SCRATCH/excluded-before.txt`.
No path in that file may start with one of the code prefixes.
Record its line count: the orchestrator expects 847, and a different count is reported, not a reason to stop.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme && git diff --cached --quiet && for m in docs/verification/closeout/commit-groups/0*.paths; do bash "$SCRATCH/check-group.sh" "$m" "$SCRATCH/verify.index" || exit 1; done && rm -f "$SCRATCH/verify.index" && test "$(git rev-list --count 2bb5a91..HEAD)" = 0 && echo TASK1-OK   # replace $SCRATCH with your scratchpad path</automated>
  </verify>
  <done>
The scheme is identical to HEAD.
`gitnexus status` reports the index up to date, and the guard hashes are unchanged.
All 137 recorded hashes match, and the seven subjects match commit-manifest.json.
All seven groups print PASS in a temporary index, and no file fails the size or name screen.
The real index is still empty, HEAD is still 2bb5a91, and the status snapshot and excluded list are saved.
  </done>
</task>

<task type="auto">
  <name>Task 2: Commit the seven groups in order, with detect-changes before each, then verify the range and write the SUMMARY</name>
  <files>main history (seven commits, no working-tree edits), QDIR/261028-tll-detect-01-design.txt to QDIR/261028-tll-detect-07-docs-reference.txt, QDIR/261028-tll-SUMMARY.md, $SCRATCH/msg-01-design.txt to $SCRATCH/msg-07-docs-reference.txt</files>
  <action>
This is approved plan Phase 0 step 5 under its ground rules: exact paths only, detect_changes before every commit, no Co-Authored-By trailer, the Claude-Session line, and no push.
Repeat steps A to F for each group in this order: 01-design, 02-logger, 03-authoring, 04-navigation, 05-deload, 06-ui-tests, 07-docs-reference.
Finish step F for one group before starting the next, and do not batch several groups into one shell call, because each reindex wait can take minutes.

A - Wait for GitNexus.
Run `bash $SCRATCH/wait-gitnexus.sh`; it must exit 0.
Then `gitnexus status` must show the up-to-date wording recorded in Task 1.
If the lock is gone but the index is stale, run `gitnexus analyze --index-only` once in the foreground and check again; stop if it is still stale.
Waiting before staging also keeps the background reindex's git calls away from `.git/index.lock`.

B - Stage and check.
Confirm `git diff --cached --quiet` exits 0.
Run `bash $SCRATCH/check-group.sh docs/verification/closeout/commit-groups/<group>.paths` with no second argument, so it uses the real index.
It must print PASS.
If it fails only because `.git/index.lock` exists, wait about 10 seconds and run it once more.
On any other failure the script has already emptied the index: stop and report.
Record `git diff --cached --shortstat` for the SUMMARY.

C - Impact check.
Run `gitnexus detect-changes --scope staged > QDIR/261028-tll-detect-<group>.txt 2>&1` and stop if it exits non-zero.
Read at most the first 60 lines of that file and note the risk level and the affected flows it names.
If a docs-only group yields no risk line, record "none reported".
HIGH or CRITICAL is expected for shared SwiftUI files (approved plan, Risks): record the rating and the named flows, and continue.
Stop only if it lists a changed file (not an affected caller or flow) that is outside the group's manifest.

D - Message.
Use the Write tool to create `$SCRATCH/msg-<group>.txt` from the template: the group's subject, a blank line, the body, a blank line, the Claude-Session line, and exactly one trailing newline.
Copy the body and the Claude-Session line verbatim from the template, and add no Co-Authored-By line.

E - Commit.
Run `git commit -F $SCRATCH/msg-<group>.txt` with no other arguments.
If it fails because `.git/index.lock` exists (a background hook may hold it briefly), wait about 10 seconds and retry once.
Any other failure, including a failing hook, means stop.

F - Verify the commit.
`git diff --cached --quiet` exits 0.
`git diff-tree --no-commit-id --name-only -r --no-renames -z HEAD | tr '\0' '\n' | LC_ALL=C sort` matches `$SCRATCH/expected.txt` (written by check-group.sh for this group) under `cmp -s`.
`git cat-file commit HEAD | sed '1,/^$/d' | cmp - $SCRATCH/msg-<group>.txt` succeeds, which proves the stored message is exactly the file.
`git diff --name-only --no-renames -z backup/m1-worktree-20261028 HEAD | tr '\0' '\n' | LC_ALL=C sort | LC_ALL=C comm -12 $SCRATCH/expected.txt -` prints nothing, which proves the committed content equals the backup.
Record the full `git rev-parse HEAD`.

After group 07:
1. Run `bash $SCRATCH/wait-gitnexus.sh` once more, so the last background reindex has finished.
2. Range checks: `git rev-list --count 2bb5a91..HEAD` prints 7.
`git log --reverse --format=%s 2bb5a91..HEAD` prints the seven subjects in order.
`git diff --name-only --no-renames -z 2bb5a91 HEAD`, sorted, equals the seven manifests concatenated, CR-stripped and sorted (303 paths).
`git log --format=%B 2bb5a91..HEAD | grep -ciE '^co-authored-by:'` prints 0.
`git log --format='%(trailers:key=Claude-Session,valueonly)' 2bb5a91..HEAD | grep -c 'session_01VB2pKGXuLZEuzD4fWeJUgN'` prints 7.
3. `git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` still exits 0.
If it does not, Xcode rewrote the scheme: repeat the Task 1 step 3 edit (never commit the scheme) and report it.
4. Status checks: write the paths from `git status --porcelain=v1 -z --untracked-files=all` (same pipeline as Task 1), minus paths under QDIR, to `$SCRATCH/status-after.txt`.
No path may start with a code prefix, and no manifest path may appear.
`LC_ALL=C comm -23 $SCRATCH/excluded-before.txt $SCRATCH/status-after.txt` must print nothing, which proves every excluded path is still uncommitted.
Report the line count (expected 847) and list the paths from `comm -13`, which appeared during the run, belong to other processes and stay uncommitted.
Commits are already made at this point, so a failed status check is reported as a failure; do not try to fix it.
5. The guard hashes still equal `$SCRATCH/guard-before.sha256`.
6. `git rev-parse origin/main` is unchanged from Task 1, so nothing was pushed.
Record `git rev-list --count origin/main..HEAD` for information only.
7. Write the SUMMARY described in the output section, then stop at Task 3 and return a checkpoint.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && test "$(git rev-list --count 2bb5a91..HEAD)" = 7 && cat docs/verification/closeout/commit-groups/0*.paths | tr -d '\r' | LC_ALL=C sort > "$SCRATCH/all.txt" && git diff --name-only --no-renames -z 2bb5a91 HEAD | tr '\0' '\n' | LC_ALL=C sort | cmp -s - "$SCRATCH/all.txt" && test "$(git log --format=%B 2bb5a91..HEAD | grep -ciE '^co-authored-by:')" = 0 && test -z "$(git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' | cut -c4- | grep -E '^(fitbod/|fitbodTests/|fitbodUITests/|FitbodWidgets|fitbod\.xcodeproj/)')" && git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme && test "$(ls .planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-detect-0*.txt | wc -l | tr -d ' ')" = 7 && echo TASK2-OK   # replace $SCRATCH with your scratchpad path</automated>
  </verify>
  <done>
main has seven new commits on 2bb5a91, in group order, each holding exactly its manifest's paths with content identical to the backup branch.
Every message equals its message file, carries the Claude-Session line and has no Co-Authored-By trailer.
Seven detect-changes files exist in QDIR, and each risk level is recorded.
No code-prefix path and no manifest path is uncommitted, every excluded path is still uncommitted, the scheme matches HEAD, and the guard hashes are unchanged.
origin/main is unchanged, and `261028-tll-SUMMARY.md` is written.
  </done>
</task>

<task type="checkpoint:orchestrator" gate="blocking">
  <name>Task 3 (orchestrator only): baseline build and full suite on the committed tip, then complete the review record</name>
  <what-built>
Tasks 1 and 2: the restored scheme, a fresh GitNexus index, seven group commits on main (not pushed), seven detect-changes reports and the SUMMARY.
The executor stops here.
The /gsd-quick orchestrator runs this task itself, because the test run exceeds a single shell call's 10-minute limit.
This task is never auto-approved.
  </what-built>
  <files>QDIR/261028-tll-BASELINE.md, QDIR/261028-tll-SUMMARY.md, /Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md</files>
  <action>
Executor: do not run any part of this task; stop and return a checkpoint.
Orchestrator: perform the steps below yourself.

Baseline (approved plan Phase 0 step 4, run after the commits).
Running it after the commits is equivalent to running it before them: Task 2 proved the committed content equals the working tree for every code path.
So this one run serves both step 4 and step 5's requirement that the tip builds and matches step 4.
Record failures only, and fix nothing in this task; fixes belong to Phases 1-4 of the approved plan.

1. Preconditions: Task 2's SUMMARY shows every check passed.
`git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` exits 0 (if Xcode rewrote it, restore it as in Task 1 step 3 first).
`pgrep -fl xcodebuild` shows no other run.
2. Prepare the large phone (the exact commands from the brief; `bootstatus -b` only waits until the boot finishes):
`xcrun simctl boot 79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE; xcrun simctl bootstatus 79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE -b; xcrun simctl ui 79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE content_size large; xcrun simctl ui 79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE appearance light`
3. From the repo root, run in the background (it takes longer than 10 minutes), with `set -o pipefail`:
`xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,id=79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE' -derivedDataPath <scratchpad>/dd -parallel-testing-enabled NO -resultBundlePath <scratchpad>/m1-baseline-01.xcresult test CODE_SIGNING_ALLOWED=NO 2>&1 | tee <scratchpad>/m1-baseline-01.log | grep -E "error:|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)"`
The result bundle path must not exist yet; use `m1-baseline-02.xcresult` for a rerun.
4. Collect the evidence.
Get totals and the failure list from `xcrun xcresulttool get test-results summary --path <scratchpad>/m1-baseline-01.xcresult`, and use `get test-results tests` if per-test detail is needed.
Confirm the widget extension built: `ls <scratchpad>/dd/Build/Products/Debug-iphonesimulator/*.app/PlugIns/` lists the FitbodWidgets `.appex`.
Record `xcodebuild -version` and the device's iOS runtime.
5. Write `QDIR/261028-tll-BASELINE.md` with:
the tip hash and subject;
the device name, id and runtime, content size `large` and light appearance;
the Xcode version, the exact commands, and the start time, end time and duration;
the build result for the app and the widget extension;
the totals for tests run, passed, failed, skipped and expected failures;
every failed test with its target, identifier and the first line of its failure;
a comparison with Codex's last full run (1,021 passed, 4 failed, 1 expected failure, per `docs/VERIFICATION.md`), naming the four tests Codex's unverified fixes target and giving each one's result now;
and the scratchpad paths of the result bundle and the full log.
Put one sentence on each line, and use "-", never an em dash.

Review record (approved plan Phase 0 step 6).

6. Copy `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md` to the scratchpad as a backup.
Read how items 1-25 are written, and note the heading pattern each item uses.
Append items 26-47 from Appendix A of the approved plan in that same format, each with its priority, defect, fix and key files.
Use Appendix A's wording verbatim (reformatted only), and invent no detail the table does not contain.
Also carry over Appendix A's "Additions to item 25" bullets and its "These are not bugs" list, because they too exist only in the approved plan.
Put one sentence on each line, and use "-", never an em dash.
The file is outside the repo, so there is nothing to commit.
7. Replace the SUMMARY's "Task 3 pending" line with the baseline headline (build result and totals) and the review-record status.

Do not commit BASELINE.md or the SUMMARY (everything under .planning stays uncommitted), and do not push.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && B=.planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-BASELINE.md && test -s "$B" && rg -q '79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE' "$B" && R=/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md && rg -qF 'builds a blank 0-week block' "$R" && rg -qF 'AVG RPE shows the mean e1RM' "$R" && rg -qF 'SAVE INVENTORY does nothing' "$R" && rg -qF 'may lose its first typed character' "$R" && echo TASK3-OK   # then count the item-heading pattern noted in step 6 for 26..47 and require 22 matches</automated>
  </verify>
  <done>
`261028-tll-BASELINE.md` records the build result for the app and the widget, exact totals, every failure, and the status of Codex's four unverified fixes on the committed tip.
The review record holds items 26-47, the item-25 additions and the not-a-bug list, in the file's existing format.
Nothing is committed under .planning, and nothing is pushed.
  </done>
  <resume-signal>No executor resume is needed: the orchestrator finishes this task and reports to the user.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Working tree to main history | Files written by Codex on 2026-10-05, and possibly by another Claude terminal now, become permanent history. |
| Background hooks to repo | GitNexus and repowise post-commit hooks run while the executor stages and commits. |
| Local main to origin (Phase 8) | Anything committed now is pushed later, and nothing is pushed in this task. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-261028-01 | Tampering | Manifest files changed between review and commit | mitigate | check-group.sh compares the staged content with backup/m1-worktree-20261028 before each commit, step F repeats the check on the committed tree, and pre-flight rechecks all 137 SHA-256 entries |
| T-261028-02 | Tampering | Excluded or unrelated paths entering a commit | mitigate | `--literal-pathspecs` exact staging, staged-name equality for each group, whole-range equality with the 303 manifest paths, and a ban on `-A`, `.`, `-a` and path arguments to commit |
| T-261028-03 | Information disclosure | Secrets or oversized blobs reaching history before the Phase 8 push | mitigate | pre-flight name screen for key, certificate, profile and env files, a 100 MB size gate, and no push in this task |
| T-261028-04 | Repudiation | Provenance of the Codex-prepared groups | mitigate | the commit body names the source and the drift check, detect-changes output is saved for each group, and the SUMMARY records full hashes |
| T-261028-05 | Denial of service | GitNexus lock or .git/index.lock never clearing | mitigate | bounded waits of about 9.5 minutes, one retry for index.lock, lock files are never deleted, and the executor stops and reports |
| T-261028-06 | Tampering | GitNexus analysis rewriting CLAUDE.md, AGENTS.md or skill files | mitigate | `--index-only` only, with guard hashes compared after the refresh and after the last commit |
| T-261028-07 | Tampering | Xcode dropping the scheme attribute again during the run | mitigate | the scheme is rechecked after group 07 and before the Task 3 run |
</threat_model>

<verification>
- `git diff --quiet HEAD -- fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` exits 0.
- `git rev-list --count 2bb5a91..HEAD` prints 7, and `git log --reverse --format=%s 2bb5a91..HEAD` prints the seven subjects in order.
- `git diff --name-only --no-renames 2bb5a91 HEAD` lists exactly the 303 manifest paths.
- No commit message in the range has a Co-Authored-By line, and all seven carry the Claude-Session line.
- `git status --porcelain=v1 --untracked-files=all` lists no code-prefix path and no manifest path.
- Seven detect-changes files exist in QDIR, and the SUMMARY records each risk level and each full commit hash.
- BASELINE.md holds exact totals and every failure for the run on sw6 iPhone 17 Pro Max at default text in light mode.
- The review record holds items 26-47.
- origin/main is unchanged.
</verification>

<success_criteria>
- The serial UI-test setting is back in the scheme, and the scheme is not part of any commit.
- The GitNexus index was fresh before every commit, and no CLAUDE.md, AGENTS.md or skill file was rewritten.
- Seven commits exist with exact paths, unchanged content and exact messages, and nothing else was committed.
- All 847 excluded paths are still uncommitted, and any path that appeared during the run is listed in the SUMMARY.
- The committed tip has a recorded baseline: build result for the app and the widget, exact counts and each failure.
- The review record is complete again.
- Nothing is pushed.
</success_criteria>

<source_audit>
| Source | Item | Covered by |
| --- | --- | --- |
| GOAL | Restore the serial UI-test scheme setting | Task 1 step 3, rechecked in Task 2 and Task 3 |
| GOAL | Refresh GitNexus | Task 1 step 5 |
| GOAL | Baseline build and full suite on the large phone | Task 3 |
| GOAL | Commit Codex's seven prepared groups | Task 1 step 6 (pre-flight) and Task 2 |
| GOAL | Complete the review record | Task 3 step 6 |
| M1-P0-1 | Back up the working tree | Already done (`4cc8d1b`); Task 1 step 1 verifies it and forbids recreating it |
| M1-P0-2 | Restore `parallelizable = "NO"` | Task 1 step 3 |
| M1-P0-3 | Refresh GitNexus | Task 1 step 5, using `gitnexus analyze --index-only` instead of the plan's `npx gitnexus analyze`, because the plain command rewrites CLAUDE.md, AGENTS.md and skill files; the intent (a fresh index) is unchanged |
| M1-P0-4 | Build the app and widget, run the full suite serially on the large phone, record exact counts, first run of Codex's four fixes | Task 3, run after the commits because Task 2 proves the committed code equals the working tree |
| M1-P0-5 | Check manifests against git status and source-hashes.json, commit in order with the commit-plan messages, detect_changes before each, excluded paths stay uncommitted, tip builds | Task 1 step 6, Task 2, Task 3 |
| M1-P0-6 | Add items 26-47 to the review record | Task 3 step 6 |
| Ground rules | Exact paths, no `git add -A`, no Co-Authored-By, Claude-Session line, no push, only the large phone, serial runs | Rules section, Task 2, Task 3 |
| REQ | None: quick task; the M1-P0 IDs map to the approved plan's Phase 0 steps | - |
| RESEARCH | None: no research phase | - |
| CONTEXT | No CONTEXT.md; the approved plan is the decision source | - |

Out of scope here (later phases of the approved plan): defect fixes, the design refresh, doc updates and the push.
Intermediate group commits are not built one by one: commit-plan.md says only the combined tree is tested, and the approved plan requires the tip to build (Task 3).
</source_audit>

<output>
At the end of Task 2, before returning the Task 3 checkpoint, create `.planning/quick/261028-tll-milestone-1-finish-phase-0-restore-the-s/261028-tll-SUMMARY.md` using the summary template's frontmatter.
It must contain:
- Scheme: the restored hunk, and whether Xcode was running.
- GitNexus: the `gitnexus status` wording and the guard-hash result.
- Pre-flight: subjects match, 137 of 137 hashes match, seven of seven groups PASS, the size and name screen results, and the excluded-path count.
- A commit table with one row per group: group, path count, `--shortstat`, full commit hash, risk level, notable affected flows, and the detect file name.
- Final checks: range, messages, scheme, status (with any paths that appeared during the run), guard hashes, origin/main unchanged, and commits ahead of origin/main.
- The line "Task 3 pending (orchestrator): baseline run and review record."
- Deviations (expected: none).
Put one sentence on each line, and use "-", never an em dash.
Do not commit the SUMMARY.
</output>
