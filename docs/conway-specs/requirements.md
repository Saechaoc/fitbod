# Requirements

## Goal

Milestone 1 is the first usable native iOS workout app: SwiftUI and SwiftData, the BRU design system, and a persisted workout flow.
Every visible action works on the small and the large phone, at default text and at AX3.
The milestone ships with docs, a component gallery, screenshots and a roadmap.

## Done criteria

The milestone is done when all of these are true:

1. The app and the widget build with zero warnings.
2. The full unit and UI suite has zero unexpected failures on both phones, at default text in light mode.
3. The authored journey passes on both phones at default text and at AX3, and again in dark mode.
4. A relaunch test shows that sets, the rest deadline and history survive a terminate and relaunch without the reset flag.
5. Every review item from 1 to 47, and finding N1, is fixed with a regression test or screenshot evidence, or is removed or deferred with a stated reason.
6. The docs and evidence match the build, and acceptance is marked only where evidence exists.
7. The work is committed in reviewable commits and pushed to `main`.

## Scope

- Review items 1 to 25 are described in `~/Desktop/fitbod-review/fitbod-m1-review.md`.
- Review items 26 to 47 are described in the same file, under "Second pass", and in Appendix A of the plan.
- Finding N1: backup and restore drop routines.
  It was found while this bundle was written, and T41 covers it.
- New findings from Phase 6 become tickets T49 and later, as [dispatch.md](dispatch.md) describes.

## Non-functional targets

| Area | Target |
|---|---|
| Width | Layouts work at 390pt (iPhone 17e) and 440pt (iPhone 17 Pro Max). |
| Text size | Every milestone screen works at AX3 (`accessibility-extra-large`) with no mid-word breaks, overlaps or clipped controls. |
| Appearance | Every milestone screen is readable in light and dark mode. |
| Tap targets | At least 44 by 44 points, except the heatmap blocks (see [tradeoffs.md](tradeoffs.md)). |
| VoiceOver | Each control reads once, with a label and a value where it has one. |
| Data | No SwiftData schema change, no data loss on relaunch, backup and restore round-trip routines. |
| Build | Zero warnings in the app, widget and test targets. |
| Stack | Local-only SwiftData, no new dependencies, BRU tokens and components only. |

## Not bugs

These were checked and are left alone:

- The Developer section in Settings shows only in DEBUG builds.
- Volume target rows do expand when tapped; they only lack a visible hint (T38 adds it).
- Changing units relabels stored numbers without converting them.
- Program's "+ NEW" already has a 44pt tap area.
- Each tab keeps its own navigation stack on purpose.
- The rounded New Block cards match the mockup.
- The DL badge clipping on the week ticker at AX3 is scroll clipping, not layout.

## Cannot be proven on a simulator

These stay open flags in the closeout docs, each with its next action:

- VoiceOver on a physical device.
- Haptics.
- Notification permission prompts.
- A fully offline journey.

## Out of scope

- Whether a first log counts as a PR (decision 9).
  It goes on the roadmap.
- The full inline routine creator from `bru-screens/create-flows.jsx`.
- Design changes on screens outside the milestone list in T43.
- Pushing anything before Phase 8, and any force-push.
