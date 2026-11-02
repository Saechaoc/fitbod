---
phase: quick-261102-g8s
plan: "01"
subsystem: docs
tags: [design-map, redesign, draft-v5, codex-review, docs-only, rsync]

requires:
  - phase: quick-261102-ayp
    provides: "draft v4 of the Today and Program redesign bundle, landed in docs/design-map/redesign"
provides:
  - "draft v5 of the Today and Program redesign bundle in docs/design-map/redesign, staged and not committed"
  - "the Codex coverage report with its complete draft v4 pass, and the new Codex feasibility report, staged exactly as the reviewers left them"
  - "a 9-line map changelog entry for draft v5, above the draft v4 entry"
affects: [Today and Program redesign, Codex feasibility review resuming on draft v5]

tech-stack:
  added: []
  patterns:
    - "rsync -a without --delete, so files that exist only in the repo (reviewer output) survive the copy"
    - "SHA-256 hashes recorded by the planner prove reviewer output was not touched"

key-files:
  created:
    - docs/design-map/redesign/reviews/round3-codex-feasibility.md
  modified:
    - docs/design-map/changelog.md
    - docs/design-map/redesign/changelog.md
    - docs/design-map/redesign/functionality-map.md
    - docs/design-map/redesign/hierarchy.md
    - docs/design-map/redesign/index.md
    - docs/design-map/redesign/open-decisions.md
    - docs/design-map/redesign/plan.md
    - docs/design-map/redesign/program-layouts.md
    - docs/design-map/redesign/review-log.md
    - docs/design-map/redesign/reviews/round3-codex-coverage.md
    - docs/design-map/redesign/risks.md
    - docs/design-map/redesign/today-layouts.md
    - docs/design-map/redesign/tradeoffs.md

key-decisions: []

patterns-established:
  - "Reviewer reports are staged verbatim: never edited, reformatted or restored, and proven by shasum -c before, during and after the work"
  - "A copy from outside the repo is proven with diff -r, which must print only the expected Only-in lines"

requirements-completed:
  - "Land draft v5 of the Today and Program redesign bundle after the Codex coverage and feasibility reviews"

duration: 3min
completed: 2026-11-02
---

# Quick Task 261102-g8s: Land draft v5 of the Today and Program redesign bundle Summary

**Draft v5 of the Today and Program redesign bundle copied byte for byte into docs/design-map/redesign, a 9-line map changelog entry added, both Codex reports proven untouched by SHA-256, and 14 docs/design-map paths staged without a commit**

## Performance

- **Duration:** about 3 min
- **Started:** about 2026-11-02T19:57Z (approximate, the start time was not recorded)
- **Completed:** about 2026-11-02T20:00Z
- **Tasks:** 2 of 2
- **Files modified:** 14 staged paths (13 modified, 1 added), all under `docs/design-map/`

## Accomplishments

- One `rsync -a` with no `--delete` brought the 11 changed leaves to draft v5.
  `diff -r` against the source prints only the two "Only in" lines for the Codex reports, which the source does not hold.
- The map changelog opens with `## 2026-11-02: redesign draft v5` on line 5, and the draft v4 heading moved to line 14.
  The edit adds 9 lines and removes none.
- The screen budget still reads `elements, all states: 222 -> 109 (50% fewer)`.
- The map checker reports exactly the nine baseline archived-ticket link errors and nothing new.
- No `scratchpad` path and no em dash appear in the changelog or the bundle.
- Exactly 14 paths are staged, all under `docs/design-map/`.
  The xcscheme change stays unstaged and `.playwright-mcp/` stays untracked.

## Verification Results

