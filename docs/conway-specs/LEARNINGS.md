---
phase: "conway"
phase_name: "conway-ticket-run"
project: "Fitbod"
generated: "2026-11-03"
run: "run_124e164710df"
span: "2026-10-29 18:32 to 2026-11-01 17:14"
counts:
  decisions: 10
  lessons: 9
  patterns: 9
  surprises: 7
missing_artifacts:
  - "PLAN.md"
  - "SUMMARY.md"
  - "VERIFICATION.md"
  - "UAT.md"
---

# Conway Run Learnings: conway-ticket-run

This run was not a GSD phase, so it has none of the GSD phase files.
These stood in for them:

- Plan: `.planning/noble-wishing-conway.md`, [dispatch.md](dispatch.md) and [worker-rules.md](worker-rules.md).
- Summary, state and verification: [run-log.md](run-log.md), with its run notes, ticket ledger, phase gates and findings F1 to F388.
- Decisions: [tradeoffs.md](tradeoffs.md).
- The user's direction during the run: `docs/DEVELOPMENT.md`.

Run notes are cited by their timestamp in run-log.md's "Orca run" section.
Paths without a folder are in `docs/conway-specs/`.

## Decisions

### Run tickets in parallel, with one worktree and one simulator pair per lane
Up to three workers ran at once.
Each ticket got its own git worktree and branch from the newest `main`, and each lane had its own 390pt and 440pt phones and its own DerivedData folder.
Only the coordinator moved `main`, and two tickets never edited the same file at the same time.

**Rationale:** The user approved parallel agents in worktrees; separate phones and build folders keep workers from interfering, and file ownership prevents merge conflicts.
**Source:** .planning/noble-wishing-conway.md ("Process", "Parallel lanes", "Simulators"), run-log.md ("Approvals", "Run setup")

---

### Cap the run at three live workers
A fourth lane was added when the user asked for a ticket right away, then the run held at three live workers; a fourth lane was refused again for T143.

**Rationale:** With four lanes and a merge build, load averages reached 560/887/393 on 12 cores and Orca timed out creating a worker terminal; swap reached 38.5 of 38.9 GB on 48 GB of RAM.
**Source:** run-log.md (2026-10-30 11:33, 11:49, 11:58, 16:27; 2026-11-01 09:25)

---

### Gate every phase with the full suite on one phone
A phase closed only after the whole unit and UI suite passed on the large gate phone and the widget built.

**Rationale:** Workers ran only their own suites; the gate catches what a change breaks elsewhere. Gate 1's first run caught F143 that way.
**Source:** dispatch.md (phase gates), run-log.md ("Phase gates"; 2026-10-30 19:15)

---

### Workers do not rebase for unrelated moves of main
When `main` moved after a worker's tested commit, by docs only or by code touching none of its files, suites or helpers, the worker reported its tested commit.
The coordinator's merge then rebased, built and reran what the move could affect.

**Rationale:** worker-rules' finishing rule makes a worker redo its required runs after any rebase that moves code, and `main` kept moving while they ran; T106 had to be told "do not rebase again".
**Source:** run-log.md (2026-11-01 05:19, 06:37, 07:03), worker-rules.md ("Finishing")

---

### Put data, correctness and test speed first at the prototype stage
After the user pushed `docs/DEVELOPMENT.md`, 14 accessibility, polish and verification tickets were deferred and marked skipped.
Live T120 (pixel polish) was stopped with its work kept on its branch, data-loss tickets jumped the lowest-id order, and new polish findings got one line in the run notes instead of a ticket.

**Rationale:** The screens are still being redesigned, so polish and AX3 fixes would be redone; data loss, wrong numbers and test speed are never deferred.
**Source:** run-log.md (2026-11-01 07:41), docs/DEVELOPMENT.md ("Deferred work")

---

### Keep only the UI tests that guard data
At the user's request, T143 kept a UI case only if it fails when the app loses, corrupts or misreports what the lifter saved or logged, plus one journey per workflow.
It deleted 351 of 424 cases: layout and text fit, AX3, dark mode, VoiceOver, looks, copy, tap targets and swipe sweeps.

