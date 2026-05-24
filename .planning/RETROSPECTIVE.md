# Fitbod — Retrospective

Living record of milestone-level lessons. Append per milestone; cross-milestone trends section accumulates patterns.

---

## Milestone: v1.0 — Granular Lifting Tracker

**Shipped:** 2026-05-23
**Phases:** 7 (Phases 1–6 + 3.1 pivot) | **Plans:** 67 | **Commits:** 304 | **LOC:** ~29,500 Swift | **Timeline:** 13 days (2026-05-10 → 2026-05-23)

### What Was Built

iOS workout tracker for one serious lifter. Schema V1→V6 with full migration chain. Session-level intent + progression. Four progression strategies (RPE Autoreg, Double, Block-Periodized, Hybrid) routed via single factory. User-defined training blocks with phased mesocycles, scheduled deloads, block timeline on Today, end-of-block review. RP-style fatigue model with stimulus-weighted weekly volume, MEV/MAV/MRV bars + body silhouette heatmap + per-muscle drilldown. Plateau detection with stall flag + suggested action. Progress views (intent-split charts, PR feed, weekly tonnage, session comparison, weekly recap). CSV / JSON export + `.fitbodbackup` ZIP backup/restore with D-33 round-trip canary. 47/47 v1 requirements satisfied, ~616 unit tests passing.

### What Worked

- **Autonomous execution with checkpointed UAT.** /gsd:autonomous --from 3 ran Phases 3.1 → 6 + lifecycle in one session. Pausing for grey-area decisions (Phase 4 reconciliation, UAT validation) preserved user control without micromanagement.
- **Namespaced @Model types per VersionedSchema (Phase 3.1 BLOCKER 3 fix).** Apple's documented pattern resolved the schema-shared-class problem cleanly; round-trip test canary became the correctness gate.
- **SessionFactory snapshot pattern (PITFALLS #1) carried through all 7 phases.** Session-level intent (3.1), block snapshot (4), deload set-count cut (4) all extended the same snapshot at-start invariant without breaking it.
- **Type-level enforcement of BLOCK-08.** DeloadAdvisor.evaluate returns `DeloadAdvisory?` not `BlockMutation`. The compiler refuses any attempt to write Block state from the advisory. Phase 4 + Phase 5 + Phase 6 (BackupRestorer) all verified to obey.
- **Plan-checker iteration loop caught architectural blockers early.** Phase 3.1 BLOCKER 3 (shared @Model classes) would have shipped a broken migration if not caught at plan-review.
- **Phase 4 in-flight reconciliation.** User executed Phase 4 in parallel with Phase 3.1 across sessions; autonomous mode committed the in-flight work and ran reconciliation inline rather than discarding.

### What Was Inefficient

- **SourceKit phantom diagnostics noise.** Every executor agent re-encountered "Cannot find type X" false positives; resolved each time by trusting xcodebuild. Documented in memory but still recurring friction.
- **Test suite parallelization broke 3 SchemaV4MigrationTests** (SwiftData process-state across simulator clones). Pass in isolation; fail in full parallel run. Not blocking but adds noise.
- **2 phases shipped without phase-level VERIFICATION.md** (Phases 02 + 03 predate VERIFICATION practice). Audit flagged as gap; plan-level summaries cover the scope.
- **Stream timeout on Phase 6 mega-agent** after ~5 plans. Resolved by checkpointing committed progress + dispatching a continuation agent. Pattern: don't push >5 plans through a single agent.
- **25 UI behaviors deferred to post-milestone UAT.** Code+test verification confirms functionality; visual polish UAT batched for post-ship.

### Patterns Established

- **Wave-based plan execution with per-plan SUMMARY.md commits.** Each plan = atomic feat commits + SUMMARY.md commit. Phase becomes a clean linear history.
- **Plan-checker → revision loop, max 3 iterations.** Iteration 1: real architectural issues. Iteration 2: targeted fixes. Iteration 3 rare. Phase 3.1 needed 2.
- **Verifier as goal-backward gate (not pass-by-default).** `human_needed` status for UI-heavy phases routes to explicit UAT decision rather than auto-passing.
- **Schema bumps land BEFORE the field reshape.** Phase 3.1 introduced SchemaV4 typealiases (Plan 01) before removing fields (Plan 02). Phase 4 added Block.reviewedAt (V5). Phase 5 added 8 fatigue fields (V6). Each bump migrates cleanly.
- **Cascading wave dependency rule: `wave = max(deps) + 1`** enforced. Phase 3.1 plan-checker caught a Plan 05 violation that would have broken parallelism contract.
- **In-flight work reconciliation rather than discard.** When a phase has uncommitted work from a prior session, commit-as-is then route a reconciliation agent rather than replanning from scratch.

### Key Lessons

1. **Trust xcodebuild over SourceKit for this codebase.** Every executor agent needs this hint. Save as recurring memory.
2. **A "complete" phase without VERIFICATION.md is documentation tech debt, not a functional gap.** Audit can flag without blocking ship.
3. **MVP-mode goal format ("As a user, I want...") matters only if verifier expects it.** Phases 1–6 shipped with capability-statement goals; verifier proceeded against ROADMAP Success Criteria.
4. **Migration test fixtures need file-backed open-V(N-1) → reopen-as-V(N) pattern, not in-memory.** In-memory containers can't simulate the version-transition contract reliably.
5. **`/gsd:autonomous --from N` with user-interruptible decision points is the right cadence.** Pure-auto loses user input on grey areas; full-interactive doubles execution time.

### Cost Observations

- **Agent dispatching:** 12+ subagent dispatches across Phases 3.1, 4, 5, 6 + verifier + integration-checker
- **Stream timeouts:** 1 (Phase 6 mega-agent at plan #5) — recovered via continuation agent
- **Notable efficiency:** Single agent for 6-plan phases (5, 6 first batch) finished in 2–3 min/plan; smaller targeted plans (3.1) similar pace

---

## Cross-Milestone Trends

*(Populates after v1.1 ships. v1.0 sets the baseline.)*

### Velocity

| Milestone | Phases | Plans | Days | Plans/day |
|-----------|--------|-------|------|-----------|
| v1.0 | 7 | 67 | 13 | 5.2 |

### Test Discipline

| Milestone | Unit tests | UI tests | Coverage gaps |
|-----------|-----------|----------|---------------|
| v1.0 | ~616 | XCTest skeleton (no UAT yet) | 25 UI behaviors deferred |

### Tech Debt at Close

| Milestone | Integration warnings | UI deferred | Doc gaps |
|-----------|---------------------|-------------|----------|
| v1.0 | 5 | 25 | 2 (Phase 02 + 03 missing aggregate VERIFICATION.md) |