| Check | Result |
|-------|--------|
| `diff -r` source vs `docs/design-map/redesign` | Only the two "Only in ...reviews:" lines, for `round3-codex-coverage.md` and `round3-codex-feasibility.md` |
| `git diff --name-only -- docs/design-map/redesign` (before staging) | 12 files: the 11 leaves and the coverage report |
| `git diff --numstat` | changelog.md `9 0`, coverage report `228 8` |
| `shasum -a 256 -c` (before, after Task 1, after staging) | `OK` for both Codex reports, all three times |
| `sed -n '5p;14p'` on the map changelog | draft v5 heading, then draft v4 heading |
| Step 3, screen budget | `elements, all states: 222 -> 109 (50% fewer)` |
| Step 4, `rg -n scratchpad` | no match, rg exit 1 |
| Step 5, `rg -n '\x{2014}'` | no match, rg exit 1 |
| Step 6, map checker | exit 1; 9 ERROR lines and `9 errors, 0 warnings`; the diff against the baseline shows only line 7 (`mmd-v5` instead of `mmd-baseline`) |
| Step 7 listing | exactly 14 paths: 13 ` M` and 1 `??` |
| `git diff --cached --name-status` | 13 `M` and 1 `A` (the feasibility report) |
| Staged path outside `docs/design-map/` | none, rg exit 1 |
| HEAD after the work | still `5c186ecd`, so no commit was made |

## Task Commits

No task was committed.
The plan overrides the task-commit protocol and ends with the change staged.

1. **Task 1: Copy the draft v5 bundle and add the map changelog entry** - commit: by the orchestrator after GitNexus detect_changes
2. **Task 2: Verify the landed bundle and stage it, without committing** - commit: by the orchestrator after GitNexus detect_changes

**Plan metadata:** commit: by the orchestrator after GitNexus detect_changes

## Files Created/Modified

- `docs/design-map/changelog.md` - hand-edited: new draft v5 entry (9 lines) above the draft v4 entry.
- `docs/design-map/redesign/changelog.md`, `functionality-map.md`, `hierarchy.md`, `index.md`, `open-decisions.md`, `plan.md`, `program-layouts.md`, `review-log.md`, `risks.md`, `today-layouts.md`, `tradeoffs.md` - the 11 leaves, rewritten to draft v5 by the copy.
- `docs/design-map/redesign/reviews/round3-codex-coverage.md` - reviewer output, staged as the reviewer left it (the draft v4 pass appended, 228 lines added and 8 deleted against HEAD).
  Not authored or edited here.
- `docs/design-map/redesign/reviews/round3-codex-feasibility.md` - reviewer output, staged as a new file exactly as the reviewer left it.
  Not authored or edited here.

## Decisions Made

None - followed plan as specified.

## Deviations from Plan

None - plan executed exactly as written.

Notes, none of which changed the result:

- Before starting I ran one read-only check that the plan does not list: branch, HEAD, `git status`, the two hashes and the source paths.
  After step 6 I also counted the ERROR lines in the checker output, and after staging I printed HEAD.
  These only confirm the plan's own claims.
- I split the Task 2 verify block across several Bash calls, in the plan's order, and added `echo` labels.
- I did not read `./CLAUDE.md` or any bundle file, as the plan directs.
  The generic executor steps for `gsd-sdk` init and state updates, the final docs commit, and GitNexus were not run.
  The plan is self-contained, makes no commit, and says the orchestrator handles planning files and `detect_changes`.
  `STATE.md` and `ROADMAP.md` were not touched.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The orchestrator runs GitNexus `detect_changes`, then commits the 14 staged paths with `docs(design-map): revise the redesign bundle to draft v5 after the Codex coverage and feasibility reviews`, no co-author trailer and no push.
  Use a plain `git commit`, not `git commit -a`, so the modified xcscheme stays out.
- The Codex feasibility reviewer resumes on draft v5.
  It stopped with five of its eleven checks done.
- This SUMMARY and the plan sit untracked under `.planning/quick/261102-g8s-land-draft-v5-of-the-today-and-program-r/` and are not staged.
- Nothing is blocked.

---
*Quick task: 261102-g8s*
*Completed: 2026-11-02*

## Self-Check: PASSED

- FOUND: this SUMMARY and all 14 staged paths exist on disk.
- No commit was expected or made: HEAD is still `5c186ecd`.
- This SUMMARY holds no em dash and is not staged: the index holds exactly the 14 `docs/design-map/` paths.