**Rationale:** The UI tests took 179.8 of Gate 2's 180 minutes, mostly on checks the stage guide defers.
**Source:** run-log.md (2026-11-01 09:25, 11:11), docs/DEVELOPMENT.md (deferred-work row on UI tests)

---

### Merge external work through the coordinator only
Codex built five tickets outside the run (T110, T112, T141, T40, T41) and never pushed to `main`; a performance branch from the user's other session was merged the same way.
Their files stayed reserved as `<id>-ext`; the coordinator rebased or stacked each branch onto `main`, reran its required runs on a free lane and merged fast-forward.

**Rationale:** The plan has only the coordinator move `main`, and the user set the same rule for Codex.
**Source:** .planning/noble-wishing-conway.md ("Parallel lanes"), run-log.md (2026-10-30 21:47, 23:03; 2026-10-31 15:12, 15:20; 2026-11-01 08:13, 10:04, 10:10)

---

### Record autopilot calls with the options they rejected
Calls made while the user was away went into tradeoffs.md as the choice, each rejected option and why.
It holds 27 coordinator calls and answers; 13 are marked as decided under autopilot.

**Rationale:** The user can revisit each call without reconstructing the reasoning.
**Source:** tradeoffs.md

---

### Accept a small visible timing change to end the test stalls
T101's fix for F144 hides the tab bar when text editing begins, about 0.3 s before the keyboard, instead of inside the keyboard animation.

**Rationale:** Removing the bar inside UIKit's keyboard-show animation gave Core Animation unbalanced callbacks that left XCTest's idle counter at 1, which stalled UI tests.
**Source:** run-log.md (2026-10-31 14:03, 19:55)

---

### Fix a defect visible in code even when its symptom does not reproduce
T140's stale open-editor key was fixed although 20 throwaway rounds never showed the symptom, because the defect was in the code and the ticket named the rule.
T115, T122 and T133 changed no code when nothing was found.

**Rationale:** The symptom needs an object address to be reused, which is rare but real; a change with no defect in code to point to would be guesswork.
**Source:** run-log.md (2026-10-31 20:17; 2026-11-01 07:47, 11:23, 11:31, 12:40)

---

## Lessons

### Fix shared test stalls before feature tickets
F144 idle stalls took 107 of Gate 1's 201 minutes, and the Milestone 1 journey ran 2792.6 s before T101 and about 165 s after.
The coordinator kept the lowest-id rule instead of starting T101 early, and the stalls kept costing every worker and gate until it merged.

**Context:** The rule was kept because an investigation might find no fixable cause; the cost was flagged for the final report.
**Source:** run-log.md (2026-10-31 02:52, 14:03, 19:55, 23:20)

---

### A UI suite grows until it dominates every run
The UI target reached 87 suites and took 179.8 of Gate 2's 180 minutes.
After T143 and T119 it ran in 23.9 minutes on the small phone, and the gates fell from 182 to 40 to 29 minutes.

**Context:** Most deleted cases checked layout, AX3, copy and looks that the prototype stage expects to redo.
**Source:** run-log.md ("Phase gates"; 2026-11-01 09:25, 11:11, 16:15, 16:34)

---

### Simulator settings are shared state between tests
Hosted accessibility unit tests passed or failed by test order and by phone.
They needed the simulator's accessibility settings at 1, every UI session set them back to 0 (F358), and an earlier test's `accessibilityActivate()` had been loading UIKit's accessibility bundle for them (F374).
T134 turned accessibility on inside the test host instead.

**Context:** Setting the flags on each phone (F348) lasted only until the next UI run.
**Source:** run-log.md (findings F315, F348, F358, F374; 2026-11-01 08:43, 09:20, 13:11), worker-rules.md ("Known traps")

---

### Unit tests must not touch the app's own defaults
`SeedTests` and `IndexedQueryTests` removed the seed stamp from the simulator's defaults, which the test host shares with the app.
The next launch then re-seeded the catalog, which deleted every exercise and muscle group, and screens holding them crashed (F296).

**Context:** T128 moved the stamp into per-test defaults suites and made the re-seed update in place.
**Source:** run-log.md (finding F296; "Shared test helpers", T128; 2026-11-01 08:49)

---

### Match external branch names by pattern
Both external deliveries used the user's `Saechaoc/` branch prefix, and the watcher and the `ls-remote` check for the bare names missed them until the user pointed them out.

