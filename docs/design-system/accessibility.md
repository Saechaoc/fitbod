# Accessibility

BRU is dense on purpose, so accessibility is built into the components rather than added per screen.

While the app is a prototype, every change keeps the foundations: BRU components and type roles, token colors, word labels and 44pt targets in shared components.
The per-screen rules below marked as the release bar (AX3 on every screen, VoiceOver traversal, physical-device checks) apply to a workflow once it is stable and to the whole app at release readiness; see [the development guide](../DEVELOPMENT.md).

## Dynamic Type

- Every type role scales with Dynamic Type (see [typography.md](typography.md)).
- Components change layout at accessibility sizes instead of truncating.
  `BRUStepper` moves its label above the control.
  `BRUHeaderBar` lets the title wrap up to three lines at accessibility sizes.
  Chip rows wrap with `BRUFlowLayout`.
  `SetRow` stacks its labeled numeric inputs at accessibility sizes.
  Headers put their title above the action row; tabs use two columns and
  Today statistics stack vertically at accessibility sizes.
- Hero numbers scale down inside fixed widths with `.minimumScaleFactor`, never below half size.
- Release bar: every screen works from the default size up to `accessibility3` at 390pt width, with no clipped or overlapping text.

## VoiceOver

- Labels are words. Uppercase is visual only (`.textCase(.uppercase)`), so VoiceOver reads "Add set", not "A D D S E T".
- Glyph-only controls get a word label ("‹ Back" is read as "Back").
- A dash that stands for a missing value gets a word label, such as "No previous set" or "No change".
  VoiceOver reads a bare "—" as "em dash", which tells the user nothing.
- Traits match behavior: header titles carry `.isHeader`; selected segments and the active tab carry `.isSelected`; `BRUToggleStyle` keeps native toggle semantics.
- Native tab containment excludes inactive destinations and their controls
  from the accessibility tree while preserving navigation state.
- Prescribed weights offer an “Explain prescribed weight” accessibility action
  alongside long-press disclosure. The October 5 gesture/action update still
  needs its device rerun; see [verification](../VERIFICATION.md).
- `BRUStepper` is one adjustable element: swipe up or down to change the value, and VoiceOver reads the formatted value.
- Rows that show several facts combine them into one element with one label, so users do not swipe through fragments.
- Every control a UI test drives has a stable `accessibilityIdentifier`.

## Contrast

- Text needs a contrast ratio of at least 4.5:1, large text (at least 18pt regular or 14pt bold) and control boundaries at least 3:1.
- `python3 docs/design-system/tokens_check.py` computes the approved foreground-role pairs in light and dark mode and exits with an error when one fails. Screens must still use those roles correctly.
- Current results and implemented token corrections: [color.md](color.md).

## Touch

At least 44 × 44pt for every target; see [interaction.md](interaction.md).

## How to test

- Previews: every Design file has a `#Preview`; the complete gallery includes normal, dark and `.accessibility3` previews.
- UI tests: set the simulator text size before launch, then attach screenshots. The milestone tests do not override it in-app.
- Simulator: `xcrun simctl ui <device> content_size accessibility-extra-large` selects the tested accessibility size. Use `large` to restore the default and `xcrun simctl ui <device> appearance dark` to review dark mode. Larger accessibility settings remain part of ongoing feature QA.
- VoiceOver labels: XCUITest queries by label (`app.buttons["Add set"]`) fail when a label is letters or a glyph, so the UI tests double as a label check.

The expanded rest sheet opens at a large detent for accessibility text and
scrolls its content. Numeric countdowns fit within the progress arc. Actual
VoiceOver navigation on a physical iPhone is a separate release check; an
accessibility-tree query is not a substitute.
