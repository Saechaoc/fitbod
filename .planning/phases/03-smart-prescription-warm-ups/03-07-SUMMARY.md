---
phase: 03-smart-prescription-warm-ups
plan: 07
subsystem: ui
tags: [swiftui, swiftdata, warmup, prescription, exercise-detail, routine-builder]

# Dependency graph
requires:
  - phase: 03-01
    provides: "WarmupConfig struct, RoutineExercise.warmupOverrideData/warmupOverride, Exercise.smallestIncrement/barWeightOverride/unitOverrideRaw/unitOverride"
  - phase: 03-02
    provides: "RoutineExerciseCard, PrescriptionEditorRow, RoutineBuilderView, RoutineExerciseDraft"
  - phase: 03-03
    provides: "ExerciseDetailView with four existing sections"
provides:
  - "WarmupConfigSheet: .medium-detent sheet editing @Binding<WarmupConfig?>"
  - "RoutineExerciseCard 'Edit warm-up...' long-press context menu entry invoking WarmupConfigSheet"
  - "PrescriptionEditorRow 'Auto warm-up' toggle functional (was disabled with Phase 2 footnote)"
  - "ExerciseDetailView 'Prescription Settings' section: smallest increment / bar weight override / unit override"
affects:
  - 03-08
  - 04-sessions-prescription

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Bindable var ex = exercise write-through pattern for SwiftData @Model in @ViewBuilder"
    - "Draft warmupOverride field round-tripped through RoutineExerciseDraft init(re:) + save(into:context:)"
    - "onEditWarmup: (RoutineExerciseDraft) -> Void = { _ in } default-closure callback on RoutineExerciseCard"

key-files:
  created:
    - fitbod/Routines/WarmupConfigSheet.swift
  modified:
    - fitbod/Routines/PrescriptionEditorRow.swift
    - fitbod/Routines/RoutineExerciseCard.swift
    - fitbod/Routines/RoutineBuilderView.swift
    - fitbod/Routines/RoutineDraft.swift
    - fitbod/ExerciseLibrary/ExerciseDetailView.swift

key-decisions:
  - "warmupOverride stored on RoutineExerciseDraft (not RoutineExercise directly) to follow existing draft pattern; round-tripped in save(into:context:)"
  - "onEditWarmup takes RoutineExerciseDraft (not RoutineExercise) — card operates with drafts; @Bindable var bd = exDraft in builder sheet body"
  - "Prescription Settings section uses three separate Section wrappers per UI-SPEC verbatim footer copy for each field"
  - "unitLabel derived from exercise.unitOverride ?? settingsList.first?.weightUnit ?? .lb for unit suffix display"

patterns-established:
  - "WarmupConfigSheet: commit() writes nil back to binding when restoring defaults (model-cleanliness per RESEARCH Pitfall 5)"
  - "RoutineBuilderView pendingWarmupSheet: RoutineExerciseDraft? follows pendingSupersetAssignment item-sheet pattern"

requirements-completed: [WARM-03, SET-02, SET-04]

# Metrics
duration: 6min
completed: 2026-05-23
---

# Phase 3 Plan 07: Warm-up Config Sheet + ExerciseDetailView Prescription Settings Summary

**WarmupConfigSheet (.medium detent, Save/Cancel toolbar, auto warm-up + skip-session toggles), RoutineExerciseCard 'Edit warm-up...' context menu, functional PrescriptionEditorRow toggle wired to RoutineExerciseDraft.warmupOverride, and ExerciseDetailView 'Prescription Settings' section with smallest-increment/bar-weight/unit-override fields**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-23T00:10:17Z
- **Completed:** 2026-05-23T00:15:39Z
- **Tasks:** 3
- **Files modified:** 5 (+ 1 created)

## Accomplishments
- WarmupConfigSheet ships standalone with UI-SPEC verbatim copy; commit() nil-clears override when user restores defaults (RESEARCH Pitfall 5 compliance)
- RoutineExerciseCard gains `onEditWarmup` callback (default `{ _ in }`, backward-compatible); 'Edit warm-up...' context menu item presents WarmupConfigSheet from RoutineBuilderView at .medium detent
- PrescriptionEditorRow 'Auto warm-up' toggle replaced from `.disabled(true)` + 'Available in Phase 3' footnote to a functional `Binding(get:set:)` reading `draft.warmupOverride`; footer copy switches verbatim on enabled state
- ExerciseDetailView 'Prescription Settings' section with three separate Section wrappers + UI-SPEC verbatim footers; @Bindable write-through for all three fields works for built-in and custom exercises