**Context:** The user had named the branches `conway-t110` and `conway-t141-ext`; they arrived as `Saechaoc/conway-t110-ext` and `Saechaoc/conway-t141-ext`.
**Source:** run-log.md (2026-10-31 15:12, 16:46; 2026-11-01 08:13, 10:04)

---

### Expect main to move outside the coordinator
The user's other sessions committed docs to `main`, a `git pull` in the main checkout rebased local commits onto origin, and a user push made the coordinator's push non-fast-forward until local `main` was rebased onto it.

**Context:** The coordinator pushes fast-forward only and rebases onto origin's new commits; it never force-pushes.
**Source:** run-log.md (2026-10-29 18:34; 2026-10-31 01:12; 2026-11-01 07:41, 14:26)

---

### Record a grant before accepting the ticket
The accept check flagged granted files as outside a ticket's ownership when the grant had been given in an answer but not recorded (T139, T134).
A ticket prepared on commits that were later rehashed showed another ticket's files the same way (T144).

**Context:** Recording the grant and running the accept check again cleared the flags; T144's flags went away when its rebase dropped the duplicate commits.
**Source:** run-log.md (2026-11-01 09:40, 13:11, 15:25)

---

### Give workers the evidence they need inside their worktree
Ticket hints that pointed at the main checkout's evidence folders conflicted with the workers' read boundary.
The prep step now copies each cited, settled ticket's evidence into the worktree read-only and lists it in the brief.

**Context:** Found when T120's hints cited main-checkout evidence.
**Source:** run-log.md (2026-11-01 07:16)

---

### Read a gate failure before blaming the change
Gate 1's first run failed on a test written for the small phone's layout, which the large gate phone rendered correctly (F143).
Gate 4's unit run hung because the simulator's test service never reported ready; it passed after a simulator reboot.

**Context:** Neither failure was in the code under test.
**Source:** run-log.md (finding F143; 2026-10-30 19:15; 2026-11-01 17:13)

---

## Patterns

### The coordinator loop
For each ticket: dispatch with a brief and standing notes; answer questions, recording each grant before replying; on `worker_done`, get stop proof, run the accept check, review the diff and screenshots, merge (rebasing and building if `main` moved), settle, push, archive the evidence, and route the findings.

**When to use:** Any multi-agent run where one owner merges to `main`.
**Source:** dispatch.md, run-log.md (merge notes throughout "Orca run")

---

### A findings ledger with one disposition each
Every observation outside a ticket's scope got an id (F1 to F388) and one disposition: a new ticket, a change or hint on an existing ticket, a tradeoff entry, an open question for the user, or a one-line note.

**When to use:** Long runs where workers keep finding problems outside their tickets.
**Source:** run-log.md ("New findings", "Ledger")

---

### Throwaway checks instead of new UI tests
After the UI cut, bug tickets proved their fix with an uncommitted UI check that failed before the change and passed after, recorded in their notes, and committed no new UI test (T123, T140, T144, T146).

**When to use:** UI bugs that do not threaten saved data.
**Source:** run-log.md (2026-11-01 11:31, 13:24, 15:25, 15:51)

---

### A shared registry of seeds and test helpers
Workers listed each new DEBUG seed flag and test helper in their notes, and the coordinator copied it into the run log so later briefs could point to it.
Examples: `-fitbod-seed-active-block`, T98's hosted-view walk, T134's `.hostedAccessibility` trait.

**When to use:** Many workers writing tests against the same app.
**Source:** run-log.md ("Shared test helpers")

---

### Stack external branches and retest them once
T141, T40 and T41 were cherry-picked onto `main` in one worktree, retested together (app build, unit target, their UI suites, widget build) and merged fast-forward in one step.

**When to use:** Several external branches that touch different files land at once.
**Source:** run-log.md (2026-11-01 10:04, 10:10)

---

### Rerun only what a move of main could affect
When a tested commit predated a move of `main` that could reach its screens, the coordinator ran the affected suites on the merged `main` before pushing and left the rest to the next gate.
T136 got its PR suite and one swipe-back case, T137 its repro and the PR suite, and T142 the whole unit target.

