# Today and Program redesign

Today puts three bands of block bookkeeping above its one action and a page of zero-value muscle rows under it.
Program lists blocks and routines without saying what the lifter is running or what comes next.
This bundle is the design review the brief asked for: a screenshot audit, a hierarchy for both screens, layouts for every state, a map of every existing capability to its new place, and a phased plan.
It builds on the design map in `docs/design-map/` and cites its findings by ID (`D-nn`), its patterns (`P-n`) and the staged decisions in `docs/design-map/decisions.md`.

Status: draft v3, 2026-11-01, revised after two Claude review rounds (round 2 verified round 1's closures and found two more blockers, both closed here).
No reviewer has checked v3 itself: three Codex attempts stopped at the ChatGPT account's usage limit before writing a report, and the next window opens at 2:41 AM on 2 Nov; see review-log.md.
The design is not final until each blocker there is closed or accepted with a reason.

| Read this file | when you need |
| --- | --- |
| audit.md | what is wrong on each screenshot and what it costs the lifter |
| hierarchy.md | each screen's purpose, primary question, next action, zone order, state tables and shared vocabulary |
| today-layouts.md | the Today wireframes, one per state, at 390pt |
| program-layouts.md | the Program wireframes, one per state, at 390pt, and what Block overview changes |
| functionality-map.md | where every existing capability goes |
| plan.md | the three implementation phases, files, tests and order |
| tradeoffs.md | each design decision and the alternatives rejected |
| risks.md | what could go wrong in the build and how to contain it |
| open-decisions.md | the product calls only the user can make, with the defaults the layouts assume |
| evaluation.md | the brief's five criteria checked against the proposal |
| screen_budget.py | run it with `python3 -I` for element counts and tap counts, current vs proposed |
| review-log.md | adversarial review findings, deduplicated, and what changed because of each |
| reviews/ | the reviewers' full reports, one per lens and round, and under specs/ the brief each reviewer was given |
| changelog.md | what changed in this bundle and why |

Sources: the 17e default-size light screenshots in `docs/design-map/screens/img/`, the screen and workflow files under `docs/design-map/`, the BRU rules in `docs/design-system/`, the user's own BRU mock-ups in `bru-screens/Fitbod-Session/screens/`, and the Swift views named in functionality-map.md.
Scope: the Today and Program tabs and the screens they push.
Block overview, the workout logger, Progress and Library change only where this bundle names them.
