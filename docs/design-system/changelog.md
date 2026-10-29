# Changelog

Newest first.
One entry per change to the design system: what changed and why.

## 2026-10-05: complete large-text navigation

- Accessibility-size headers place the title above the side actions, so
  Settings and long screen titles remain readable.
- Accessibility-size tab controls use two columns; Today statistics stack
  vertically. Program and Progress no longer truncate to the same prefix,
  and statistics no longer split words into narrow columns.
- Native tab containment retains each destination's state while removing
  inactive tabs from accessibility, including during nested sheet presentation.
  The visible navigation controls remain BRU.
- Routine-name Done now commits and dismisses the keyboard for multiline
  fields. The session authoring journey verifies exact entered names.
- At accessibility sizes, the session name scrolls with the exercise cards,
  leaving space to edit prescriptions above the keyboard.
- A simultaneous long press and named accessibility action now request the
  weight explanation. Saved failure evidence showed the old competing gesture
  focused the editor instead. This final fix awaits a simulator rerun.

## 2026-10-04: volume bar and faint text

- `MuscleVolumeBar`: the set count and the NOT TRAINED chip now use `bruMuted`, and the row no longer fades to 50%.
  Before, they used `bruFaint` as a text color and could not be read.
- `MuscleVolumeBar`: the MEV, MAV and MRV labels now sit just above their ticks at full width.
  Before, each label was squeezed into its 1pt tick and drawn 10pt to its left.
  A label that would collide with its neighbor is left out, and all of them are at accessibility text sizes.
- `MuscleVolumeBar`: the track is 16pt tall again. Its ticks no longer stretch it to 22pt.
- `MuscleVolumeBar`: every row on a screen now shares one axis, as in the reference: 25 sets, the largest default MRV, or the largest MRV on screen if a target runs past that.
  Before, each bar ended at its own MRV, so rows could not be compared and volume past MRV could not show.
  Now MRV sits inside the track and the fill keeps growing past the red MRV tick.
- Today's volume summary: the caption reads WORKING SETS · THIS WEEK instead of the reference's 7 DAYS, because the total counts from the start of the calendar week.
  The change against last week is rounded to whole sets, so it reads +29 instead of +29.0.
- `SessionComparisonView`: zero-change dashes use `bruMuted` instead of `bruFaint`.
- Dashes that stand for a missing value now have spoken labels in the logger's Previous column, the workout detail's BEST cell, the session comparison deltas, the routine builder's RPE and Routine slot labels.
  The rule is in [accessibility.md](accessibility.md).
- `ExercisePRsView`: record rows use the exercise's own unit instead of a hard-coded "kg", drop the RPE when none was logged, and the "ALL TIME" header is a label instead of a button that did nothing.
- Added the rule that `bruFaint` is a fill, never a text color, to [color.md](color.md).

## 2026-10-03: accessible foundation and live gallery

- Added the DEBUG component gallery in Settings with real interactive samples,
  immediate action feedback, normal/dark/accessibility previews and long labels.
- Added semantic `bruSignalText`, `bruSignalOnInk` and `bruOnSignal` foregrounds;
  retained the bright signal fill and corrected muted text on inset/disabled fills.
  The contrast script now checks the actual intended role combinations. A separate
  caller and screen audit remains necessary.
- Shared signal buttons/chips/badges use constant ink labels. Headers and readouts
  use readable accent text. Signal actions have a contrasting outer ink outline.
- Added `BRUMetrics` for concrete spacing/borders/radii/touch dimensions. Compact
  buttons now provide 44pt minimum targets. Expanded text links enforce that floor.
- Wrapping layout constrains oversized chips to the available width, so a single
  long label can wrap at accessibility text sizes.
- `BRUToggleStyle` respects Reduce Motion. Every file in the design namespace now
  has a SwiftUI preview, including layout, touch targets, colors and measurements.
- Custom exercise editing uses BRU chrome, names missing inputs and keeps the form
  open with retryable error feedback when persistence fails.
- Set inputs stack at accessibility sizes; prescription controls use shared
  steppers. The session builder retains its draft through nested pickers and
  provides stable, accessible exercise reordering.
- Active filter chips, completed-history labels and optional per-set overrides
  use readable foreground roles. Expanded rest controls scroll and use a large
  sheet at accessibility text sizes.

## 2026-10-03: milestone 1 documentation

- Wrote these docs: principles, color, typography, layout, iconography, interaction, accessibility and the component catalog.
- Added `tokens_check.py`, which reads the asset catalog and checks approved foreground pairs. The initial seven distinct failing pairings motivated the implemented correction documented in [color.md](color.md).
- `BRUHeaderBar`: both APIs now render one chrome. The row is at least 44pt, titles and labels use `labelSmall` uppercase with 1.5 tracking, the title carries the header trait and wraps to two lines at large sizes. Before, the `HeaderAction` form showed a mixed-case `bodyEmphasis` title and the slot form an uppercase label, so headers differed from screen to screen.
- `BRUSegmentedControl`: new. It replaces the system segmented `Picker`, the last system control on the Settings screen.
- `BRUStepper`: the label moves above the control at accessibility text sizes so neither truncates.
