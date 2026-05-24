---
phase: 02.1
slug: bru-visual-rewrite
mode: refactor
created: 2026-05-23
total_plans: 11
total_waves: 5
---

# Phase 2.1 — BRU Visual Rewrite (Core Loop): Plan Index

> Atomic, commit-sized plans that rewrite every Phase 2 user-facing surface to the BRU brutalist design system per `02-UI-SPEC.md` v2 (commit 4c1674b). Backlog sourced from `02-UI-REVIEW.md` (commit 7a1f142): 72 itemized migration tasks across 7 audit waves, condensed into 11 plans across 5 execution waves. Zero new functional requirements — all preserved Phase 2 + 3 + 3.1 + 4 + 5 + 6 behaviors must STILL PASS after each plan ships.

## Phase Goal

All Phase 2 user-facing surfaces (TodayView, RoutineBuilderView, SessionLoggerView, SessionHistoryView, RestTimerOverlay, IntentChip, SetTypeChip, PinnedNoteCapsule) render in the BRU brutalist design system: ink/paper/signal palette, Space Grotesk + JetBrains Mono fonts, sharp borders, no rounded corners, no Apple HIG defaults. Zero references to `Color.accentColor`, `Color.primary`, `Color(.system*)`, `.font(.body/.headline/.title*)`, `Image(systemName:)`, `RoundedRectangle(cornerRadius:)`, `Capsule()` clips, or `.buttonStyle(.bordered)` remain in Phase 2 surfaces.

## Wave Structure

| Wave | Plans | Theme | Parallel? |
|------|-------|-------|-----------|
| 1 | 02.1-01 | Foundations (color tokens + fonts + Info.plist + BRUFont enum + pbxproj wiring) | — |
| 2 | 02.1-02 + 02.1-03 | BRU primitive library (6 leaf + 9 composite — 15 total components under `fitbod/Design/`) | Yes (file-disjoint) |
| 3 | 02.1-04 + 02.1-05 + 02.1-06 + 02.1-07 + 02.1-09 | Independent surface rewrites (TodayView NEW; RoutineBuilder; RoutinesList; SessionLogger root; Rest timer + Live Activity) | Yes (file-disjoint) |
| 4 | 02.1-08 + 02.1-10 | Wave 3 dependents (SessionLogger sub-widgets; History views — both touch Wave 3 outputs) | Yes (file-disjoint within wave) |
| 5 | 02.1-11 | Cleanup + grep audit + UI tests + ROADMAP closure | — |

## Plans

| Plan | Wave | Objective | Files | Tests |
|------|------|-----------|-------|-------|
| 02.1-01 | 1 | 8 colorsets + `Color+BRU.swift` + 4 OFL fonts + `Info.plist UIAppFonts` + `BRUFont.swift` + pbxproj wiring | 18 (8 colorsets + 2 .swift + 4 fonts + 2 licenses + Info.plist + pbxproj + test) | BRUFoundationsTests |
| 02.1-02 | 2 | 6 leaf BRU primitives: BRUDivider, BRUChip, BRUDisplay, BRUReadout, BRUSectionHead, BRUButton | 6 .swift in `fitbod/Design/` + pbxproj + test | BRUCorePrimitivesTests |
| 02.1-03 | 2 | 9 composite BRU primitives: BRUHeaderBar, BRUTabBar, BRUSpark, BRUDashedSlot, BRUPillButton, BRUSupersetBracket, BRUCornerBadge, SetCompletionGlyph, BRUPhoneFrame | 9 .swift in `fitbod/Design/` + pbxproj + test | BRUCompositePrimitivesTests |
| 02.1-04 | 3 | TodayView NEW surface (extracted from 219-line inline `private struct` in RootView) + 7 sub-components | 8 .swift in `fitbod/Views/` + RootView edit + test | TodayViewBRUCopyTests |
| 02.1-05 | 3 | RoutineBuilderView + 5 component rewrites + 3 new files (BottomActionBar, RoutineBuilderDayTabs, SetRowsContainer) | 9 .swift in `fitbod/Routines/` + pbxproj + test | RoutineBuilderBRUCopyTests |
| 02.1-06 | 3 | RoutinesListView + RoutineRow + NewFolderSheet + MoveRoutineSheet rewrites | 4 .swift in `fitbod/Routines/` + test | RoutinesListBRUCopyTests |
| 02.1-07 | 3 | SessionLoggerView root + 6 core session sub-views (Card, SetRow, RPE chip row, DecimalRPE, SetTypeChip, IntentChip) | 7 .swift in `fitbod/Sessions/` + `fitbod/Views/` + pbxproj + test | SessionLoggerBRUCopyTests |
| 02.1-08 | 4 | 11 SessionLogger sub-widgets (sheets, rows, banners, PinnedNoteCapsule) + WorkoutHeaderToolbar NEW + wires WorkoutHeaderToolbar into SessionLoggerView | 12 .swift in `fitbod/Sessions/` + pbxproj + test | SessionWidgetsBRUCopyTests |
| 02.1-09 | 3 | Rest timer subsystem (RestTimerOverlay rewrite + RestTimerProgressRing→RestTimerProgressArc rename + 4 widget files: LiveActivity, LockScreen, DynamicIslandCompact NEW, DynamicIslandExpanded NEW) + InSessionPRBanner | 8 .swift across `fitbod/Sessions/RestTimer/` + `FitbodWidgets/` + test | RestTimerBRUCopyTests |
| 02.1-10 | 4 | ExerciseHistoryView + IntentFilterChipRow + ExerciseHistoryRow rewrites; PRStripFooter NEW; SessionHistoryView + SessionHistoryStatStrip + WeeklyTonnageSparkCard + SessionHistoryRow all NEW; wire SessionHistoryView into navigation | 8 .swift in `fitbod/ExerciseLibrary/` + `fitbod/Sessions/` + RootView edit + test | HistoryBRUCopyTests |
| 02.1-11 | 5 | Wave G grep audit + final cleanup (delete PlaceholderTabView.swift) + 3 UI snapshot tests + BRUGrepAuditTests guardrail + verify zero residual banned tokens | RootView + SessionLoggerView + RoutinesListView (small final edits) + 3 UI tests + 1 audit test | BRUGrepAuditTests + 3 UI tests |

