---
phase: 03-smart-prescription-warm-ups
plan: "04"
subsystem: settings-ui
tags: [settings, plate-inventory, seeder, swiftui, swiftdata, form, sheet]
dependency_graph:
  requires: [03-01, 03-03]
  provides: [PlateInventoryDefaults, PlateInventorySeeder, PlateInventoryEditor, PlateCalculatorSheet, SettingsView-SmartProgression]
  affects: [fitbod/App/RootView.swift, fitbod/Settings/SettingsView.swift]
tech_stack:
  added: []
  patterns:
    - "@Query + @Bindable write-through Form (no Save button — live persistence)"
    - "Pure factory enum (PlateInventoryDefaults) — no SwiftData coupling, pure value types"
    - "Doubly-idempotent seeder (UserDefaults flag + fetch-count guard)"
    - "Segmented Picker with explicit .tag() per PlateEquipmentKind case"
    - "ContentUnavailableView for empty-plates state (iOS 17+ pattern)"
    - "PlateCalculator.solve() piped into live HStack visualization (pure SwiftUI Rectangles)"
    - "stepperBinding(for:on:) local Binding that mutates through PlateInventory.availablePlates"
key_files:
  created:
    - fitbod/Settings/PlateInventory+Defaults.swift
    - fitbod/Settings/PlateInventorySeeder.swift
    - fitbod/Settings/PlateInventoryEditor.swift
    - fitbod/Settings/PlateCalculatorSheet.swift
  modified:
    - fitbod/App/RootView.swift
    - fitbod/Settings/SettingsView.swift
decisions:
  - "Seeder hook placed in RootView.runSeed() (not fitbodApp.swift) — the exercise seed also runs there; co-locating both seeds keeps the first-launch flow in one place and avoids adding a .task to fitbodApp which has no scene context for @MainActor"
  - "PlateInventorySeeder reads UserSettings.first?.weightUnit after exercise seed completes, falls back to .lb — safe because exercise seed inserts UserSettings.default() before returning"
  - "PlateInventoryEditor uses VStack(picker + Form) rather than a TabView — segmented Picker at top is cleaner UX for 4 short labels and avoids nested TabView-in-Form SwiftUI layout quirks"
  - "stepperBinding(for:on:) creates a local Binding over availablePlates array mutation — required because PlateSpec is a value type (Codable struct); direct Binding into array elements is not available without this indirection"
  - "Two UI-SPEC footers in SettingsView smartProgressionSection stacked via VStack — SwiftUI Section only accepts a single footer view; VStack is the canonical stacking approach"
  - "PlateCalculatorSheet plate-stack visualization uses ScrollView(.horizontal) wrapper — handles long stacks (many plates) without overflowing the .medium detent sheet"
metrics:
  duration_minutes: 30
  completed_date: "2026-05-23"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 2
requirements: [SET-03, SET-04, SET-07, PRES-08]
---

# Phase 3 Plan 04: Plate Inventory UI & Seeder Summary

**One-liner:** Plate inventory end-to-end — pure defaults factory (kg/lb verbatim from CONTEXT.md), doubly-idempotent first-launch seeder (4 rows), tabbed PlateInventoryEditor with live write-through, PlateCalculatorSheet with asset-contract colored visualization, and SettingsView "Smart Progression" section with two new Steppers.

---

## What Was Built

### Task 1 — Defaults factory + first-launch seeder (commit `f2e96be`)

**`fitbod/Settings/PlateInventory+Defaults.swift`**
- `public enum PlateInventoryDefaults` — pure factory, no SwiftData coupling
- `static func make(for kind: PlateEquipmentKind, unitSystem: WeightUnit) -> [PlateSpec]`
- `static func barWeight(for kind: PlateEquipmentKind, unitSystem: WeightUnit) -> Double`
- kg barbell: 25×4, 20×2, 15×2, 10×2, 5×2, 2.5×2, 1.25×2 — verbatim from 03-CONTEXT.md Area 4
- lb barbell: 45×4, 35×2, 25×2, 10×2, 5×2, 2.5×2, 1.25×2 — verbatim from 03-CONTEXT.md Area 4
- Dumbbell: shorter plate list (barWeight 0.0 — handle bundled in plate math); EZ-Bar/Trap-Bar: mirror barbell plates with kind-specific bar weights (7/15 kg/lb, 22/50 kg/lb)

