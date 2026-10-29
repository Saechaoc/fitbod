# BRU principles

BRU reads like a training log printed on warm paper with black ink.
Every BRU screen follows the rules below.
The chosen direction is `bru-screens/Fitbod-Session/screens/directions--brutalist.png`.

## 1. Paper and ink carry the interface

Surfaces are warm off-white paper (`bruPaper`, `bruBg`, `bruBg2`).
Text, rules and heavy panels are black ink (`bruInk`).
In dark mode the two swap, so ink panels become light slabs on a dark page.
Token details: [color.md](color.md).

## 2. One accent, used on purpose

The orange-red signal (`bruSignal`) marks the one primary action on a screen, completed sets, personal records and upward trends.
It is never decoration, and two signal CTAs never compete on one screen.
Amber, green and blue are status colors, not accents.

## 3. Rules make the structure

Sections are separated by 2pt ink rules and list rows by 1pt hair rules.
There are no shadows, no blur, no rounded corners and no capsules.
Measurements: [layout.md](layout.md).

## 4. Type does the work of icons

Condensed caps carry titles and hero numbers, mono carries data and labels.
Typographic glyphs (‹ › ▸ + −) replace SF Symbols.
Details: [typography.md](typography.md) and [iconography.md](iconography.md).

## 5. Compact, never cramped

Data rows are dense so a whole workout fits on screen.
Every touch target is still at least 44pt, and all text scales with Dynamic Type.
Details: [interaction.md](interaction.md) and [accessibility.md](accessibility.md).

## 6. Uppercase is a style, not a string

Labels look uppercase through `.textCase(.uppercase)` while the source string stays in normal case.
VoiceOver and UI tests therefore read words ("Add set"), not letters.

## 7. System chrome stays out

BRU screens use no navigation bars, toolbars, `Form`, segmented `Picker`, system `Stepper` or system toggle styling.
BRU components replace each of them: [components.md](components.md).
Unit tests grep the BRU screens for the banned APIs (`BRUGrepAuditPhase6Tests`, `Phase3BRUGrepAuditTests`, `BRUPrimitivesTests`).
