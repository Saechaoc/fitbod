---
phase: quick-261101-ujp
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/design-map/redesign/
  - docs/design-map/tools/check_map.py
  - docs/design-map/README.md
  - docs/design-map/changelog.md
  - docs/design-map/decisions.md
  - docs/ROADMAP.md
autonomous: true
requirements:
  - "Land the Today and Program redesign bundle in docs/design-map/redesign"
must_haves:
  truths:
    - "docs/design-map/redesign/ holds the 33 bundle files (14 at the top, 6 reports in reviews/, 13 briefs in reviews/specs/), byte-identical to the source bundle."
    - "The design map's README, changelog and decisions link redesign/, and docs/ROADMAP.md lists the bundle's 14 open product calls."
    - "The map checker skips only redesign/reviews/ and still reports exactly the nine baseline errors, so the rest of the bundle passes the em dash, table and link checks."
    - "screen_budget.py runs from its new place and reports 199 -> 100 elements."
    - "One commit holds exactly the six intended paths, with the step 8 message and no trailer; the xcscheme change and .playwright-mcp/ stay out of it, and nothing is pushed."
  artifacts:
    - path: docs/design-map/redesign/index.md
      provides: "The bundle's index page"
    - path: docs/design-map/redesign/open-decisions.md
      provides: "The 14 product calls the ROADMAP bullet points to"
    - path: docs/design-map/redesign/screen_budget.py
      provides: "The runnable screen budget"
    - path: docs/design-map/tools/check_map.py
      provides: "Text checks that skip the verbatim reviewer reports"
      contains: 'MAP / "redesign" / "reviews"'
    - path: docs/design-map/README.md
      provides: "The map's table row for redesign/"
      contains: '| [redesign/](redesign/) |'
    - path: docs/design-map/changelog.md
      provides: "The newest changelog entry"
      contains: '## 2026-11-01: Today and Program redesign'
    - path: docs/design-map/decisions.md
      provides: "The note on D-159 and D-341"
      contains: 'The Today and Program redesign in [redesign/](redesign/) plans the first rebuild.'
    - path: docs/ROADMAP.md
      provides: "The redesign's open decisions in the product-direction list"
      contains: '- **Today and Program redesign:**'
  key_links:
    - from: docs/design-map/README.md
      to: docs/design-map/redesign/
      via: "table row link"
      pattern: '\[redesign/\]\(redesign/\)'
    - from: docs/design-map/changelog.md
      to: docs/design-map/redesign/reviews/
      via: "changelog entry link"
      pattern: '\(redesign/reviews/\)'
    - from: docs/design-map/decisions.md
      to: docs/design-map/redesign/
      via: "paragraph link"
      pattern: '\[redesign/\]\(redesign/\)'
    - from: docs/ROADMAP.md
      to: docs/design-map/redesign/open-decisions.md
      via: "code path in the product-direction list"
      pattern: 'docs/design-map/redesign/open-decisions\.md'
    - from: docs/design-map/tools/check_map.py
      to: docs/design-map/redesign/reviews/
      via: "skip in check_text_files"
      pattern: 'MAP / "redesign" / "reviews"'
---

<objective>
Land the finished Today and Program redesign bundle in `docs/design-map/redesign/`, link it from the design map and the roadmap, and commit it as one docs-only commit.
Purpose: the redesign joins the map that feeds the Milestone 2 design, and its 14 open product calls appear in the roadmap list where the user settles product questions.
Output: 33 copied files, five small additions to existing files and one commit.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
Do not read `./CLAUDE.md` or the bundle's files.
This plan holds every rule and text the task needs.

Project rules for this task (from CLAUDE.md):
- Never write the em dash character; use "-" instead. The map's checker rejects any em dash under docs/design-map.
- In Markdown, put each full sentence on its own line.
- Commit messages never carry a Co-Authored-By trailer or any agent name.
- Never push.
- Two unrelated changes already sit in the working tree and must NOT be staged or committed: `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` (modified) and `.playwright-mcp/` (untracked). Stage explicit paths only; never `git add -A` or `git add .`.
- This is a docs-only change; no Xcode build or test run is needed.

