---
phase: quick-261029-nse
plan: "01"
status: complete
subsystem: docs
tags: [orca, retries, evidence, provenance]
requires: []
provides: [Fresh retry briefs through invariant loaders, Explicit accepted evidence bindings]
affects: [Conway dispatch, worker contracts, run ledger]
tech-stack:
  added: []
  patterns: [Immutable worktree briefs, Ledger-selected input aliases]
key-files:
  created: []
  modified:
    - docs/conway-specs/dispatch.md
    - docs/conway-specs/worker-rules.md
    - docs/conway-specs/run-log.md
key-decisions:
  - "Native retries reuse the stored loader, not cached attempt metadata."
  - "Accepted dependencies, failed/resume inputs and coordinator snapshots remain distinct."
patterns-established: [Per-attempt brief archival, Required-file input validation]
requirements-completed: [F1, F2]
duration: 5min
completed: 2026-10-30
commit: 859d89ab1f5f52a2048d284c08c82b534090443b
followup_commit: cb7e341
---

# Phase quick-261029-nse Plan 01: Retry Briefs and Accepted Inputs Summary

**Invariant task loaders now read fresh immutable worktree briefs, while consumers receive provenance-checked evidence at unchanged ticket paths.**

## Atomic task

- Completed 1/1 documentation task in the existing checkout.
- Commit: `859d89ab1f5f52a2048d284c08c82b534090443b` — `docs(261029-nse): fix retry briefs and accepted evidence bindings`.
- Follow-up commit: `cb7e341` - `docs(261029-nse): allow tour retries without saved coverage`.
- Both commits change only the three implementation paths above, with no file deletions.
- Preserved prior ownership, safe settlement, split completion and rerun/refresh contracts.

## Validation

- `python3 -I docs/conway-specs/capacity_model.py`: exit 0; 48 tickets, 0 errors, one pre-existing `fitbodUITests/SkipWarmupsUITests.swift` warning.
- `git diff --check` and `git diff --cached --check`: passed.
- Read-only contract assertions: passed; sole ordered loader, no embedded attempt metadata, consistent binding roles, and unchanged safety/ownership/split/rerun sections.
- `npx --no-install gitnexus detect-changes --scope staged --repo fitbod`: exit 1, `No indexed repositories found`.
- GitNexus was unavailable, not a passing analysis; no install or reindex attempted.
- Fallback: reviewed complete staged name list, exact-three-path stat and full diff; no unrelated staged files/hunks or source-symbol edits.
- Repeated the validator, whitespace check and staged GitNexus/manual scope check for the two-document early-failure refinement; results remained 48 tickets, 0 errors and the same warning, with the index still unavailable.

## Documentary walkthroughs

- Native failed/stopped retry: safely settle, prepare fresh worktree/brief with current attempt/base/output/mode/failure/inputs, skip task-create, reuse the exact stored loader with `--retry-of`.
- Rejected success: safely settle, create a new task with the same loader, launch without `--retry-of`; neither task-update nor combined task/spec flags refresh metadata.
- Accepted/settled T40-r2: T41 receives local `evidence/T40/{notes.md,delete-paths.md}`; T47 receives `evidence/T40/closeout-statement.md`; failed T40 and accepted T40-r2 archives remain intact.
- T31: bind `export-diff.md` and every required named snapshot when a newer export is reported; T47 also enumerates its required backup/verification reports and captures.
- Refusal: missing required source/copied files, incorrect provenance, failed/rejected/unsettled dependencies, or missing/contradictory/worktree-mismatched briefs stop launch/work; nonempty folders and cached prompts are not fallbacks.
- T46 exception: its own safely settled FAILED evidence is copied to local T46 as `failed/resume`, not accepted dependency; resume only from complete saved configuration coverage while retaining the full 33-screen/eight-configuration/264-image obligations.
- Early T46 failure: no completed configuration or incomplete saved coverage means no resume binding and a full restart from the first configuration; missing failed-attempt files do not block that retry.
- Partial T46 reruns remain separate from the accepted full tour; T47 selects applicable accepted per-pair coverage, never substitutes a partial tour.
- Run-log copies remain coordinator snapshots with source/run/time provenance, not accepted producers.
- Brief, input aliases and snapshot stay frozen; resolved escapes and equal/ancestor/descendant collisions with each other or output are rejected.
- Settlement archives the exact frozen brief in the unique attempt archive; the reserved filename and prior archives are preserved.

## Deviations and limitations

A final scenario check added the early-failure restart rule above to preserve retryability when T46 has no usable saved coverage.
Validation was documentary/static only: no Orca actions, workers, simulators, branches/worktrees, pushes or runtime evidence files were created.
No unintended stubs or out-of-plan threat surfaces were found; template fields are intentionally filled only for real launches.
STATE updates and the planning-artifact commit remain with the parent; this summary is intentionally uncommitted.

## Self-Check: PASSED

Verified all three docs and this summary exist, both implementation commits exist and touch only the three scoped docs, and their staged checks contained no unrelated files.
