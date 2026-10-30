# Color

Source of truth: the colorsets in `fitbod/Assets.xcassets/` and their Swift names in `fitbod/Design/Color+BRU.swift`.
Every token has a light and a dark value and adapts automatically.
Run `python3 docs/design-system/tokens_check.py` to print this table from the asset catalog and check contrast.

## Tokens

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `Color.bruPaper` | `#FAFAF7` | `#0A0A0A` | Main surface; text on ink panels |
| `Color.bruBg` | `#F2EFE7` | `#16140F` | Screen edges, status bar and bottom inset fill |
| `Color.bruBg2` | `#EDEAE0` | `#1C1A14` | Inset cards, chart backing |
| `Color.bruFaint` | `#E8E5DD` | `#222220` | Completed or de-emphasized fills, disabled controls |
| `Color.bruInk` | `#0A0A0A` | `#FAFAF7` | Text, 2pt rules, heavy panels, selected states |
| `Color.bruMuted` | `#69655C` | `#9D998E` | Secondary text, captions, metadata |
| `Color.bruHair` | `#D4D0C5` | `#2E2C28` | 1pt list-row dividers only |
| `Color.bruSignal` | `#FF5C1A` | `#FF7A3D` | The accent: primary CTA, completed sets, PRs, upward trends |
| `Color.bruSignalText` | `#C03700` | `#FF7A3D` | Readable accent text on paper-role surfaces |
| `Color.bruSignalOnInk` | `#FF5C1A` | `#C03700` | Readable accent text on adaptive ink panels |
| `Color.bruOnSignal` | `#0A0A0A` | `#0A0A0A` | Constant ink labels on signal, amber and green fills |
| `Color.bruAmber` | `#E3A12A` | `#FFB54D` | Warning: under minimum volume, under-trained |
| `Color.bruGreen` | `#3F8F5C` | `#4FBB78` | Encouragement: add a set, productive volume |
| `Color.bruBlue` | `#2F5ACF` | `#4A78E6` | Accumulation phase badge |
| `Color.bruTabSurface` | `#FFFFFF` | `#0A0A0A` | Tab bar surface only (cool white, not warm paper) |
| `Color.bruTabSeparator` | `#D9D9D9` | `#454545` | Tab bar cell dividers only |

## Rules

- Ink and paper swap in dark mode. An ink panel is black in light mode and near-white in dark mode, so pick text colors by role (`bruPaper` on `bruInk`), never by appearance.
- `bruSignal` is the only accent fill. Use it for one primary action per screen and for state that matters (completed, PR, trend). Its readable foreground variants share the same semantic role. Never use the bright fill as small text on paper.
- Amber, green and blue are status colors. Always pair them with a word ("Under MEV"), never color alone.
- `bruHair` and the two tab tokens are single-purpose. Do not use them as text or surface colors.
- `bruFaint` is a fill behind text, never a text color. On paper it is too light to read. Put `bruMuted` or `bruInk` text on it.
- Never use `Color.accentColor`, `Color(.system...)` or hex literals in feature code.

## Other colorsets

`AccentColor` is the app's global tint. It colors system alerts, confirmation dialogs and the text cursor, so it uses the ink values to keep system chrome neutral.
No BRU screen reads it directly.

New Block's phase colors come from `BlockPhaseColors` in `fitbod/Periodization/BlockPhaseColors.swift`.
Accumulation, intensification, peak and deload fill with `bruBlue`, `bruSignal`, `bruGreen` and `bruAmber`; realization and the chart labels use these phase colorsets:

| Colorset | Light | Dark | Use |
| --- | --- | --- | --- |
| `phaseRealization` | `#7A3C6E` | `#C68BBE` | Realization fill: phase badge, Add Phase swatch, chart band and rail |
| `phaseAccumulationLabel` | `#2A52BF` | `#9DB6F5` | ACCUM. label on the progression chart |
| `phaseIntensificationLabel` | `#A83000` | `#FF7A3D` | INTENS. label on the progression chart |
| `phasePeakLabel` | `#22603C` | `#8FD9A8` | PEAK label on the progression chart |
| `phaseRealizationLabel` | `#4E2646` | `#E0B8D8` | REAL. label on the progression chart |
| `phaseDeloadLabel` | `#8A5C18` | `#F2C46E` | DELOAD label on the progression chart |

Each chart label sits on its phase band, the phase fill at 0.18 opacity over `bruPaper`, and reads at 4.5:1 or more there in both modes.
The lowest are DELOAD at 4.86:1 and ACCUM. at 5.05:1 in light mode.
`tokens_check.py` does not check these band pairs; `ProgramDarkModeUITests` measures them on screen.

## Contrast

Required: 4.5:1 for text, 3:1 for large text (at least 18pt regular or 14pt bold) and for control boundaries.
`tokens_check.py` checks the approved role pairs; it does not inspect every view's rendered foreground/background.
The initial milestone values failed the following pairs. They motivated the
foreground-role correction below; they are retained here as rationale, not as
approved pairings:

| Pair | Mode | Ratio | Where it shows |
| --- | --- | --- | --- |
| `bruSignal` text on `bruPaper` | light | 2.95 | Signal labels and header actions, completed set numbers |
| `bruPaper` text on `bruSignal` | light | 2.95 | CTA labels on the signal fill |
| `bruSignal` text on `bruInk` | dark | 2.48 | Signal text on ink panels, which are near-white in dark mode |
| `bruInk` text on `bruAmber` | dark | 1.68 | Amber warning chip |
| `bruPaper` text on `bruGreen` | light | 3.79 | Green encouragement chip |
| `bruMuted` on `bruBg2` | light | 4.48 | Secondary text in inset cards |
| `bruMuted` on `bruFaint` | light | 4.28 | Disabled button labels |

## Implemented foundation correction

Shared buttons, chips, badges, readouts and headers now use the role-specific
foregrounds. Fills keep `bruSignal` unchanged, so the accent looks the same.
Signal buttons have an ink outline because the orange fill alone falls just
below 3:1 against paper. Pressed buttons use paper on ink. Compact buttons
retain a 44pt touch target.
Text gets its own tokens, chosen with `tokens_check.py`:

| New or changed token | Light | Dark | Use |
| --- | --- | --- | --- |
| `bruSignalText` (new) | `#C03700` | `#FF7A3D` | Signal-colored text and thin strokes on paper, `bruBg` and `bruBg2` |
| `bruSignalOnInk` (new) | `#FF5C1A` | `#C03700` | Signal-colored text on ink panels |
| `bruOnSignal` (new) | `#0A0A0A` | `#0A0A0A` | Labels on signal, amber and green fills |
| `bruMuted` (changed) | `#69655C` | `#9D998E` | Secondary text, now at least 4.6:1 on every light surface |

These are the role pairs checked by the script. Passing this table proves the
token combinations; screen verification must additionally prove each caller
uses the correct foreground for its actual surface. The caller audit remains
part of milestone verification. The change is tracked in [changelog.md](changelog.md).
