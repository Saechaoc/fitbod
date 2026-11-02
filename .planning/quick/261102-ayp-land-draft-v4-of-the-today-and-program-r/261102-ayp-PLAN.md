---
phase: quick-261102-ayp
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/design-map/redesign/
  - docs/design-map/changelog.md
autonomous: true
requirements:
  - "Land draft v4 of the Today and Program redesign bundle in docs/design-map/redesign"
must_haves:
  truths:
    - "docs/design-map/redesign/ equals the draft v4 source bundle byte for byte: the 14 top-level leaves carry the v4 text, every earlier report and brief is unchanged, and the untracked round3-codex-coverage.md report stays in reviews/ beside round3-codex-experience.md."
    - "The map changelog's newest entry is '## 2026-11-02: redesign draft v4', directly above '## 2026-11-01: Today and Program redesign', and the edit adds 8 lines and removes none."
    - "screen_budget.py prints 'elements, all states: 222 -> 109 (50% fewer)'."
    - "No 'scratchpad' path and no em dash appear in the bundle or the map changelog, and the map checker still reports exactly the nine baseline errors."
    - "The git index holds exactly 17 paths, all under docs/design-map/; the xcscheme change stays unstaged, .playwright-mcp/ stays untracked, and the executor makes no commit and no push."
  artifacts:
    - path: docs/design-map/redesign/index.md
      provides: "The bundle's index, marked draft v4"
      contains: "Status: draft v4, 2026-11-02"
    - path: docs/design-map/redesign/changelog.md
      provides: "What changed in each leaf for draft v4"
      contains: "## 2026-11-02, draft v4"
    - path: docs/design-map/redesign/review-log.md
      provides: "Each round 3 finding and its resolution"
      contains: "## Round 3 (Codex): settled in draft v4"
    - path: docs/design-map/redesign/screen_budget.py
      provides: "The runnable screen budget for draft v4"
    - path: docs/design-map/redesign/reviews/round3-codex-experience.md
      provides: "The Codex experience review of draft v3, verbatim"
      contains: "# Round 3 Codex experience review"
    - path: docs/design-map/redesign/reviews/round3-codex-coverage.md
      provides: "The partial Codex coverage review of draft v3, verbatim"
      contains: "# Round 3 coverage and factual accuracy review"
    - path: docs/design-map/changelog.md
      provides: "The map's newest changelog entry"
      contains: "## 2026-11-02: redesign draft v4"
  key_links:
    - from: docs/design-map/changelog.md
      to: docs/design-map/redesign/reviews/
      via: "entry link naming the two Codex reports"
      pattern: 'under \[redesign/reviews/\]\(redesign/reviews/\) as round3-codex-experience\.md and round3-codex-coverage\.md'
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
Land draft v4 of the Today and Program redesign bundle in `docs/design-map/redesign/`, add its entry to the map changelog, verify the result, and stage it.
Do not commit: the orchestrator runs GitNexus `detect_changes` and then makes the commit.
Purpose: the landed bundle catches up with the revision made after round 3's Codex reviews, and the two Codex reports join the earlier reports under `reviews/`.
Output: 14 updated leaves, 2 newly staged reports, one 8-line changelog entry, and a git index limited to `docs/design-map/`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Do not read `./CLAUDE.md` or the bundle's files.
This plan holds every rule and text the task needs.

Project rules for this task (from CLAUDE.md):
- Never write the em dash character; use "-" instead. The map checker rejects it everywhere under `docs/design-map/` except `screens/tree/` and `redesign/reviews/`.
- In Markdown, put each full sentence on its own line.
- Never add an agent name or a Co-Authored-By line, and never push.
- `docs/design-map/changelog.md` is hand-written and is the one file to edit. `docs/design-map/redesign/changelog.md` is the bundle's own changelog and arrives with the copy; do not edit it.
- Two unrelated changes sit in the working tree and must stay out of the index: `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` (modified) and `.playwright-mcp/` (untracked). Stage only the step 7 paths; never run `git add -A` or `git add .`.
- This is a docs-only change; no Xcode build or test run is needed.

Commit override: this plan makes no commit at all, neither per task nor for metadata.
That overrides the executor's usual task-commit protocol; the plan ends with the change staged.

