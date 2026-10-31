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

Every other Phase 1 ticket is done and archived.

| Ticket | Title |
|---|---|
| [T100](tickets/T100-empty-program-chip-lines-per-phone.md) | The empty Program test expects the chip lines each phone draws |

### Phase 2: P2 defects

| Ticket | Title |
|---|---|
| [T18](tickets/T18-swipe-back-everywhere.md) | Swipe-back on every pushed screen |
| [T19](tickets/T19-plate-inventory-and-calculator.md) | Plate Inventory and the plate calculator |
| [T20](tickets/T20-archive-and-restore-routines.md) | Archive asks first, and restore works |
| [T21](tickets/T21-name-first-new-routine.md) | Name-first new routine |
| [T22](tickets/T22-compare-and-session-counts.md) | Compare and session counts skip empty workouts |
| [T23](tickets/T23-weekly-tonnage.md) | Weekly Tonnage fixes |
| [T24](tickets/T24-phase-rows-voiceover-and-block-name.md) | Phase rows in VoiceOver, and the block name field |
| [T25](tickets/T25-new-block-layout-small-and-ax3.md) | New Block layout on the small phone and at AX3 |
| [T26](tickets/T26-block-hero-program-routine-text-fit.md) | Block hero, Program rows and routine editor text fit |
| [T27](tickets/T27-today-ax3.md) | Today at AX3 |
| [T28](tickets/T28-warmup-ramp-and-stat-strips-ax3.md) | Warm-up ramp and stat strips at AX3 |
| [T29](tickets/T29-session-editor-polish.md) | Session editor polish |
| [T30](tickets/T30-exercise-display-names.md) | Exercise display names |
| [T31](tickets/T31-design-export-check.md) | Design export check |
| [T32](tickets/T32-custom-exercise-editor-bru.md) | Custom exercise editor and muscle picker in BRU |
| [T33](tickets/T33-pinned-note-bru.md) | Pinned Note sheet in BRU |
| [T87](tickets/T87-today-sheet-order.md) | Today shows the block review and the weekly recap one at a time |
| [T96](tickets/T96-history-pr-count.md) | Exercise history counts its real PRs and stops writing state while it draws |
| [T97](tickets/T97-calibrating-step-copy.md) | Why this weight explains RPE autoregulation's calibrating suggestions |
| [T99](tickets/T99-block-review-prs-and-ax3.md) | The block review counts its PRs and keeps its stats whole at AX3 |
| [T101](tickets/T101-ui-tests-idle-after-typing.md) | UI tests stop waiting a minute per step after typing |
| [T102](tickets/T102-compare-rounding-and-back.md) | Compare rounds its e1RM changes and goes back with ‹ BACK |
| [T103](tickets/T103-streak-and-recap-skip-empty-workouts.md) | Today's day streak and the weekly recap skip empty workouts |
| [T104](tickets/T104-weekly-tonnage-weeks-detail-voiceover.md) | Weekly Tonnage stops crashing, keeps whole weeks and works with VoiceOver |
| [T105](tickets/T105-new-block-delete-and-voiceover-names.md) | New Block's revealed Delete deletes, and VoiceOver reads its controls by name |

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

### Phase 4: test health

| Ticket | Title |
|---|---|
| [T39](tickets/T39-number-entry-like-a-user.md) | Number entry like a user |
| [T40](tickets/T40-slotted-session-delete-guard.md) | Slotted session delete guard |
| [T41](tickets/T41-backup-keeps-routines.md) | Backup keeps routines |
| [T42](tickets/T42-zero-build-warnings.md) | Zero build warnings |

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
