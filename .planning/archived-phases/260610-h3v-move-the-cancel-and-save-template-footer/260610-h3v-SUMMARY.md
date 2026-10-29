---
phase: quick-260610-h3v
plan: "01"
subsystem: periodization-ui
tags: [spacing, footer, new-block, bru]
key-files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
decisions:
  - "Top padding increased 10 -> 24 (+14pt delta) to match mockup gap above footer buttons"
  - "bottomActionHeight token bumped 72 -> 86 in lockstep to preserve scroll clearance"
metrics:
  duration: ~3 min
  completed: "2026-06-10"
  tasks_completed: 1
  files_changed: 1
---

# Quick 260610-h3v: Move the Cancel and Save Template Footer — Summary

**One-liner:** Footer top padding increased 10 -> 24pt and bottomActionHeight bumped 72 -> 86pt in lockstep so the CANCEL / SAVE TEMPLATE buttons sit lower with a clear gap above them, matching final-design.png.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Increase footer top padding (spacing-only) | 0d12a6f | fitbod/Periodization/BlockBuilderView.swift |

---

## Changes Made

### fitbod/Periodization/BlockBuilderView.swift

Two changes applied, both in lockstep:

1. **`NewBlockBottomActionBar` padding (line ~1934):**
   - `.padding(.top, 10)` → `.padding(.top, 24)` (+14pt)
   - No other padding values touched; `.padding(.bottom, 8)` and `.padding(.horizontal, NewBlockScreenTokens.screenMargin)` unchanged

2. **`NewBlockScreenTokens.bottomActionHeight` token (line ~326):**
   - `72` → `86` (same +14pt delta, in lockstep with the top-padding increase)
   - Comment updated: "52pt button + ~32pt padding" (was "52pt button + ~20pt padding")

---

## Verification

### Automated tests — all three guardrail suites GREEN

- `NewBlockBuilderFidelityTests` — 6/6 passed
- `BlockBuilderViewCopyTests` — 1/1 passed (verbatim copy including "CANCEL" / "SAVE TEMPLATE" unchanged)
- `BlockBuilderViewActivationTests` — 3/3 passed

No copy, struct-name, button-height, or behavior changes were introduced; all guardrails confirmed clean.

### Visual judgment (executor)

Comparing the committed spacing against `bru-screens/New-block/final-design.png`:

The mockup shows the CANCEL (ghost) button and the SAVE TEMPLATE (filled, dark) button sitting near the bottom of the screen with a clear, visible gap between the last phase card and the footer bar. The gap is noticeably more than the previous 10pt hugging distance — consistent with the 24pt top padding applied. The bar background extends through the safe area inset.

The 24pt value was specified in the plan based on mockup analysis. Based on visual comparison, the gap looks consistent with the mockup's proportions.

**Final visual sign-off rests with the user.** Build and run on iPhone 17 Simulator or device, open Routines -> New Block, and compare against `bru-screens/New-block/final-design.png`. If the gap reads too small or too large, the top-padding value and `bottomActionHeight` can be re-tuned by the same delta.

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None.

---

## Threat Flags

None. This is a pure spacing change with no new network endpoints, auth paths, file access patterns, or schema changes.

---

## Self-Check

- [x] `fitbod/Periodization/BlockBuilderView.swift` modified — confirmed
- [x] Commit `0d12a6f` exists — confirmed
- [x] `.padding(.top, 24)` set — verified via grep
- [x] `bottomActionHeight = 86` set — verified via grep
- [x] All three guardrail suites GREEN — confirmed by xcodebuild output

## Self-Check: PASSED