Where to run: the main working tree, `/Users/chrissaechao/Desktop/fitbod`, on branch `main` (the GSD config sets `use_worktrees: false`).
Start every Bash call with `cd /Users/chrissaechao/Desktop/fitbod &&`, because the two untracked Codex reports exist only in this tree.

Paths outside the repo:
- Source bundle: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/`. It is draft v4, with 14 top-level files, 7 reports in `reviews/` and 13 briefs in `reviews/specs/`.
- The source has no `reviews/round3-codex-coverage.md`. That report exists only in the repo, untracked, and rsync without `--delete` leaves it in place.
- Checker baseline: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt`.

State at HEAD `64f7d7a0`, checked by the planner on 2026-11-02:
- `git status --short` shows ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme`, `?? .playwright-mcp/`, `?? docs/design-map/redesign/reviews/round3-codex-coverage.md` and `?? docs/design-map/redesign/reviews/round3-codex-experience.md`. Nothing is staged.
- A checksum dry run of step 1 shows that the 14 leaves differ in content and `reviews/round3-codex-experience.md` differs only in its timestamp. Every other report and brief is identical, and no file mode changes.
- In `docs/design-map/changelog.md`, line 3 is the "Newest first: ..." line, line 4 is blank, and line 5 is `## 2026-11-01: Today and Program redesign`. No other line has that text.

Planner dry run, 2026-11-02: steps 1 to 6 ran on a scratch copy of `docs/`, with the other top-level folders symlinked.
The copy matched the source byte for byte, and the changelog diff was 8 added lines and 0 deleted.
Step 3 printed the expected line, and steps 4 and 5 printed nothing (rg exit 1).
Step 6 exited 1, and its output matched the baseline except the `mermaid     18 blocks written to <folder>` line, which names the folder passed to `--mmd-out`.
The checker exits 1 at baseline because of the nine archived-ticket link errors, so exit 1 is expected.

Two notes on the steps:
- From the repo root, rg anchors the glob `-g '!reviews/**'` to the current folder, so it does not match `docs/design-map/redesign/reviews/`, and steps 4 and 5 scan the reviewer reports too.
  That is stricter than intended and still passes, because the dry run found no "scratchpad" and no em dash in any report.
  Run the commands as written. If a hit appears in a file under `redesign/reviews/`, stop and report it; do not edit a report.
- The search pattern in the step 5 command, repeated in Task 2's verify block, is the em dash character itself (U+2014); those two commands are the only places it appears in this plan.

GitNexus: no symbol is edited by hand.
The copy replaces `docs/design-map/redesign/screen_budget.py`, a standalone script that nothing imports or runs, so this plan runs no `gitnexus_impact`.
The orchestrator runs `gitnexus_detect_changes` before its commit.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Copy the draft v4 bundle and add the map changelog entry</name>
  <files>docs/design-map/redesign/ (14 leaves rewritten by the copy; reviews/round3-codex-experience.md re-copied with identical content), docs/design-map/changelog.md</files>
  <action>
  Carry out steps 1 and 2 of the `<steps>` block below, in order and exactly as written.
  The step 2 entry lands character for character: do not reword, rewrap or reindent it, and keep the two leading spaces on its one continuation line.
  For step 2, read only lines 1 to 6 of `docs/design-map/changelog.md`.
  Then use the Edit tool with `old_string` set to the line `## 2026-11-01: Today and Program redesign`, and `new_string` set to the step 2 entry, one blank line, and that same heading line.
  Change nothing else in that file, and do not edit any copied file.
  If a Task 1 check fails, redo the step that caused it; if the cause is inside a copied file, stop and report it.
  </action>
  <verify>
    <automated>
