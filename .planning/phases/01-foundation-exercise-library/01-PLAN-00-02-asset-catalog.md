---
phase: 01
plan: 00-02
wave: 0
slug: asset-catalog
complexity: S
requirements: []
covers_ui_spec: ["Color § AccentColor", "Asset Contract § AccentColor + AppIcon"]
depends_on: []
files_modified:
  - fitbod/Assets.xcassets/AccentColor.colorset/Contents.json
  - fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json
  - fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png  # generated
created: 2026-05-10
---

# Plan 00-02 — Asset Catalog

> **Wave 0 / Sequence 2.** Independent of plan `00-01` — can be committed before, after, or simultaneously with it. Populates the asset catalog with the accent-color values locked in `01-UI-SPEC.md` and provides a placeholder `AppIcon` so the app can be installed on the simulator/device for visual checks.

## Goal

Wire the `AccentColor` asset to `#0E7C86` (light) / `#3FBFC9` (dark) per `01-UI-SPEC.md`, and generate a placeholder `AppIcon` (1024×1024 white "F" on accent color) that fills every required iOS icon slot via Xcode's "single size" Icon Composer flow.

## Requirements Covered

This plan does not directly close any product requirements but locks in the visual identity layer that **LIB-01..06 and SET-01** consume via system-default `.tint(.accentColor)` propagation (no per-view `.tint()` modifiers needed — system picks up the catalog asset automatically).

UI-SPEC.md sections honored: § Color (60/30/10 split, accent reserved-for list), § Asset Contract.

## Files to Create / Modify

### Modify
`fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` — populate with universal color, light + dark appearance variants:

```json
{
  "colors" : [
    {
      "idiom" : "universal",
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue"  : "0.525",
          "green" : "0.486",
          "red"   : "0.055"
        }
      }
    },
    {
      "idiom" : "universal",
      "appearances" : [
        { "appearance" : "luminosity", "value" : "dark" }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue"  : "0.788",
          "green" : "0.749",
          "red"   : "0.247"
        }
      }
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Component derivation (sRGB 0.0–1.0 from hex):
- `#0E7C86` → R `0x0E/255 = 0.055`, G `0x7C/255 = 0.486`, B `0x86/255 = 0.525`
- `#3FBFC9` → R `0x3F/255 = 0.247`, G `0xBF/255 = 0.749`, B `0xC9/255 = 0.788`

### Create
- `fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json` — single-size icon manifest using the iOS 18+ "Any Appearance" 1024×1024 slot:
  ```json
  {
    "images" : [
      {
        "filename" : "AppIcon-1024.png",
        "idiom" : "universal",
        "platform" : "ios",
        "size" : "1024x1024"
      }
    ],
    "info" : { "author" : "xcode", "version" : 1 }
  }
  ```
- `fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — a 1024×1024 PNG showing a single capital "F" in white (SF Pro Display, ~600pt, semibold weight) centered on a teal (`#0E7C86`) background. Generation method (planner's discretion — any of the following is acceptable):
  1. **Recommended:** Use macOS `sips`/`ImageIO` + ASCII Swift script in a one-shot Bash invocation that writes the PNG from PNG-encoded `CGContext` calls. Sample reference: `sips -s format png ...` cannot draw text; a Swift one-shot is cleaner.
  2. **Alternative:** Hand-author via Preview.app or any image tool; commit the resulting PNG. (Acceptable because this is a personal-install app per `PROJECT.md` — no App Store review.)
  3. **Fallback:** Use an SF Symbol screenshot at 1024×1024 if Swift-script approach proves friction-y.

A one-shot generation script lives at `scripts/generate_app_icon.swift` (if the planner chooses this route) — committed alongside the PNG.

## Acceptance Criteria

1. The asset catalog JSON for `AccentColor` parses without error: `plutil -lint fitbod/Assets.xcassets/AccentColor.colorset/Contents.json` exits 0.
2. The `AccentColor` light value matches `#0E7C86` (within sRGB rounding): a quick visual check by opening the asset in Xcode shows teal in light mode and lighter teal in dark mode.
3. The `AppIcon.appiconset/Contents.json` parses without error: `plutil -lint fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json` exits 0.
4. `AppIcon-1024.png` is exactly 1024×1024 pixels: `sips -g pixelWidth -g pixelHeight fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` reports `pixelWidth: 1024` and `pixelHeight: 1024`.
5. After this plan's commit, the simulator build (once plan `01-02` makes the project compile) shows the teal icon on the home screen.

## Test Expectations

No code tests in this plan. Validation is via `plutil -lint` + `sips -g pixelWidth -g pixelHeight` invocations on the committed asset files.

**Sanity check commands:**
```bash
plutil -lint fitbod/Assets.xcassets/AccentColor.colorset/Contents.json
plutil -lint fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json
sips -g pixelWidth -g pixelHeight fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

## Decisions Honored

- **UI-SPEC.md § Color:** Accent values `#0E7C86` (light) / `#3FBFC9` (dark), sRGB color space. Deep teal chosen for "precision instrument" positioning over stock `.systemBlue`.
- **UI-SPEC.md § Asset Contract:** Placeholder `AppIcon` (capital "F" white on accent) acceptable for personal-install; artistic icon deferred to a polish pass.

## Anti-Patterns Avoided

- **Not** scattering `.tint(Color(red: 0.055, green: 0.486, blue: 0.525))` calls across views. The accent flows from the asset catalog through every `NavigationLink` chevron / `Toggle` / `Slider` / selected `TabView` icon automatically.
- **Not** vendoring a 3rd-party brand asset library. UI-SPEC locks the visual stance to "iOS-native chrome with one designated accent."

## Out of Scope (handled by later plans)

- Wiring `.tint(.accentColor)` on individual views — the asset catalog reference is enough; no per-view modifier needed.
- Per-view dark-mode previews — the asset auto-applies based on `colorScheme`; previews in later plans use `.preferredColorScheme(.dark)` only when verifying a specific surface.

## Commit Message Template

```
chore(01): wire AccentColor #0E7C86/#3FBFC9 + placeholder AppIcon

- AccentColor.colorset: sRGB universal + dark luminosity variant per UI-SPEC § Color
- AppIcon: 1024×1024 white "F" on teal background; single-slot iOS 18+ icon manifest
- accent will propagate to TabView selection, NavigationLink chevron, Toggle,
  Slider, .searchable cursor automatically — no per-view .tint() needed
```
