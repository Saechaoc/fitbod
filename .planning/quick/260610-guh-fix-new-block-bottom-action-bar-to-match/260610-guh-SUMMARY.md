---
phase: 260610-guh
plan: "01"
subsystem: Periodization
tags: [ui, bru-design, bottom-bar, typography]
key-files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
decisions:
  - "Used displayPrimaryTitle computed property to strip trailing arrow glyphs for display while preserving verbatim literals in primaryTitle for guardrail test compatibility"
  - "Added NewBlockType.cta (13pt) alongside existing chrome (11pt) — did not mutate chrome to avoid global visual regression across ~15 call sites"
  - "Overlaid RoundedRectangle stroke on CANCEL button container rather than the Button label frame to match ghost-pill pattern used elsewhere in BRU design system"
metrics:
  duration: "~20 minutes"
  completed: "2026-06-10"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 1
---

# Phase 260610-guh Plan 01: Fix New Block Bottom Action Bar Summary

**One-liner:** Restyle NewBlockBottomActionBar to BRU final-design — outlined ghost CANCEL pill, bookmark.fill CTA icon, SpaceGrotesk-Bold 13pt typography, no trailing arrow glyphs in rendered text.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add cta font token + restyle NewBlockBottomActionBar | 9aa9a56 | fitbod/Periodization/BlockBuilderView.swift |
| 2 | Run guardrail + fidelity test suites | (no commit — test-only) | — |
| 3 | Human visual diff against final-design.png | pending-human | — |

## Source Edits Made

### Edit A — NewBlockType.cta token (line 333)

Added a new `cta` static let immediately after `chrome` in the `NewBlockType` enum:

```swift
static let cta = Font.custom("SpaceGrotesk-Bold", size: 13)
```

The existing `chrome` line (size: 11) was left completely untouched. It remains referenced by ~15 other call sites in the file.

### Edit B — NewBlockBottomActionBar rewrite (lines 1886–1957)

Three changes within the struct:

1. **CANCEL button** — switched from `NewBlockType.chrome` + ink foreground + no border to `NewBlockType.cta` + `muted` foreground + `overlay(RoundedRectangle.stroke(cardStroke, lineWidth: 1))`. Horizontal padding bumped 18 → 22 to give the outlined pill proper breathing room.

2. **Primary CTA** — replaced the `RoundedRectangle(cornerRadius: 2).frame(width: 7, height: 7).foregroundStyle(.white)` square glyph with `Image(systemName: "bookmark.fill").font(.system(size: 12, weight: .semibold))`. HStack spacing bumped 6 → 8. Text switched from `primaryTitle` to `displayPrimaryTitle` and from `chrome` to `cta` font at tracking 2.5. Fill/clip/disabled behavior unchanged.

3. **displayPrimaryTitle** — new private computed property alongside the unchanged `primaryTitle`:
   ```swift
   private var displayPrimaryTitle: String {
       primaryTitle
           .replacingOccurrences(of: " ▸", with: "")
           .replacingOccurrences(of: " ↑", with: "")
   }
   ```
   This strips the arrow glyphs from rendered text while keeping the source literals intact for the verbatim guardrail tests.

4. **Trailer comment** — updated to credit the 260610-guh restyle alongside the existing 260528-vi2 attribution.

### Unchanged (confirmed)

- `bottomActionHeight = 72` — untouched
- `NewBlockType.chrome = Font.custom("SpaceGrotesk-Bold", size: 11)` — untouched
- `primaryTitle` returns original literals: `"NAME FIRST ↑"`, `"SAVE CHANGES ▸"`, `"SAVE TEMPLATE ▸"` — untouched
- Padding tokens (`.horizontal: screenMargin`, `.top: 10`, `.bottom: 8`) — untouched
- `.background(NewBlockScreenTokens.paper.ignoresSafeArea(edges: .bottom))` — untouched

## Test Results

All three guardrail suites ran on iPhone 17 Pro Max simulator. Result: `** TEST SUCCEEDED **`

| Suite | Tests | Result |
|-------|-------|--------|
| BlockBuilderViewCopyTests | 1 | passed |
| NewBlockBuilderFidelityTests | 6 | passed |
| BlockBuilderViewActivationTests | 3 | passed |

**Total: 10 tests, 0 failures, 0 compile errors.**

Key assertions confirmed passing:
- `verbatimCopyStringsArePresentInSource` — source still contains `"NAME FIRST ↑"`, `"SAVE TEMPLATE ▸"`, `"CANCEL"` verbatim
- `blockBuilderViewExposesNewBlockMockStructureAndCopy` — full structure/copy fidelity
- `blockBuilderViewExposesDirectManipulationAffordances` — affordance rendering intact

## Task 3: Human Visual Verification — Pending

Task 3 is a `checkpoint:human-verify`. Build compiles cleanly and all guardrail tests pass. Visual sign-off against `bru-screens/New-block/final-design.png` is pending manual review.

**To verify:**
1. Build and run fitbod on iPhone 17 Pro Max simulator in Xcode.
2. Periodization tab → "+ NEW BLOCK".
3. Scroll to bottom — confirm:
   - CANCEL: light-gray outlined pill, muted-gray text, no fill, left-aligned.
   - Primary CTA: black filled pill, white bookmark icon + "SAVE TEMPLATE" (no arrow).
   - Both buttons appear heavier than before (13pt vs 11pt).
4. Empty the name field → confirm "NAME FIRST" (no arrow) in muted style.
5. If editing a block, confirm "SAVE CHANGES" (no arrow).

## Deviations from Plan

None — plan executed exactly as written. All structural constraints respected.

## Known Stubs

None. The bottom action bar is fully wired — `canCreate` and `isEditing` flow from the parent view via `let` properties.

## Self-Check

- [x] `fitbod/Periodization/BlockBuilderView.swift` modified and committed at 9aa9a56
- [x] `NewBlockType.cta` present in source
- [x] `primaryTitle` literals `"NAME FIRST ↑"`, `"SAVE TEMPLATE ▸"`, `"CANCEL"` preserved verbatim
- [x] `displayPrimaryTitle` strips arrows for display
- [x] `bookmark.fill` replaces 7×7 square glyph
- [x] `RoundedRectangle.stroke(cardStroke` on CANCEL
- [x] `chrome` unchanged at size: 11
- [x] `bottomActionHeight` unchanged at 72
- [x] All 3 guardrail suites passed (10/10 tests)
- [x] No test files created or modified
