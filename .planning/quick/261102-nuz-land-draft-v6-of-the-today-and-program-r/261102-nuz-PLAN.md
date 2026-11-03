---
phase: quick-261102-nuz
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/design-map/redesign/
  - docs/design-map/changelog.md
autonomous: true
requirements:
  - "Land draft v6 of the Today and Program redesign bundle after the Codex feasibility review"
must_haves:
  truths:
    - "docs/design-map/redesign/ equals the draft v6 source bundle byte for byte, apart from the two Codex reports the source does not hold: the 10 changed leaves carry the v6 text; audit.md, open-decisions.md, program-layouts.md, screen_budget.py and every earlier report and brief are unchanged; and round3-codex-coverage.md and round3-codex-feasibility.md keep the SHA-256 hashes the planner recorded."
    - "The map changelog's newest entry is '## 2026-11-02: redesign draft v6', directly above '## 2026-11-02: redesign draft v5', and the edit adds 9 lines and removes none."
    - "screen_budget.py prints 'elements, all states: 222 -> 109 (50% fewer)'."
    - "No 'scratchpad' path and no em dash appear in the bundle, its reviewer reports or the map changelog, and the map checker still reports exactly the nine baseline errors."
    - "The git index holds exactly 12 paths, all modified and all under docs/design-map/: the map changelog, the 10 leaves and the feasibility report; the xcscheme change stays unstaged, .playwright-mcp/ stays untracked, and the executor makes no commit and no push."
  artifacts:
    - path: docs/design-map/redesign/index.md
      provides: "The bundle's index, marked draft v6"
      contains: "Status: draft v6, 2026-11-02"
    - path: docs/design-map/redesign/changelog.md
      provides: "What changed in each leaf for draft v6"
      contains: "## 2026-11-02, draft v6"
    - path: docs/design-map/redesign/review-log.md
      provides: "Each finding and its resolution, with round 3 settled in draft v6"
      contains: "## Round 3 (Codex): settled in draft v6"
    - path: docs/design-map/redesign/screen_budget.py
      provides: "The runnable screen budget, unchanged since draft v4"
    - path: docs/design-map/redesign/reviews/round3-codex-feasibility.md
      provides: "The Codex feasibility review of draft v4 with its draft v5 continuation appended, verbatim"
      contains: "## Draft v5 continuation"
    - path: docs/design-map/redesign/reviews/round3-codex-coverage.md
      provides: "The Codex coverage review of draft v3 with its draft v4 pass, unchanged since HEAD"
      contains: "## Draft v4 pass"
    - path: docs/design-map/changelog.md
      provides: "The map's newest changelog entry"
      contains: "## 2026-11-02: redesign draft v6"
  key_links:
    - from: docs/design-map/changelog.md
      to: docs/design-map/redesign/reviews/
      via: "entry link naming the feasibility report's draft v5 continuation"
      pattern: 'The Codex feasibility report under \[redesign/reviews/\]\(redesign/reviews/\) now carries .*"Draft v5 continuation" section'
    - from: docs/design-map/changelog.md
      to: docs/design-map/redesign/changelog.md
      via: "entry link"
      pattern: '\[redesign/changelog\.md\]\(redesign/changelog\.md\)'
    - from: docs/design-map/changelog.md
      to: docs/design-map/redesign/review-log.md
      via: "entry link"
      pattern: '\[redesign/review-log\.md\]\(redesign/review-log\.md\)'
---

<objective>
Land draft v6 of the Today and Program redesign bundle in `docs/design-map/redesign/`, add its entry to the map changelog, verify the result, and stage it with the Codex feasibility report exactly as the reviewer left it.
Do not commit: the orchestrator runs GitNexus `detect_changes` and then makes the commit.
Purpose: the landed bundle catches up with the revision made after the Codex feasibility reviewer finished its pass on draft v5, which closes round 3 with no open blocker, and the reviewer's "Draft v5 continuation" section is committed with it.
Output: 10 updated leaves, the feasibility report's appended section staged verbatim, one 9-line changelog entry, and a git index of 12 paths, all under `docs/design-map/`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Do not read `./CLAUDE.md` or the bundle's files.
This plan holds every rule and text the task needs.

Project rules for this task (from CLAUDE.md):
- Never write the em dash character; use "-" instead.
  The map checker rejects it everywhere under `docs/design-map/` except `screens/tree/` and `redesign/reviews/`.
- In Markdown, put each full sentence on its own line.
- Never add an agent name or a Co-Authored-By line, and never push.
- `docs/design-map/changelog.md` is hand-written and is the one file to edit.
  `docs/design-map/redesign/changelog.md` is the bundle's own changelog and arrives with the copy; do not edit it.
