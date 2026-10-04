# Chalkline components — design ↔ code

Every component drawn on the Claude Design canvas ("Fitbod · Chalkline
design system", **Components — states** board and the screen boards) has
exactly one SwiftUI implementation. This table is the contract between the
two: when a component changes, change both and keep the names aligned.

All components take tokens from [`ChalkTokens.swift`](../../fitbod/DesignSystem/ChalkTokens.swift)
(see [README.md](README.md)), scale with Dynamic Type, and have both an
Xcode `#Preview` and a live section in the in-app **Component gallery**
(Settings → Design system).

## Foundation components (`fitbod/DesignSystem/`)

| Design (canvas) | SwiftUI | File | Gallery section | Rules |
|---|---|---|---|---|
| Button / primary | `ButtonStyle.chalk(.primary, size:)` | `ChalkButtons.swift` | Buttons | The one next action per region. Accent fill, ink label. |
| Button / secondary | `.chalk(.secondary)` | 〃 | Buttons | Ink outline on surface. Alternate actions ("Add set", "Add exercises"). |
| Button / inverse | `.chalk(.inverse)` | 〃 | Buttons | Ink fill. Strong but not "next" ("Done" on the summary). |
| Button / ghost | `.chalk(.ghost)` | 〃 | Buttons | Text-only, for low-weight actions ("Skip warm-ups", "Clear"). |
| Button / destructive | `.chalk(.destructive)` | 〃 | Buttons | Danger outline; always behind a confirmation. |
| Button / on panel | `.chalk(.onPanel)` | 〃 | Rest timer | Raised controls on iron panels (−15 / +15, presets). |
| Button sizes | `size: .compact` 44 · `.regular` 50 · `.large` 56 | 〃 | Buttons | Large = thumb-zone bars. `fullWidth:` for bars and sheets. |
| Icon button | `ChalkIconButton(_:accessibilityLabel:style:action:)` | 〃 | Buttons | 44 pt; label is a required argument. |
| Chip (filter) | `ChalkChip(_:isSelected:extraCount:showsMenuIndicator:)` | `ChalkControls.swift` | Chips · Tags | Selected = ink fill + "+N". ▾ when it opens a picker. |
| Tag | `ChalkTag(_:style:)` (solid, outline, subtle, accent, onPanel) | 〃 | Chips · Tags | Non-interactive labels: intent, CUSTOM, NEXT. |
| Search field | `ChalkSearchField(text:prompt:)` | 〃 | Inputs | States the library size in its prompt; clear button; accent focus ring. |
| Text field | `ChalkTextField(_:text:prompt:error:isProminent:identifier:)` | 〃 | Inputs | Label above, error below with danger ring. |
| Validation text | `ChalkValidationText(_:)` | 〃 | Inputs / Messages | Icon + text, danger color. Never color alone. |
| Stepper | `ChalkStepper` / `ChalkStepperRow` | 〃 | Inputs | − value +, 44 pt targets; VoiceOver adjustable. Rows stack at large text. |
| Formatting | `ChalkFormat` (`duration`, `clock`, `weight`, `rpe`, `volume`) | 〃 | — | All numbers on screen go through these. |
| Screen header | `ChalkScreenHeader(_:overline:subtitle:trailing:)` | `ChalkContainers.swift` | (top of gallery) | Display title + 3 pt rule. |
| Section header | `ChalkSectionHeader(_:trailing:)` | 〃 | every section | Condensed caps + 1.5 pt rule. |
| Card | `ChalkCard(padding:emphasized:)` | 〃 | Panels · Metrics · Rows | Paper surface, hairline outline. |
| Panel | `ChalkPanel(padding:radius:)` | 〃 | Panels · Metrics · Rows | Iron = live state. Accessibility container. |
| Metric | `ChalkMetric(_:value:caption:onPanel:emphasis:)`, `ChalkMetricTile` | 〃 | Panels · Metrics · Rows | Label over monospaced number; one VoiceOver element. |
| Progress bar | `ChalkProgressBar(progress:onPanel:)` | 〃 | Rest timer | Accent fill; animation off with Reduce Motion. |
| Inline message | `ChalkInlineMessage(_:kind:)` (.error / .info) | 〃 | Messages · Empty state | Form-level summary ("Fix 2 things to save…"). |
| Empty state | `ChalkEmptyState(systemImage:title:message:primary…:secondary…)` | 〃 | Messages · Empty state | Dashed outline; always offers the next step. |
| Bottom bar | `ChalkBottomBar` | 〃 | — | Thumb-zone primary action via `safeAreaInset(edge: .bottom)`. |

## Domain components

| Design (canvas) | SwiftUI | File | Preview / gallery | Notes |
|---|---|---|---|---|
| Set row (open / next / error / completed) | `SetEntryRow` + `SetTableMetrics` | `Sessions/SetRow.swift` | `#Preview("Set rows")`, gallery "Set entry" | Single line: Set · Previous · Weight · Reps · RPE · ✓. Stacks when the row can't fit. Tap Previous to copy. |
| Exercise card in workout | `SessionExerciseCard` | `Sessions/SessionExerciseCard.swift` | Workout preview | Index badge, prescription line, ⋯ menu (swap, pinned note, plate math, skip warm-ups, remove), warm-ups, ruled column labels, Add set. |
| Workout header (panel) | `WorkoutHeaderPanel` | `Sessions/SessionLoggerView.swift` | Workout preview | Routine snapshot name, Elapsed / Sets / Volume, progress. |
| Rest dock | `RestTimerDock` | `Sessions/RestTimer/RestTimerOverlay.swift` | `#Preview("Rest dock")`, gallery "Rest timer" | Panel above the home indicator: countdown, −15 / +15 / Skip. Overtime flips to "Rest done +0:18". |
| Rest sheet | `RestTimerSheet` | 〃 | — | Big countdown, end time, presets 1:00–5:00, ±15 s. |
| Summary hero + recap | `WorkoutSummaryView` | `Sessions/WorkoutSummaryView.swift` | `#Preview("Summary — finished workout")` | Hero panel, per-exercise best set and delta vs last time. |
| Exercise row | `ExerciseRow(exercise:isSelected:)` | `ExerciseLibrary/ExerciseRow.swift` | `#Preview("Rows")` | Name (wraps) + "Equipment · Muscles"; CUSTOM tag; check circle in multi-select. |
| Filter bar | `ExerciseFilterBar` | `ExerciseLibrary/ExerciseFilterBar.swift` | Library preview | Muscle ▾ · Equipment ▾ · Custom · Clear. |
| Filter picker | `FilterPickerSheet` | `ExerciseLibrary/FilterPickerSheet.swift` | `#Preview("Muscle picker")` | Multi-select within a facet; Clear + Done. |
| Exercise picker | `ExercisePickerSheet` | `ExerciseLibrary/ExerciseLibraryView.swift` | — | Library in a sheet; multi-select adds in tap order; "Add N exercises" bar. |
| Routine row | `RoutineRow` | `Routines/RoutineRow.swift` | Routines preview | Name + "4 exercises · 14 sets · last done …"; Start button. |
| Builder exercise card | `RoutineExerciseCard` + `PrescriptionEditorRow` | `Routines/` | — | Collapsed summary line; expanded steppers for sets / reps / RPE / rest, intent, progression, advanced. |
| History row | `HistoryRow` | `History/HistoryView.swift` | `#Preview("History — demo")` | Day number, routine snapshot name, duration · sets · volume. |
| Resume card | `ActiveWorkoutCard` (Today), resume card (Routines) | `App/TodayView.swift`, `Routines/RoutinesListView.swift` | `#Preview("Today — demo history")` | Iron panel with Resume / Discard. |
| Prescription badges | `BumpBanner`, `CalibratingBadge`, `PinnedNoteCapsule` | `Sessions/` | their previews | Restyled phase-3 components. |

## Screens (canvas board → SwiftUI)

| Canvas board | SwiftUI screen | Preview |
|---|---|---|
| Library — populated + filtered | `ExerciseLibraryView` | `#Preview("Library")` |
| Library — no matches | `EmptyLibraryView` | `#Preview("With query that has no matches")` |
| Exercise detail — history | `ExerciseDetailView` | via app / UI tests |
| Custom exercise — validation error | `CustomExerciseEditor` | `#Preview("New exercise")` |
| Routines — empty | `RoutinesListView` | `#Preview("Routines — empty")` |
| Routine builder — validation error / editing | `RoutineBuilderView` | via app / UI tests |
| Routine detail — ready to start | `RoutineDetailView` | `#Preview("Routine detail — demo")` |
| Today — resume workout | `TodayView` | `#Preview("Today — demo history")` |
| Active workout — logging + rest / set error, rest sheet | `SessionLoggerView` (+ `WorkoutFlowView`) | `#Preview("Workout — in progress")` |
| Workout complete — summary | `WorkoutSummaryView` | `#Preview("Summary — finished workout")` |
| History — previous performance | `HistoryView`, `ExerciseHistoryView` | `#Preview("History — demo")` |

Screens marked "via app / UI tests" are covered by the screenshot tour in
`fitbodUITests/LayoutAuditUITests.swift` (see
[../verification.md](../verification.md)).

## Adding a component

1. Draw its states on the canvas (default, pressed, disabled, selected,
   error as relevant).
2. Implement it in `fitbod/DesignSystem/` using only tokens; give it an
   accessibility label/value/traits story and a `#Preview`.
3. Add a section to `ComponentGalleryView`.
4. Add a row to the table above.
