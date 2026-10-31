# Worker rules

These rules are part of every ticket in this bundle.
The stored task spec is an invariant loader: read these rules, then the authoritative `docs/conway-specs/evidence/attempt-brief.md` in your worktree, then the local base ticket file it names.
Every brief/header reference below means that on-disk brief, never cached task-prompt metadata.
The brief identifies the attempt and mode, and only its explicit rerun/refresh fields override the base ticket and generic commit instructions.
Protected paths, safety rules and every other applicable constraint remain in force.
Original work and its retries retain the base ticket's implementation and acceptance requirements.
Before work, check the brief's worktree/branch and dispatch base against your actual root/branch and initial HEAD.
If the brief, named ticket or required input is missing, contradictory, launch/worktree-mismatched or unclear about an override, stop and ask the coordinator; never fall back to an old spec, cached prompt or previous brief.
The coordinator writes a fresh brief before every launch, including native retries; it and all supplied inputs are read-only and immutable during your attempt.

## Your job

You implement, verify or refresh one ticket under its effective brief.
Do only its permitted actions within its effective ownership and scoped acceptance.
The base ticket is reference where the brief explicitly overrides it.
For implementation work, the ticket says what must be true when you finish, not how to write the code.
You choose the code, but it must follow `CLAUDE.md` and these rules.
When the effective brief or an applicable base-ticket instruction is unclear, ask the coordinator with Orca `ask` before you guess.
The review the tickets cite, with items 1 to 47, is `docs/review-docs/fitbod-m1-review.md`.
Product decisions are in [decisions.md](decisions.md).
Engineering calls are in [tradeoffs.md](tradeoffs.md).
Do not reopen either one.

## Workflow exception

The project `CLAUDE.md` says to start edits through a `/gsd-*` command.
This run replaces that workflow with these tickets and [run-log.md](run-log.md).
Your on-disk brief says whether the user approved this exception.
If that brief does not say so, ask the coordinator before you edit any file.
Never run a `/gsd-*` command yourself.

## Workspace

- Work in your own ticket worktree, on the branch Orca made for it.
  Run `git rev-parse --show-toplevel` first: that is your worktree root, and every repo path in your ticket is relative to it.
- Read and write only inside your worktree, apart from your phones, your DerivedData folder and your scratchpad.
  Copilot CLI asks before it changes files outside its folder, and nobody is there to answer.
- Never touch the main checkout.
  Only the coordinator works there and moves `main`.
- Never create, switch or delete a branch or a worktree.
- Other workers run at the same time, each in its own worktree.
  Your on-disk brief lists their tickets and the files they own or hold.
- For original work/retries, before editing outside effective `owns`, ask the coordinator and wait for a yes, even for a UI test your change broke, a test that pins copy, or `docs/ROADMAP.md`.
  This narrows the original Ownership section because another worker may be editing that file.
- Read-only T44/T45/T46 verification reruns have effective `owns: []` and write evidence only, with no tracked edits, staging, commits or edit grants.
  Docs refreshes may edit only their explicitly listed document/image paths and cannot widen scope through a generic ask.
- If the coordinator replies "wait", finish and commit any other authorized changes, then ask again; it answers only after the file is safely freed.
  After the yes, follow Finishing's conditional rebase, so you edit the newest version of the file, and commit the authorized edit.
- If your on-disk brief says lane "gate", no other code worker runs beside you.
  Follow the effective brief, not overridden base-ticket permissions; the gate exception never allows verification edits or expands refresh scope.
- Stage only authorized files you changed in commit-capable work.
- Before starting work, including read-only verification, save `git status --porcelain` to `status-before.txt` in your evidence folder.
- New Swift files need no project file edit, because the targets use folder-synchronized groups.
- A path in `owns` that starts with `new:` is a file you create.
  If that file already exists, another effort made it, so add to it, keep its tests, and say so in `notes.md`.

## Files you must never edit or stage

