# Today redesign 1.3: session sheet, StartSlot and state slabs

Archived 2026-11-10. Implementation scope for [RM-006](../../ROADMAP.md#rm-006)
is complete; the roadmap owns current status and follow-up triggers. These are
historical implementation notes, not a separate backlog.

**Delivered:** StartSlot/shared start routes, deterministic state seeds, the
session sheet/no-block hero, all Today state slabs and obsolete Today entry-point
removals. SchemaV7 and logged snapshots are unchanged. Volume summary (RM-010),
Program layout (RM-011), review notice (RM-013), next-day lines (RM-014), and broader
accessibility/release checks were excluded. The shared `.template` builder route
was retained because Program's live template cards still call it; its migration
belongs to RM-011.

**Build:** slices 1–4 landed as `0c9135be`, `9bb0a087`, `ca3ec867`, and `0b1ac37e`;
slices 5–6 are delivered by the commit containing this archive, rebased from
`0b1ac37e` onto `7615f5f4` (workout progression).
**Results:** the final unit target passed 1,291 tests with one expected failure.
The full tier enumerated and ran 1,384 tests, with no missing/repeated tests and a
successful widget build. Its only UI failure was an obsolete “No active block”
assertion; the corrected block lifecycle class passed 2/2 on 2026-11-10. All 92 UI
tests have passing evidence across that run and the focused correction. A final
44pt touch-area correction to READY’s Open button passed the unit target and all
six state-route tests (1,297 passed, one expected failure), including a tap near
the Open control’s top edge. Integration on `7615f5f4` then passed 1,298 unit
tests with one expected failure, six state routes, and the author/relaunch/history
journey after correcting its scroll-view index race. The 390pt/default first, done, ready, rest,
repair and attach captures were inspected in light/dark. The sheet title wraps
to two readable lines; long names, AX3 and physical VoiceOver remain at stability
(RM-044/RM-047), not acceptance claims of this archive. Detailed output remains in
ignored local artifacts; RM-006 records the concise run references.

The notes below were reconciled on 2026-11-08 before implementation. Their original
GSD/executor, fixed simulator, fixed commit-count and capture-commit mandates were
retired by the current development policy.

Read [AGENTS.md](../../../AGENTS.md), [CLAUDE.md](../../../CLAUDE.md),
[DEVELOPMENT.md](../../DEVELOPMENT.md), [SETUP.md](../../SETUP.md)
and [ARCHITECTURE.md](../../../ARCHITECTURE.md) before implementation.
Approved design detail: [hierarchy](../../design-map/redesign/hierarchy.md),
[Today layouts](../../design-map/redesign/today-layouts.md),
[Program layouts](../../design-map/redesign/program-layouts.md) and
[RM-042 O-1–O-16](../../ROADMAP.md#rm-042). Later approved calls win.

## Outcome and boundaries

One NEXT rule makes the hero, alternate-session sheet, Program starts and
session detail credit the same slot. Every Today state draws its intended
piece, with one alternate-session ghost row and no Today block creation.

Included: StartSlot/state suggestion, shared starter/detail callers, session
sheet/grouping, done/ready/rest/fix/attach/pick/first slabs, removal of obsolete
picker/start controls, deterministic DEBUG seeds and affected caller/tests/docs.
SchemaV7 and frozen workouts remain unchanged. Volume summary RM-010, Program
layout RM-011, resume row RM-012, review notice/acknowledgement RM-013, next-day
lines RM-014 and broader accessibility/release work are excluded.

Steps 1.1/1.2 are shipped (RM-057/RM-058). Resolve RM-001–RM-005 safeguards only
where the changed paths depend on them; unrelated planning/development can
continue. Required phone observations in RM-007/RM-008/RM-045/RM-046 do not gate
this feature. No new schema work occurs here; future schema work requires RM-029.

## Approved behavior to preserve

- Rotation NEXT is the resolver's next slot. Weekday NEXT is today's slot
  before a counted workout started today, otherwise the next training day's
  slot; on a rest day use that next training slot, or nil if absent.
- With no block, anchor after the newest finished slotted workout in
  the routine, wrap and skip empty sessions. Open, unslotted, deleted-slot
  and other-routine workouts do not move that anchor.
- A twice-slotted session takes NEXT when it matches, otherwise its first
  matching slot after NEXT, wrapping. With no NEXT, use its first live slot.
  Outside the active routine starts are unslotted. Recompute/revalidate at the
  actual start, including detail-open then slot deletion.
- T-PICK chooses the eligible live routine holding the newest finished slotted
  workout, then the routine holding the most recently updated usable session,
  then a usable standalone session. Archived routines cannot drive the choice.
- The sheet has Cancel, one row per distinct session in each routine in first-slot
  order, usable NEXT only, disabled empty routine rows and Other sessions opening
  detail for preview/repair/start. Rotation/no-block skips are explained;
  weekday rows skip nothing. Rows wrap to content with 44pt minimum targets.
- T-DONE lists all finished counted workouts started today, newest first, and
  outranks ready. **O-15:** it is paper on paper in both appearances, replacing
  the interim dark slab. Captions omit unknown duration/zero PR counts.
- T-READY starts the oldest-created ready block in one tap, with date/count and
  actionable failure/retry/Open. T-REST says Rest day. Fresh store T-FIRST has
  only the first-routine prompt; no-block T-FIX has repair and no volume surface.
  Block repair/T-ATTACH retain another-session access when any usable session exists.
- Remove Today block-creation/empty-workout entry placeholders, StartBlockCTA,
  obsolete picker/choice presentation and unused conflict alert. Remove shared
  helpers only after all real callers are migrated. A usable standalone session
  still trains through T-PICK/detail; don't turn removal into a template requirement.
- **O-16:** every start/resume uses the existing Today-owned logger routing,
  including Program/session/Live Activity. Back lands on Today. Another session
  takes two taps from T-TODAY; a mistaken empty start costs Back then Discard.
- Keep existing shared PR/history/count rules and base session summary counts.
  No new source-reading copy tests, inert fields or silent saves.

## Implementation sequence

1. Inspect current callers/fixtures/config and run GitNexus upstream impact for
   every existing symbol before changing it. Report direct callers/processes/risk;
   warn on HIGH/CRITICAL and refresh a stale index. Keep unrelated edits intact.
2. Add pure StartSlot rules/tests; wire suggestion into TodayState. Reuse existing
   counted-workout/calendar helpers and deterministic ordering. No model fetches
   in the pure helper and no persistence mutations during view rendering.
3. Wire the starter and detail/Program callers to the shared rule, computing the
   slot at tap time. Preserve start failure/rollback and already-in-progress routing.
   Keep any old helper until its callers migrate so intermediate changes compile.
4. Build the testable sheet grouping and content, then slabs/ghost/first prompt;
   integrate Today as one state switch. Migrate Today and UI-test entry paths
   before removing the old picker, empty-start helper or obsolete controls.
5. Add ready-only, empty-session and done-today seeds; add a reviewed-ended-block
   variant only if needed to isolate T-PICK. Anchor every finished-today/set stamp
   between local midnight and launch, with set stamps within workout bounds.
6. Run appropriate checks below, update affected current references and record
   concise commands/build/results/limitations in RM-006. GitNexus detect_changes
   is required before any eventual commit. No push is implied by these notes.

Likely reach: `WorkoutStarter`, `TodayState`, `TodayView`, `BlackSlabCTA`,
`DoneTodaySlab`, `ReadyBlockCard`, `TodaySessionPicker`, `BlockSessionChoiceSheet`,
`StartBlockCTA`, `SessionTemplateDetailView`, `SplitDetailView`, new sheet/slot/slab
pieces and DEBUG seed callers. Reinspect real signatures; the old line numbers,
file lists and fixed fixture counts were not a contract.

## Verification and completion

Unit cases: rotation/weekday/no training day; duplicate/deleted/empty slots;
wrap/skips; newest counted no-block anchor; archived/standalone candidates;
most recently updated usable-session fallback; two consecutive no-block starts;
two finished-today workouts and Done-over-ready; ready ties and failed start.
Keep all route callers on the same environment calendar.

Run the unit target, then affected existing start/resolver/factory/journey UI
checks serially on dedicated simulators. Retained suites include TodayStateTests,
WorkoutStarterTests, TodayHeroUITests, BlockLifecycleEntryPointsUITests,
NewBlockSavesUITests, EditorSwipeDismissUITests, MilestoneOneJourneyUITests,
SessionHistoryBRUUITests and ArchiveRoutineUITests where their entry paths change.
For affected Program behavior, keep NewBlockBuilderFidelityTests,
ProgramViewFidelityTests and AdaptiveColorSourceTests. Adapt obsolete assertions;
add focused slot/state logic coverage and data-protecting start/relaunch checks,
not source-reading copy tests or an arbitrary new test count.

Inspect changed 390pt/default states in light and dark, including the sheet,
standalone/empty routines, repair escape, ready failure, multiple done workouts,
rest/attach and the two-tap mistaken-start recovery. Save captures/logs to CI
artifacts or ignored local output; record what was actually inspected in RM-006.
The full tier belongs to a large main-merge check/release trigger, not every
prototype step. It pins default/light and does not establish AX3/dark coverage.
Physical accessibility/ergonomics return at the owning workflow's stability trigger.

Done requires RM-006's agreed scope working, appropriate checks passing and docs
updated, without routine personal sign-off. If a required external observation
is unavailable, record Implemented; verification pending with that exact check
in RM-006 and continue independent work. Move this finished implementation plan
to `docs/archive/features/` with historical scope/build/results and RM backlink;
archive placement cannot close an unobserved device claim.
