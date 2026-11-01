---
id: T134
title: Hosted accessibility tests pass in any order and on any phone
phase: 4
items: []
depends_on: [T106]
size: M
sim: large
owns: [new:fitbodTests/HostedAccessibility.swift, fitbodTests/StallBadgeBRUTests.swift, fitbodTests/WeekDetailRowsTests.swift, fitbodTests/ProgressChartDescriptorTests.swift]
---

# T134: Hosted accessibility tests pass in any order and on any phone

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F315, F348 and F358, from T106's and T129's workers.

- Unit tests that host a SwiftUI view and read its accessibility tree get no tree unless the simulator's `com.apple.Accessibility` `ApplicationAccessibilityEnabled` and `AccessibilityEnabled` defaults are 1.
- A UI test session sets both back to 0 (F358), so these tests fail in any `fitbodTests` run on a phone that has run a UI test since the flags were last set.
  Today every worker and every gate sets the flags by hand before a unit run.
- `StallBadgeBRUTests`' two accessibility tests, `WeekDetailRowsTests`, the hosted cases in `ProgressChartDescriptorTests` and T129's legend test are known to need the tree.

## Target

- How hosted views get an accessibility tree in `fitbodTests`.

## Change

1. Find what makes a hosted SwiftUI view build its accessibility tree in the unit-test host whatever the simulator's accessibility defaults, and give hosted accessibility tests one shared way to get it, in `fitbodTests/HostedAccessibility.swift`.
2. Every unit test that reads a hosted view's accessibility tree uses it.

## Constraints

- The app behaves exactly as it does today, and the app target does not change.
- No fixed sleeps: poll the run loop at 50 ms with a ceiling, as T98's tests do.
- Each case typically runs in under 1 s.

## Ownership

You may edit the files in `owns`, plus any other unit test that fails with both flags at 0, to move it to the shared way.
Ask before you edit anything else.

## Repro first

- On the large phone, set both flags to 0 with `xcrun simctl spawn <udid> defaults write com.apple.Accessibility <key> -bool false`, run `fitbodTests`, and record every test that fails.
- Set both back to 1 and record that the same tests pass.

## Observable acceptance

- With both flags at 0, every test the repro recorded passes alone and inside the full `fitbodTests` run, three runs in a row.
- `fitbodTests` passes with both flags at 1, and the app and the widget build.
- Both flags are back at 1 on the phone when you finish.

## Deferred

Prototype stage (`docs/DEVELOPMENT.md`): these parts of the first version of this ticket come back when the workflow is stable.

- A hosted test that VoiceOver's activate on a `.bruRow` row runs its action (F317).
- The unreachable branch in `RowTapRecognizer.touchesEnded` (`fitbod/Design/BRURowButtonStyle.swift`).
- `BlockReviewPRMarkTests` and `BlockReviewHeroLayoutTests` sharing their hosting code (F328).

## Hints

- T129's notes in `docs/conway-specs/evidence/T129/notes.md` record the flags' effect and the reset after a UI run.
- T106's notes in `docs/conway-specs/evidence/T106/notes.md`, under "VoiceOver's activate", record what it tried.
- `fitbodTests/ProgressChartDescriptorTests.swift` holds T98's hosting and polling.
- Open-source snapshot libraries, such as cashapp's AccessibilitySnapshot, enable application accessibility inside the test process through `libAccessibility`; this is not verified here.
  Anything private stays in the test target.
