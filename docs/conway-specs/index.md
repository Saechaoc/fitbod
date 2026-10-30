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
| `tickets/` | one ticket per file, listed below |
| `evidence/` | one folder per ticket, written by workers; git ignores it |

## Tickets

### Phase 1: P0 and P1 defects

| Ticket | Title |
|---|---|
| [T01](tickets/T01-ui-test-foundation.md) | UI test foundation |
| [T02](tickets/T02-shared-counts-and-plurals.md) | Shared counts and plural helper |
| [T03](tickets/T03-library-copy-edit-first-tap.md) | Library Copy and Edit open on the first tap |
| [T04](tickets/T04-skip-warmups-and-logged-counts.md) | Skip warm-ups works, and counts stay honest |
| [T05](tickets/T05-dirty-editors-resist-swipe-down.md) | Dirty editors resist swipe-down |
| [T06](tickets/T06-reps-and-rpe-controls.md) | Reps and RPE controls in the session editor |
| [T07](tickets/T07-notes-sheets-local-copy.md) | Notes sheets edit a local copy |
| [T08](tickets/T08-one-tap-export-and-backup.md) | One-tap export and backup |
| [T09](tickets/T09-visible-why-control.md) | Visible WHY control, Use and Override |
| [T10](tickets/T10-one-block-template-catalog.md) | One block template catalog |
| [T11](tickets/T11-new-block-two-saves.md) | New Block's two saves |
| [T12](tickets/T12-block-overview-states.md) | Block overview states |
| [T13](tickets/T13-pr-list-and-series-chips.md) | PR list and progress chips |
| [T14](tickets/T14-heatmap-hit-areas.md) | Heatmap hit areas and VoiceOver |
| [T15](tickets/T15-program-empty-state-ax3.md) | Program empty state and Resume pill at AX3 |
| [T16](tickets/T16-program-and-new-block-dark-mode.md) | Program and New Block in dark mode |
| [T17](tickets/T17-stripe-height-and-button-bleed.md) | Stripe height and button bleed |
| [T49](tickets/T49-rpe-chip-hold-opens-decimal-picker.md) | Holding an RPE chip opens the decimal picker |
| [T50](tickets/T50-why-uses-finished-workouts.md) | WHY suggests from finished workouts only |
| [T51](tickets/T51-plateau-uses-finished-workouts.md) | Plateau check reads finished workouts only |
| [T52](tickets/T52-rpe-creep-skips-empty-workouts.md) | RPE creep skips workouts without a logged set |
| [T53](tickets/T53-stall-badge-window.md) | Stall badge names the exercise's own window |
| [T54](tickets/T54-custom-exercise-name-trim.md) | Custom exercise names save without outer spaces |
| [T55](tickets/T55-pinned-note-capsule-tap-target.md) | Pinned note capsule takes taps across 44 points |
| [T56](tickets/T56-progress-chart-unit-and-fit.md) | Progress chart hero shows the right unit, and its name and PR mark fit |
| [T57](tickets/T57-pr-list-working-sets-and-ax3-toggle.md) | PR list ranks working sets only, and its intent toggle fits AX3 |
| [T58](tickets/T58-e1rm-one-point-per-workout.md) | e1RM chart plots one point per workout |
| [T59](tickets/T59-swap-resets-prescription.md) | Swapping an exercise resets its prescription and override marks |
| [T60](tickets/T60-plate-inventory-swipe-delete.md) | Plate inventory rows delete with a swipe |
| [T61](tickets/T61-zero-suggestion-placeholder.md) | A zero suggestion reads as no suggestion |
| [T62](tickets/T62-heatmap-voiceover-order.md) | VoiceOver reads the heatmap one figure at a time |
| [T63](tickets/T63-program-header-and-sheets-ax3.md) | Program's header and block sheets fit AX3, and + NEW takes a 44pt tap |
| [T64](tickets/T64-plateau-footer-and-window-test.md) | The plateau footer stops pointing to a missing setting, and a test pins the stall window |
| [T65](tickets/T65-edit-keeps-active-block.md) | Saving an edit keeps the active block active |
| [T66](tickets/T66-tab-bar-bleed.md) | The tab bar's fill stays out of the home indicator area at large text |
| [T67](tickets/T67-lifecycle-entry-points.md) | Ending a block and swapping its routine go through the lifecycle service |
| [T68](tickets/T68-progress-hero-adds-up.md) | The progress chart's hero numbers add up |
| [T69](tickets/T69-builder-back-names-its-tab.md) | The block builder's back control names the tab it opened from |
| [T70](tickets/T70-block-review-after-end.md) | The block review opens after a block ends |
| [T71](tickets/T71-pr-toggle-every-size.md) | The PR list's intent toggle fits every text size and says which is selected |
| [T72](tickets/T72-one-sample-per-workout.md) | The plateau and RPE-creep checks count each workout once |
| [T73](tickets/T73-signal-text-on-paper.md) | Orange text on Program and New Block reads clearly in light mode |
| [T74](tickets/T74-add-phase-sheet-header.md) | The Add Phase sheet has a BRU header and a CANCEL |
| [T75](tickets/T75-swap-rebuilds-warmups.md) | A swap rebuilds the warm-ups for the new exercise, and the swap tests drive the real swap |
| [T76](tickets/T76-added-exercise-prescription.md) | An exercise added mid-workout gets its prescription |
| [T77](tickets/T77-plate-inventory-list.md) | Plate Inventory's swipe-to-delete works on iOS 26 and closes like other rows |
| [T78](tickets/T78-active-block-counts.md) | The active block's week and session counts tell the truth |
| [T79](tickets/T79-no-history-why-sheet.md) | Why this weight shows no zero weight and no unknown plate size |
| [T80](tickets/T80-calibrating-weight-cell.md) | A calibrating set's weight can be typed, and shows once chosen |
| [T81](tickets/T81-heatmap-figure-labels.md) | VoiceOver names each heatmap figure once |
| [T82](tickets/T82-e1rm-chart-voiceover.md) | VoiceOver reads each e1RM point's rounded weight |
| [T83](tickets/T83-action-popover-fit.md) | The action popover's items stay whole and take a 44pt tap |
| [T84](tickets/T84-previous-top-set-whole-workout.md) | The previous top set reads the whole workout |
| [T86](tickets/T86-block-review-fixes.md) | The block review fits its screen, names what Start next opens, and stops once a block starts |
| [T88](tickets/T88-warmup-skip-and-swap.md) | "Skip warm-ups this session only" skips, and a swap rebuilds skipped warm-ups |
| [T89](tickets/T89-why-sheet-inputs.md) | Why this weight shows the set's targets, its last session and full-width steps |
| [T90](tickets/T90-shared-ui-test-helpers.md) | UI tests share one set of helpers |

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

### Phase 3: P3 polish and copy

| Ticket | Title |
|---|---|
| [T34](tickets/T34-copy-sweep.md) | Copy sweep |
| [T35](tickets/T35-today-polish.md) | Today polish |
| [T36](tickets/T36-rest-sheet-and-rpe-chips.md) | Rest sheet and RPE chips |
| [T37](tickets/T37-library-and-detail-polish.md) | Library and exercise detail polish |
| [T38](tickets/T38-program-new-block-settings-small-fixes.md) | Small fixes on Program, New Block and Settings |
| [T85](tickets/T85-pr-row-phrases.md) | PR rows keep "@ RPE" and the kind label whole |

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
