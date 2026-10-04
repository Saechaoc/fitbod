# Chalkline — Fitbod's design system

Chalkline is the visual and interaction language of the app. It is built
for one job: logging heavy, structured training quickly and reading it back
precisely.

**Identity in one line:** a training logbook. Warm chalk paper for reading,
iron-black panels for live state ("now"), one signal orange for the next
thing to do, and ruled tables for numbers.

It takes cues from strong editorial training apps (warm off-white surfaces,
black panels, an orange-red accent, bold condensed headings, clear dividers)
but is its own system: the accent is reserved for *the next action* instead
of decoration, every number sits in a ruled table column, inputs are larger
than typical (44 pt fields, 48 pt set check, 56 pt thumb-zone primaries),
and every text pair clears WCAG AA.

| | Where |
|---|---|
| Tokens (code) | [`fitbod/DesignSystem/ChalkTokens.swift`](../../fitbod/DesignSystem/ChalkTokens.swift) |
| Components (code) | [`fitbod/DesignSystem/`](../../fitbod/DesignSystem/) — see [components.md](components.md) |
| In-app gallery | Settings → Design system → **Component gallery** ([`ComponentGalleryView.swift`](../../fitbod/DesignSystem/ComponentGalleryView.swift)) |
| Design canvas | Claude Design — "Fitbod · Chalkline design system" (Foundations, Components and 13 screen boards) |
| Screen specs | [../design/screens.md](../design/screens.md) |

Views never hard-code a hex value, a font, or a spacing number. If a value
is missing, add a token here and in `ChalkTokens.swift` together.

---

## 1. Principles

1. **The next action is orange — and only that.** At any moment there is at
   most one accent-filled control per region: Start workout, the next set's
   check ring, the rest dock's Skip/Done, Save. Orange is never decoration,
   never a section color, never body text.
2. **Live state is iron.** Things happening *now* (the workout header, the
   rest timer, the finished-workout hero) sit on a black panel. Everything
   you read later sits on paper.
3. **Numbers live in columns.** Set tables use fixed, Dynamic-Type-scaled
   columns (Set · Previous · Weight · Reps · RPE · ✓) under a 1.5 pt ink rule.
   Digits are monospaced so values don't jitter.
4. **Fast, one-handed.** Primary actions sit in the thumb zone (bottom bars,
   trailing check buttons). Targets are ≥ 44 pt; the set check is 48 pt.
5. **Honest data.** Nothing is logged silently. Invalid input gets an inline
   message + danger outline + haptic + VoiceOver announcement — never a
   disabled button with no explanation.
6. **Scale, don't truncate.** Every text style is a Dynamic Type style; rows
   reflow (stack) instead of clipping when the text gets large.

---

## 2. Color

Semantic tokens — `chalkInk2` means *secondary text*, never "a grey". Each
token resolves for light, dark and Increase Contrast (`HC`) automatically
(`ChalkPalette.Token.uiColor` is trait-aware). SwiftUI usage:
`.foregroundStyle(.chalkInk2)`, `.background(Color.chalkCanvas)`.

### Surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `chalkCanvas` | `#F2EEE5` | `#11100E` | App background (paper) |
| `chalkSurface` | `#FBF9F4` | `#1C1A17` | Cards, list rows, sheets |
| `chalkSunken` | `#E6E1D4` (HC `#DDD6C6`) | `#282621` | Input wells, idle chips |
| `chalkComplete` | `#E3DDCF` | `#24221E` | Background of a completed set row |
| `chalkDivider` | `#CFC7B6` (HC `#9E9583`) | `#38352F` (HC `#5A564E`) | Hairline separators (decorative) |

### Ink

| Token | Light | Dark | Use |
|---|---|---|---|
| `chalkInk` | `#171614` | `#F2EEE5` | Primary text, icons, outlines, rules, selected chips |
| `chalkInk2` | `#57534B` (HC `#3F3C36`) | `#B5AFA1` (HC `#D2CCBE`) | Secondary text, meta lines |
| `chalkInk3` | `#66615A` (HC `#4A4640`) | `#9A9487` (HC `#C2BCAE`) | Captions, placeholders, "no previous" dashes |

### Iron panels (live state)

