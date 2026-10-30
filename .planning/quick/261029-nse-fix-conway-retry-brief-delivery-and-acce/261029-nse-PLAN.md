---
phase: quick-261029-nse
plan: "01"
type: execute
wave: 1
depends_on: []
autonomous: true
date: 2026-10-30
branch_name: null
workflow: {use_worktrees: false}
requirements: [F1, F2]
files_modified:
  - docs/conway-specs/dispatch.md
  - docs/conway-specs/worker-rules.md
  - docs/conway-specs/run-log.md
must_haves:
  truths:
    - "Native retries reuse an invariant task loader but receive the current immutable worktree brief."
    - "Consumers read explicitly selected accepted, safely settled evidence through unchanged local ticket paths."
    - "Failed-resume inputs and coordinator snapshots remain distinct from accepted dependency evidence."
  artifacts:
    - {path: docs/conway-specs/dispatch.md, provides: "Correct launch, binding, retry and archival instructions"}
    - {path: docs/conway-specs/worker-rules.md, provides: "Authoritative brief and immutable input rules"}
    - {path: docs/conway-specs/run-log.md, provides: "Per-attempt brief and input-binding provenance"}
  key_links:
    - {from: "Stored Orca task loader", to: "docs/conway-specs/evidence/attempt-brief.md", via: "Worker-local read before every attempt"}
    - {from: "Ledger-selected producer archive", to: "Consumer-local evidence alias", via: "Coordinator copy and required-file validation before launch"}
---

<objective>
Fix review findings F1/F2 from 65c02ae/e66830c through concise edits to three existing docs, not a protocol redesign.
Purpose: deliver fresh retry metadata and correct accepted producer evidence without changing consumer tickets.
Output: one atomic docs-only implementation. Baseline HEAD: e66830cdaf571512d98bc374a64fb54e16c2fb50.
</objective>

<execution_context>
@~/.copilot/get-shit-done/workflows/execute-plan.md
@~/.copilot/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@AGENTS.md
Read only dispatch.md Start/Retry/Settle, worker-rules.md opening/Evidence, and run-log.md Ledger under docs/conway-specs/.
Read-only path checks: docs/conway-specs/tickets/T41-backup-keeps-routines.md Hints line 84; docs/conway-specs/tickets/T47-verification-docs.md Change step 6.
Discovery level 0: existing documentation patterns; CLI constraints supplied and verified by parent. No research/discussion/checker, new tooling, or historical STATE reads.
</context>

