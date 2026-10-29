# Milestone 1 journey audit (2026-10-02, in progress)

Hands-on audit of the workout journey on the iPhone 17e simulator (fresh install, main @ 4f991f1).

## Fixed

- `BottomActionBar` stretched to full height and hid the whole routine builder (commit 4f991f1).

## Open: P0 (blocks the journey)

1. Pre-V7 stores crash at launch (`Inverse Relationship does not exist`). Debug session: `.planning/debug/pre-v7-store-launch-crash.md`. Cause: historical schemas V1-V6 reference live `@Model` types; they need frozen nested snapshots.
2. Program "+ New → New routine" opens the session builder and creates an orphaned `SessionTemplate`. It should create a `Split` and open `SplitDetailView` (spec section 8). Saved sessions appear nowhere.
3. A workout can only start through an active block. Nothing offers Start from a routine or session (Today, SplitDetailView). `RoutinesListView` has a start path but no screen reaches it.
4. `SessionHistoryView` is only linked from the unreachable `RoutinesListView`.
5. The standalone exercise library (browse, detail, custom exercise) has no entry point. Decision: adopt the reference IA, TODAY · PROGRAM · PROGRESS · LIBRARY, and push Settings from the Today header (reverses 3b0a2fa; document as an assumption).

## Open: routine builder

- `RoutineBuilderDayTabs` stretches vertically (same unbounded-separator bug).
- Disabled Save is unreadable (0.4 opacity) and bleeds into the home-indicator area.
- `4 DAYS / WK` and `~52 MIN` are hard-coded placeholder chips.
- The `•••` menu (Duplicate, Move, Delete) and add-day are no-ops.
- The name field is single line and truncates long names. The reference wraps.
- Stock iOS steppers and toggles inside the BRU card. The per-exercise "RPE autoreg" chip disagrees with the routine-level "Double progression" chip.
- Screen title says "New routine" but edits a session (glossary leak).

## Open: design system

- `.plain` buttons with `Spacer` but no `.contentShape` miss taps in their empty middle (`BRUDashedSlot`, `BRUSectionHead`, `BRUTabBar`, `ResumeWorkoutSlab`, `SessionExerciseCard`, and others; run `rg` for `buttonStyle(.plain)` and check each).
- `BRUFont` uses fixed `Font.custom(size:)`, so there is no Dynamic Type. Switch to `relativeTo:` and re-check layouts at large text sizes.
- The exercise library picker is a stock iOS List with no BRU styling, no title, and no cancel button.
- Today legend row has a stray partial-width black underline. The "NOT TRAINED" chip is almost invisible.
- The app icon is a generic placeholder "F".

## Open: workout logger (code audit 2026-10-02)

- `RestTimerOverlay` is never shown. Its countdown, ±15 s and Skip controls can't be reached.
- Rest timer state lives only in memory (`@State` engine) and isn't stored as an end time (deadline). It is lost when you leave the logger or the app is killed.
- No summary after Finish. History is unreachable and its rows can't be tapped. There is no session detail screen.
- The "Previous" column can show today's sets, because it doesn't exclude the current or unfinished sessions.
- You can't remove a set or un-complete one. The drag handle is decorative.
- The resume slab counts planned sets as "logged", and its elapsed time doesn't tick.
- Today's Discard deletes a session with logged sets without asking.
- `SessionFactory` links the exercise live and doesn't copy its name. `Session.template` and `templateName` are never written.
- Start errors are swallowed in `TodayView.startWorkout`.
- Custom exercise: there's no message for an empty name, and save failures are silent.

## Decisions

- Schema history reset (user decision, 2026-10-02): keep a single baseline schema, pass no migration plan, and move incompatible stores aside instead of deleting them.
- IA: TODAY · PROGRAM · PROGRESS · LIBRARY. Settings is pushed from the Today header.

## Workstreams

- A (orchestrator, branch m1-journey): design-system foundation (Dynamic Type, button states, hit areas, BRU form controls, docs, gallery).
- B (orchestrator, m1-journey): navigation (Library tab, routine creation, session detail with Start, Today session list, history and session detail).
- C (agent, own worktree): workout logger (rest-timer overlay and saved deadline, remove and un-complete set, Finish summary, Previous fix, name snapshot).
- D (debugger agent, main tree): persistence reset.

## Testing notes

- In the Simulator, the computer-use `type` action is dropped. Use `key` presses, or `pbcopy` plus cmd+V. Scroll by dragging.
- Helper scripts are in the session scratchpad: `bi.sh` (build, install, launch) and `try-store.sh` (load a backed-up store).