- Two unrelated changes sit in the working tree and must stay out of the index: `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` (modified) and `.playwright-mcp/` (untracked).
  Stage only the step 7 paths; never run `git add -A` or `git add .`.
- This is a docs-only change; no Xcode build or test run is needed.
- Run both Python scripts, `screen_budget.py` and `check_map.py`, only as `python3 -I`.

Commit override: this plan makes no commit at all, neither per task nor for metadata.
That overrides the executor's usual task-commit protocol; the plan ends with the change staged.

Where to run: the main working tree, `/Users/chrissaechao/Desktop/fitbod`, on branch `main` (the GSD config sets `use_worktrees: false`).
Start every Bash call with `cd /Users/chrissaechao/Desktop/fitbod &&`, because the feasibility report's appended section exists only in this tree.

Paths outside the repo:
- Source bundle: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/`.
  It is draft v6, with 14 top-level files, 7 reports in `reviews/` and 13 briefs in `reviews/specs/`.
- The source has no `reviews/round3-codex-coverage.md` and no `reviews/round3-codex-feasibility.md`.
  Both exist only in the repo, both are tracked, and rsync without `--delete` leaves them in place.
  They are reviewer output: stage the feasibility report exactly as it is, leave the coverage report as it is, and never edit, reformat or restore either one.
- Checker baseline: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt`.

State at HEAD `13a70a34`, checked by the planner on 2026-11-02:
- `git status --short` shows ` M docs/design-map/redesign/reviews/round3-codex-feasibility.md`, ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` and `?? .playwright-mcp/`.
  Nothing is staged.
- A dry run of step 1 (`rsync -a -n -i`, with and without `--checksum`) shows that the 10 leaves differ in content.
  audit.md, open-decisions.md, program-layouts.md, screen_budget.py and every report and brief in the source are identical, and the dry run lists no folder and no mode change.
- The feasibility reviewer appended its `## Draft v5 continuation` section (line 163) to the tracked feasibility report, which now has 348 lines, 185 added and 8 deleted against HEAD.
  The coverage report is unchanged since HEAD and has 398 lines.
- SHA-256 of `reviews/round3-codex-coverage.md`: `a03c5bea755621ab8fdd3147aca0b725a528542d27ef3da2528417e6fd49ceba`.
- SHA-256 of `reviews/round3-codex-feasibility.md`: `57be06b1221ebeae50a1035bbc7b4e4ee4100dd1a8b393aae57c384e2cefd95d`.
- In `docs/design-map/changelog.md`, line 3 is the "Newest first: ..." line, line 4 is blank, line 5 is `## 2026-11-02: redesign draft v5` and line 14 is `## 2026-11-02: redesign draft v4`.
  No other line has the line 5 text, and no line mentions draft v6.

Planner dry run, 2026-11-02: steps 1 to 6 ran on a scratch copy of `docs/`, with the other top-level folders symlinked.
`diff -r` printed exactly the two "Only in" lines for the Codex reports, and the same 10 leaves differed from the working tree.
The changelog diff was 9 added lines and 0 deleted.
The new heading landed on line 5 and the v5 heading on line 14.
Step 3 printed the expected line, and steps 4 and 5 printed nothing (rg exit 1).
Step 6 exited 1, and its output matched the baseline except the `mermaid     18 blocks written to <folder>` line, which names the folder passed to `--mmd-out`.
The checker exits 1 at baseline because of the nine archived-ticket link errors, so exit 1 is expected.
Comparing HEAD's blobs with the scratch copy through `git hash-object`, which writes nothing, predicted the 12 staged paths of step 7, all modified, with no added or deleted file and no mode change.

Two notes on the steps:
- From the repo root, rg anchors the glob `-g '!reviews/**'` to the current folder, so it does not match `docs/design-map/redesign/reviews/`, and steps 4 and 5 scan all 22 files there: 9 reports, both Codex reports included, and 13 briefs.
  That is stricter than intended and still passes, because the dry run found no "scratchpad" and no em dash in any of them, the feasibility report's appended section included.
  Run the commands as written.
  If a hit appears in a file under `redesign/reviews/`, stop and report it; do not edit a report.
- The search pattern in the step 5 command, repeated in Task 2's verify block, is `\x{2014}`, rg's escape for the em dash (U+2014), so this plan never writes the character itself.
  The planner confirmed that the pattern matches a real em dash.

