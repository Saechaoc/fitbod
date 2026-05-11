---
phase: 01
plan: 00-02
subsystem: foundation/asset-catalog
tags: [ios, swiftui, assets, brand]
requires: []
provides:
  - AccentColor (light #0E7C86, dark #3FBFC9, sRGB)
  - AppIcon (1024x1024 placeholder, iOS 18+ single-slot manifest)
affects:
  - fitbod/Assets.xcassets/AccentColor.colorset/Contents.json
  - fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json
  - fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
  - scripts/generate_app_icon.swift
tech_stack:
  added:
    - CoreText (icon glyph rendering in generator script)
    - ImageIO (PNG encoding in generator script)
  patterns:
    - Asset-catalog-driven theming (no per-view .tint() modifiers)
key_files:
  created:
    - fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
    - scripts/generate_app_icon.swift
  modified:
    - fitbod/Assets.xcassets/AccentColor.colorset/Contents.json
    - fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json
decisions:
  - Used CoreText (kCTFontAttributeName / kCTForegroundColorAttributeName) instead of NSAttributedString.Key.* since AppKit/UIKit are not importable from a `swift` CLI invocation
  - Replaced 14-slot stock AppIcon manifest with single 1024x1024 iOS-only slot (iOS 18+ "Any Appearance" flow) — drops macOS slots since fitbod is iOS-only
  - Substituted `python3 -m json.tool` for `plutil -lint` validation: on macOS 26.4+, plutil rejects JSON-format Contents.json files even though they are the Xcode-canonical format
metrics:
  duration_seconds: 266
  tasks_completed: 4
  files_touched: 4
  completed: 2026-05-11T06:05:36Z
---

# Phase 1 Plan 00-02: Asset Catalog Summary

One-liner: Wired AccentColor to UI-SPEC teal (#0E7C86 light / #3FBFC9 dark) and generated a 1024×1024 placeholder AppIcon (white "F" on accent) via a CoreText one-shot Swift script.

## Outcome

The fitbod target's tint now propagates from the asset catalog through every native SwiftUI control — `TabView` selection, `NavigationLink` chevron, `Toggle`, `Slider`, `.searchable` cursor — automatically, with no per-view `.tint()` modifiers required. The placeholder AppIcon fills the simulator/device home-screen slot once the project compiles (after plan 01-02 wires Item.swift removal and `SchemaV1`). Visual identity layer is locked.

## Files Touched

| Path | Status | Purpose |
|------|--------|---------|
| `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` | modified | Universal + dark luminosity sRGB color variants |
| `fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json` | modified | Single-slot iOS 18+ 1024×1024 icon manifest (replaces 14-slot stock template) |
| `fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | created | 21,055-byte 1024×1024 PNG, white "F" on teal background |
| `scripts/generate_app_icon.swift` | created | CoreGraphics/CoreText one-shot icon generator; reproducible build of the placeholder |

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `a1df0f3` | chore | wire AccentColor #0E7C86/#3FBFC9 + placeholder AppIcon |

## Acceptance Criteria Verification

| # | Criterion | Status | Verification |
|---|-----------|--------|--------------|
| 1 | AccentColor JSON parses | PASS (with substituted validator) | `python3 -m json.tool` — see Deviations |
| 2 | Light value matches `#0E7C86` (R 0.055, G 0.486, B 0.525) | PASS | sRGB components in committed JSON exactly match planner-derived values |
| 2b | Dark value matches `#3FBFC9` (R 0.247, G 0.749, B 0.788) | PASS | sRGB components in committed JSON exactly match planner-derived values |
| 3 | AppIcon JSON parses | PASS (with substituted validator) | `python3 -m json.tool` — see Deviations |
| 4 | AppIcon-1024.png is 1024×1024 | PASS | `sips -g pixelWidth -g pixelHeight` reports `pixelWidth: 1024 / pixelHeight: 1024` |
| 5 | Teal icon appears on home screen after build | DEFERRED | Project not yet compileable (gates on plan 01-02 removing `Item.swift` and wiring `SchemaV1`); icon will appear automatically when build succeeds |

## Color Component Derivation

Light `#0E7C86`:
- R `0x0E` = 14/255 = **0.055**
- G `0x7C` = 124/255 = **0.486**
- B `0x86` = 134/255 = **0.525**

Dark `#3FBFC9`:
- R `0x3F` = 63/255 = **0.247**
- G `0xBF` = 191/255 = **0.749**
- B `0xC9` = 201/255 = **0.788**

All values stored in sRGB color space (`"color-space" : "srgb"`).

## Deviations from Plan

### 1. [Rule 1 — Acceptance criteria command outdated on macOS 26.4+] Substituted `python3 -m json.tool` for `plutil -lint`

- **Found during:** Acceptance-criteria validation
- **Issue:** Plan's acceptance criteria specify `plutil -lint <Contents.json>` exits 0. On macOS 26.4.1 (current host), `plutil -lint` rejects JSON-format input with `(Unexpected character { at line 1)` even when the file is well-formed JSON. The tool expects xml/binary plist format; the JSON-Xcode convention for `.colorset` / `.appiconset` `Contents.json` is no longer accepted by `plutil -lint`. (This may be a regression — older macOS versions accepted JSON.)
- **Fix:** Validated both Contents.json files with `python3 -m json.tool <path> > /dev/null` (exits 0 on valid JSON, non-zero otherwise). Both files PASS this equivalent check. The semantic intent of the acceptance criterion — "JSON is syntactically valid" — is satisfied.
- **Files modified:** None (only the validation command changed)
- **Commit:** N/A (no code change)

### 2. [Rule 3 — Blocking issue] CoreText attribute keys substituted for AppKit `NSAttributedString.Key`

- **Found during:** First run of `scripts/generate_app_icon.swift`
- **Issue:** Initial draft used `NSAttributedString.Key.font` / `.foregroundColor`, which are defined in AppKit / UIKit. When invoked as `swift scripts/generate_app_icon.swift ...` from the command line, neither framework is implicitly imported, so the compiler reports `error: type 'NSAttributedString.Key' has no member 'font'`.
- **Fix:** Replaced `[NSAttributedString.Key: Any]` with `[CFString: Any]` keyed by the CoreText constants `kCTFontAttributeName` / `kCTForegroundColorAttributeName`, and switched from `NSAttributedString` to `CFAttributedStringCreate` for the same reason. This is the right primitive for a Foundation-only CoreText/ImageIO pipeline anyway.
- **Files modified:** `scripts/generate_app_icon.swift`
- **Commit:** `a1df0f3` (combined with main commit)

### 3. [Rule 3 — Race against Xcode's actool] Used `git commit -o` (`--only`) for atomic commit

- **Found during:** Initial commit attempts
- **Issue:** Xcode (running in the background with the project open, PID 5706) appears to reconcile and rewrite `Contents.json` files asynchronously when its asset-catalog watcher detects changes — it reverted the AccentColor manifest back to the empty stock state multiple times between Write and `git add`. Combined with a parallel orchestrator from plan 00-01 staging unrelated `.gitkeep` files, ordinary `git add ... && git commit` repeatedly failed: by commit time the working-tree changes had been unstaged because Xcode had reset them to match HEAD.
- **Fix:** Used `git commit -o <path>... -m ...` in a single shell pipeline that writes all four files via heredoc and immediately commits with the `--only` flag. `--only` snapshots the listed paths from the working tree at commit time and bypasses any subsequent unstaging caused by external processes. Commit `a1df0f3` succeeded on the first attempt with this pattern.
- **Files modified:** None (only the commit approach changed)
- **Commit:** `a1df0f3`

## Anti-Patterns Honored

- No `.tint(Color(red: 0.055, ...))` modifiers anywhere — accent flows entirely from the catalog asset.
- No third-party brand asset libraries vendored.

## Out of Scope (handled by later plans)

- Wiring `.tint(.accentColor)` on individual views (system auto-resolves the catalog asset on iOS 18+; no per-view modifier needed)
- Artistic icon replacement (planner explicitly defers to a polish pass)
- Per-view dark-mode previews (`.preferredColorScheme(.dark)` only used in later plans when verifying a specific surface)
- macOS app icon slots (fitbod is iOS-only per `PROJECT.md`; the 13 macOS slots from the stock template were dropped intentionally in this plan)

## Generator Script Reuse

`scripts/generate_app_icon.swift` is idempotent and re-runnable. To regenerate the icon (e.g., after a color tweak):

```bash
swift scripts/generate_app_icon.swift fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

Output is deterministic for a given (background color, font, glyph) tuple. If a future polish pass swaps in an artistic icon, this script can be deleted (or kept as a "regenerate placeholder" escape hatch).

## Self-Check: PASSED

- File `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` exists and contains both light and dark sRGB variants — verified via `git show HEAD:...`
- File `fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json` exists and contains single 1024×1024 iOS slot — verified via `git show HEAD:...`
- File `fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` exists (21,055 bytes) — verified via `git cat-file -s HEAD:...`
- File `scripts/generate_app_icon.swift` exists in commit — verified via `git show --stat a1df0f3`
- Commit `a1df0f3` exists on `main` — verified via `git log --oneline`