Paths outside the repo:
- Source bundle: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/` (33 files).
- Checker baseline: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt`.

Where the anchors sit at HEAD `0ef702ea` (read only these ranges):

| File | Lines | What is there |
|---|---|---|
| `docs/design-map/tools/check_map.py` | 507-508 | the `screens/tree` skip inside `check_text_files` |
| `docs/design-map/README.md` | 19-20 | the `decisions.md` row, then the `tools/` row |
| `docs/design-map/changelog.md` | 3-5 | the "Newest first" line, a blank line, then `## 2026-11-01: review decisions` |
| `docs/design-map/decisions.md` | 41-43 | the `- **Polish later (144):**` bullet, a blank line, then `## Pattern fixes` |
| `docs/ROADMAP.md` | 62-69 | the "Frozen prescription versus live WHY" bullet (its last line, 67, ends "is a schema change."), a blank line, then `## Release checks and remaining surfaces` |

Planner dry run, 2026-11-01: steps 1 to 7 ran on a scratch copy of the repo.
Every anchor in steps 2 to 6 occurs exactly once, and every edit only adds lines: check_map.py 2, README.md 1, changelog.md 9, decisions.md 4, ROADMAP.md 3.
The copy was byte-identical to the source, the budget script exited 0, `rg` found no "scratchpad", and the checker printed the nine baseline ERROR lines and nothing new.
The checker exits 1 at baseline because of those nine errors, so exit 1 is expected.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Copy the redesign bundle, link it from the map and the roadmap, verify and commit</name>
  <files>docs/design-map/redesign/ (33 new files, copied verbatim), docs/design-map/tools/check_map.py, docs/design-map/README.md, docs/design-map/changelog.md, docs/design-map/decisions.md, docs/ROADMAP.md</files>
  <action>
  Run every command from the repo root, `/Users/chrissaechao/Desktop/fitbod`.
  Carry out steps 1 to 8 in the `<steps>` block below, in order and exactly as written.
  The texts in its code blocks land in the repo character for character: do not reword, rewrap or reindent them.
  Steps 2 to 6 only add lines next to the named anchors; read just the ranges in the context table, then insert with the Edit tool.
  Do not edit any copied file, and change nothing else in the five edited files.
  Before step 2, if the GitNexus MCP tools are available, run `gitnexus_impact` with target `check_text_files` and direction `upstream`, because CLAUDE.md requires impact analysis before a symbol edit.
  A search found one caller, `check()` at line 551 of the same file, and the edit only adds a skip, so expect LOW risk.
  Before step 8, run `gitnexus_detect_changes` if it is available; it should show no symbol change beyond `check_text_files`.
  If the GitNexus tools are not available, say so in the summary.
  If a step 7 check fails, the mistake is in steps 1 to 6: fix it there and run step 7 again.
  If a check still fails and the cause is inside a copied file, stop and report it instead of editing the file.
  Commit on the current branch, `main`.
  </action>
  <steps>
Step 1. Copy the bundle verbatim (the source is outside the repo):
```
rsync -a /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/redesign/ docs/design-map/redesign/
```
Expected result: `docs/design-map/redesign/` holds 14 files (audit.md, changelog.md, evaluation.md, functionality-map.md, hierarchy.md, index.md, open-decisions.md, plan.md, program-layouts.md, review-log.md, risks.md, screen_budget.py, today-layouts.md, tradeoffs.md), `reviews/` with six round1-claude-*.md and round2-claude-*.md reports, and `reviews/specs/` with 13 briefs. Do not edit any copied file.

Step 2. `docs/design-map/tools/check_map.py`, inside `check_text_files` (around line 507): directly after the existing two lines
```
        if path.is_relative_to(MAP / "screens" / "tree"):
            continue  # the app's own text, copied as the app shows it
```
add
```
        if path.is_relative_to(MAP / "redesign" / "reviews"):
            continue  # the reviewers' reports and briefs, kept verbatim
```
Nothing else in that file changes.