## Audit Coverage Map

Every UI-REVIEW Backlog item (72 total across Waves A-G) is covered by one of these 11 plans:

| Audit Wave | Audit Items | Closing Plan(s) |
|------------|-------------|-----------------|
| A — Foundations | 1-9 | 02.1-01 (1-8) + 02.1-02 + 02.1-03 (item 9 — 15 primitives split across both) |
| B — TodayView | 10-17 | 02.1-04 |
| C — Routines | 18-30 | 02.1-05 (22-30) + 02.1-06 (18-21) |
| D — SessionLogger | 31-48 | 02.1-07 (31-36, 42, 48) + 02.1-08 (37-41, 43-47) |
| E — Rest timer | 49-54 | 02.1-09 |
| F — History views | 55-63 | 02.1-10 |
| G — Cleanup | 64-72 | 02.1-11 (64-70, 72) + 02.1-01 (71 — OFL attribution shipped in Wave A) |

## ROADMAP Success Criteria Coverage

| ROADMAP Criterion # | Description | Closing Plan(s) |
|---------------------|-------------|-----------------|
| 1 | 8 BRU color assets + Color+BRU.swift | 02.1-01 |
| 2 | 4 OFL fonts + Info.plist UIAppFonts + BRUFont.swift 7 roles | 02.1-01 |
| 3 | 15+ BRU primitive components under fitbod/Design/ | 02.1-02 + 02.1-03 (+ RestTimerProgressArc in 02.1-09 under `fitbod/Sessions/RestTimer/`) |
| 4 | TodayView in `fitbod/Views/TodayView.swift` (not inlined) with BRU composition | 02.1-04 |
| 5 | RoutineBuilderView, SessionLoggerView, SessionHistoryView rewritten to BRU mockup | 02.1-05 + 02.1-07 + 02.1-08 (SessionLogger) + 02.1-10 (SessionHistory) |
| 6 | RestTimerOverlay is full-bleed slab; SetTypeChip drops system colors; PinnedNoteCapsule drops yellow; IntentChip rebuilt as BRUChip | 02.1-07 (SetTypeChip + IntentChip) + 02.1-08 (PinnedNoteCapsule) + 02.1-09 (RestTimerOverlay) |
| 7 | Grep audit zero residual deprecated tokens + existing Phase 2 tests pass + UI snapshot tests | 02.1-11 |

## Dependency Graph

```
                              [02.1-01 Foundations] (wave 1)
                                       |
                       +---------------+----------------+
                       |                                |
            [02.1-02 Leaf Primitives]      [02.1-03 Composite Primitives]
                       |     (wave 2)              (wave 2)
                       |                                |
                       +-----+--------+-----+-----+-----+
                             |        |     |     |     |
                       [02.1-04] [02.1-05] [02.1-06] [02.1-07] [02.1-09]
                       Today    Builder   Routines  Logger    RestTimer
                                          (wave 3 — parallel within)
                             |        |     |     |     |
                             +--------+-----+--+--+-----+
                                              |     |
                                       [02.1-08]   [02.1-10]
                                       Logger     History
                                       widgets    views
                                               (wave 4)
                                              |     |
                                              +--+--+
                                                 |
                                          [02.1-11 Cleanup]
                                                 (wave 5)
```

## File-Ownership Sanity

Every plan's `files_modified` was audited for cross-wave overlap. Same-wave plans have ZERO file overlap (verified via per-wave grep). Cross-wave overlaps are intentional and documented in dependency chains (e.g., RootView is touched by 02.1-04 then 02.1-10 then 02.1-11 — each in a strictly later wave).

`pbxproj` is touched by all 11 plans (additive entry insertion only). Each plan's pbxproj task generates fresh 24-hex UUIDs to prevent collision. The `.bak` backup pattern in every pbxproj task ensures recovery on corruption.

## Out of Scope (Deferred)

Per UI-SPEC line 716-731:
- Phase 5 fatigue surfaces (heatmap, MEV/MAV/MRV bars) — deferred to a future Phase 5.1
- Phase 4 block surfaces (BlockBuilderView, BlockReviewView, BlockCard) — deferred to Phase 4.1
- Phase 6 progress chart surfaces (ExerciseProgressView, WeeklyTonnageView) — deferred to a future Phase 6.1
- Settings tab — deferred to a future revision (likely Phase 6 polish)
- Custom exercise editor — deferred to Phase 1 UI-SPEC revision

## Execution Notes

- Use `/gsd-execute-phase 02.1` to run all 11 plans in wave order.
- Each plan ships ≥1 commit per task (typically 2-3 commits per plan).
- Wave 5 (Plan 02.1-11) MUST complete before Phase 2.1 is marked complete in ROADMAP.md.
- After all plans complete, the grep audit in Plan 02.1-11 BRUGrepAuditTests should report zero residual deprecated tokens.
