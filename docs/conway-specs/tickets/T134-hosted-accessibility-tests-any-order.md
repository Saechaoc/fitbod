---
id: T134
title: Hosted accessibility tests pass in any order, and the row style's VoiceOver activate is tested
phase: 4
items: []
depends_on: [T106]
size: M
sim: large
owns: [fitbodTests/StallBadgeBRUTests.swift, new:fitbodTests/BRURowButtonStyleTests.swift, new:fitbodTests/HostedAccessibility.swift, fitbod/Design/BRURowButtonStyle.swift, fitbodTests/BlockReviewPRMarkTests.swift, fitbodTests/BlockReviewHeroLayoutTests.swift]
---

# T134: Hosted accessibility tests pass in any order, and the row style's VoiceOver activate is tested

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.
Read [../../test-performance-guide.md](../../test-performance-guide.md) too; this ticket applies it.

## Problem

These are findings F315 and F317, which T106's worker found.

- `StallBadgeBRUTests` "StallBadge renders label text STALLED (uppercased)" and "StallBadge accessibility label is verbatim per UI-SPEC" fail when run without the rest of `fitbodTests`.
  The hosted SwiftUI view has no accessibility tree unless something earlier in the run built one, so the two tests pass or fail by test order.
- For the same reason T106 could not ship a hosted test that VoiceOver's activate opens a `.bruRow` row: its hosted view reported no accessibility elements.
  So nothing fails if the style's accessibility action is removed, and XCUITest cannot activate through VoiceOver.
- T98's `ProgressChartDescriptorTests` does find SwiftUI's accessibility elements when run alone: it hosts the screen in a window attached to the app's scene and polls the run loop with a ceiling.
- `RowTapRecognizer.touchesEnded` in `fitbod/Design/BRURowButtonStyle.swift` has a branch that can never run: `start` is always set by then.
- `BlockReviewPRMarkTests` and `BlockReviewHeroLayoutTests` each repeat about 35 lines of hosting code (finding F328, from T113's review).

## Target

- How hosted views get an accessibility tree in `fitbodTests`, `StallBadgeBRUTests`, and a new `BRURowButtonStyleTests`.
- `RowTapRecognizer.touchesEnded`.

## Change

1. Find what makes a hosted SwiftUI view build its accessibility tree in the unit-test host, and give hosted accessibility tests one shared way to get it, in `fitbodTests/HostedAccessibility.swift`.
2. `StallBadgeBRUTests`' two accessibility tests use it, and pass when run alone.
3. `BRURowButtonStyleTests` proves that VoiceOver's activate on a `.bruRow` button runs its action.
   It fails when the style's accessibility action is removed; prove that once and record it in `notes.md`.
4. `RowTapRecognizer.touchesEnded` recognizes the tap without the unreachable branch.
5. `BlockReviewPRMarkTests` and `BlockReviewHeroLayoutTests` host their views through the same shared code.

## Constraints

- The app behaves exactly as it does today.
- No fixed sleeps: poll the run loop at 50 ms with a ceiling, as T98's tests do.
- Each case typically runs in under 1 s.

## Ownership

You may edit the files in `owns`.
Ask before you move any other hosted accessibility test to the shared way.

## Repro first

- Run `StallBadgeBRUTests` alone with `-only-testing`, and record its two failures.
- Run `ProgressChartDescriptorTests` alone, record that it passes, and note in `notes.md` how its hosting differs.

## Observable acceptance

- `StallBadgeBRUTests` and `BRURowButtonStyleTests` each pass alone three runs in a row, and inside the full `fitbodTests` run.
- `BlockReviewPRMarkTests` and `BlockReviewHeroLayoutTests` pass alone and inside the full run.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T106's notes in `docs/conway-specs/evidence/T106/notes.md`, under "VoiceOver's activate" and Findings, record what it tried.
- `fitbodTests/ProgressChartDescriptorTests.swift` holds T98's hosting and polling.