| Token | Light | Dark | Use |
|---|---|---|---|
| `chalkPanel` | `#171614` | `#2A2723` | Workout header, rest dock/sheet, summary hero |
| `chalkPanelRaised` | `#2B2925` | `#36332E` | Controls placed on a panel |
| `chalkPanelBorder` | `#171614` | `#403C36` | Panel outline (separates panel from canvas in dark mode) |
| `chalkOnPanel` | `#F2EEE5` | `#F2EEE5` | Text on panels |
| `chalkOnPanel2` | `#B4AE9F` (HC `#D6D0C2`) | `#B8B2A4` (HC `#D6D0C2`) | Secondary text on panels |

### Signal

| Token | Light | Dark | Use |
|---|---|---|---|
| `chalkAccent` | `#EC4E25` | `#FF6A3D` | Fill of the one primary action; progress; focus ring. **Never text.** |
| `chalkOnAccent` | `#171614` | `#171614` | Text/icons on an accent fill (ink, not white — 4.9:1 / 6.4:1) |
| `chalkAccentInk` | `#AD3510` (HC `#8F2A0B`) | `#FF7F57` | Accent-colored *text* on paper ("Prescribed 225 lb", set number of the next set) |
| `chalkAccentOnPanel` | `#FF6E42` | `#FF8A63` | Accent-colored text on panels ("Rest done +0:18") |
| `chalkDanger` | `#B42318` (HC `#8F1A12`) | `#FF7B6E` | Errors, validation, destructive actions |

The asset catalog's `AccentColor` is set to `chalkAccentInk` so system
controls that take the tint (toggles are re-tinted to ink explicitly) stay
legible.

### Contrast (WCAG 2.x, computed from the hex values above)

| Pair | Light | Dark |
|---|---:|---:|
| ink on canvas / surface | 15.6 / 17.2 | 16.4 / 15.0 |
| ink2 on canvas / surface | 6.6 / 7.3 | 8.7 / 8.0 |
| ink3 on canvas / surface / sunken | 5.3 / 5.8 / 4.7 | 6.3 / 5.8 / 5.0 |
| ink2 on complete | 5.7 | 7.3 |
| onPanel / onPanel2 on panel | 15.6 / 8.2 | 12.8 / 7.0 |
| accentOnPanel on panel | 6.5 | 6.4 |
| onAccent on accent | 4.9 | 6.4 |
| accentInk on canvas / surface | 5.5 / 6.1 | 7.6 / 7.0 |
| danger on canvas / surface | 5.7 / 6.3 | 7.5 / 6.9 |
| accent (non-text UI) on canvas | 3.2 | 6.7 |

Every text pair is ≥ 4.5:1. The accent fill is ≥ 3:1 against paper (WCAG
1.4.11 for UI components) and always carries ink text. Increase Contrast
darkens secondary inks, dividers and the accent ink further.

### Color rules

- One accent-filled control per region. A second "important" action is
  `secondary` (ink outline) or `inverse` (ink fill).
- Completed rows use `chalkComplete` + a filled ink check — completion is
  never communicated by color alone (the check glyph and VoiceOver value
  "complete" carry it too).
- Errors: `chalkDanger` text **with** an `exclamationmark.circle.fill` icon
  and a 1.5 pt danger outline on the offending field.
- Never put `chalkInk2/3` text on `chalkPanel` (use the `OnPanel` tokens).

---

## 3. Typography

SF Pro text styles only, so everything follows Dynamic Type. Condensed
width + heavy weight carries the identity on headings, labels, buttons and
numbers; reading text stays standard width (and is never uppercased).

| Token | Text style | Weight / width | Use |
|---|---|---|---|
| `chalkDisplay` | largeTitle | heavy · condensed · UPPERCASE | Screen hero titles ("UPPER A") |
| `chalkTitle` | title2 | bold · condensed | Sheet/section titles, empty-state titles |
| `chalkSubtitle` | title3 | heavy · condensed | Small headings inside cards, set number in stacked rows |
| `chalkHeadline` | headline | semibold | Exercise and routine names (wrap, never truncate) |
| `chalkBody` | body | regular | Reading text |
| `chalkCallout` | callout | regular | Supporting copy |
| `chalkFootnote` | footnote | regular | Meta lines ("Barbell · Chest") |
| `chalkLabel` | caption | bold · condensed · UPPERCASE · +0.8 tracking | Overlines, column labels (`chalkLabelStyle()`) |
| `chalkChip` | subheadline | bold · condensed | Chip text |
| `chalkButton` | headline | heavy · condensed · UPPERCASE · +0.6 tracking | Button labels |
| `chalkMetric` | title3 | heavy · condensed · monospaced digits | Set inputs, inline numbers |
| `chalkMetricLarge` | title | heavy · condensed · monospaced digits | Metric tiles, history day numbers |

