---
id: superset-assignment
kind: sheet
title: Add to superset
view: fitbod/Routines/SupersetAssignmentSheet.swift:20
tab: [program, today]
presents_from: [session-editor]
closes_with: cancel
mock: bru-screens/Fitbod-Session/screens/phase-2--modal-superset.png
seed: -fitbod-seed-progress-history
captured: 2026-10-31 61353088
img: [img/17e-default-light-superset-assignment.png, img/17e-default-dark-superset-assignment.png, img/17e-ax3-light-superset-assignment.png, img/17promax-default-light-superset-assignment.png, img/17promax-ax3-light-superset-assignment.png]
tree: tree/superset-assignment.txt
---

The lifter puts one exercise of a saved session into an existing superset or a new one.

<img src="img/17e-default-light-superset-assignment.png" width="300" alt="Add to superset on the iPhone 17e">

## Entry points

| From | Tap | Kind |
|---|---|---|
| [session-editor](session-editor.md) | a long press on an exercise's title row, then Move to superset… or Make superset, in a saved session | sheet |

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| CANCEL | [session-editor](session-editor.md), unchanged | sheet | cancel |
| A superset row, such as "Superset A (Bench + Row)" | [session-editor](session-editor.md), with the exercise in that superset | sheet | verb |
| + NEW SUPERSET | [session-editor](session-editor.md), with the exercise in a new superset | sheet | verb |
| A swipe down | [session-editor](session-editor.md), unchanged | sheet | cancel |

+ NEW SUPERSET saves the new superset to the store at once, before the session itself is saved.
Pairing two exercises takes two trips: one exercise makes the superset, and the second picks it from the list.

## States

| State | How to reach it | Screenshot |
|---|---|---|
| No supersets yet | W13 progress seed: Bench & Squat's editor, a long press on the bench press, Make superset | [main](img/17e-default-light-superset-assignment.png) |
| With supersets to join | not captured: the tour cancels the sheet, so no superset exists when it opens | - |
| AX3 | The title fits one line above CANCEL, on both phones | [ax3](img/17e-ax3-light-superset-assignment.png), [Pro Max AX3](img/17promax-ax3-light-superset-assignment.png) |
| Pro Max | Same as the main state; the title fits one line beside CANCEL | [Pro Max](img/17promax-default-light-superset-assignment.png) |

Dark mode changes only colour and size: [dark](img/17e-default-dark-superset-assignment.png).
At default text on the 17e the title wraps to two lines, "ADD TO" over "SUPERSET".

## Compared with the mock-up

| In the mock-up | In the app | Difference |
|---|---|---|
| A half-height sheet with a grabber over the dimmed editor | a full-height sheet | The editor behind is hidden. |
| "LONG-PRESSED: INCLINE DB PRESS" and a large ADD TO SUPERSET title | a small header title | The sheet does not say which exercise it acts on. |
| "Pair 2-4 lifts. Sets alternate between members. Rest belongs to the last lift in the cluster." | no help text | Nothing explains what a superset does. |
| Every exercise of the session with a checkbox, SOURCE and PAIR A tags and a CLUSTER chip | existing supersets as rows, plus + NEW SUPERSET | The lifter cannot pick partners here. |
| REST BEHAVIOR: MINIMAL, STANDARD, EXTENDED with a summary line | none | No rest setting for the superset. |
| A CANCEL and PAIR 2 LIFTS ▸ footer | CANCEL in the header, + NEW SUPERSET in the body | The confirm action names no count. |

## VoiceOver order

1. Cancel
2. ADD TO SUPERSET
3. + New superset

Gaps:

- The title is typed in capitals in the source, so VoiceOver may read it as letters, and it is not marked as a header.
- The session editor behind the sheet stays in the tree (not checked by hand).

## Findings

<!-- findings are linked after the audit -->