Step 3. `docs/design-map/README.md`: insert this row directly after the row that starts with `| [decisions.md](decisions.md) |`:
```
| [redesign/](redesign/) | the Today and Program redesign: audit, hierarchy, layouts for every state, a map of every capability to its new place, a phased plan, and its adversarial reviews |
```

Step 4. `docs/design-map/changelog.md`: insert this entry after the intro line "Newest first: ..." and its blank line, so it becomes the first entry, above "## 2026-11-01: review decisions" (keep one blank line before and after):
```
## 2026-11-01: Today and Program redesign

- Added [redesign/](redesign/), the Today and Program redesign: a screenshot audit, a hierarchy for both screens, layouts for every state, a map of every capability to its new place, a three-phase plan, and a runnable screen budget.
  It builds on this map's audit rows, its patterns and the stages in [decisions.md](decisions.md).
- Two Claude review rounds (coverage, experience and feasibility lenses) closed seven blockers; the reports and the briefs are under [redesign/reviews/](redesign/reviews/).
  The Codex round was attempted three times and stopped at the account's usage limit each time, so no reviewer has checked draft v3 itself.
- The plan's Phase 1 replaces the elements behind D-159 (When stable) and D-341 (Polish later), so the stage of those two rows is a question for the user; the stage lists are unchanged.
- The map's text checks now skip [redesign/reviews/](redesign/reviews/), which holds the reviewers' reports and briefs verbatim.
```

Step 5. `docs/design-map/decisions.md`: insert this paragraph after the bullet that starts with `- **Polish later (144):**` and before the heading `## Pattern fixes` (one blank line on each side):
```
The Today and Program redesign in [redesign/](redesign/) plans the first rebuild.
Its Phase 1 covers the Today and Program rows staged "With the redesign", and it also replaces the elements behind D-159 (When stable) and D-341 (Polish later): Today's block band and stat strip.
Those two rows change stage only when the user confirms, because this file records the user's review; the lists above are unchanged.
```

Step 6. `docs/ROADMAP.md`: append this bullet as the last bullet of the "## Decisions awaiting product direction" list, directly after the "Frozen prescription versus live WHY" bullet and before the blank line that precedes "## Release checks and remaining surfaces" (wrap at about 80 columns like its neighbours):
```
- **Today and Program redesign:** `docs/design-map/redesign/open-decisions.md`
  lists 14 product calls, each with the default the layouts assume. The plan
  there starts once they are confirmed or changed.
```

Step 7. Verify, all four must hold:
- `python3 -I docs/design-map/redesign/screen_budget.py` exits 0 and its output contains "199 -> 100".
  - Planner note: the script prints an ASCII arrow, in the line `elements, all states: 199 -> 100 (49% fewer)`, so match `->`.
- `rg -n scratchpad docs/design-map/redesign` prints nothing (exit code 1).
- `python3 -I docs/design-map/tools/check_map.py --mmd-out "$(mktemp -d)"` ends with "9 errors, 0 warnings" and every ERROR line is one of the nine pre-existing archived-ticket link errors (assumptions.md, audit.md and missing-screens.md linking ../conway-specs/tickets/T118, T122, T40, T41, T39). The baseline output is saved at /private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad/check-baseline.txt; the ERROR lines must match it exactly (compare with `grep '^ERROR'` on both). Any new ERROR line means a mistake in steps 1-6; fix it and re-run.
  - Planner note: the checker exits 1 because of those nine errors; that is the baseline, not a failure.
- `git status --short` shows only the intended paths plus the two pre-existing unrelated entries.
  - Planner note: the intended paths show as ` M` for the five edited files and `?? docs/design-map/redesign/`. This quick task's own folder under `.planning/quick/` and `.planning/STATE.md` may also show; the GSD workflow owns them, so leave them out of the step 8 commit.

