# Layout: spacing, rules, radii and safe areas

Shared measurements live in `fitbod/Design/BRUMetrics.swift`: spacing,
border weights, square corner radius, 44pt targets and 52pt primary actions.
Buttons and steppers consume these constants; older feature layouts retain
matching numeric values. Use the shared tokens when extending the system.

## Spacing scale

| Value | Use |
| --- | --- |
| 0 | Between stacked sections that are separated by a rule. This is the most common stack spacing. |
| 4 | Label to value inside a readout, tight chip rows. |
| 8 | Between related controls, inside cards. |
| 12 | Between groups inside a section, button padding. |
| 16 | Screen gutter (leading and trailing padding), section padding. |
| 24 | Above a new block of content, empty-state spacing. |
| 32 | Large empty-state and hero spacing. |

Odd values (2, 6, 10, 14) exist only as optical corrections next to type.
Do not introduce new values for layout.

## Rules and borders

| Rule | Token | Use |
| --- | --- | --- |
| 2pt solid | `bruInk` | Section boundaries, header bottom rule, segmented control frame, step buttons. `BRUDivider(.ink)`. |
| 1pt solid | `bruHair` | List row separators only. `BRUDivider()`. |
| 1.5pt outline | `bruInk` | Ghost buttons, the incomplete set square, chart frames. |
| 4pt stripe | `bruSignal` | The leading edge of `LiveEditBanner`. |
| 2pt dashed, 6 on 4 off | `bruInk` | "Add" slots (`BRUDashedSlot`). |
| 1pt solid | `bruTabSeparator` | Tab bar cell dividers only. |

## Radii and depth

Every corner is square: there are no corner radii, no capsules, no shadows and no blur.
Depth comes from ink panels and rules instead.

## Fixed chrome

| Element | Size |
| --- | --- |
| `BRUHeaderBar` | Content row at least 44pt, plus a 2pt ink rule. The row grows only when Dynamic Type makes labels taller. |
| `BRUTabBar` | 2pt ink rule plus a 61pt label band, 63pt in total, mounted with `.safeAreaInset(edge: .bottom)`. |
| `BRUButton` | Minimum heights 44pt (`.sm` and `.md`), 52pt (`.lg`). Compact size changes typography, not the touch-target floor. |

## Widths and safe areas

- The smallest supported phone is 390pt wide (iPhone 15, 16e and 17e class). Every screen must fit at 390pt with no horizontal scrolling or clipping.
- Prefer flexible widths (`maxWidth: .infinity`, `Spacer`, `BRUFlowLayout` for chip rows) over fixed widths.
- Content respects the safe area. `bruBg` fills the status bar and the bottom inset so edges never show a different color.
- One `NavigationStack` per tab. Screens draw their own `BRUHeaderBar` instead of a navigation bar.
