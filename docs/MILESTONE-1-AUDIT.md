# Milestone 1 requirement audit — 2026-10-05

The native SwiftUI/SwiftData app is the deliverable. **Final acceptance is open:**
current UI failures and restricted execution prevent a clean closeout. Source,
verified behavior and pending work are distinguished below. Exact results and
commands are in [VERIFICATION.md](VERIFICATION.md); all flags are in
[MILESTONE-1-CLOSEOUT.md](MILESTONE-1-CLOSEOUT.md).

| Requirement | Implementation / evidence | Status |
| --- | --- | --- |
| Preserve stack and supplied reference | SwiftUI, SwiftData, Charts and ActivityKit; BRU assets and design exports retained. [Screen contracts](CORE-SCREENS.md). | Implemented |
| Documented visual foundation | Semantic light/dark colors, Dynamic Type roles, touch/layout metrics, native icon. [Design system](design-system/README.md); 19 contrast pairs pass. | Verified within documented scope |
| Reusable components and real gallery | DEBUG Today → Settings → Developer → Component gallery; native buttons, inputs and timers, previews. AX3 gallery passes. | Verified |
| Library search/filter/custom exercise | Local filtering, no-match/clear paths, validated custom exercise and detail. Latest authored run reaches builder prescription editing. | Initial steps verified; full journey pending |
| Routine/session ordering and editing | Unsaved draft retained through nested pickers, Move up/down, sets/reps/rest targets; AX3 name moves into scroll content. Numeric test interaction fixed after failure. | Final rerun pending |
| Logger operations and rest recovery | Six explicit UI cases cover logging, add/delete/undo, discard, finish, rest/background/relaunch; units cover persistence and validation. | Completed recorded passes; final source rerun pending |
| C8: swap header and persistence | Single picker header; active workout changes survive relaunch while completed history retains original exercise. Swap passes at 17e AX3. | Verified |
| C9: previous performance exclusion | Current/unfinished sessions excluded; focused unit tests in full suite. | Verified |
| C10: immutable snapshots | Disk reopen plus upstream name/prescription edits, session/block snapshot suites. | Verified |
| New History and Settings entry points | Today Sessions, Progress Workouts, Today Settings sheet; native tab containment prevents inactive-tab controls leaking into accessibility. Both History/Today AX3 cases pass. | Verified |
| Core accessibility and icon | Complete large-text header/tab names, stacked statistics/logger inputs, 44pt controls, rest controls, labels and contrast; 1024px native icon inspected. | Core checks pass; physical and secondary pass open |
| Weight explanation | Real sheet tests exposed long-press/editor competition. Simultaneous gesture and named accessibility action prepared. | Unverified correction |
| Full authored journey, both specified phones at large text | 17e AX3 latest fails numeric replacement; no current Pro Max AX3 full authored pass. Earlier default-size journeys are historical. | **Open** |
| Full unit suite | 973 passing test identifiers, 1 expected SwiftData runtime-issue test. No unexpected unit failures in completed run. | Recorded pass; final changes need rerun |
| Full UI suite | 48 identifiers pass, 4 fail; 51/55 invocations including launch variants. | **Open** |
| Setup, verification, roadmap and flags | [Setup](SETUP.md), [verification](VERIFICATION.md), [roadmap](ROADMAP.md), [closeout](MILESTONE-1-CLOSEOUT.md). | Updated |
| Grouped commits and push main | Exact path groups prepared; unrelated files excluded. Current sandbox makes repository metadata read-only. | **Blocked; no commits or push** |

## Evidence limits

- Simulator trees/screenshots do not establish physical VoiceOver navigation,
  haptics, notification denial, or lock-screen/Dynamic Island lifecycle.
- Token checks cover approved combinations, not all rendered analytics screens.
- SchemaV7 recovery preserves incompatible stores; it does not migrate them.
  Populated restore to a second installation remains unproven.
- Local core behavior needs no backend; a deliberate network-disabled journey
  and optional image fallback audit are still release checks.
- The `.deny` expected failure is intentionally not runtime enforcement proof.
- No skipped or failed test is reported as a pass. New fixes are not validated
  by older passing bundles.
