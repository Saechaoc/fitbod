# Milestone 1 closeout

The deliverable is the native SwiftUI/SwiftData app, its BRU design system,
reproducible simulator evidence and a roadmap for the remaining release work.
**Final acceptance is open; no commits or push have been made.** The latest
complete run has 973 passing unit-test identifiers, one expected SwiftData
failure, and four UI failures. Corrections are prepared but cannot be rerun
under the current sandbox. See [VERIFICATION.md](VERIFICATION.md) for exact
counts, screenshots, reproduction commands and environment failures.

## Work still required to close this milestone

Since 2026-11-01, item 2 belongs to release readiness, not to this milestone;
see [the development guide](DEVELOPMENT.md#release-readiness).

1. Rerun the numeric replacement, workout menu and weight explanation fixes,
   then the complete unit/UI suite.
2. Pass the full authored journey on both 17e and 17 Pro Max at AX3; the 17e
   logger/gallery/History/swap passes do not replace this requirement.
3. Complete GitNexus refresh, review each exact staged commit group, run
   `detect_changes(scope: staged)` before every commit, then push the already
   authorized main. The current sandbox blocks CoreSimulator/macro execution,
   global GitNexus registry writes and repository metadata writes.

## Delivered behavior

- Search and combine muscle/equipment filters, create a validated custom
  exercise, author ordered sessions, edit targets and start a workout.
- Log weight/reps, complete or undo sets, add/delete sets, edit notes, adjust
  or skip rest, resume after relaunch, finish and reopen immutable history.
- C8: the swap picker has one header. A swap persists in the active workout
  while finished history retains its original exercise.
- C9: Previous excludes the current and other unfinished workouts.
- C10: workout names and prescriptions remain frozen after upstream edits.
  Disk-backed tests release containers and reopen SQLite to verify persistence.
- History is reachable from Today → Sessions and Progress → Workouts.
  Settings opens from the Today header; native tab containment excludes
  inactive tabs from accessibility without discarding their navigation state.
- BRU tokens, components, gallery and native app icon are documented. Large
  text uses wider header actions, two-column tabs, vertical Today statistics,
  stacked logger inputs and scrollable rest controls.
- Volume rows use readable count/zero-state colors and a shared axis. Cropped
  simulator evidence includes trained and untrained muscles.

## Product choices retained and open flags

| Flag | Current behavior / limit | Next action |
| --- | --- | --- |
| Units | Settings changes labels, not stored numbers. Exercise unit overrides win. No canonical-unit conversion is implied. | Add per-set unit provenance and an explicit conversion policy before mixing unit systems. |
| First-log PRs | The first record in every intent/rep-range/kind bucket counts as a PR. Early workouts can show a large badge such as PR × 19. Badges count record kinds per exercise, not unique exercises or sets. | Decide whether establishing a baseline should be celebrated as a new record. |
| Deload signal 3 | Requires three finished sessions and excludes the workout being logged. Locked D-14 semantics count misses below the top of the rep range. | Decide whether misses should instead mean below the bottom of the range. |
| Weekly volume | Calendar-week presentation now says THIS WEEK. The summary sums weighted muscle contributions, so a compound set can contribute more than once. | Decide whether to rename the aggregate or display physical working-set count. |
| Week boundaries | FatigueModel still uses fixed-second offsets for weekly boundaries. | Replace them with calendar arithmetic and test daylight-saving transitions. |
| Transient targets | Missing-target fallbacks link transient SwiftData models to persisted muscles during rendering. This is a review risk, not a reproduced data-loss claim. | Prove rendering performs no insertion; prefer immutable fallback values. |
| Logger density | Default rows remain approximately 143pt tall; accessibility inputs stack. | Design compact rows while preserving touch targets and context. |
| Block Review | EXPORT is currently static header text; the PR summary remains a placeholder. | Finish both with the block-program journey. |
| Secondary accessibility | Core labels/targets and selected large-text surfaces are checked. Full large-text authoring is still open. Secondary analytics need combined history/PR readouts and missing-value announcements; heatmap absent/below-MEV distinction needs review. | Complete milestone journeys, then include secondary screens in the next feature pass and physical VoiceOver traversal. |
| Physical device | Simulator tests do not establish physical VoiceOver, haptics, notification permission denial or Dynamic Island/lock-screen lifecycle. | Complete physical-device release checks. |
| Backup / sync | Local export/backup surfaces exist; populated restore on a second installation is unproven. No account or cloud sync is included. | Verify populated restore before relying on it; define sync ownership separately. |
| Offline proof | Core catalog and workout operations use local data; optional images may use the network. An explicit network-disabled journey has not been run. | Verify optional-image fallbacks and the full journey with networking disabled. |
| Schema baseline | SchemaV7 is the sole baseline. Incompatible SQLite stores and siblings are moved aside recoverably, not migrated. | Keep recovery distinct from historical-schema migration. |
| SwiftData deny | One known-issue test deliberately avoids a hard-delete operation that can abort the test process. Schema metadata is checked separately. | Resolve runtime enforcement before claiming it is proven. |
| Pattern filter | Hidden because the seeded catalog has no usable pattern metadata. | Curate metadata before exposing it. |
| Unwired routines view | RoutinesListView remains reachable through previews/source tests rather than the main journey. | Review it before reusing or removing it. |
| CI on main | Existing workflow triggers are claude/** pushes, PRs and manual dispatch. A direct main push does not automatically run CI. | Keep local evidence explicit; extend triggers deliberately if desired. |
| Toolchain diagnostics | Earlier complete runs include nonfatal text-concatenation deprecations and an LLDB version diagnostic. The latest sandbox attempt cannot launch macros or simulator services. | Rerun in a normal Xcode session; keep environment failures distinct from test failures. |

## Visible and repository changes to know

- The four tabs are Today, Program, Progress and Library. Settings as a Today
  sheet reverses the earlier Settings-tab choice and is easy to change later.
- The tab bar hides in the logger and while the keyboard is visible.
- Signal CTA labels are black for contrast; the accent color is neutral.
  Removed Settings rows had no working behavior.
- “Per week” reports observed frequency; it replaces the unsupported adherence
  percentage. Real adherence requires a schedule-based denominator.
- Resume-slab Discard confirms when completed sets exist; the logger menu's
  Discard always confirms. Summary uses one bottom Done action.
- The old schema-history commits were squashed; the backup branch is
  `archive/frozen-schema-history`.
- PR #1 was recorded through an ours merge; only its CI workflow was ported
  into the local app. It did not replace the native implementation.
- GitNexus can rate shared SwiftUI changes CRITICAL because module import edges
  fan out widely. Those ratings are disclosed, not treated as proof that every
  referenced function changes behavior. The latest all-worktree scan reports
  667 changed symbols and 75 flows; staged checks are still pending.
- The commit plan uses exact task-owned paths and no Co-Authored-By trailer.
  Unrelated planning, reference-design and tooling changes are explicitly
  excluded. [Commit groups](verification/closeout/commit-plan.md) are prepared;
  the first staging attempt was denied at `.git/index.lock`. The index remains
  empty; nothing was committed or pushed.

The next feature priorities and acceptance criteria are in [ROADMAP.md](ROADMAP.md).

The [portable BRU review](../.lavish/milestone-1-closeout.html) presents the
evidence and all 18 product/release flags. It matches the project design system.
Lavish could not start its preview server, so no live review link or browser
layout-validation result is available.
