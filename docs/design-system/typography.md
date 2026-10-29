# Typography

Source of truth: `fitbod/Design/BRUFont.swift`.
Every role is `Font.custom(_:size:relativeTo:)`, so all text scales with Dynamic Type from the base sizes below.

## Faces

| Face | PostScript name | Use |
| --- | --- | --- |
| Bebas Neue Regular | `BebasNeue-Regular` | Condensed caps: screen titles, hero numbers, big CTA labels. It has no lowercase. |
| Space Grotesk Bold | `SpaceGrotesk-Bold` | Headings, exercise names, card titles. |
| Space Grotesk SemiBold | `SpaceGrotesk-SemiBold` | Secondary headings. |
| JetBrains Mono Bold | `JetBrainsMono-Bold` | Labels, chips, data values. |
| JetBrains Mono Regular | `JetBrainsMono-Regular` | Body copy and metadata. |
| Geist Regular | `Geist-Regular` | Long paragraphs only, such as empty-state explainers. |

The font files are in `fitbod/Resources/Fonts/` and are registered with `UIAppFonts` in `fitbod/Info.plist`.
Their licenses are in `fitbod/Resources/Fonts/LICENSES`.

## Roles

| Role | Face | Base size | Scales like | Tracking | Case | Use |
| --- | --- | --- | --- | --- | --- | --- |
| `condensedHero` | Bebas Neue | 64 | largeTitle | 0 | caps | The weight on the active set |
| `condensedTitle` | Bebas Neue | 40 | largeTitle | 0 | caps | Screen titles, the exercise title in a workout |
| `condensedHeading` | Bebas Neue | 28 | title | 0 | caps | Section heroes, empty-state headlines, big readouts |
| `condensedLabel` | Bebas Neue | 22 | title2 | 0 | caps | Primary CTA labels ("Log set ▸"), stat values |
| `displayHero` | Space Grotesk Bold | 56 | largeTitle | -0.5 | as typed | Hero headlines |
| `displayLarge` | Space Grotesk Bold | 32 | largeTitle | -0.3 | as typed | Section headers |
| `displayMedium` | Space Grotesk Bold | 18 | title3 | 0 | as typed | Card titles, exercise names |
| `bodyEmphasis` | JetBrains Mono Bold | 14 | subheadline | -0.2 | as typed | Emphasized body, primary data values |
| `bodyDefault` | JetBrains Mono Regular | 13 | footnote | 0 | as typed | Secondary data, descriptions |
| `labelLarge` | JetBrains Mono Bold | 13 | footnote | 1.4 | uppercase | Button labels, prominent tags |
| `labelSmall` | JetBrains Mono Bold | 11 | caption2 | 1.2 | uppercase | Small labels, chips, header titles (1.5 in the header) |
| `labelMicro` | JetBrains Mono Bold | 9 | caption2 | 1.0 | uppercase | Status badges only |

"Scales like" is the system text style whose Dynamic Type curve the role follows.
`BRUFont.textStyle(forPointSize:)` picks it from the base size when a call site uses `Font.bru(_:size:)` for a one-off size.

## Rules

- Use a role. Never call `Font.custom` in feature code. Use `Font.bru(_:size:)` only when no role fits.
- Apply tracking and `.textCase(.uppercase)` at the call site, as the table says. The string itself stays in normal case.
- `labelMicro` is never used for text a user must read to act. Use `labelSmall` instead.
- Mono digits do not shift as values change. Add `.monospacedDigit()` to changing numbers in other faces.
- Hero and condensed numbers grow fast at accessibility sizes. Where width is limited, pair them with `.lineLimit(1)` and `.minimumScaleFactor(0.5)`.
- `BRUHeaderBar` lets multiword titles wrap to two lines at a 0.85 minimum scale.
  Single-word titles stay on one line and can scale to 0.65 to fit compact
  screens at accessibility sizes.

The type scale preview is `#Preview("BRU Type Scale")` in `BRUFont.swift`.
Dynamic Type behavior and testing: [accessibility.md](accessibility.md).