Step 8. Commit exactly these paths and nothing else:
```
git add docs/design-map/redesign docs/design-map/tools/check_map.py docs/design-map/README.md docs/design-map/changelog.md docs/design-map/decisions.md docs/ROADMAP.md
git commit -m "docs(design-map): land the Today and Program redesign bundle" -m "Audit, hierarchy, layouts, functionality map, phased plan, tradeoffs, risks, open decisions, screen budget and the adversarial review reports and briefs, under docs/design-map/redesign. The map's README, changelog and decisions link it, the roadmap lists its open decisions, and the map's checker skips the verbatim reviewer reports."
```
No Co-Authored-By trailer. No push.
  </steps>
  <verify>
    <automated>
S=/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/c8a88e9e-42ab-499c-9486-051f4a4b0c7a/scratchpad
diff -r "$S/redesign" docs/design-map/redesign && echo COPY-IDENTICAL
python3 -I docs/design-map/redesign/screen_budget.py > "$S/ujp-budget.txt"; echo "budget exit=$?"; grep -F -- '199 -> 100' "$S/ujp-budget.txt"
rg -n scratchpad docs/design-map/redesign; echo "rg exit=$? (want 1)"
python3 -I docs/design-map/tools/check_map.py --mmd-out "$(mktemp -d)" > "$S/ujp-check.txt" 2>&1; tail -1 "$S/ujp-check.txt"
diff <(grep '^ERROR' "$S/ujp-check.txt") <(grep '^ERROR' "$S/check-baseline.txt") && echo ERRORS-MATCH-BASELINE
git status --short
    </automated>
  </verify>
  <done>
  Before the commit, the verify block prints COPY-IDENTICAL, `budget exit=0` with the line `elements, all states: 199 -> 100 (49% fewer)`, `rg exit=1`, `9 errors, 0 warnings` and ERRORS-MATCH-BASELINE.
  After the commit, `git show --stat --format= HEAD` lists 38 files: the 33 under `docs/design-map/redesign/` and the five edited files.
  In `git show --numstat --format= HEAD`, the five edited files show 0 deleted lines and these added lines: check_map.py 2, README.md 1, changelog.md 9, decisions.md 4, ROADMAP.md 3.
  `git log -1 --format=%B` prints exactly the step 8 subject, a blank line and the body, with no trailer lines.
  `git status --short` still lists ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` and `?? .playwright-mcp/`, lists nothing under `docs/`, and lists no other path except planning files the GSD workflow owns.
  Nothing is pushed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| session scratchpad to repo | The bundle is copied from outside the repo into committed docs. |
| working tree to commit | Two unrelated local changes sit beside this change. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ujp-01 | Information disclosure | docs/design-map/redesign/ | mitigate | Step 7's `rg -n scratchpad` gate proves no session path is committed, and the `diff -r` check proves the commit holds the bundle byte for byte. |
| T-ujp-02 | Information disclosure | .playwright-mcp/ (untracked, may hold browser session data) | mitigate | Step 8 stages six explicit paths only, never `git add -A` or `git add .`; `git status --short` after the commit still lists it as untracked. |
| T-ujp-03 | Tampering | docs/design-map/redesign/screen_budget.py, run on the dev machine | mitigate | Run it only as `python3 -I`, which ignores Python environment variables and imports nothing from the script's folder; the script comes from this session's own scratchpad. |
| T-ujp-04 | Tampering | the skip in check_text_files, docs/design-map/tools/check_map.py | accept | The skip covers only redesign/reviews/, which holds reviewer text kept verbatim; the rest of redesign/ stays under every text check, and the dry run found no new error. |
</threat_model>

<verification>
- Step 7's four checks hold before the commit (the verify block above).
- The commit holds 38 files, the five edited files show only added lines, and its message has no trailer.
- `fitbod.xcscheme` and `.playwright-mcp/` stay out of the commit, and nothing is pushed.
</verification>

<success_criteria>
One new commit on `main` holds the 33 bundle files under `docs/design-map/redesign/`, byte for byte, plus the five additions in `check_map.py`, the map's `README.md`, `changelog.md` and `decisions.md`, and `docs/ROADMAP.md`.
The map checker still reports only the nine baseline errors.
Nothing else is staged, committed or pushed.
</success_criteria>

<output>
Write `261101-ujp-SUMMARY.md` beside this plan when done.
It is not part of the step 8 commit.
</output>
