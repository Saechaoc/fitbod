# Conway: Milestone 1 closeout tickets

Milestone 1 of Fitbod still has 47 open review defects and one new finding, and it has not been verified on both phones at AX3 and in dark mode.
This bundle turns the approved plan (`.planning/noble-wishing-conway.md`) into 48 code-free tickets.
A coordinator runs them on up to three Orca workers at once, each ticket in its own git worktree, and merges each ticket into `main` after review.

Stage note, 2026-11-01: the app is a prototype, so [the development guide](../DEVELOPMENT.md#deferred-work) defers the accessibility, polish and verification tickets until their workflow is stable or the app reaches release readiness.
Dispatch the data, correctness and test-speed tickets it lists first.

Status: ready to dispatch once every precondition in [dispatch.md](dispatch.md) holds.
Nothing from this bundle has been dispatched.
The quick-task run of the same plan must finish its last two tasks first, so read "Another session runs the same plan" in [risks.md](risks.md) first.

| Read this file | When you need |
|---|---|
| [assumptions.md](assumptions.md) | the facts this bundle relies on |
| [requirements.md](requirements.md) | the goal, done criteria, scope and quality targets |
| [decisions.md](decisions.md) | the nine product decisions the user approved |
| [tradeoffs.md](tradeoffs.md) | engineering calls, with the options rejected |
| [risks.md](risks.md) | failure modes and mitigations |
| [worker-rules.md](worker-rules.md) | the rules every worker follows; part of every ticket |
| [dispatch.md](dispatch.md) | the coordinator playbook: lanes, worktrees, merging, gates and Phase 8 |
| [run-log.md](run-log.md) | approvals, lanes, the ticket ledger, gates and findings |
| [capacity_model.py](capacity_model.py) | run it with `python3 -I` to validate the tickets and estimate time for one to four lanes |
| [changelog.md](changelog.md) | what changed in this bundle and why |
| `tickets/` | one open ticket per file, listed below |
| `evidence/` | one folder per ticket, written by workers; git ignores it |

## Tickets

Completed tickets are archived: their files leave `tickets/`, their rows leave the tables below, and `ARCHIVED` in [capacity_model.py](capacity_model.py) keeps each one's id, phase, review items and planned new files.
Archived ids are never reused.
To read an archived ticket, `git log --diff-filter=D -1 -- 'docs/conway-specs/tickets/T01-*'` names the commit that removed it, and `git show <commit>^:<path>` prints it.

### Phase 1: P0 and P1 defects

Every Phase 1 ticket is done and archived.

### Phase 2: P2 defects

Every Phase 2 ticket is done and archived.

### Phase 3: P3 polish and copy

| Ticket | Title |
|---|---|
| [T118](tickets/T118-weekly-tonnage-label-and-rows.md) | Weekly Tonnage keeps its previous-best label whole, and its week rows open their workouts |
| [T120](tickets/T120-new-block-toast-and-duration-steppers.md) | New Block's undo toast stays small, and its duration steppers say what they change |
| [T122](tickets/T122-routine-session-drag-slots.md) | A session dragged on the routine screen lands on the slot under the finger |
| [T124](tickets/T124-rest-sheet-fits-at-ax3.md) | The rest sheet's countdown and ±15s buttons fit at AX3 |
| [T125](tickets/T125-logger-plates-during-entry.md) | The logger shows a set's plates while its weight is being entered |
| [T126](tickets/T126-section-head-action-hit-area.md) | Section head actions keep their touch area off the title at accessibility sizes |
| [T127](tickets/T127-pr-volume-grouping.md) | The PR list writes volume with thousands separators, as the chart does |
| [T128](tickets/T128-reseed-keeps-lifter-data.md) | Re-seeding the exercise library keeps the lifter's exercises, history and targets |
| [T129](tickets/T129-progress-chart-names-every-line.md) | The progress chart names every line it draws, and labels its first and last dates |
| [T130](tickets/T130-new-block-keeps-its-draft.md) | New Block keeps the lifter's draft when the screen behind it redraws |
| [T132](tickets/T132-planned-hero-and-session-summary-at-ax3.md) | The planned block hero and session summaries keep their parts whole at AX3 |
| [T136](tickets/T136-pr-row-opens-its-workout.md) | A PR row opens the workout it was set in |
| [T137](tickets/T137-progress-rows-open-only-on-tap.md) | Progress's rows open only on a tap |
| [T138](tickets/T138-block-review-pr-chips-and-stats-once.md) | The block review's PR chips read to VoiceOver, and its stats load once |
| [T139](tickets/T139-week-windows-follow-the-calendar.md) | Week windows follow the calendar across daylight saving, and Muscles Hit keeps a stable order |
| [T140](tickets/T140-long-press-remove-and-remove-labels.md) | Removing an exercise by long press forgets its open editor, and REMOVE controls read normally to VoiceOver |

### Phase 4: test health

| Ticket | Title |
|---|---|
| [T39](tickets/T39-number-entry-like-a-user.md) | Number entry like a user |
| [T40](tickets/T40-slotted-session-delete-guard.md) | Slotted session delete guard |
| [T41](tickets/T41-backup-keeps-routines.md) | Backup keeps routines |
| [T42](tickets/T42-zero-build-warnings.md) | Zero build warnings |
| [T117](tickets/T117-history-tests-cover-non-pr-rows-and-every-label.md) | Exercise history's tests cover a row without a PR and every label |
| [T119](tickets/T119-progress-ui-tests-budgets.md) | Progress UI tests fit the test budgets |
| [T121](tickets/T121-new-block-ui-tests-budgets.md) | New Block UI tests fit the test budgets |
| [T123](tickets/T123-ui-runs-clear-rest-notifications.md) | UI test runs stay free of leftover rest notifications, and the journey suite reads cheaply |
| [T131](tickets/T131-editor-ui-tests-budgets.md) | The session editor's UI tests fit the test budgets |
| [T133](tickets/T133-volume-target-tests-adjust-and-relaunch.md) | Volume target tests cover VoiceOver's adjust and a relaunch, and the fatigue smoke test launches cleanly |
| [T134](tickets/T134-hosted-accessibility-tests-any-order.md) | Hosted accessibility tests pass in any order, and the row style's VoiceOver activate is tested |
| [T135](tickets/T135-shared-ui-test-helpers.md) | UI suites share one copy of their helpers, and the swipe-back suite finds rows by name and fits its budgets |

### Phase 5: design refresh

| Ticket | Title |
|---|---|
| [T43](tickets/T43-design-refresh.md) | Design refresh from a newer export |

### Phase 6: full verification

| Ticket | Title |
|---|---|
| [T44](tickets/T44-full-verification-run.md) | Full verification run |
| [T45](tickets/T45-ax3-dark-journeys-and-persistence.md) | AX3 and dark journeys, relaunch persistence |
| [T46](tickets/T46-screenshot-tour.md) | Screenshot tour |

### Phase 7: docs and evidence

| Ticket | Title |
|---|---|
| [T47](tickets/T47-verification-docs.md) | Verification docs |
| [T48](tickets/T48-product-docs-roadmap-gallery.md) | Product docs, roadmap, gallery and review page |

### Phase 8: commit, push, report

The coordinator does Phase 8 alone; see [dispatch.md](dispatch.md).