GitNexus: no symbol is edited by hand.
The copy leaves `docs/design-map/redesign/screen_budget.py` unchanged and touches no other code, so this plan runs no `gitnexus_impact`.
The orchestrator runs `gitnexus_detect_changes` before its commit.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Copy the draft v6 bundle and add the map changelog entry</name>
  <files>docs/design-map/redesign/ (10 leaves rewritten by the copy; the two Codex reports left untouched), docs/design-map/changelog.md</files>
  <action>
  Carry out steps 1 and 2 of the `<steps>` block below, in order and exactly as written.
  The step 2 entry lands character for character: do not reword, rewrap or reindent it, and keep the two leading spaces on its one continuation line.
  For step 2, read only lines 1 to 6 of `docs/design-map/changelog.md`.
  Then use the Edit tool with `old_string` set to the line `## 2026-11-02: redesign draft v5`, and `new_string` set to the step 2 entry, one blank line, and that same heading line.
  Change nothing else in that file, and do not edit any copied file or either Codex report.
  If a Task 1 check fails, redo the step that caused it; if the cause is inside a copied file or a Codex report, stop and report it.
  </action>
  <verify>
    <automated>
cd /Users/chrissaechao/Desktop/fitbod
S=/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad
diff -r "$S/redesign" docs/design-map/redesign
git diff --name-only -- docs/design-map/redesign | wc -l
git diff --numstat -- docs/design-map/changelog.md docs/design-map/redesign/reviews/round3-codex-feasibility.md
printf '%s  %s\n' a03c5bea755621ab8fdd3147aca0b725a528542d27ef3da2528417e6fd49ceba docs/design-map/redesign/reviews/round3-codex-coverage.md 57be06b1221ebeae50a1035bbc7b4e4ee4100dd1a8b393aae57c384e2cefd95d docs/design-map/redesign/reviews/round3-codex-feasibility.md | shasum -a 256 -c
sed -n '5p;14p' docs/design-map/changelog.md
    </automated>
  </verify>
  <done>
  `diff -r` prints exactly two lines: `Only in docs/design-map/redesign/reviews: round3-codex-coverage.md` and `Only in docs/design-map/redesign/reviews: round3-codex-feasibility.md`.
  `git diff --name-only` counts 11 changed tracked files under `docs/design-map/redesign/`: the 10 leaves and `reviews/round3-codex-feasibility.md`.
  `git diff --numstat` reports 9 added and 0 deleted lines for `docs/design-map/changelog.md`, and still 185 added and 8 deleted for the feasibility report.
  `shasum -c` prints `OK` for both Codex reports.
  If it prints `FAILED` for either, a report changed after planning: stop and report it, and do not edit or restore the report.
  Line 5 of the map changelog is `## 2026-11-02: redesign draft v6`, and line 14 is `## 2026-11-02: redesign draft v5`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Verify the landed bundle and stage it, without committing</name>
  <files>No file edits; stages docs/design-map/redesign/ and docs/design-map/changelog.md in the git index</files>
  <action>
  Carry out steps 3 to 8 of the `<steps>` block below, in order and exactly as written.
  The verify block runs the step 6 command with its output saved to `nuz-check.txt` in the scratchpad, so that it can be diffed against the baseline.
  If a check in steps 3 to 6 fails, the mistake is in Task 1: fix it there and run the checks again.
  Any new ERROR line is a failure to fix, not to accept.
  If a failure's cause is inside a copied file or a reviewer report, stop and report it instead of editing the file.
  Run the step 7 listing first, then stage with the one step 7 `git add` command and nothing else, then make no commit and no push (step 8).
  In SUMMARY.md, write `commit: by the orchestrator after GitNexus detect_changes` where a commit hash would go, and do not stage SUMMARY.md.
  </action>
  <verify>
    <automated>