These paths belonged to the user or another terminal when this bundle was written:

- `.planning/config.json`, `bru-screens/block-builder.jsx`, `bru-screens/routine-builder.jsx`
- `.claude/CLAUDE.md`, `.claude/skills/gitnexus/`, `.ignore`, `.mcp.json`, `.planning/graphs/`
- `.planning/quick/260528-c6i-extract-reusable-blocknamefield-swiftui-/`, `.planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/`, `.planning/quick/260610-jag-verify-and-fix-screen-width-overflow-for/screenshots/`, `.planning/quick/training-block-spec/spec.md`
- `.repowise/`, `AGENTS.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `graphify-out/`
- `bru-screens/New-block/`, `bru-screens/New-modal/`, `bru-screens/create-flows.jsx`, `bru-screens/discard/`, `bru-screens/routines-list.jsx`, `bru-screens/routines-modals.jsx`

These paths are protected for every ticket:

- Any changelog file, including `docs/design-system/changelog.md`.
- `CLAUDE.md`, `AGENTS.md`, everything under `.claude/`, `.planning/`, `.gitnexus/`, `.repowise/` and `graphify-out/`.
- Everything under `build/`.
  It holds local Xcode output, and git ignores it.
- Everything under `bru-screens/`.
  These are read-only design references.
- `fitbod.xcodeproj/project.pbxproj` and `.gitignore`.
- Everything under `docs/conway-specs/` except your own evidence folder, which git ignores.
- `.lavish/`, except paths authorized by T48's effective brief.

Xcode sometimes drops `parallelizable = "NO"` from `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme`.
If `git status` shows that scheme changed and your ticket did not ask for it, restore it from `HEAD` before you commit.

## Simulators

Use only the two phones your on-disk brief names, always by id:

| Phone | Width | Ticket `sim` value |
|---|---|---|
| Your lane's iPhone 17e, such as "sw6-L1 iPhone 17e" | 390pt | `small` |
| Your lane's iPhone 17 Pro Max, such as "sw6-L1 iPhone 17 Pro Max" | 440pt | `large` |

- An exclusive ticket gets the gate phones instead: "sw6 iPhone 17e" and "sw6 iPhone 17 Pro Max".
- Never use any other device: no other lane's phones, the personal iPhone 17 Pro, any `fitbod-codex-*` device, or the quick-task run's `sw6-hcv` and `sw6-uhg` phones.
- Pass phones to `xcodebuild` and `simctl` by id, never by name, because every lane has phones of the same models.
- Run one simulator job at a time.
- Your ticket's `sim` field says where the repro runs: `small`, `large`, `both`, or `none`.
- Unit tests always run on the large phone.
- Before your first run and again before you finish, set both phones to default text and light mode with `xcrun simctl ui <id> content_size large` and `xcrun simctl ui <id> appearance light`.
- For a dark mode run, use `xcrun simctl ui <id> appearance dark`.
- For a whole run at AX3, use `xcrun simctl ui <id> content_size accessibility-extra-large`.
  For a single AX3 test inside a normal run, use the AX3 launch option from T01.

## Build and test

- Build into the DerivedData folder your on-disk brief names, never into another lane's folder or the default one, because two builds in one folder block each other.
- Your worktree starts with no build products, so your first build is a full build; start it in the background.
- Put result bundles in your own scratchpad, with your ticket id and a counter in the name, for example `T08-after-2.xcresult`.
- Build the app with `xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination "platform=iOS Simulator,id=<id>" -derivedDataPath <DerivedData> build CODE_SIGNING_ALLOWED=NO`.
- Run tests with the same command, plus `-parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath <bundle>`, with `test` in place of `build`.
  Without `-collect-test-diagnostics never`, a run with any failure or known issue waits up to ten minutes in `simctl diagnose` before it writes its bundle.
- Choose tests with one `-only-testing:` flag each, for example `-only-testing:fitbodTests` or `-only-testing:fitbodUITests/NewBlockModalUITests`.
- Build the widget with the `FitbodWidgetsExtension` scheme and the same flags.
- Save each full log to a file in your scratchpad and read only the summary lines, because xcodebuild output is huge.
- Read results with `xcrun xcresulttool get test-results summary --path <bundle>` and `xcrun xcresulttool get test-results tests --path <bundle>`.
- Export screenshots with `xcrun xcresulttool export attachments --path <bundle> --output-path <folder>`.
- One shell call can run for at most ten minutes.
  Start any run that may take longer in the background, and wait for its completion notice.
  Keep sending Orca heartbeats while you wait.
- The app's DEBUG launch flags are `-fitbod-reset-store`, `-fitbod-seed-demo-workout` and `-fitbod-start-program`.
  Use the T01 launch helpers instead of passing flags by hand.

## Required runs

Every ticket that changes app or test code does these runs:

1. Write the repro test first.
   Run it and watch it fail for the reason your ticket describes.
   Save the failure summary to `repro-fail.txt`.
2. Make the change, then rerun the repro test until it passes.
3. Run the whole unit target, `fitbodTests`, on the large phone.
4. Run every UI suite your ticket names, and every existing UI suite whose files you changed, on each phone your ticket's `sim` names.
5. Build the app and the widget.
6. Save every passing summary, with its result bundle path, to `after-pass.txt`.

One expected failure is allowed in `fitbodTests`: `ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement`, which is a known issue.
Any other failure counts as unexpected.
Runs 3 to 5 must cover your final commit, after its rebase onto `main`; see Finishing.

## Tests that pin copy and structure

Some unit tests read source files and pin exact copy, struct names or patterns.
Examples are `BRUGrepAuditTests`, `ProgramViewFidelityTests`, `RoutinesListCopyTests`, `PRsAndComparisonCopyTests`, `WeeklyTonnageViewCopyTests` and the six New Block guardrail suites.

- If your ticket changes pinned copy on purpose, update the test in the same commit so it pins the new copy.
- If one of them fails for any other reason, your change is wrong.

The six New Block guardrail suites are `BlockBuilderViewActivationTests`, `BlockBuilderViewCopyTests`, `BRUPeriodizationAuditTests`, `BRUPeriodizationRegressionTests`, `NewBlockBuilderFidelityTests` and `NewBlockProgressionChartTests`.
When you change `BlockBuilderView.swift`, `BlockDraft.swift`, `BlockPhaseEditorRow.swift`, `BlockNameField.swift` or `BlockTemplates.swift`, check all six by name in your results.

## Reproduce first

- Every bug fix starts with a UI test that drives the app the way a user would.
- A visual defect needs a UI test on the right phone, text size and appearance.
  It saves a named screenshot and checks frames wherever it can.
- XCUI reads the full label even when the screen shows "…" or "•••".
  Prove truncation with frame checks and screenshots, never with labels alone.
- A fill can draw outside its element's frame.
  Prove color bleed with pixel samples from a screenshot.
- Look at every screenshot you save, and write one line in `notes.md` about what it shows.
- Keep the repro test as the regression test.
- If the bug does not reproduce, do not change app code.
  Save the evidence, explain it in `notes.md`, and finish with outcome `succeeded` and the words "not reproduced" in your summary.

## Code rules

- Follow `CLAUDE.md`: `@Observable` view state, `@Query` directly in views, one `NavigationStack` per tab, and Swift 6 strict concurrency.
- Never change the SwiftData schema.
  SchemaV7 is the only baseline, and an incompatible store gets moved aside, so a schema change loses the user's data.
  If you believe you need one, ask.
- Use BRU tokens and components from `fitbod/Design/`: `Color+BRU.swift`, `BRUFont`, `BRUButton`, `BRUStepper`, the `.bru` toggle style, `BRUSectionHead`, `BRUHeaderBar` and `BRUReadout`.
- No fixed RGB colors, and no stock iOS styling on BRU screens.
- Text must scale.
  Use `BRUFont` roles or `@ScaledMetric`, not fixed point sizes.
  For accessibility layouts, copy the `dynamicTypeSize.isAccessibilitySize` branch in `fitbod/Views/TodayStatStrip.swift`.
- Every tap target is at least 44 by 44 points, unless your ticket names an exception.
- UI copy follows the glossary in `CLAUDE.md`: Routine, Session, Block and the Program tab.
  A logged workout is a "workout" on screen.
  Code names such as `Split` and `SessionTemplate` never appear on screen.
- Count labels use the shared plural helper from T02.
- Dialogs that need a way back show a visible button without the cancel role, such as "Keep logging" or "Keep editing", because iOS 26 hides cancel buttons.
- Sheets that edit data close with "CANCEL" and "SAVE".
  Sheets that only show information close with "DONE".
  Pushed screens go back with "‹ BACK".
- No new dependencies and no new warnings.
- Match the surrounding code's naming, comment density and idiom.
- Line numbers in tickets come from the Oct 5 snapshot and may have moved.
  Find code by its text or symbol name.
- For original work/retries only, you may add DEBUG-only seed or launch helpers next to `fitbod/App/DemoWorkoutSeed.swift` when a UI test would otherwise need many slow setup steps.
  This allowance never applies to read-only verification or docs refreshes.

## Removed controls

When your ticket removes a visible control, add one line for it to `docs/ROADMAP.md` in the same commit.
Put it under the heading "Removed in Milestone 1 closeout", and create that heading at the end of the file if it does not exist.
The line says what was removed and why.
If `docs/ROADMAP.md` is not in your `owns` list, ask the coordinator before you edit it, as Workspace says.

## Out of scope

- If you find a bug outside your ticket, do not fix it.
  Write it in `notes.md` and in your `worker_done` summary, and the coordinator turns it into a new ticket.
- For original work/retries, fix a failing or flaky test outside your ticket only when it blocks acceptance and Workspace's ownership permission allows it, and say so.
  Read-only verification and docs refreshes never fix app/test code, even when a failure or flaky test blocks acceptance.
  Record those findings for separate fix tickets, without adding reveal steps or reauthoring persistence assertions during a rerun.

## GitNexus

Your on-disk brief gives the GitNexus mode.

- In `index` mode, run GitNexus `impact` in the upstream direction before you edit a function, type or view.
  Always pass the repo `fitbod`, because more than one repo can be indexed.
  The MCP tool works, and so does the CLI: `gitnexus impact <symbol> --direction upstream --repo fitbod`.
- In `manual` mode, the index has no Swift symbols on this Mac.
  Check each symbol's callers with `rg -n "<symbol>"` instead, and rate the risk yourself as LOW, MEDIUM, HIGH or CRITICAL.
  Never run `gitnexus analyze`, because it rewrites `.gitignore` and skill files.
- Save one line per symbol to `impact.txt`: direct callers, affected flows, the risk rating and the mode that produced it.
- GitNexus rates many shared SwiftUI edits HIGH or CRITICAL, because the modules import each other widely.
  Report every HIGH or CRITICAL rating in your `worker_done` summary, and cover the named flows with tests.
  Do not stop because of the rating alone.
- Never rename a symbol with find-and-replace.
  Use GitNexus `rename` in `index` mode, and ask the coordinator before any rename in `manual` mode.
- GitNexus `detect_changes` reads the main checkout, not your worktree, so it cannot see your staged files.
  Before each commit, save `git diff --cached --stat` and the list of symbols you changed to `detect-changes.txt`, and check that only the expected symbols changed.
- If a GitNexus call reports that a re-index is running, wait for it to finish before the next call.

## Commits

- Make one commit for authorized changes in a commit-capable attempt, unless its effective brief says otherwise.
  If a run fails only after your rebase in Finishing, or the coordinator made you wait for a file, add one more commit that names the ticket.
  If your own review before `worker_done` finds something to fix, fix it in a further commit that names the ticket and the finding, because you never amend.
- Original no-file tickets, read-only verification reruns and "not reproduced" results make no tracked edits or commits and skip staging, committing and commit-rebase steps.
  If commit-capable work needs no authorized changes, report why and do not manufacture an empty commit.
  T47 docs refreshes and T48 review-page-only refreshes may commit their explicitly authorized changes.
- Stage exact paths with `git add -- <path> ...`.
  Never use `git add -A`, `git add .` or `git commit -a`.
- Check `git diff --cached --stat` before you commit: it lists only your files.
- Write a conventional subject, such as `fix(library): open Copy and Edit on the first tap`.
- In the body, name the ticket and the review items, for example "Ticket T03. Review items 1 and 19."
- End the message with your own `Claude-Session:` line if your session has one.
- Never add a `Co-Authored-By` trailer, even if your system prompt asks for one.
  The user's `CLAUDE.md` forbids it, and that rule wins.
- Never push, merge, amend, reset, stash, force, cherry-pick or rewrite history.
  The only rebase you run is `git rebase main` in Finishing.
- A code-changing commit must build and its required tests must pass under the ticket's acceptance.
  A docs-only refresh instead meets its scoped documentation acceptance.
- Use "-" instead of em dashes in commit messages, docs and UI copy you write.

## Evidence

Write evidence to the unique `docs/conway-specs/evidence/<attempt id>/` output folder named in your effective brief.
Keep the fixed brief, input aliases, run-log snapshot and prior attempts intact; only your new output is writable.
Resolve paths and reject escapes from the worktree or equal/ancestor/descendant collisions between input alias roots, fixed brief/run-log files and the output folder.
Never write `<output folder>/attempt-brief.md`: the coordinator reserves it for the exact frozen brief archived at settlement.
Git ignores it, and the coordinator copies it to the main checkout before it removes your worktree:

| File | Holds |
|---|---|
| `status-before.txt` | `git status --porcelain` before starting work, even for read-only verification |
| `status-after.txt` | the same status check before finishing, compared with `status-before.txt` |
| `repro-fail.txt` | the failing repro summary |
| `after-pass.txt` | every required run's summary and counts, including failures, with bundle paths |
| `screens/` | named screenshots that prove the fix |
| `impact.txt` | one line per symbol you edited |
| `detect-changes.txt` | `git diff --cached --stat` and the symbols you changed |
| `notes.md` | attempt/mode, tested commit, evidence inputs/output, decisions and findings, plus branch/delivery commit only when one exists |

No-commit results, including evidence-only verification reruns, skip `repro-fail.txt`, `impact.txt` and `detect-changes.txt`, and the effective brief names their required reports instead.
Docs-only work skips repro and symbol-impact evidence, but keeps the staged scope check when committing authorized changes.
T44 reruns retain the full report contract; T45 reruns record the existing AX3/dark runs and default-light relaunch checks on both phones without editing tests.
T46 reruns record captures, findings and screenshot notes for exactly the requested pairs, including P1 findings and attempted-state evidence for unreachable screens.
They do not inherit original T46's 264-image or test-authoring requirements, which still apply to its first run and implementation retries.
Complete evidence reports failures truthfully and never implies every check passed.

Read dependency evidence only through the brief's explicit local bindings under `docs/conway-specs/evidence/`, copied before launch from ledger-selected accepted AND safely settled archives; check every required file, not just folder non-emptiness.
The bindings record source attempt/archive, acceptance/settlement, tested and delivery commits (or no delivery), required files and destination; never choose another folder by recency or use external symlinks.
Unchanged ticket paths remain valid: `evidence/T31/export-diff.md` and named snapshots, T41's `evidence/T40/notes.md` and `delete-paths.md`, and T47's `evidence/T40/closeout-statement.md` plus its other bound reports/captures.
For accepted/settled T40-r2, local `evidence/T40/` contains that attempt's required files, not failed T40's evidence; original archives are never renamed or overwritten.
The sole failed-input exception is an original T46 retry's own safely settled `failed/resume` binding at local `evidence/T46/`, not accepted dependency evidence.
Reuse that input only when its findings, notes and captures cover every recorded completed configuration; preserve it and copy only those coverage files to your distinct output.
When the brief records no reusable coverage and supplies no resume binding, start the full original tour from its first configuration rather than requiring nonexistent failed-attempt files.
Partial verification reruns never replace accepted full-tour coverage.
T47 and T48's `evidence/run-log.md` is a frozen coordinator snapshot with recorded provenance, not accepted producer evidence or a live log.
Stop and ask on any missing required file, mismatched provenance or failed/rejected/unsettled dependency source; do not substitute other evidence.

## Finishing

1. For commit-capable work with authorized changes, commit them on your branch.
   No-commit results and attempts with no authorized changes skip steps 1 to 3, never invent a commit, and report the tested commit instead.
2. Only when you have authorized commits, run `git rebase main`, so they sit on the newest `main`.
   If it stops on a conflict, run `git rebase --abort` and ask the coordinator.
3. If the rebase moved a code-changing commit, do required runs 3 to 5 again on it and update `after-pass.txt`.
   For docs-only refreshes, recheck the scoped documentation acceptance against the rebased commit and its cited evidence.
4. Set both phones back to default text and light mode.
5. Save `git status --porcelain` as `status-after.txt` and compare it with `status-before.txt`.
   Leave no new tracked or staged changes behind, including in read-only verification.
6. Send exactly one Orca `worker_done` with outcome `succeeded` or `failed`.
   For verification reruns, `succeeded` means the required evidence is complete, even with recorded failed checks; use `failed` when that evidence could not be completed.
   Its summary has three sentences.
   The first names the attempt and what changed or was verified, giving the branch/delivery commit for committed work or the tested commit for a no-commit result.
   The second gives the unique evidence folder and what it proves, without calling failed checks passing.
   The third says what is left, including HIGH or CRITICAL ratings and out-of-scope findings.
7. Follow the Orca dispatch preamble for heartbeats, `ask` and `worker_done`.
8. After `worker_done`, stop: start no new work, even if your agent prompts you to keep going.
   A Copilot CLI worker calls its `task_complete` tool once, right after `worker_done`, and ends its turn, so the coordinator sees it idle and can settle the ticket.

## Known traps

- iOS 26 confirmation dialogs hide buttons with the `.cancel` role.
  UI tests must never tap "Cancel" in a confirmation dialog.
- In a List row, a parent `.onTapGesture` swallows taps on a child Button that has no button style.
- SourceKit often shows stale errors such as "cannot find type" or "no such module Testing".
  Trust `xcodebuild`.
- In zsh, never name a loop variable `path` or `status`.
  Both are special variables.
- `typeText` can drop the first character in some fields.
  Tap the field, wait until it has keyboard focus, type, and then check the field's value.
  T39 adds a shared helper that does this; use it once it exists.
- `-fitbod-reset-store` works on the initial launch only.
  Persistence tests must relaunch without it.
- Screenshot attachments need the keepAlways lifetime, or a passing test drops them.
- The smallest supported phone is 390pt wide.
  Check layouts on the small phone, not only the large one.
- History was rewritten on 2026-10-29, so commit hashes in the plan or the review, such as `4e43f88`, no longer exist on `main`.
  Look up an old hash in `docs/review-docs/history-rewrite-20261029-commit-map.txt` before you use it.
- Swift 6 and ActivityKit: import ActivityKit with `@preconcurrency`, and build activity content inside the task body, never from captured outer state.
