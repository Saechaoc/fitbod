---
phase: quick-261101-ujp
plan: "01"
subsystem: docs
tags: [design-map, redesign, docs-only, check_map]

requires:
  - phase: design-map review decisions (2026-11-01)
    provides: the audit rows, patterns and stages that the redesign builds on
provides:
  - "docs/design-map/redesign/ with 33 files copied byte for byte from the finished bundle"
  - "Links to the bundle from the map's README, changelog and decisions, and its 14 open product calls in docs/ROADMAP.md"
  - "A map checker that skips only redesign/reviews/"
affects: [Milestone 2 design, Today and Program redesign, design-map text checks]

tech-stack:
  added: []
  patterns:
    - "Verbatim reviewer text stays out of the map's text checks through a path skip in check_text_files, the same way screens/tree already does"

key-files:
  created:
    - docs/design-map/redesign/ (33 files: 14 at the top, 6 reports in reviews/, 13 briefs in reviews/specs/)
  modified:
    - docs/design-map/tools/check_map.py
    - docs/design-map/README.md
    - docs/design-map/changelog.md
    - docs/design-map/decisions.md
    - docs/ROADMAP.md

key-decisions:
  - "Followed the plan's step 8 commit command exactly, with no Co-Authored-By or session trailer, as the plan and the user's global rule require."
  - "Left .planning/STATE.md and .planning/ROADMAP.md untouched; the orchestrator owns the GSD docs commit."

requirements-completed:
  - "Land the Today and Program redesign bundle in docs/design-map/redesign"

duration: 3min
completed: 2026-11-01
---

# Quick Task 261101-ujp: Land the Today and Program Redesign Bundle Summary

**The finished Today and Program redesign bundle (33 files) now lives in `docs/design-map/redesign/`, linked from the design map and the roadmap, in one docs-only commit that leaves the map checker at its nine baseline errors.**

## Performance

- **Duration:** about 3 min
- **Started:** 2026-11-02T06:15:04Z
- **Work and commit finished:** 2026-11-02T06:16:29Z
- **Tasks:** 1 of 1
- **Files changed in the commit:** 38 (33 new, 5 edited)

## Accomplishments

- Copied the bundle with `rsync -a`.
  It holds 14 files at the top, 6 reviewer reports in `reviews/` and 13 briefs in `reviews/specs/`.
  A `diff -r` against the source, run on the working tree and again on `git archive HEAD`, shows no difference.
- Added the skip for `redesign/reviews/` to `check_text_files` in `docs/design-map/tools/check_map.py`.
  The rest of `redesign/` stays under the em dash, table and link checks, and the checker found no new error there.
- Linked the bundle from the map's `README.md` (one table row), `changelog.md` (a new newest entry) and `decisions.md` (one paragraph on D-159 and D-341).
- Added the "Today and Program redesign" bullet to the "Decisions awaiting product direction" list in `docs/ROADMAP.md`.
  It points to `docs/design-map/redesign/open-decisions.md`, which lists the 14 product calls.

## Task Commits

1. **Task 1: Copy the redesign bundle, link it from the map and the roadmap, verify and commit** - `12ea884a` (docs)
   Full hash: `12ea884a77720b394c868db624f262ba41bfe0f8`.
   Subject: `docs(design-map): land the Today and Program redesign bundle`.

**Plan metadata:** not committed by this executor; the orchestrator makes the docs commit for the summary and state files.

## Verification Gates

All four gates from step 7 held before the commit.

| Gate | Result |
|---|---|
| Copy matches the source | `diff -r` printed nothing and `COPY-IDENTICAL` |
| Screen budget | `python3 -I docs/design-map/redesign/screen_budget.py` exit 0; line `elements, all states: 199 -> 100 (49% fewer)` |
| No session path in the bundle | `rg -n scratchpad docs/design-map/redesign` printed nothing, exit 1 |
| Map checker | last line `9 errors, 0 warnings`; its nine `ERROR` lines are identical to `check-baseline.txt` (`ERRORS-MATCH-BASELINE`); checker exit 1 is the baseline |
| Working tree | only the five edited files, `docs/design-map/redesign/` and the planning folder plus the two unrelated entries |

The nine checker errors are the known archived-ticket links:

- `assumptions.md` links T118 and T122.
- `audit.md` links T40, T41, T39, T122 and T118.
- `missing-screens.md` links T118 and T41.

All of them point at `../conway-specs/tickets/`, which does not exist.
None of them is in `redesign/`.

After the commit:

- `git show --name-only --format= HEAD` lists 38 files.
- `git show --numstat --format= HEAD` shows 0 deleted lines everywhere.
  Added lines are check_map.py 2, README.md 1, changelog.md 9, decisions.md 4 and ROADMAP.md 3, and the 33 bundle files are all additions.
- `git log -1 --format=%B` prints the step 8 subject, a blank line and the body, with no trailer lines.
- `git status --short` still lists ` M fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` and `?? .playwright-mcp/`, and nothing under `docs/`.
- No em dash appears in the five edited files or in the bundle outside `reviews/`.
- Nothing was pushed.
  The branch is one commit ahead of `origin/main`, and that commit is this one.

## Files Created/Modified

- `docs/design-map/redesign/` - 33 files copied verbatim, including `index.md`, `open-decisions.md` and the runnable `screen_budget.py`
- `docs/design-map/tools/check_map.py` - skips `redesign/reviews/` in `check_text_files`
- `docs/design-map/README.md` - table row for `redesign/`
- `docs/design-map/changelog.md` - newest entry, "2026-11-01: Today and Program redesign"
- `docs/design-map/decisions.md` - paragraph noting that Phase 1 replaces the elements behind D-159 and D-341, with the stage change left to the user
- `docs/ROADMAP.md` - bullet listing the redesign's 14 open product calls

## Decisions Made

- No trailer on the commit.
  The plan's step 8 and done criteria call for none, and the user's global rule says never to add an agent as co-author.
- No change to any copied file, as the plan requires.
  No check failed because of a copied file, so no stop-and-report was needed.

## Deviations from Plan

None - plan executed exactly as written.

GitNexus MCP tools were not available to this executor, so the plan's two GitNexus steps were skipped as the orchestrator instructed.
The orchestrator ran `gitnexus_impact` on `check_text_files` beforehand (LOW risk, one caller, `check()`), and runs the change detection before the final docs commit.

## Issues Encountered

None.
A `cat -A` call in the post-commit check failed because macOS `cat` has no `-A` flag.
I re-ran the check with `cat -e`, and it showed the expected message.

## Threat Model Check

- T-ujp-01: mitigated. `rg -n scratchpad` found nothing, and the committed bundle equals the source byte for byte.
- T-ujp-02: mitigated. Six explicit paths were staged, and `.playwright-mcp/` is still untracked.
- T-ujp-03: mitigated. Both scripts ran as `python3 -I`.
- T-ujp-04: accepted as planned. The skip covers only `redesign/reviews/`.
- No new security-relevant surface was added, so there are no threat flags.

## Known Stubs

None. This change is docs only and wires no UI or data.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The redesign's 14 open product calls are listed in `docs/ROADMAP.md`.
The redesign plan starts once the user confirms or changes them.
The stage of D-159 and D-341 stays unchanged in `docs/design-map/decisions.md` until the user confirms.

## Self-Check: PASSED

- `docs/design-map/redesign/index.md`: found.
- `docs/design-map/redesign/open-decisions.md`: found.
- `docs/design-map/redesign/screen_budget.py`: found.
- Commit `12ea884a`: found in `git log`.
