---
phase: quick-261102-ayp
plan: "01"
subsystem: docs
tags: [design-map, redesign, docs-only, check_map, draft-v4]

requires:
  - phase: quick-261101-ujp
    provides: the landed Today and Program redesign bundle (draft v3) that this change revises

provides:
  - "docs/design-map/redesign/ equal to the draft v4 source bundle: 14 revised leaves, with round3-codex-coverage.md beside round3-codex-experience.md under reviews/"
  - "A 2026-11-02 entry at the top of docs/design-map/changelog.md"
  - "17 docs/design-map paths staged in the git index for the orchestrator's commit"
affects: [Milestone 2 design, Today and Program redesign, design-map text checks]

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - docs/design-map/redesign/reviews/round3-codex-coverage.md
    - docs/design-map/redesign/reviews/round3-codex-experience.md
  modified:
    - docs/design-map/changelog.md
    - "docs/design-map/redesign/ (14 leaves: 13 Markdown files and screen_budget.py)"

key-decisions:
  - "Made no commit and no push, as the plan's commit override requires; the orchestrator commits after GitNexus detect_changes."
  - "Left .planning/STATE.md and .planning/ROADMAP.md untouched; the orchestrator owns the GSD docs commit."
  - "Ran step 5's em dash search with the regex escape for U+2014, so that no em dash was typed; it matches the same character."

requirements-completed:
  - "Land draft v4 of the Today and Program redesign bundle in docs/design-map/redesign"

duration: 3min
completed: 2026-11-02
---

# Quick Task 261102-ayp: Land Draft v4 of the Today and Program Redesign Bundle Summary

**Draft v4 of the Today and Program redesign bundle is copied byte for byte into `docs/design-map/redesign/` (14 revised leaves plus both round 3 Codex reports), the map changelog opens with its 8-line 2026-11-02 entry, and exactly 17 `docs/design-map/` paths are staged and uncommitted.**

commit: by the orchestrator after GitNexus detect_changes

## Performance

- **Duration:** about 3 min
- **Started:** not captured.
  The plan file was written at 2026-11-02T16:21:41Z.
  The first change, the map changelog edit, landed at 2026-11-02T16:23:18Z.
- **Staged:** 2026-11-02T16:24:16Z
- **Tasks:** 2 of 2
- **Paths staged:** 17 (15 modified, 2 added)

## Accomplishments

- Copied the draft v4 bundle with `rsync -a` and no `--delete`.
  It rewrote the 14 leaves and re-copied `reviews/round3-codex-experience.md` with identical content.
  The untracked `reviews/round3-codex-coverage.md` stayed in place, because the source does not have it.
  `diff -r` against the source now prints one line: `Only in docs/design-map/redesign/reviews: round3-codex-coverage.md`.
- Added the 8-line `## 2026-11-02: redesign draft v4` entry to `docs/design-map/changelog.md`, directly above `## 2026-11-01: Today and Program redesign`.
  The edit adds 8 lines and removes none.
  No copied file was edited.
- Ran the plan's steps 3 to 6.
  The screen budget, the scratchpad scan, the em dash scan and the map checker all gave the expected result.
- Staged the two step 7 paths and nothing else.
  The xcscheme change stays unstaged, and `.playwright-mcp/` stays untracked.

## Task Commits

1. **Task 1: Copy the draft v4 bundle and add the map changelog entry** - commit: by the orchestrator after GitNexus detect_changes
2. **Task 2: Verify the landed bundle and stage it, without committing** - commit: by the orchestrator after GitNexus detect_changes

Both tasks go into the one commit that the orchestrator makes.
HEAD is still `64f7d7a0`; this executor made no commit and no push.

**Plan metadata:** not committed by this executor; the orchestrator makes the docs commit for the summary and state files.

## Verification Gates

| Gate | Result |
|---|---|
| Copy matches the source | `diff -r` printed only `Only in docs/design-map/redesign/reviews: round3-codex-coverage.md` |
| Tracked leaves changed | `git diff --name-only -- docs/design-map/redesign` counted 14 |
| Map changelog edit | `git diff --numstat` printed `8	0`; line 5 is `## 2026-11-02: redesign draft v4`; line 13 is `## 2026-11-01: Today and Program redesign` |
| Step 3, screen budget | `elements, all states: 222 -> 109 (50% fewer)` |
| Step 4, no session path | no output, `rg exit=1` |
| Step 5, no em dash | no output, `rg exit=1`; the same pattern printed `1` when run on a real U+2014 |
| Step 6, map checker | `exit 1`; 9 `ERROR` lines; last line `9 errors, 0 warnings` |
| Checker against baseline | `diff` shows only line 7, the `mermaid     18 blocks written to` folder (`mmd-v4` instead of `mmd-baseline`) |
| Step 7, staged set | `git diff --cached --name-status` lists 17 paths: 15 `M` and 2 `A`; nothing is outside `docs/design-map/`; no deletions |
| Step 8, no commit | HEAD is still `64f7d7a0` |

The plan's `must_haves` artifact strings are all present: `Status: draft v4, 2026-11-02` in `index.md`, `## 2026-11-02, draft v4` in `redesign/changelog.md`, `## Round 3 (Codex): settled in draft v4` in `review-log.md`, both report titles, and the new heading in the map changelog.
The three `key_links` patterns each match once in `docs/design-map/changelog.md`.
`screen_budget.py` exists.

The nine checker errors are the known archived-ticket links to `../conway-specs/tickets/`, which does not exist.
None of them is in `redesign/`.

## Staged Paths