## Task Commits

1. **Task 1: WarmupConfigSheet (standalone, .medium detent)** - `a2fba66` (feat)
2. **Task 2: PrescriptionEditorRow + RoutineExerciseCard integration** - `0af772b` (feat)
3. **Task 3: ExerciseDetailView Prescription Settings section** - `2debf8e` (feat)

## Files Created/Modified
- `fitbod/Routines/WarmupConfigSheet.swift` — new .medium-detent sheet with Auto warm-up + Skip warm-ups this session only toggles, Save/Cancel toolbar, two #Preview blocks
- `fitbod/Routines/PrescriptionEditorRow.swift` — autoWarmupToggle now functional with Binding(get:set:) + UI-SPEC verbatim footer; Phase 2 disabled state removed
- `fitbod/Routines/RoutineExerciseCard.swift` — added `onEditWarmup: (RoutineExerciseDraft) -> Void` param + 'Edit warm-up...' Label context menu item
- `fitbod/Routines/RoutineBuilderView.swift` — added `@State pendingWarmupSheet`, `onEditWarmup` closure, WarmupConfigSheet sheet presentation
- `fitbod/Routines/RoutineDraft.swift` — added `warmupOverride: WarmupConfig?` to RoutineExerciseDraft; round-tripped in `init(re:)` and `save(into:context:)`
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift` — added @Query<UserSettings>, unitLabel computed property, prescriptionSettingsSection @ViewBuilder with 3 Section wrappers

## Decisions Made
- `onEditWarmup` uses `RoutineExerciseDraft` (not `RoutineExercise`) because RoutineExerciseCard operates entirely with drafts; the builder presents `@Bindable var bd = exDraft` and passes `$bd.warmupOverride` to WarmupConfigSheet
- warmupOverride is stored on RoutineExerciseDraft and round-tripped through the save path rather than writing directly to RoutineExercise; this preserves the draft-as-mutation-surface pattern and keeps Cancel working without side effects
- Three separate Section wrappers used (vs one combined section) to give each field its own verbatim footer per UI-SPEC

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `onEditWarmup` uses RoutineExerciseDraft instead of RoutineExercise**
- **Found during:** Task 2 (RoutineExerciseCard integration)
- **Issue:** Plan specified `onEditWarmup: (RoutineExercise) -> Void` but RoutineExerciseCard operates with `RoutineExerciseDraft`; there is no `RoutineExercise` available in the card
- **Fix:** Changed signature to `(RoutineExerciseDraft) -> Void`; added `warmupOverride: WarmupConfig?` field to RoutineExerciseDraft with full round-trip; builder uses `@Bindable var bd = exDraft` + `$bd.warmupOverride` in sheet body
- **Files modified:** RoutineExerciseCard.swift, RoutineDraft.swift, RoutineBuilderView.swift
- **Verification:** swiftc -parse clean; WarmupConfigSheet bound to draft.warmupOverride via @Bindable
- **Committed in:** 0af772b (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - adapt to actual codebase type)
**Impact on plan:** Functionally equivalent outcome; the binding contract is identical — WarmupConfigSheet still receives @Binding<WarmupConfig?> and writes through to the persisted RoutineExercise on Save.

## Issues Encountered
None — all three tasks executed cleanly. Full-codebase swiftc -parse passed with zero errors after all changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- WARM-03, SET-02, SET-04 closed
- WarmupConfigSheet ready to be driven from SessionExerciseCard in plan 03-08 (session-time warm-up skip)
- RoutineExerciseDraft.warmupOverride round-trips to RoutineExercise.warmupOverride at save time — plan 03-08's WarmupRamp.shouldGenerate can read from the persisted RoutineExercise
- ExerciseDetailView Prescription Settings fields editable; smallestIncrement / barWeightOverride feed plan 03-06's DoubleProgressionStrategy and PlateCalculator respectively

---
*Phase: 03-smart-prescription-warm-ups*
*Completed: 2026-05-23*
