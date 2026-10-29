---
phase: 260610-g9d
plan: "01"
type: quick
status: complete
subsystem: periodization/new-block
tags: [swiftui, performance, gestures, drag-reorder]
key_files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
metrics:
  completed: "2026-06-10"
---

# Quick 260610-g9d: Fix phase-card drag-reorder jank

User report: drag movement "sorta snappy and slow."

## Diagnosis

1. **Spring leaked onto the finger-tracking row.** `.animation(spring, value: dragTargetIndex)` sat outside `.offset(y: reorderOffset(...))`, so every boundary crossing wrapped the lifted row's offset in a ~280ms spring — alternating instant/laggy tracking.
2. **Whole-screen invalidation per drag frame.** `dragOffsetY` was `@State` on the ~2000-line `BlockBuilderView`; every finger move re-evaluated the full body (name band, metrics, Swift Charts card).
3. **0.4s long-press arm** — sluggish vs platform-standard ~0.25s lift.

## Changes (orchestrator-implemented inline, diagnosis pre-done)

- Extracted `fileprivate struct NewBlockPhaseListSection` (same file — introspection guardrails intact): owns `draggingPhaseID`/`dragOffsetY`/`dragTargetIndex` + `movePhase`/`phasePitch`/`dropTarget`/`beginReorder`/`updateReorder`/`endReorder`/`gapOffset` + PHASES header + row ForEach + lift haptic. Parent passes `draft`, `onDelete`, `onAddPhase` closures; delete/undo toast + add-phase sheet stay parental. Per-frame drag invalidation now hits only this subtree. Side benefit: shrinks the body that blows the type-checker budget (open flag from 260610-fba).
- **Animation split:** sibling gap offset + scale inside the two spring `.animation` modifiers; lifted row's `dragOffsetY` offset applied *outside* them (plus `zIndex`). Held card tracks 1:1; siblings spring; drop settle still animates via `endReorder`'s `withAnimation`. `gapOffset` returns 0 for the active row.
- `updateReorder` writes `dragTargetIndex` only on actual change.
- `LongPressGesture(minimumDuration:)` 0.4 → 0.25.

## Commit anomaly (parallel session)

The working-tree edits were swept into the concurrent session's whole-file commit **7c4c169** (`fix(260610-g8d-01): remove discard-changes confirmation modal from New Block`) before this task could commit separately. Verified all g9d changes present at HEAD (`NewBlockPhaseListSection`, `gapOffset`, `0.25` arm) and merged state passes all suites. Transient build failure mid-task (`cannot find 'initialSnapshot'`) was that session's discard-flow WIP mid-flight, not g9d edits. History note: 7c4c169 is mixed-concern (discard-modal removal + drag perf).

## Verification

- Build + all 4 suites green post-merge: BlockBuilderViewCopy · NewBlockBuilderFidelity · BlockBuilderViewActivation · NewBlockProgressionChart.
- Drag feel (1:1 tracking, no boundary rubber-band, faster arm): pending human verify on device.

## R2 — row-local @GestureState drag (fa0bbbc)

User: still snappy/not smooth after r1. R1's animation split was correct but the dominant cost remained: per-frame `dragOffsetY` writes re-evaluated the whole section body (all rows × fresh closures → no body skipping), debug build amplifying it.

- Translation moved into `NewBlockPhaseEditorRow` as `@GestureState dragTranslation` — per-frame invalidation is now ONE card body. Auto-resets on end/cancel with a spring matching the drop settle.
- Row computes its own drop slot (`rowIndex`/`rowCount`/`reorderPitch` props) and reports only boundary crossings via `onReorderTarget(Int)` (renamed from `onReorderChanged(CGSize)`), gated by 0.55-pitch hysteresis — no gap flicker when hovering at a boundary.
- Section drops `dragOffsetY`/`updateReorder`/`dropTarget` and both `.animation(value:)` modifiers; lift/retarget/drop all animate via explicit `withAnimation` transactions (zero spring leakage onto the held card by construction).
- Build + all 4 suites green. Drag feel pending human verify — NOTE: simulator + debug build understate smoothness; judge on device or at least Release.
