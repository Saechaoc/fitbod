# Conway: Milestone 1 closeout tickets

Milestone 1 of Fitbod still has 47 open review defects and one new finding, and it has not been verified on both phones at AX3 and in dark mode.
This bundle turns the approved plan (`.planning/noble-wishing-conway.md`) into 48 code-free tickets.
A coordinator runs them on up to three Orca workers at once, each ticket in its own git worktree, and merges each ticket into `main` after review.

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

| Ticket | Title |
|---|---|
| [T101](tickets/T101-ui-tests-idle-after-typing.md) | UI tests stop waiting a minute per step after typing |
| [T105](tickets/T105-new-block-delete-and-voiceover-names.md) | New Block's revealed Delete deletes, and VoiceOver reads its controls by name |
| [T110](tickets/T110-per-set-overrides-removed.md) | The session editor stops offering per-set overrides that the logger ignores |
| [T112](tickets/T112-exercise-history-rows.md) | Exercise history shows its workouts again |

### Phase 3: P3 polish and copy

| Ticket | Title |
|---|---|
| [T34](tickets/T34-copy-sweep.md) | Copy sweep |
| [T35](tickets/T35-today-polish.md) | Today polish |
| [T36](tickets/T36-rest-sheet-and-rpe-chips.md) | Rest sheet and RPE chips |
| [T37](tickets/T37-library-and-detail-polish.md) | Library and exercise detail polish |
| [T38](tickets/T38-program-new-block-settings-small-fixes.md) | Small fixes on Program, New Block and Settings |
| [T85](tickets/T85-pr-row-phrases.md) | PR rows keep "@ RPE" and the kind label whole |
| [T98](tickets/T98-chart-audio-graph-rounding.md) | The progress chart's audio graph reads rounded values |
| [T106](tickets/T106-sideways-drag-does-not-open-rows.md) | A sideways drag on a row does not open it |
| [T107](tickets/T107-plate-screens-tabs-targets-stack.md) | The plate screens keep their tabs whole and their controls easy to hit |
| [T108](tickets/T108-block-overview-and-routine-at-ax3.md) | The block overview and the routine screen read cleanly at AX3 |
| [T109](tickets/T109-muscle-screen-steppers-order-tests.md) | The muscle screen uses BRU steppers, keeps a stable order and is always tested |
| [T111](tickets/T111-session-editor-rows-announced-removable.md) | Session editor rows are announced, removable and easy to hit |
| [T113](tickets/T113-block-review-pr-marks.md) | The block review's PR marks agree, and its stats read cheaply and whole |
| [T114](tickets/T114-recap-target-from-plan.md) | The weekly recap measures last week against its plan |
| [T115](tickets/T115-weekly-tonnage-label-and-rows.md) | Weekly Tonnage keeps its previous-best label whole, and its week rows open their workouts |

### Phase 4: test health

| Ticket | Title |
|---|---|
| [T39](tickets/T39-number-entry-like-a-user.md) | Number entry like a user |
| [T40](tickets/T40-slotted-session-delete-guard.md) | Slotted session delete guard |
| [T41](tickets/T41-backup-keeps-routines.md) | Backup keeps routines |
| [T42](tickets/T42-zero-build-warnings.md) | Zero build warnings |
| [T116](tickets/T116-progress-ui-tests-budgets.md) | Progress UI tests fit the test budgets |

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