cd /Users/chrissaechao/Desktop/fitbod
S=/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad
python3 -I docs/design-map/redesign/screen_budget.py | grep 'elements, all states'
rg -n scratchpad docs/design-map/redesign -g '!reviews/**'; echo "rg exit=$? (want 1)"
rg -n '\x{2014}' docs/design-map/changelog.md docs/design-map/redesign -g '!reviews/**'; echo "rg exit=$? (want 1)"
mkdir -p "$S/mmd-v6" && python3 -I docs/design-map/tools/check_map.py --mmd-out "$S/mmd-v6" > "$S/nuz-check.txt" 2>&1; echo "exit $?"
diff "$S/nuz-check.txt" "$S/check-baseline.txt"
git diff --cached --name-status
git diff --cached --name-only | rg -v '^docs/design-map/'; echo "outside docs/design-map: rg exit=$? (want 1)"
printf '%s  %s\n' a03c5bea755621ab8fdd3147aca0b725a528542d27ef3da2528417e6fd49ceba docs/design-map/redesign/reviews/round3-codex-coverage.md 57be06b1221ebeae50a1035bbc7b4e4ee4100dd1a8b393aae57c384e2cefd95d docs/design-map/redesign/reviews/round3-codex-feasibility.md | shasum -a 256 -c
git status --short
git rev-parse --short HEAD
    </automated>
  </verify>
  <done>
  Step 3 prints `elements, all states: 222 -> 109 (50% fewer)`.
  Both rg checks print no match and `rg exit=1`.
  The checker prints `exit 1`.
  The diff against the baseline shows only line 7, the `mermaid     18 blocks written to` line, whose folder ends in `mmd-v6` instead of `mmd-baseline`.
  So the nine ERROR lines and the final `9 errors, 0 warnings` line match the baseline.
  `git diff --cached --name-status` lists exactly 12 paths, each with `M`: `docs/design-map/changelog.md`, the 10 leaves and `docs/design-map/redesign/reviews/round3-codex-feasibility.md`.
  The outside check prints nothing and `rg exit=1`.
  `shasum -c` prints `OK` for both Codex reports.
  `git status --short` still shows ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` and `?? .playwright-mcp/`.
  Every `docs/design-map/` path in it shows `M` with a blank second column, so the index holds the working-tree version of each staged file.
  It shows no other unstaged or untracked path, except planning files under `.planning/` that the GSD workflow owns.
  `git rev-parse --short HEAD` prints `13a70a34` and the index still holds the 12 paths, which shows that no commit was made, and nothing is pushed.
  </done>
</task>

</tasks>

<steps>
Step 1. Copy the bundle (the source is outside the repo).
Run exactly this command, with no `--delete`:
```
rsync -a /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/ docs/design-map/redesign/
```
It updates 10 files: changelog.md, evaluation.md, functionality-map.md, hierarchy.md, index.md, plan.md, review-log.md, risks.md, today-layouts.md and tradeoffs.md.
audit.md, open-decisions.md, program-layouts.md, screen_budget.py and every report and brief in the source are already identical.
The two Codex reports that exist only in the repo, `reviews/round3-codex-coverage.md` (tracked and unchanged since HEAD) and `reviews/round3-codex-feasibility.md` (tracked, with its appended "Draft v5 continuation" section), stay in place untouched.

Step 2. Edit `docs/design-map/changelog.md`: insert a new entry directly above the existing `## 2026-11-02: redesign draft v5` heading, with one blank line between the new entry and that heading.
Match that entry's bullet format: one sentence per line, continuation lines indented two spaces under their bullet, plain dashes only, never an em dash.
Use this text:
```
## 2026-11-02: redesign draft v6

- [redesign/](redesign/) is revised to draft v6 after the Codex feasibility reviewer finished its pass on draft v5 (0 blockers and 3 fix-soon findings, all closed), which closes round 3 with no open blocker.
  A further adversarial pass waits for the Codex account's weekly limit to reset on 8 Nov.
- The deload-alert setting gate moves into `DeloadAdvisor.evaluate`, `BlockOverviewScreen.nextTrainingDay` moves into `StartSlot` as `nextTrainingDate` with its contract and tests unchanged, and `BlockLifecycleEntryPointsUITests` expects no review notice after its journey closes the review and relaunches.
- The Codex feasibility report under [redesign/reviews/](redesign/reviews/) now carries the reviewer's "Draft v5 continuation" section, as the reviewer wrote it.
- `docs/design-map/redesign/screen_budget.py` still reports 222 -> 109 elements across 17 states.
- What changed in each leaf: [redesign/changelog.md](redesign/changelog.md); each finding and its resolution: [redesign/review-log.md](redesign/review-log.md), round 3.
```

Step 3. This command must print `elements, all states: 222 -> 109 (50% fewer)`:
```
python3 -I docs/design-map/redesign/screen_budget.py | grep 'elements, all states'
```

Step 4. This command must print nothing:
```
rg -n scratchpad docs/design-map/redesign -g '!reviews/**'
```

Step 5. This command must print nothing:
```
rg -n '\x{2014}' docs/design-map/changelog.md docs/design-map/redesign -g '!reviews/**'
```

Step 6. This command must exit 1 and report exactly the 9 pre-existing archived-ticket link errors and nothing else:
```
mkdir -p /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/mmd-v6 && python3 -I docs/design-map/tools/check_map.py --mmd-out /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/mmd-v6; echo "exit $?"
```
Compare its output against the baseline saved at `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt`.
Any new error line is a failure to fix, not to accept.