cd /Users/chrissaechao/Desktop/fitbod
S=/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad
diff -r "$S/redesign" docs/design-map/redesign
git diff --name-only -- docs/design-map/redesign | wc -l
git diff --numstat -- docs/design-map/changelog.md
sed -n '5p;13p' docs/design-map/changelog.md
    </automated>
  </verify>
  <done>
  `diff -r` prints exactly one line: `Only in docs/design-map/redesign/reviews: round3-codex-coverage.md`.
  `git diff --name-only` counts 14 changed tracked files under `docs/design-map/redesign/`.
  `git diff --numstat` reports 8 added and 0 deleted lines for `docs/design-map/changelog.md`.
  Line 5 of the map changelog is `## 2026-11-02: redesign draft v4`, and line 13 is `## 2026-11-01: Today and Program redesign`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Verify the landed bundle and stage it, without committing</name>
  <files>No file edits; stages docs/design-map/redesign/ and docs/design-map/changelog.md in the git index</files>
  <action>
  Carry out steps 3 to 8 of the `<steps>` block below, in order and exactly as written.
  The verify block runs the step 6 command with its output saved to `ayp-check.txt` in the scratchpad, so that it can be diffed against the baseline.
  If a check in steps 3 to 6 fails, the mistake is in Task 1: fix it there and run the checks again. Any new ERROR line is a failure to fix, not to accept.
  If a failure's cause is inside a copied file or a reviewer report, stop and report it instead of editing the file.
  Stage with the one step 7 command and nothing else, then make no commit and no push (step 8).
  In SUMMARY.md, write `commit: by the orchestrator after GitNexus detect_changes` where a commit hash would go, and do not stage SUMMARY.md.
  </action>
  <verify>
    <automated>
cd /Users/chrissaechao/Desktop/fitbod
S=/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad
python3 -I docs/design-map/redesign/screen_budget.py | grep 'elements, all states'
rg -n scratchpad docs/design-map/redesign -g '!reviews/**'; echo "rg exit=$? (want 1)"
rg -n '—' docs/design-map/changelog.md docs/design-map/redesign -g '!reviews/**'; echo "rg exit=$? (want 1)"
mkdir -p "$S/mmd-v4" && python3 -I docs/design-map/tools/check_map.py --mmd-out "$S/mmd-v4" > "$S/ayp-check.txt" 2>&1; echo "exit $?"
diff "$S/ayp-check.txt" "$S/check-baseline.txt"
git diff --cached --name-status
git diff --cached --name-only | rg -v '^docs/design-map/'; echo "outside docs/design-map: rg exit=$? (want 1)"
git status --short
    </automated>
  </verify>
  <done>
  Step 3 prints `elements, all states: 222 -> 109 (50% fewer)`.
  Both rg checks print no match and `rg exit=1`.
  The checker prints `exit 1`.
  The diff against the baseline shows only line 7, the `mermaid     18 blocks written to` line, whose folder ends in `mmd-v4` instead of `mmd-baseline`. So the nine ERROR lines and the final `9 errors, 0 warnings` line match the baseline.
  `git diff --cached --name-status` lists exactly 17 paths: `M` for `docs/design-map/changelog.md` and the 14 leaves, and `A` for `docs/design-map/redesign/reviews/round3-codex-coverage.md` and `docs/design-map/redesign/reviews/round3-codex-experience.md`.
  The outside check prints nothing and `rg exit=1`.
  `git status --short` still shows ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` and `?? .playwright-mcp/`. It shows no other unstaged or untracked path, except planning files under `.planning/` that the GSD workflow owns.
  The index still holds the 17 paths, which shows that no commit was made, and nothing is pushed.
  </done>
</task>

</tasks>

<steps>
Step 1. Copy the bundle (the source is outside the repo). Run exactly this command, with no `--delete`:
```
rsync -a /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/ docs/design-map/redesign/
```
It updates 14 files (audit.md, changelog.md, evaluation.md, functionality-map.md, hierarchy.md, index.md, open-decisions.md, plan.md, program-layouts.md, review-log.md, risks.md, screen_budget.py, today-layouts.md, tradeoffs.md) and touches `reviews/round3-codex-experience.md` with identical content.
The two untracked Codex reports under `reviews/` stay in place.

Step 2. Edit `docs/design-map/changelog.md`: insert a new entry directly above the existing `## 2026-11-01: Today and Program redesign` heading, with one blank line between the new entry and that heading.
Match that entry's bullet format: one sentence per line, continuation lines indented two spaces under their bullet, plain dashes only, never an em dash.
Use this text:
```
## 2026-11-02: redesign draft v4

- [redesign/](redesign/) is revised to draft v4 after round 3's Codex experience review of draft v3 (4 blockers and 10 fix-soon findings, all closed or accepted) and the partial Codex coverage review (2 blockers and 7 fix-soon findings, folded in as far as the report goes).
  The Codex feasibility review has not run, and the coverage reviewer stopped at the account's usage limit with its "Not reached" list open.
- The two Codex reports land under [redesign/reviews/](redesign/reviews/) as round3-codex-experience.md and round3-codex-coverage.md.
- `docs/design-map/redesign/screen_budget.py` now reports 222 -> 109 elements across 17 states; the two accepted over-budget states are unchanged.
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
rg -n '—' docs/design-map/changelog.md docs/design-map/redesign -g '!reviews/**'
```

