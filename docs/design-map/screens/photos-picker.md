---
id: photos-picker
kind: system
title: Photos
view: fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift:79
tab: library
presents_from: [custom-exercise]
closes_with: close
mock: none
seed: none
captured: 2026-10-31 61353088
img: [img/17e-default-light-photos-picker.png, img/17promax-default-light-photos-picker.png]
tree: tree/photos-picker.txt
---

The lifter picks one photo from the library to show on a custom exercise.

<img src="img/17e-default-light-photos-picker.png" width="300" alt="Photos on the iPhone 17e">

## Entry points

| From | Tap | Kind |
|---|---|---|
| [custom-exercise](custom-exercise.md) | + ADD PHOTO, or CHANGE PHOTO when the exercise already has one | sheet |

iOS draws this sheet; the app only presents it, limited to images, from its BRU text control.
iOS shows its own "Private Access to Photos" banner, because the app asks for no photo library permission.

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| ✕ (VoiceOver "Cancel") | [custom-exercise](custom-exercise.md), unchanged | sheet | close |
| A photo | [custom-exercise](custom-exercise.md), with the photo shown above CHANGE PHOTO and REMOVE PHOTO | sheet | verb |

The app loads the picked photo's full data as it is and keeps it on the exercise.
The picker's own footer says "Location Is Included", and the app does not remove that metadata.
If the photo fails to load, the editor shows nothing and keeps its old state.

## States

| State | How to reach it | Screenshot |
|---|---|---|
| The simulator's sample library | W01 fresh store: Library > a new custom exercise > its detail > Edit > + ADD PHOTO | [main](img/17e-default-light-photos-picker.png) |

The Pro Max at default text changes only size: [Pro Max](img/17promax-default-light-photos-picker.png).
The dark and AX3 versions were not captured: this is the last step of its walk, which ends with the app terminated, and the main-state runs do not open it.

## Compared with the mock-up

No mock-up was drawn for this sheet.

## VoiceOver order

The picker runs in its own process, so the tree holds the exercise editor behind it plus the picker's own elements:

1. Cancel
2. Photos, Selected
3. Collections
4. Private Access to Photos
5. The first photo, read as "Photo" and its date
6. Sort and Filter
7. Search

Gaps:

- The app's exercise detail and editor stay in the tree behind the sheet; they belong to iOS's presentation, not to the app's own views.

## Findings

- Minor: [D-111](../audit.md#d-111).
- Polish: [D-292](../audit.md#d-292).
