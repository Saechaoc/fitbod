---
phase: 7
slug: program-graph-schema-v7-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-10
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`, `#expect`) for unit/model tests; XCTest for UI tests only |
| **Config file** | fitbod.xcodeproj (xcodebuild test plans) |
| **Quick run command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:fitbodTests/SchemaV7MigrationTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30` |
| **Estimated runtime** | quick ~90s; full ~8–12 min |

---

## Sampling Rate

- **After every task commit:** Run parse check (`find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse`) + quick run command when migration tests exist
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~720 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (filled by planner) | | | | | | | | | |

Key validation targets from spec §7/§9 (Phase 7 slice):
- Ghost-free splits picker post-migration (only auto-splits, archived hidden)
- Session→SessionTemplate ref remapping
- Rotation continuity backfill (active block's last completed session gets slot)
- templateName backfill + archive backfill presence
- Session.slot delete-rule = nullify (history intact)
- Slot-position contiguity invariant after reorder/add/remove
- Deny rule: template hard-delete while slotted
- Count-pin refresh: schemas.count == 7 / stages.count == 6 (SchemaV4MigrationTests + SchemaV6MigrationTests)
- Full Phase 1–6 regression sweep stays green after mechanical rename