Step 6. This command must exit 1 and report exactly the 9 pre-existing archived-ticket link errors and nothing else:
```
mkdir -p /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/mmd-v4 && python3 -I docs/design-map/tools/check_map.py --mmd-out /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/mmd-v4; echo "exit $?"
```
Compare its output against the baseline saved at `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt`.
Any new error line is a failure to fix, not to accept.

Step 7. Stage these two paths and nothing else:
```
git add docs/design-map/redesign docs/design-map/changelog.md
```
Never stage `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` or `.playwright-mcp/`; both are pre-existing unrelated changes.
`git status --short` must then show those two paths still unstaged and untracked, and the staged set limited to `docs/design-map/`.

Step 8. Do NOT commit.
The orchestrator runs GitNexus `detect_changes` and then commits with the message `docs(design-map): revise the redesign bundle to draft v4 after the Codex reviews`, with no co-author trailer and no push.
The executor's SUMMARY.md records "commit: by the orchestrator after GitNexus detect_changes" instead of a hash.
</steps>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| session scratchpad to repo | The draft v4 bundle is copied from outside the repo into tracked docs. |
| Codex reviewer output to repo | Two reports written by an outside reviewer are staged verbatim. |
| working tree to index | Two unrelated local changes sit beside this change. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ayp-01 | Information disclosure | docs/design-map/redesign/ | mitigate | Step 4's `rg -n scratchpad` proves no session path lands. Its glob does not exclude `reviews/`, so the reports are scanned too, and `diff -r` proves the leaves match the source byte for byte. |
| T-ayp-02 | Information disclosure | reviews/round3-codex-coverage.md, whose line 7 names the absolute repo path under /Users/chrissaechao | accept | Fourteen files already committed under redesign/ name the same path, and every commit carries the author's name. The planner's scan found no secret, token or email address in either report. |
| T-ayp-03 | Information disclosure | .playwright-mcp/ (untracked, may hold browser session data) | mitigate | Step 7 stages two explicit paths and never runs `git add -A` or `git add .`; `git diff --cached --name-only` must list only docs/design-map/ paths. |
| T-ayp-04 | Tampering | screen_budget.py and check_map.py, run on the dev machine | mitigate | Run both only as `python3 -I`, which ignores Python environment variables and does not import from the script's folder. The budget script comes from this session's own scratchpad, and `diff -r` proves the landed copy is that file. |
| T-ayp-05 | Tampering | the existing skip of redesign/reviews/ in check_map.py | accept | The skip predates this change (12ea884a) and covers only reviewer text kept verbatim; steps 4 and 5 still scan the reports. |
</threat_model>

<verification>
- Task 1's checks hold: the copy matches the source, 14 tracked leaves changed, and the map changelog gained 8 lines and lost none.
- Task 2's checks hold: steps 3 to 6 pass, the index holds the 17 paths under `docs/design-map/`, the two unrelated paths stay out, and nothing is committed or pushed.
- Source coverage: steps 1 and 2 are Task 1, and steps 3 to 8 are Task 2. No step is left out, and none is added.
</verification>

<success_criteria>
The working tree's `docs/design-map/redesign/` is draft v4 byte for byte, plus the untracked coverage report, and the map changelog opens with the 2026-11-02 entry.
The map checker still reports only the nine baseline errors.
Exactly 17 paths under `docs/design-map/` are staged, nothing else is staged, and the executor makes no commit and no push.
</success_criteria>

<output>
Write `261102-ayp-SUMMARY.md` beside this plan when done.
Where a commit hash would go, record `commit: by the orchestrator after GitNexus detect_changes`.
Do not stage the summary; the orchestrator's docs commit handles planning files.
</output>
