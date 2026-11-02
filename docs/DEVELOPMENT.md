# Development guide

Fitbod is a prototype.
We are still shaping its storyboards, workflows and visual design, so the goal of most work is to learn whether an idea works, quickly.
This guide says how much engineering each change needs at this stage, what must never be skipped, what can wait, and when the waiting ends.

Stage as of 2026-11-01: **prototype**.
The stage changes per workflow (see [Stages](#stages)), and the whole app moves to release readiness only on the conditions at the end of this guide.

## Principles

- **Learn first.** Build the simplest version that works end to end and lets the lifter try the idea.
- **Scale effort to the change.** Tests, abstractions, optimization, documentation and visual polish match how mature and how risky the change is.
- **Keep the safeguards.** Correctness, data integrity, privacy and security are never deferred.
- **Defer on purpose.** Deferred work is named below with the condition that brings it back.
- **No process for its own sake.** Do not replace extra code with extra documents, checklists, tickets or approval steps.

## Never deferred

These are cheap or protect the lifter's data, so they apply to every change at every stage.

- **Logged data stays true.** A finished workout, its sets and its prescription snapshot survive relaunch and later template edits.
  Model, persistence, engine and backup changes get unit tests, and a relaunch check when they change what is stored.
  Examples: `MilestoneOnePersistenceTests`, `SessionSnapshotFidelityTests`.
- **No silent failures that lose work.** A failed save must say so and must not poison later saves.
  The design map's blockers D-01 to D-04 are this class (`docs/design-map/audit.md`).
- **Prescription math is right.** Progression, e1RM, volume, PR and plate logic get unit tests; the whole unit target runs in about 36 seconds.
- **Schema and unit rules hold.** SchemaV7 recovery moves stores aside and never migrates; units relabel and never convert (see `CLAUDE.md`).
- **Local only.** No network sync, accounts, analytics or HealthKit.
  Backup and import code must validate a file before it writes to the store.
- **Accessibility foundations.** Use what the platform and BRU already give for free:
  - native controls and BRU components, not custom gesture views;
  - type from `BRUFont` roles, so Dynamic Type works without per-screen work;
  - colors from BRU tokens, so `docs/design-system/tokens_check.py` covers contrast;
  - a word label on glyph-only controls, and uppercase through `.textCase(.uppercase)`;
  - the 44 pt minimum inside shared components, not patched per screen;
  - an `accessibilityIdentifier` on controls a UI test drives.
- **The phone you lift with works.** Check each changed screen at default text, light mode, on a 390 pt phone (iPhone 17e simulator), because that is the support floor.
- **GitNexus impact check before editing a symbol, as `CLAUDE.md` requires.** It is one call and catches callers you did not know about.

## Scale effort to the change

| Change | Tests | Visual check | Docs |
|---|---|---|---|
| Trying a new screen, flow or layout | Unit tests only for logic that computes something. No UI test unless it guards data. | 17e, default text, light | Commit message |
| Copy or styling change | None. Update or delete any copy-pinning test the change breaks, in the same commit. | 17e, default text, light | Commit message |
| A workflow becoming stable | One journey UI test for the workflow | Add dark mode, Pro Max and AX3 for that workflow | Its design-map screen files |
| Model, persistence, engine or backup | Unit tests, plus a relaunch test if stored data changes | As needed | `CLAUDE.md` architecture tables if a rule changes |
| Bug fix | Reproduce it the way the lifter meets it. Add a regression test when the bug cost data or is likely to return. | Where it showed | Commit message |

Run the unit target on every change, and only the UI tests for the workflow you touched.
`scripts/test.sh fast` runs the unit target in about 35 seconds; add `-only-testing:fitbodTests -only-testing:fitbodUITests/<Suite>` to include one UI suite.
Run the full UI suite on one phone before merging a large change to `main`.
`scripts/test.sh full` runs everything, the UI suite in two shards, in about 14 minutes; see `docs/SETUP.md` (Test tiers).
Both phones and AX3 belong to [release readiness](#release-readiness).

Fix lint or a flaky test when it blocks your change or sits in code you are already changing.
Otherwise note it in one line and move on.
The same holds for visual flaws on screens you are not working on.

## Deferred work

| Deferred | Why it can wait | Comes back when |
|---|---|---|
| VoiceOver refinement: combined row labels, announcements, missing-value labels, audio graphs, rotor order (T117) | The labels are rewritten each time a screen's layout changes. | The workflow is stable |
| AX3 layout fixes on individual screens (the design map's patterns P-4 and P-5) | Each fix and its UI test is redone when the layout changes. | The workflow is stable |
| Dark mode and Pro Max checks per screen | Tokens already cover dark mode; layouts still move. | The workflow is stable |
| Pixel polish: the design map's 177 `polish` rows, T120 | The screens are being redesigned. | The screen's design is approved |
| New copy-pinning tests that read Swift source (45 files, about 8,200 lines today) | They fail on every intended copy change. Add none; delete one when it blocks a change. | Release readiness, as a copy check over the running UI |
| UI tests that do not guard data: layout sizes and text fit, AX3, dark mode, VoiceOver, BRU look, copy, tap targets, swipe-back sweeps and the OCR fidelity test | T143 deleted them on 2026-11-01, 351 of 424 cases, so the whole UI suite runs in about 40 minutes instead of 3 hours. Git history before `e697189` keeps them. | The workflow is stable |
| Full UI suite on both phones and at AX3 (T44, T45) | It takes about 2 to 3 hours serially. | Release readiness |
| Screenshot tours, verification reports and doc refreshes (T46, T47, T48) | They describe screens that will change. | A milestone closes, or release readiness |
| Physical-device checks: VoiceOver traversal, haptics, notification denial, Live Activities | Simulators cannot prove them, and the flows are still changing. | Release readiness |
| Performance work | Only one user, and no slowness felt in use. | A real workout feels slow |

Never deferred, whatever the ticket says: T40 and T41 (data loss), and test-speed work that makes iteration faster (T119, T121).

## Process

- Use `/gsd-quick` or `/gsd-fast` for most prototype work.
  Use the full phase flow (research, plan check, verifier) only for multi-day work that changes models or several workflows.
- Use a multi-agent ticket bundle (like `docs/conway-specs/`) only when several workers really run in parallel; for one person, a short list in the conversation is enough.
- Do not write a new report, checklist or ticket to record a small change. The commit message is the record.
- Product decisions go in `docs/ROADMAP.md`; do not copy them into other files.

## Stages

**Prototype.** The default for every workflow now.
Follow [Never deferred](#never-deferred) and the first rows of the effort table.

**Stable workflow.** A workflow (see `docs/design-map/workflows/`) is stable when all three hold:

1. Its screens and steps match a design the user approved, such as a design-map mock-up or review decision.
2. Its structure has not changed through two weeks of real gym use.
3. No open product decision in `docs/ROADMAP.md` touches it.

Then do that workflow's deferred items marked "the workflow is stable": one journey UI test, dark mode, Pro Max, AX3 layout and the VoiceOver pass.

## Release readiness

Release readiness starts before any of these happens:

- someone other than the developer installs the app (TestFlight, App Store or a shared build);
- the app becomes the lifter's only record of training, with no other log kept;
- a milestone is declared release quality.

It requires:

- every workflow stable, and every deferred item above done;
- the full unit and UI suite green on both phones, at default text and at AX3, and in dark mode;
- a VoiceOver traversal of every workflow on a physical iPhone, plus haptics, notification denial and Live Activities;
- a contrast and touch-target audit per screen, and Reduce Motion;
- a populated backup restored on a second installation, and a full journey with networking off;
- the release checks in `docs/ROADMAP.md`.