**When to use:** Merging under a no-rebase rule.
**Source:** run-log.md (2026-11-01 09:41, 10:13, 10:21)

---

### Isolated stores and defaults for persistence tests
A persistence test writes through one on-disk container in a temporary folder, releases it, and reopens the same file the way a launch does.
Its defaults live in a per-test suite that the test removes.

**When to use:** Any test of what survives a relaunch.
**Source:** run-log.md ("Shared test helpers", T128; 2026-11-01 12:40)

---

### The data-guard rule for UI tests
A UI case stays only if it fails when the app loses, corrupts or misreports saved or logged data.
That covers relaunch and persistence, saves, deletes, archive and restore, backup and export, a removal that asks first, logged weight and reps, counts, PRs, history built from logged workouts, and one end-to-end journey per workflow.

**When to use:** Deciding whether a new UI test is worth its time at the prototype stage.
**Source:** tickets/T143-ui-suite-keeps-data-guards.md (archived; in git at `b62b5ba`), run-log.md (2026-11-01 09:25), docs/DEVELOPMENT.md

---

### Tradeoff entries name the call, the rejected options and why
Each entry says what was chosen, each rejected option with its reason, and whether it was decided under autopilot so the user can revisit it.

**When to use:** Any decision made on someone else's behalf.
**Source:** tradeoffs.md

---

## Surprises

### The run found twice the work it started with
The bundle began with 48 tickets (T01 to T48) and ended with 146; the findings F1 to F388 produced most of the other 98.
The run took 384 commits and ended with 127 tickets done and 19 skipped.

**Impact:** Most of the run's tickets came from its own findings rather than the plan.
**Source:** run-log.md ("Ledger", "New findings"; 2026-11-01 17:14), the bundle at run base `dd098af`

---

### Codex joined although the plan ruled out other agents
The plan said no other agent, Codex included, would edit the repo or its worktrees during the run.
At the user's direction, Codex built five tickets outside it, and the user's other session supplied a performance branch.

**Impact:** The coordinator added an external-branch procedure (watch, review, rebase or stack, retest, fast-forward merge) and reserved those tickets' files.
**Source:** .planning/noble-wishing-conway.md ("Process"), run-log.md (2026-10-30 21:47; 2026-10-31 15:12, 15:20; 2026-11-01 08:13)

---

### Main stopped compiling on another Xcode
After T129 merged, `ProgressChartDescriptor.series` no longer type-checked on Xcode 26.5, while every build in the run passed.
Codex's external run found it, and its commit `37bca71` split the expression into typed steps.

**Impact:** Only a second toolchain caught it.
**Source:** run-log.md (2026-11-01 09:28, 10:04)

---

### A hang seen elsewhere could not be reproduced here
T115's AX3 scroll hang showed on the iOS 26.5 runtime, which this machine does not have; it has only iOS 27.0 and 27.1.
Three runs here passed, so T115 closed as not reproduced.

**Impact:** It stays an open question for the user.
**Source:** run-log.md (2026-10-31 17:00, 20:17)

---

### The user changed priorities through the repo
On 2026-11-01 at 07:31 to 07:36 the user pushed `docs/DEVELOPMENT.md` and a stage note rather than messaging the coordinator, and the coordinator replanned from the repo.

**Impact:** 14 tickets were deferred, a live ticket (T120) was stopped mid-work, and the dispatch order changed.
**Source:** run-log.md (2026-11-01 07:41)

---

### Agents stay busy after reporting done
The user's Ponytail review hook runs one more read-only review turn when a Copilot worker stops, so agents keep "working" for a few minutes after `worker_done`.

**Impact:** The coordinator waits for stop proof before touching a worker's worktree.
**Source:** run-log.md ("Orca run" setup notes)

---

### A catalog re-seed deleted the lifter's data
When the seed stamp fell behind, the importer deleted every exercise and muscle group and inserted them again.
That dropped custom exercises, edited weights and targets, and history's links to exercises (F296); a store already damaged that way still crashes at launch after the fix (F351).

**Impact:** Rated HIGH. T128 rewrote the importer to update in place, and repairing damaged stores is an open question for the user.
**Source:** run-log.md (findings F296, F351; 2026-11-01 08:49)