**`fitbod/Settings/PlateInventorySeeder.swift`**
- `@MainActor public enum PlateInventorySeeder`
- `static func seedIfNeeded(in context: ModelContext, unitSystem: WeightUnit)`
- Fast path: `UserDefaults.standard.bool(forKey: "plateInventorySeeded")`
- Double-idempotency: `FetchDescriptor<PlateInventory>` count ≥ 4 → set flag + return
- Loops `PlateEquipmentKind.allCases` → inserts 4 `PlateInventory` rows → `try? context.save()` → stamps flag

**`fitbod/App/RootView.swift`** (modified)
- `runSeed()` reads `UserSettings.first?.weightUnit ?? .lb` after exercise seed completes
- Calls `PlateInventorySeeder.seedIfNeeded(in: modelContext, unitSystem: unitSystem)`
- `// NOTE:` comment documents the `.lb` fallback rationale

### Task 2 — PlateInventoryEditor + SettingsView Smart Progression (commit `0d99cbf`)

**`fitbod/Settings/PlateInventoryEditor.swift`**
- `public struct PlateInventoryEditor: View` — pushed onto Settings NavigationStack (no own NavigationStack)
- Segmented `Picker` with 4 explicit `.tag(PlateEquipmentKind.xxx)` entries — tab labels: "Barbell" / "Dumbbells" / "EZ-Bar" / "Trap Bar" (UI-SPEC verbatim)
- Section "Bar weight": `TextField` bound via `@Bindable` to `barWeight`, decimal pad, unit suffix
- Section "Plates per side": `ForEach` sorted descending, `Stepper` via `stepperBinding(for:on:)`, swipe-to-delete "Delete" (destructive), "Add Plate" button
- Section footer: "Reset to Defaults" text button (accent per UI-SPEC item 21)
- Toolbar trailing: "Calculator" → `showCalculatorSheet = true` → `PlateCalculatorSheet.presentationDetents([.medium])`
- `.alert("Reset plate inventory?", ...)` — body "Replaces with the default {unit} plate set for {kind}." — buttons "Reset" (destructive) / "Cancel" — all UI-SPEC verbatim
- "Add Plate" sheet: NavigationStack + Form + TextField placeholder "e.g. 25" + "Add" confirm (UI-SPEC verbatim)
- `ContentUnavailableView` empty state when `availablePlates.isEmpty`: "No plates configured" / "Add plates to use the plate calculator." / "Add Plate" accent button (UI-SPEC verbatim)
- All edits write through `@Bindable` immediately — no Save button

**`fitbod/Settings/SettingsView.swift`** (modified)
- New `smartProgressionSection(settings:)` helper inserted between "Units" and "About" sections
- Section header "Smart Progression" (UI-SPEC verbatim)
- `NavigationLink { PlateInventoryEditor() } label: { Text("Plate Inventory") }` — chevron automatic
- `Stepper(value: $s.defaultIncrementKg, in: 0.25...10.0, step: 0.25)` with `LabeledContent`
- `Stepper(value: $s.minCalibrationSets, in: 5...30, step: 1)` with `LabeledContent`
- Footer (VStack): "Used when an exercise has no specific increment set..." + "RPE autoregulation uses the Tuchscherer table..." (both UI-SPEC verbatim)

### Task 3 — PlateCalculatorSheet (commit `0b94b3c`)