<tasks>
<task type="auto">
  <name>Task 1: Correct retry brief delivery and accepted input bindings together</name>
  <files>docs/conway-specs/dispatch.md, docs/conway-specs/worker-rules.md, docs/conway-specs/run-log.md</files>
  <action>
  1. For F1, move/relabel the existing task-header template as the sole worktree brief template; retain every current field, add the retry failure note there, and name the base ticket path for local reading. Store ONLY an invariant loader instruction in task-create --spec: read worker-rules, then docs/conway-specs/evidence/attempt-brief.md in this worker's worktree, then its named base ticket. Remove inline brief/ticket concatenation; no attempt-specific identifiers, output paths or previous brief belong in the stored spec.
  2. Document every launch as fresh worktree, freshly persisted coordinator-written brief, copied/validated inputs, then launch. The fixed brief is worker-read-only and immutable throughout that attempt. Missing, contradictory or launch/worktree-mismatched briefs stop execution; never fall back to cached prompt metadata. Settle archives that exact brief as evidence/<attempt id>/attempt-brief.md alongside that attempt's output before authorized cleanup, preserving prior archives.
  3. In Retry, explicitly skip task-create when reusing a failed/stopped task; retain worker-start --task <existing task> --retry-of <dispatch> --worktree path:<new worktree> and existing agent flags. Rejected succeeded results require a new task containing the same invariant loader and launch without --retry-of. task-update cannot change specs, and worker-start --task/--spec are alternatives; neither is a metadata-refresh workaround. Preserve retry limits, modes and failed scope.
  4. For F2, replace the brief's input-folder field with explicit bindings: consumer-local relative alias -> selected producer attempt archive, tested/delivery commits (delivery absent when none), and exact required files. Select accepted AND safely settled dependency sources from the ledger, not directory recency. Copy into fresh stable aliases in EACH consumer worktree, validate source provenance and every required file before launch, and freeze inputs for the attempt. Refuse missing, mismatched, rejected, failed or unsettled dependencies; folder non-emptiness is insufficient.
  5. Apply bindings consistently to T31 export-diff.md and named snapshots, T41's T40 notes.md/delete-paths.md, and T47's T40 closeout-statement.md plus its other required reports/captures. Explicit example: failed T40 followed by accepted/settled T40-r2 means local evidence/T40/ contains T40-r2 reports for T41/T47. Keep literal ticket paths unchanged and both producer archives intact in main; never rename/overwrite archives, use external symlinks, or silently choose the newest directory.
  6. Preserve original T46 retry's exceptional binding from its own safely settled failed attempt to local evidence/T46/, labeled failed/resume input, never accepted dependency evidence. Retain its full-tour resumption/coverage obligations and keep accepted full-tour evidence distinct from partial reruns. Label evidence/run-log.md as a coordinator snapshot, not an accepted producer task. Reject escaping or equal/ancestor/descendant path collisions among aliases, the fixed brief, run-log copy and current output folder; reserve the archived brief filename.
  7. Align worker-rules opening/header references and Evidence with the loader, local base-ticket read, immutable inputs and fail-closed checks. Update existing Ledger paragraphs to retain brief location/archive and each binding's role, source attempt, acceptance/settlement, commits, required files and local alias; record snapshot provenance without inventing producer acceptance. Preserve all prior safety, ownership, rerun, settlement and split policies.
  8. Keep edits concise and confined to these three docs. Do not create an actual attempt-brief.md, duplicate its template, edit tickets/risks/capacity model/changelog/project instructions/earlier quick artifacts, change Swift/Python, or run Orca/simulators/worktree operations. Parent owns STATE updates and final plan/summary commit.
  </action>
  <verify>
    <automated>python3 -I docs/conway-specs/capacity_model.py</automated>
    <automated>git diff --check</automated>
    Expect 48 tickets, 0 errors, and only the pre-existing SkipWarmupsUITests.swift warning.
    Documentary walkthroughs, not operational runs:
    - Failed/stopped native retry skips task-create and receives new attempt/output/failure metadata through the unchanged loader; rejected-success retry creates a new task without --retry-of.
    - Accepted/settled T40-r2 supplies T41/T47's stable T40 aliases; failed original archives remain intact. Missing required files or failed/unsettled dependency sources block launch.
    - Original T46's failed/resume exception retains full coverage obligations; if no configuration completed or saved coverage is incomplete, omit the resume binding and restart the full tour. Partial reruns never replace the full tour. Run-log snapshots remain separately classified.
    - Missing/mismatched briefs stop; frozen brief/input paths cannot collide with each other or outputs; settlement archives the exact brief.
    Before the implementation commit, stage only the three scoped docs and attempt:
    <automated>npx --no-install gitnexus detect-changes --scope staged --repo fitbod</automated>
    Parent verified no index exists: record the unavailable result, not a passing analysis; do not analyze/install. No source symbols change.
    Docs-only fallback: review the complete outputs of git diff --cached --name-only, git diff --cached --stat -- docs/conway-specs/dispatch.md docs/conway-specs/worker-rules.md docs/conway-specs/run-log.md, and git diff --cached -- docs/conway-specs/dispatch.md docs/conway-specs/worker-rules.md docs/conway-specs/run-log.md. Require exactly those staged paths and no unrelated hunks; do not unstage others' work.
    <automated>git diff --cached --check</automated>
  </verify>
  <done>Both findings are resolved consistently across the three docs; every walkthrough passes, validator results match baseline, and staged-scope/GitNexus fallback evidence is recorded.</done>
</task>
</tasks>

<threat_model>
Trust boundary: coordinator archives/metadata -> worker-local brief and input copies.
| Threat ID | STRIDE | Component | Disposition | Mitigation |
|---|---|---|---|---|
| T-261029-nse-01 | Tampering | Brief/aliases | mitigate | Freeze inputs, reject path collisions/escapes, stop on missing/mismatched metadata. |
| T-261029-nse-02 | Spoofing | Dependency provenance | mitigate | Ledger-selected accepted/settled sources, explicit commits/files, labeled exceptions. |
| T-261029-nse-SC | Tampering | CLI tooling | mitigate | --no-install only; no analyze/install; exact-path staged fallback. |
</threat_model>

## Source coverage audit
| Source | ID | Scope | Plan/task | Status |
|---|---|---|---|---|
| GOAL | Quick request | Fresh retry metadata and correct accepted inputs | 01/1 | COVERED |
| REQ | F1, F2 | Both supplied review findings; no phase requirement IDs | 01/1 | COVERED |
| RESEARCH | — | Not requested; no research artifact/dependencies | — | N/A |
| CONTEXT | User request | Three-doc scope, exceptions, policy preservation, validation and parent ownership | 01/1 | COVERED |

<verification>
Require the task's automated checks, all documentary walkthroughs and complete staged scope review; no operational execution.
</verification>
<success_criteria>
Only the three implementation docs change; unchanged native task loaders deliver fresh briefs and immutable, provenance-checked consumer aliases without weakening existing policies.
</success_criteria>
<output>
Create .planning/quick/261029-nse-fix-conway-retry-brief-delivery-and-acce/261029-nse-SUMMARY.md with changes, walkthrough/check results and the unavailable GitNexus fallback. Leave STATE and final plan/summary commit to the parent.
</output>
