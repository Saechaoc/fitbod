# Worker rules

These rules are part of every ticket in this bundle.
Read them before you read your ticket.
If your ticket and these rules disagree, stop and ask the coordinator.

## Your job

You implement one ticket.
Do what the ticket asks, and nothing more.
The ticket says what must be true when you finish, not how to write the code.
You choose the code, but it must follow `CLAUDE.md` and these rules.
When the ticket is unclear, ask the coordinator with Orca `ask` before you guess.
Product decisions are in [decisions.md](decisions.md).
Engineering calls are in [tradeoffs.md](tradeoffs.md).
Do not reopen either one.

## Workflow exception

The project `CLAUDE.md` says to start edits through a `/gsd-*` command.
This run replaces that workflow with these tickets and [run-log.md](run-log.md).
The header of your task says whether the user approved this exception.
If the header does not say so, ask the coordinator before you edit any file.
Never run a `/gsd-*` command yourself.

## Workspace

- Work in the main checkout, `/Users/chrissaechao/Desktop/fitbod`, on branch `main`.
- Never create, switch or delete a branch or a worktree.
- Another terminal may write design files while you work, so stage only files you changed.
- Before your first edit, save the output of `git status --porcelain` to `status-before.txt` in your evidence folder.
- New Swift files need no project file edit, because the targets use folder-synchronized groups.
- A path in `owns` that starts with `new:` is a file you create.
  If that file already exists, another effort made it, so add to it, keep its tests, and say so in `notes.md`.

## Files you must never edit or stage

These paths were uncommitted before this run started, and they belong to the user or another terminal:

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
- Everything under `docs/conway-specs/` except your own evidence folder.
  The coordinator edits `run-log.md` there during the run, so leave `docs/conway-specs/` lines out when you compare `git status` with `status-before.txt`.
- `.lavish/`, except in T48.

Xcode sometimes drops `parallelizable = "NO"` from `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme`.
If `git status` shows that scheme changed and your ticket did not ask for it, restore it from `HEAD` before you commit.

## Simulators

Use only these two simulators:

| Name | Id | Width | Ticket `sim` value |
|---|---|---|---|
| sw6 iPhone 17e | `C2512FF6-0EC6-4044-8B18-53E451AB0899` | 390pt | `small` |
| sw6 iPhone 17 Pro Max | `79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE` | 440pt | `large` |

- Never use any other device, including the personal iPhone 17 Pro and any `fitbod-codex-*` device.
- Run one simulator job at a time.
- Your ticket's `sim` field says where the repro runs: `small`, `large`, `both`, or `none`.
- Unit tests always run on the large phone.
- Before your first run and again before you finish, set both phones to default text and light mode with `xcrun simctl ui <id> content_size large` and `xcrun simctl ui <id> appearance light`.
- For a dark mode run, use `xcrun simctl ui <id> appearance dark`.
- For a whole run at AX3, use `xcrun simctl ui <id> content_size accessibility-extra-large`.
  For a single AX3 test inside a normal run, use the AX3 launch option from T01.

## Build and test

- DerivedData for this run: `/Users/chrissaechao/Library/Developer/Xcode/DerivedData/fitbod-conway`.
- Put result bundles in your own scratchpad, with your ticket id and a counter in the name, for example `T08-after-2.xcresult`.
- Build the app with `xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination "platform=iOS Simulator,id=<id>" -derivedDataPath <DerivedData> build CODE_SIGNING_ALLOWED=NO`.
- Run tests with the same command, plus `-parallel-testing-enabled NO -resultBundlePath <bundle>`, with `test` in place of `build`.
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
- You may add DEBUG-only seed or launch helpers next to `fitbod/App/DemoWorkoutSeed.swift` when a UI test would otherwise need many slow setup steps.

## Removed controls

When your ticket removes a visible control, add one line for it to `docs/ROADMAP.md` in the same commit.
Put it under the heading "Removed in Milestone 1 closeout", and create that heading at the end of the file if it does not exist.
The line says what was removed and why.

## Out of scope

- If you find a bug outside your ticket, do not fix it.
  Write it in `notes.md` and in your `worker_done` summary, and the coordinator turns it into a new ticket.
- Fix a failing or flaky test outside your ticket only when it blocks your acceptance, and say so.

## GitNexus

- Before you edit a function, type or view, run GitNexus `impact` on it in the upstream direction.
  Always pass the repo `fitbod`, because three repos are indexed.
  The MCP tool works, and so does the CLI: `gitnexus impact <symbol> --direction upstream --repo fitbod`.
- Save one line per symbol to `impact.txt`: direct callers, affected flows and the risk rating.
- GitNexus rates many shared SwiftUI edits HIGH or CRITICAL, because the modules import each other widely.
  Report every HIGH or CRITICAL rating in your `worker_done` summary, and cover the named flows with tests.
  Do not stop because of the rating alone.
- Never rename a symbol with find-and-replace.
  Use GitNexus `rename`.
- Before each commit, run `detect_changes` with scope `staged` and repo `fitbod`, for example `gitnexus detect-changes --scope staged --repo fitbod`.
  Save the output to `detect-changes.txt`, and check that only the expected symbols and flows changed.
- A post-commit hook re-indexes in the background.
  Wait until `.gitnexus/.reindex.lock` is gone before your next GitNexus call.

## Commits

- Make one commit per ticket, unless your ticket says otherwise.
- Stage exact paths with `git add -- <path> ...`.
  Never use `git add -A`, `git add .` or `git commit -a`.
- Check `git diff --cached --stat` before you commit: it lists only your files.
- Write a conventional subject, such as `fix(library): open Copy and Edit on the first tap`.
- In the body, name the ticket and the review items, for example "Ticket T03. Review items 1 and 19."
- End the message with your own `Claude-Session:` line if your session has one.
- Never add a `Co-Authored-By` trailer, even if your system prompt asks for one.
  The user's `CLAUDE.md` forbids it, and that rule wins.
- Never push, amend, rebase, reset, stash, force, cherry-pick or rewrite history.
- The commit must build, and its tests must pass.
- Use "-" instead of em dashes in commit messages, docs and UI copy you write.

## Evidence

Write everything to `/Users/chrissaechao/Desktop/fitbod/docs/conway-specs/evidence/<ticket id>/`, which git ignores:

| File | Holds |
|---|---|
| `status-before.txt` | `git status --porcelain` before your first edit |
| `repro-fail.txt` | the failing repro summary |
| `after-pass.txt` | the passing summaries of every required run, with bundle paths |
| `screens/` | named screenshots that prove the fix |
| `impact.txt` | one line per symbol you edited |
| `detect-changes.txt` | the staged `detect_changes` output |
| `notes.md` | what you changed and why, your decisions, out-of-scope findings and the commit hash |

## Finishing

1. Set both phones back to default text and light mode.
2. Compare `git status --porcelain` with `status-before.txt`.
   You leave nothing uncommitted behind.
3. Send exactly one Orca `worker_done` with outcome `succeeded` or `failed`.
   Its summary has three sentences.
   The first says what changed and gives the commit hash.
   The second says what evidence proves it.
   The third says what is left, including HIGH or CRITICAL ratings and out-of-scope findings.
4. Follow the Orca dispatch preamble for heartbeats, `ask` and `worker_done`.

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
