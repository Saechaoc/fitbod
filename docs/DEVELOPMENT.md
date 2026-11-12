# Development guide

Fitbod is a prototype.
We are still shaping its storyboards, workflows and visual design, so the goal of most work is to learn whether an idea works, quickly.
This guide says how much engineering each change needs at this stage, what must never be skipped, what can wait, and when the waiting ends.

Stage as of 2026-11-08: **prototype**.
The stage changes per workflow (see [Stages](#stages)), and the whole app moves to release readiness only on the conditions at the end of this guide.

## Principles

- **Learn first.** Build the simplest version that works end to end and lets the lifter try the idea.
- **Scale effort to the change.** Tests, abstractions, optimization, documentation and visual polish match how mature and how risky the change is.
- **Keep the safeguards.** Correctness, data integrity, privacy and security are never deferred.
- **Defer on purpose.** Deferred work and its return conditions live in [the roadmap](ROADMAP.md); this guide defines the stages and effort policy.
- **No process for its own sake.** Do not replace extra code with extra documents, checklists, tickets or approval steps.

## Never deferred

These are cheap or protect the lifter's data, so they apply to every change at every stage.

- **Logged data stays true.** A finished workout, its sets and its prescription snapshot survive relaunch and later template edits.
  Model, persistence, engine and backup changes get unit tests, and a relaunch check when they change what is stored.
  Examples: `MilestoneOnePersistenceTests`, `SessionSnapshotFidelityTests`.
- **No silent failures that lose work.** A failed save must say so and must not poison later saves.
  The design map's dated blockers D-01 to D-04 are this class; their follow-ups, [RM-001–RM-005](ROADMAP.md#current-focus), are done.
- **Prescription math is right.** Progression, e1RM, volume, PR and plate logic get unit tests; the whole unit target runs in about 36 seconds.
- **Schema and unit rules hold.** SchemaV7 has no historical migration chain; recovery preserves incompatible stores separately. Units relabel and never implicitly convert (see `ARCHITECTURE.md`).
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
  `scripts/shot.sh` captures a seeded state there in one command (`docs/SETUP.md`, Captures and phone installs).
  After `scripts/shot.sh`, open the capture beside the screen's approved reference, list each difference, and fix the clear ones in the same slice.
  The reference is the `mock:` path, from the repository root, in the screen's `docs/design-map/screens/<id>.md`, or a `docs/design-map/mockups/*-390-*.png` when one exists; a screen with neither has no approved reference yet.
  Pro Max captures stay with stable workflows, as the table below says.
- **GitNexus impact check before editing a symbol, as `CLAUDE.md` requires.** It is one call and catches callers you did not know about.

## Scale effort to the change

| Change | Tests | Visual check | Docs |
|---|---|---|---|
| Trying a new screen, flow or layout | Unit tests only for logic that computes something. No UI test unless it guards data. | 17e, default text, light | Commit message |
| Copy or styling change | None. Update or delete any copy-pinning test the change breaks, in the same commit. | 17e, default text, light | Commit message |
| A workflow becoming stable | One journey UI test for the workflow | Add dark mode, Pro Max and AX3 for that workflow | Its design-map screen files |
| Model, persistence, engine or backup | Unit tests, plus a relaunch test if stored data changes | As needed | `ARCHITECTURE.md` if a contract changes |
| Bug fix | Reproduce it the way the lifter meets it. Add a regression test when the bug cost data or is likely to return. | Where it showed | Commit message |

Run the unit target for app changes, and only the UI tests for the workflow you touched.
Run affected existing UI checks when routes, interactions or stored-data behavior change; new prototype UI tests are needed only when they protect data. Copy/styling changes use simulator inspection and need no new copy-pinning test.
For documentation/tooling-only changes, run their relevant checks; app tests are needed only if app behavior changes.
`scripts/test.sh fast` runs the unit target in about 35 seconds; add `-only-testing:fitbodTests -only-testing:fitbodUITests/<Suite>` to include one UI suite.
Run the full UI suite on one phone before merging a large change to `main`.
`scripts/test.sh full` runs everything, the UI suite in two shards, in about 14 minutes; see `docs/SETUP.md` (Test tiers).
Both-phone/AX3 checks return for each [stable workflow](#stages), and the full configuration matrix returns at [release readiness](#release-readiness).
The full runner pins its simulators to default text/light mode; it does not prove AX3/dark coverage. Run and record those configurations explicitly when due.

Fix lint or a flaky test when it blocks your change or sits in code you are already changing.
Otherwise note it in one line and move on.
The same holds for visual flaws on screens you are not working on.

## Deferred work

Current deferred outcomes and return conditions are recorded only in [ROADMAP.md](ROADMAP.md):

- [Stable-workflow accessibility/layout](ROADMAP.md#rm-044), including VoiceOver, AX3, dark mode and large-phone checks.
- [Approved-screen polish](ROADMAP.md#rm-035) and [measured performance/maintenance](ROADMAP.md#rm-034).
- [Two-phone release journeys](ROADMAP.md#rm-048), [physical checks](ROADMAP.md#rm-047), and [release captures/docs/gallery](ROADMAP.md#rm-051).
- [Kept-test follow-ups](ROADMAP.md#rm-054); presentation-only UI suites were removed by T143 and are not restored wholesale. Do not add source-reading copy-pinning tests; check running UI when stable.

Data integrity, correctness, privacy/security and test-speed fixes that block iteration are never deferred.
A skipped ticket is not a completed outcome.

## Process

- Start from the relevant `docs/ROADMAP.md` entry; no GSD command or separate planning ledger is required.
- Update that RM entry when work changes scope, status, dependencies or evidence. Add a stable RM ID only for a distinct outcome; retain original finding IDs when deduplicating.
- Use a short conversation plan for execution. Keep any necessary temporary implementation detail subordinate to the roadmap.
- Routine testing is the agent's responsibility. The user may try builds whenever convenient; personal sign-off is not required for every feature.
- Build in small slices. A slice lands on `main` and is pushed when its local checks pass; no pull request is required and CI gates nothing ([RM-053](ROADMAP.md#rm-053)).
- Use **Planned → Active → Done**. Done means the agreed scope works, appropriate agent-run checks pass and affected docs are current. A relevant failing check is not a pass; record its actual disposition.
- If implementation is finished but required proof is unavailable, use **Implemented; verification pending** and identify exactly what remains unproven. Ask for user involvement only for unavailable observations (for example, Lock Screen rendering or gym ergonomics) or a product decision. Those checks block only work that actually requires their result; continue independent planning/development.
- Separate **Requires** (real prerequisites), **Scheduled after** (delivery order) and **Verify when** (stability/release/integration triggers). Rehearse every schema change on a copy of the phone's store (`scripts/rehearse-store.sh`); prove populated backup/recovery ([RM-029](ROADMAP.md#rm-029)) before a change SwiftData cannot migrate in place, and load provenance before mixed-unit analytics. Keep correctness/privacy/data-integrity safeguards local to affected paths; unrelated work need not wait.
- Do not write a new report, checklist or ticket to record a small change. The commit message is the record.
- Product decisions and completion criteria go in `docs/ROADMAP.md`; technical contracts go in `ARCHITECTURE.md`. Dated audits, screenshots and layouts are references, not status sources.
- Record concise test results and limitations in the relevant RM entry. Keep run logs and screenshots in CI artifacts or ignored local output; do not create report archives or evidence dumps in the repository.
- Move finished substantial implementation plans to `docs/archive/features/` with a historical banner, included/excluded scope, build/commit, results/limitations and an RM backlink. Archive the completed implementation even if a required phone check remains open in the roadmap; do not archive it as accepted behavior. Small changes need no plan archive.
- Preserve older completion claims without criterion-matched evidence as **historically shipped; acceptance unrecorded**. Do not impose a whole-app retest to relabel history.
- Maintain affected architecture, setup, conventions and current design references with each feature. Dated audits/captures remain labeled historical evidence. Run `python3 -I docs/design-map/tools/check_map.py --self-test` and the checker for documentation changes; `bash docs/design-map/tools/check.sh` also renders Mermaid. Check changed links/anchors, archive references, finding ownership and prerequisite cycles.

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

- every workflow stable, and every applicable deferred roadmap item done;
- the full unit and UI suite green on both phones, at default text and at AX3, and in dark mode;
- a VoiceOver traversal of every workflow on a physical iPhone, plus haptics, notification denial and Live Activities;
- a contrast and touch-target audit per screen, and Reduce Motion;
- a populated backup restored on a second installation, and a full journey with networking off;
- the release checks in `docs/ROADMAP.md`.