Step 7. First list what the `git add` below will stage:
```
git status --short --untracked-files=all docs/design-map
```
It must list exactly 12 paths, all ` M`: `docs/design-map/changelog.md`, the 10 leaves and `docs/design-map/redesign/reviews/round3-codex-feasibility.md`.
If it lists any other path, stop and report it.
Then stage these two paths and nothing else:
```
git add docs/design-map/redesign docs/design-map/changelog.md
```
Never stage `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` or `.playwright-mcp/`; both are pre-existing unrelated changes.
`git diff --cached --name-status` must then list 12 `M` lines and nothing else.
`git status --short` must then show those two paths still unstaged and untracked, and the staged set limited to `docs/design-map/`.
HEAD must still be `13a70a34`.

Step 8. Do NOT commit.
The orchestrator runs GitNexus `detect_changes` and then commits with the message `docs(design-map): revise the redesign bundle to draft v6 after the Codex feasibility review`, with no co-author trailer and no push.
The executor's SUMMARY.md records "commit: by the orchestrator after GitNexus detect_changes" instead of a hash.
</steps>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| session scratchpad to repo | The draft v6 bundle is copied from outside the repo into tracked docs. |
| Codex reviewer output to repo | The feasibility report, written by an outside reviewer, is staged verbatim with its appended "Draft v5 continuation" section; the coverage report is already committed and stays as it is. |
| working tree to index | Two unrelated local changes sit beside this change. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-nuz-01 | Information disclosure | docs/design-map/redesign/ | mitigate | Step 4's `rg -n scratchpad` proves no session path lands. Its glob does not exclude `reviews/`, so the reports are scanned too, and `diff -r` proves the leaves match the source byte for byte. |
| T-nuz-02 | Information disclosure | reviews/round3-codex-coverage.md, whose line 11 names the absolute repo path under /Users/chrissaechao | accept | That line is already committed at HEAD, where fifteen files under redesign/ name the same path, all of them reports and briefs under reviews/, and every commit carries the author's name. This change leaves the coverage report untouched, and the copy adds no file that names the path. The feasibility report, its appended section included, names no absolute path, and neither the orchestrator's scan nor the planner's found a secret, token or email address in it. |
| T-nuz-03 | Information disclosure | .playwright-mcp/ (untracked, may hold browser session data) | mitigate | Step 7 lists what it will stage, stages two explicit paths and never runs `git add -A` or `git add .`; `git diff --cached --name-only` must list only docs/design-map/ paths. |
| T-nuz-04 | Tampering | screen_budget.py and check_map.py, run on the dev machine | mitigate | Run both only as `python3 -I`, which ignores Python environment variables and does not import from the script's folder. The budget script is unchanged since HEAD, and `diff -r` proves the landed copy equals the source file. |
| T-nuz-05 | Tampering | the existing skip of redesign/reviews/ in check_map.py | accept | The skip predates this change (12ea884a) and covers only reviewer text kept verbatim; steps 4 and 5 still scan the reports. |
| T-nuz-06 | Tampering | the two Codex reports, which the source does not hold, so `diff -r` cannot vouch for them | mitigate | Both tasks' `shasum -c` checks prove the reports match the hashes the planner recorded, and the plan forbids editing or restoring them. |
</threat_model>

<verification>
- Task 1's checks hold: the copy matches the source, 11 tracked files under `redesign/` changed (the 10 leaves and the feasibility report), both Codex reports pass the hash check, and the map changelog gained 9 lines and lost none.
- Task 2's checks hold: steps 3 to 6 pass, the index holds the 12 paths under `docs/design-map/`, the two unrelated paths stay out, HEAD is still `13a70a34`, and nothing is committed or pushed.
- Source coverage: steps 1 and 2 are Task 1, and steps 3 to 8 are Task 2.
  No step is left out, and none is added.
</verification>

<success_criteria>
The working tree's `docs/design-map/redesign/` is draft v6 byte for byte, plus the two Codex reports exactly as the reviewers left them, and the map changelog opens with the draft v6 entry.
The map checker still reports only the nine baseline errors.
Exactly 12 paths under `docs/design-map/` are staged, nothing else is staged, and the executor makes no commit and no push.
</success_criteria>

<output>
Write `261102-nuz-SUMMARY.md` beside this plan when done.
Where a commit hash would go, record `commit: by the orchestrator after GitNexus detect_changes`.
Do not stage the summary; the orchestrator's docs commit handles planning files.
</output>
