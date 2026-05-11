# Phase 1 — Deferred Items (Out-of-Scope Discoveries)

Items found during plan execution that are out of scope for the current plan and have been stashed, noted, or routed to a later plan.

## Discovered during 01-PLAN-00-01 execution (2026-05-10)

### Item 1 — AccentColor / AppIcon asset catalog edits appearing in working tree (RESOLVED)

**Found:** While executing 00-01, the working tree repeatedly showed modifications to:
- `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json`
- `fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Untracked `scripts/generate_app_icon.swift`
- Untracked `fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

These files kept reappearing after each stash because a parallel agent was concurrently executing plan **01-PLAN-00-02**, which owns the AccentColor + placeholder AppIcon work.

**Why it was out of scope for 00-01:** Plan 01-PLAN-00-01's "Out of Scope" section explicitly states:
> "Populating `AccentColor.colorset` → handled by `01-PLAN-00-02`."

**Resolution:** Plan **00-02** has now landed in commit `a1df0f3` (`chore(01-00-02): wire AccentColor #0E7C86/#3FBFC9 + placeholder AppIcon`). My stashes contained intermediate snapshots of the same content that 00-02 ultimately committed, so all four stashes were dropped after confirming the final commit captured the work.

**Coordination note:** Plans 00-01 and 00-02 ran in parallel (both are Wave 0, sequence 1 vs 2). They have no file overlap by design — 00-01 owns the pbxproj, Item.swift deletion, and folder scaffold; 00-02 owns the asset catalog + AppIcon generator. No conflict actually occurred; the working-tree thrash was just the parallel agents updating disk in interleaved fashion. Both landed cleanly.

**Action for future executors:** None. The work is committed.