Exact staged lines from `git status --short`:

```
M  docs/design-map/changelog.md
M  docs/design-map/redesign/audit.md
M  docs/design-map/redesign/changelog.md
M  docs/design-map/redesign/evaluation.md
M  docs/design-map/redesign/functionality-map.md
M  docs/design-map/redesign/hierarchy.md
M  docs/design-map/redesign/index.md
M  docs/design-map/redesign/open-decisions.md
M  docs/design-map/redesign/plan.md
M  docs/design-map/redesign/program-layouts.md
M  docs/design-map/redesign/review-log.md
A  docs/design-map/redesign/reviews/round3-codex-coverage.md
A  docs/design-map/redesign/reviews/round3-codex-experience.md
M  docs/design-map/redesign/risks.md
M  docs/design-map/redesign/screen_budget.py
M  docs/design-map/redesign/today-layouts.md
M  docs/design-map/redesign/tradeoffs.md
```

The rest of `git status --short`, none of it staged:

```
 M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme
?? .planning/quick/261102-ayp-land-draft-v4-of-the-today-and-program-r/
?? .playwright-mcp/
```

## Files Created/Modified

- `docs/design-map/redesign/` - 14 leaves replaced with draft v4: `audit.md`, `changelog.md`, `evaluation.md`, `functionality-map.md`, `hierarchy.md`, `index.md`, `open-decisions.md`, `plan.md`, `program-layouts.md`, `review-log.md`, `risks.md`, `today-layouts.md`, `tradeoffs.md` and the runnable `screen_budget.py`
- `docs/design-map/redesign/reviews/round3-codex-experience.md` - newly tracked; content identical to the file that was already in the tree
- `docs/design-map/redesign/reviews/round3-codex-coverage.md` - newly tracked; the partial Codex coverage review, kept verbatim
- `docs/design-map/changelog.md` - new newest entry, "2026-11-02: redesign draft v4"

## Decisions Made

- No commit and no push.
  The plan's commit override says so, and the orchestrator commits after `gitnexus_detect_changes`.
  Step 8 gives its message as `docs(design-map): revise the redesign bundle to draft v4 after the Codex reviews`, with no co-author trailer.
- No edit to any copied file or reviewer report.
  No check failed, so no stop-and-report was needed.
- `.planning/STATE.md` and `.planning/ROADMAP.md` are untouched.
  Quick tasks stay out of ROADMAP.md, and the orchestrator owns the docs commit.

## Deviations from Plan

None in substance - the plan was executed as written, and no check failed.

Two notes on form, for transparency:

- **Step 5 notation.**
  I ran the em dash search as `rg -n '\x{2014}' ...` instead of typing the literal U+2014 character, so that I never wrote an em dash.
  It is the same character with the same scope and globs.
  The pattern printed `1` when run on a real em dash, so the empty result is not vacuous.
- **Extra read-only checks, not in the plan.**
  - `cmp` of the untracked `round3-codex-experience.md` against the source before rsync overwrote it.
    The file was not in git and could not be restored, and the two copies were identical.
  - A `git status --short --untracked-files=all docs/design-map` listing before `git add`, to confirm that no stray file would be swept in.
    It showed 15 modified and 2 untracked paths, as expected.
  - A count showing that the step 4 and 5 scans include all 21 files under `redesign/reviews/`, which T-ayp-01 relies on.
  - A scan of the two Codex reports for email addresses and secret-looking strings, which found none.

No `gitnexus_impact` was run, as the plan says: no symbol is edited by hand, and `screen_budget.py` is a standalone script that nothing imports or runs.
The orchestrator runs `gitnexus_detect_changes` before its commit.

## Issues Encountered

None that affected the result.
`.planning/STATE.md` is 263 KB and over the Read tool's limit, so I read only its first 60 lines.
Nothing in the plan depended on the rest.

## Threat Model Check

- T-ayp-01 (mitigated): step 4 found no `scratchpad` path, the scan covered the reviewer reports too, and `diff -r` shows the leaves match the source.
- T-ayp-02 (accepted as planned): a scan of both reports found no secret, token or email address.
- T-ayp-03 (mitigated): step 7 staged two explicit paths, and `git diff --cached --name-only` lists only `docs/design-map/` paths.
- T-ayp-04 (mitigated): `screen_budget.py` and `check_map.py` both ran as `python3 -I`, and `diff -r` proves the landed `screen_budget.py` is the source file.
- T-ayp-05 (accepted as planned): the skip of `redesign/reviews/` in `check_map.py` is unchanged, and steps 4 and 5 still scan the reports.
- No new security-relevant surface was added, so there are no threat flags.

## Known Stubs

None. This change is docs only and wires no UI or data.

## User Setup Required

None - no external service configuration required.

## Next Step for the Orchestrator

Run `gitnexus_detect_changes`, then commit the staged set with the step 8 message and no co-author trailer.
Do not push.
Add this SUMMARY.md, and any STATE.md update you make, in the separate docs commit.

## Self-Check: PASSED

- All claimed files exist: this SUMMARY.md, the two Codex reports, `index.md`, `review-log.md`, `redesign/changelog.md`, `screen_budget.py` and `docs/design-map/changelog.md`.
- There is no commit hash to verify, because this executor made no commit.
  HEAD is still `64f7d7a0`, and the index holds exactly 17 paths.
- This SUMMARY.md, the xcscheme and `.playwright-mcp/` are not staged.
- `.planning/STATE.md` and `.planning/ROADMAP.md` are untouched.
- This SUMMARY.md contains no em dash.