Navigation bar titles use the same condensed heavy face via
`ChalkAppearance.apply()` (UIKit appearance, scaled with `UIFontMetrics`).
Large countdowns (rest dock 40 pt, rest sheet 88 pt) use `@ScaledMetric`
sizes so they scale too.

---

## 4. Space, shape, size

| Spacing (`Chalk.Space`) | xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48 · gutter 16 |
|---|---|
| **Radius** (`Chalk.Radius`, continuous corners) | sm 6 (chips, tags, badges) · md 10 (inputs, buttons, messages) · lg 16 (cards, panels) · xl 24 (hero panels, rest dock) |
| **Stroke** (`Chalk.Line`) | hairline 1 (separators, card outlines) · strong 1.5 (control outlines, table rule) · focus 2 (accent focus ring) · heavy 3 (rule under screen titles) |
| **Touch / size** (`Chalk.Size`) | minTouch 44 · input 44 · setCheck 48 · button 50 · primaryBar 56 · chip 40 (44 hit area) |
| **Motion** (`Chalk.Motion`) | quick 0.15 s · standard 0.25 s — always gated by Reduce Motion |

Set-table columns (`SetTableMetrics`, scaled with Dynamic Type): Set 28 ·
Previous ≥ 44 (flexible) · Weight 74 · Reps 54 · RPE 42 · ✓ 48, spacing 6.
When the measured row width is narrower than their sum (small iPhones at
larger text, every phone at accessibility sizes) rows switch to the stacked
layout and the column labels collapse to "SETS".

---

## 5. Iconography

SF Symbols only, at the text style of their context, `regular`/`semibold`
weight. Icon-only buttons always have an accessibility label
(`ChalkIconButton(_:accessibilityLabel:)` makes it a required argument).

| Meaning | Symbol |
|---|---|
| Tabs | `calendar` Today · `list.bullet.rectangle.portrait` Routines · `dumbbell` Library · `clock.arrow.circlepath` History · `gearshape` Settings |
| Add / overflow / close-minimize | `plus` · `ellipsis` · `chevron.down` |
| Set complete | `checkmark` in a filled ink circle (open set: outlined ring; next set: accent ring) |
| Error | `exclamationmark.circle.fill` (always paired with text) |
| Swap / note / pin / plate math | `arrow.left.arrow.right` · `square.and.pencil` · `pin` · `circle.grid.2x1` |
| Destructive | `trash` |

---

## 6. Interaction states

| State | Treatment |
|---|---|
| Pressed | Buttons: ink overlay + 0.97 scale (scale skipped with Reduce Motion) |
| Disabled | 45 % opacity; the control still explains itself (e.g. "Select exercises") |
| Selected (chip, list row, preset) | Ink fill + canvas text, `.isSelected` trait; picker rows add a check |
| Focused input | 2 pt accent ring |
| Error | 1.5 pt danger ring + `ChalkValidationText` below + error haptic + VoiceOver announcement |
| Next set | Set number in accent ink + accent check ring |
| Completed set | `chalkComplete` row, filled ink check, fields read-only (tap ✓ again to edit) |
| Live (now) | Iron panel |
| Overtime rest | Countdown turns accent-on-panel and counts up ("+0:18"), success haptic once |

---

## 7. Accessibility rules

- **Dynamic Type:** text styles only; `@ScaledMetric` for any fixed number
  that sits next to text; rows stack instead of truncating; names wrap.
- **VoiceOver:** set rows expose "Set 2 weight, lb", value "225" or
  "empty, required"; the check reads "Complete set 2" / value "open|complete";
  steppers and the rest countdown are adjustable (swipe up/down = ±1 / ±15 s);
  validation errors are announced; decorative icons are hidden.
- **Touch targets:** ≥ 44 × 44 pt everywhere (`Chalk.Size.minTouch`).
- **Color independence:** state is always also conveyed by glyph, text or
  value.
- **Reduce Motion:** scale and slide transitions are replaced by fades; the
  progress bar animation is removed.
- **Safe areas:** bottom bars use `safeAreaInset(edge: .bottom)`; canvas
  backgrounds ignore safe areas, content never does.
- **Contrast:** see the table above; Increase Contrast variants exist for
  every secondary ink.