**`fitbod/Settings/PlateCalculatorSheet.swift`**
- `public struct PlateCalculatorSheet: View` — `let equipment: PlateEquipmentKind`, `let inventory: PlateInventory`
- `@State private var targetWeightText: String = "60"`, `barWeightText` initialized from `inventory.barWeight` on `.onAppear`
- Section "Target weight": TextField `.decimalPad`
- Section "Bar weight": TextField + validation footer "Bar weight exceeds target. Check the bar weight." (UI-SPEC verbatim, `.systemRed`)
- Section "Plate stack": `plateStackView(stack:)` or "No combination found" inline + footer (UI-SPEC verbatim)
- `solvedStack: PlateStack?` computed via `PlateCalculator.solve(target:barWeight:plates:)`
- `plateStackView`: `ScrollView(.horizontal)` → HStack of left-side plates (reversed) + 60pt bar segment + right-side plates
- `plateRect(weight:)`: 24pt-tall `RoundedRectangle` + `.caption` weight label below
- `plateColor(for:)`: asset-contract color tiers per UI-SPEC § Asset Contract:
  - ≥25 → `Color(.systemRed).opacity(0.8)`
  - ≥20 → `Color(.systemBlue).opacity(0.8)`
  - ≥15 → `Color(.systemYellow).opacity(0.8)`
  - ≥10 → `Color(.systemGreen).opacity(0.8)`
  - ≥5 → `Color(.systemGray5)`
  - ≥2.5 → `Color(.systemGray3)`
  - <2.5 → `Color(.systemGray6)` (microplates)
- Bar segment: `Color(.systemGray4)`, 6pt tall, 60pt wide (center)
- NavigationStack + "Plate Calculator" title + "Done" toolbar dismiss (DecimalRPEPickerSheet analog)
- `#Preview` block: `@Previewable @State var present`, `PreviewModelContainer.make()`, `PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)`, `.presentationDetents([.medium])`

---

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `f2e96be` | feat | Defaults factory + first-launch plate inventory seeder |
| `0d99cbf` | feat | PlateInventoryEditor tabbed Form + SettingsView Smart Progression section |
| `0b94b3c` | feat | PlateCalculatorSheet Try-It plate calculator at .medium detent |

---

## Deviations from Plan

### Auto-adjusted: Seeder hook location

**Found during:** Task 1

**Issue:** The plan specified adding the seeder call to `fitbodApp.swift` via a `.task {}` block. However, `fitbodApp.swift` has no `.task {}` block and no SwiftUI scene body that can host one — it only has a synchronous `init()` and `var body: some Scene`. The exercise seed runs in `RootView.runSeed()` (called from `.task {}` on `RootView`), not in `fitbodApp`.

**Fix (Rule 3 — blocking issue):** Added `PlateInventorySeeder.seedIfNeeded(...)` call to `RootView.runSeed()` immediately after `importer.seedIfNeeded()` completes. This is the correct location: both seeds share the same context, ordering is guaranteed (exercise seed creates `UserSettings` first so `weightUnit` is readable), and the `@MainActor` constraint of `PlateInventorySeeder` is satisfied by `RootView`'s main-actor context.

**Files modified:** `fitbod/App/RootView.swift` (instead of `fitbod/fitbodApp.swift`)

---

### Auto-adjusted: Stepper footers stacked via VStack

**Found during:** Task 2

**Issue:** The plan called for separate footer text per Stepper. SwiftUI `Section` accepts only a single footer view. With both Steppers in one section, both footers must co-exist.

**Fix (Rule 2 — missing correctness):** Combined both UI-SPEC footer strings into a `VStack(alignment: .leading, spacing: 4)` inside the single section footer. Both strings are verbatim from UI-SPEC; no copy was altered.

---

## Known Stubs

None. All four files are fully implemented. The plate inventory is seeded with real data on first launch. The calculator runs live against the stored inventory. No placeholder values, no TODO markers.

---

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or trust-boundary schema changes. All data is local SwiftData storage, consistent with the project's local-only stance.

---

## Self-Check: PASSED

- FOUND: `fitbod/Settings/PlateInventory+Defaults.swift`
- FOUND: `fitbod/Settings/PlateInventorySeeder.swift`
- FOUND: `fitbod/Settings/PlateInventoryEditor.swift`
- FOUND: `fitbod/Settings/PlateCalculatorSheet.swift`
- FOUND: seeder hook in `fitbod/App/RootView.swift`
- FOUND: Smart Progression section in `fitbod/Settings/SettingsView.swift`
- FOUND: commit `f2e96be` (git log confirms)
- FOUND: commit `0d99cbf` (git log confirms)
- FOUND: commit `0b94b3c` (git log confirms)
- swiftc -parse: 0 error lines (all 3 tasks verified)
