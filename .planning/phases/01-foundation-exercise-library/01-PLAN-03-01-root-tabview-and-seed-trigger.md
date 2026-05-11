---
phase: 01
plan: 03-01
wave: 3
slug: root-tabview-and-seed-trigger
complexity: M
requirements: ["FOUND-05", "LIB-01"]
covers_pitfalls: ["#6 (seed off main; splash while empty)", "#11 (autosave coordination)"]
depends_on: ["02-02", "00-02"]
files_modified:
  - fitbod/App/RootView.swift  # NEW (moved+renamed from ContentView.swift)
  - fitbod/App/PlaceholderTabView.swift  # NEW
  - fitbod/ContentView.swift  # DELETED (replaced by App/RootView.swift)
  - fitbod/fitbodApp.swift  # update import path if needed
  - fitbod.xcodeproj/project.pbxproj  # group + file moves
created: 2026-05-10
---

# Plan 03-01 — Root TabView and Seed Trigger

> **Wave 3 / Sequence 1.** Replaces the interim `RootView` stub from plan `01-02` with the real `RootView` containing a 5-tab `TabView` (Library + Settings live; Today / Routines / Progress are placeholders). Wires the `ExerciseLibraryImporter.seedIfNeeded()` call from `RootView.task`, showing a "Preparing library…" splash while the seed runs on the background `@ModelActor`.

## Goal

Stand up the user-visible root surface. Move `ContentView.swift` → `fitbod/App/RootView.swift`, rewrite it as a `TabView` with 5 tabs (3 placeholders), and trigger the seed pipeline on first launch with a non-blocking splash. After this plan, launching the app produces a 5-tab UI with the Library tab showing an empty `List` (real content lands in plan `03-02`) and the Settings tab showing nothing (real content lands in plan `04-01`).

## Requirements Covered

- **FOUND-05** (UI integration): the seed runs from `RootView.task` against a `@ModelActor` and the UI does not freeze. The "Preparing library…" `ProgressView` is shown while `@Query<Exercise>` returns empty AND `seedComplete == false`. Once the seed finishes, the tabs render. This satisfies the "no UI freeze" success criterion from ROADMAP.md.
- **LIB-01** (entry surface): the Library tab is reachable from the tab bar with the locked SF Symbol (`dumbbell`) and label ("Library") from UI-SPEC.md. The actual list of exercises is rendered by plan `03-02`'s `ExerciseLibraryView`.

## Files to Create / Modify

### Create

1. `fitbod/App/PlaceholderTabView.swift`:
   ```
   import SwiftUI

   /// Single-line placeholder for tabs not implemented in Phase 1.
   /// Copy locked by UI-SPEC.md § Tab labels.
   struct PlaceholderTabView: View {
       let phaseNumber: Int

       var body: some View {
           NavigationStack {
               VStack(spacing: 8) {
                   Text("Available in Phase \(phaseNumber)")
                       .font(.body)
                       .foregroundStyle(.secondary)
               }
               .frame(maxWidth: .infinity, maxHeight: .infinity)
           }
       }
   }

   #Preview { PlaceholderTabView(phaseNumber: 2) }
   ```

2. `fitbod/App/RootView.swift` — **NEW** file (functionally replaces `fitbod/ContentView.swift`; pbxproj edit deletes the old reference and adds the new one):
   ```
   import SwiftUI
   import SwiftData
   import OSLog

   struct RootView: View {
       @Environment(\.modelContext) private var modelContext
       @Query private var exercises: [Exercise]
       @State private var seedComplete = false

       var body: some View {
           Group {
               if !seedComplete && exercises.isEmpty {
                   ProgressView("Preparing library…")
                       .progressViewStyle(.circular)
                       .frame(maxWidth: .infinity, maxHeight: .infinity)
               } else {
                   tabBar
               }
           }
           .task {
               do {
                   let importer = ExerciseLibraryImporter(modelContainer: modelContext.container)
                   try await importer.seedIfNeeded()
               } catch {
                   Logger(subsystem: "com.fitbod.app", category: "seed")
                       .error("Seed failed: \(error.localizedDescription)")
               }
               seedComplete = true
           }
       }

       private var tabBar: some View {
           TabView {
               PlaceholderTabView(phaseNumber: 2)
                   .tabItem {
                       Label("Today", systemImage: "figure.strengthtraining.traditional")
                   }

               PlaceholderTabView(phaseNumber: 2)
                   .tabItem {
                       Label("Routines", systemImage: "list.bullet.rectangle.portrait")
                   }

               # Plan 03-02 replaces this body with ExerciseLibraryView().
               LibraryTabHost()
                   .tabItem {
                       Label("Library", systemImage: "dumbbell")
                   }

               PlaceholderTabView(phaseNumber: 6)
                   .tabItem {
                       Label("Progress", systemImage: "chart.xyaxis.line")
                   }

               # Plan 04-01 replaces this body with SettingsView().
               SettingsTabHost()
                   .tabItem {
                       Label("Settings", systemImage: "gearshape")
                   }
           }
       }
   }

   /// Library tab body — interim placeholder until plan 03-02 wires
   /// ExerciseLibraryView. Importantly: this view is NOT a @Query consumer,
   /// so swapping it for ExerciseLibraryView is a 1-line edit.
   private struct LibraryTabHost: View {
       var body: some View {
           NavigationStack {
               Text("Library tab — plan 03-02 fills this in")
                   .font(.callout)
                   .foregroundStyle(.secondary)
                   .navigationTitle("Exercises")
           }
       }
   }

   /// Settings tab body — interim placeholder until plan 04-01.
   private struct SettingsTabHost: View {
       var body: some View {
           NavigationStack {
               Text("Settings tab — plan 04-01 fills this in")
                   .font(.callout)
                   .foregroundStyle(.secondary)
                   .navigationTitle("Settings")
           }
       }
   }

   #Preview {
       RootView()
           .modelContainer(PreviewModelContainer.make())
   }
   ```

### Delete

3. `fitbod/ContentView.swift` — its interim stub from plan `01-02` is now superseded by `fitbod/App/RootView.swift`. Delete the file AND remove its `PBXFileReference` from the project navigator.

### Modify

4. `fitbod/fitbodApp.swift` — no source change needed (still references `RootView()` as in plan `01-02`); only verify the build still finds `RootView` after the file move.

5. `fitbod.xcodeproj/project.pbxproj` — move file references:
   - Remove `ContentView.swift` reference.
   - Add `fitbod/App/RootView.swift` and `fitbod/App/PlaceholderTabView.swift` to the `fitbod` target under the `App/` group.

## Acceptance Criteria

1. `fitbod/App/RootView.swift` exists. `fitbod/ContentView.swift` does NOT exist.
2. `fitbod/App/PlaceholderTabView.swift` exists.
3. Launching the app on the simulator:
   - Shows `ProgressView("Preparing library…")` briefly on first launch (the seed runs, then the splash dismisses).
   - On second launch, the splash flashes for <100ms and the tab bar appears immediately (idempotent path — `@Query<Exercise>` is non-empty from the persisted store).
4. The tab bar shows 5 tabs in order with the locked SF Symbols + labels from UI-SPEC.md:
   - `figure.strengthtraining.traditional` / "Today"
   - `list.bullet.rectangle.portrait` / "Routines"
   - `dumbbell` / "Library"
   - `chart.xyaxis.line` / "Progress"
   - `gearshape` / "Settings"
5. Tapping each placeholder tab shows `Text("Available in Phase 2")` (or `Phase 6`) per UI-SPEC.md.
6. Tapping the Library tab shows the interim "Library tab — plan 03-02 fills this in" text (replaced in next plan).
7. Tapping the Settings tab shows the interim "Settings tab — plan 04-01 fills this in" text (replaced in plan `04-01`).
8. The accent color (`AccentColor` asset from plan `00-02`) tints the selected tab item (verified visually).
9. Build still passes: `xcodebuild build` exits 0.
10. The `RootView`'s `#Preview` block builds in the Xcode canvas (smoke check that `PreviewModelContainer.make()` injection still works after the file move).

## Test Expectations

This plan adds no new unit tests. The behavior is validated by:
- Launching the simulator and observing the splash → tabs transition.
- The seed tests from plan `02-02` already cover the importer correctness; this plan only adds the invocation site.

**Sanity build check:**
```bash
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \
  | grep -E 'error:' || echo "BUILD OK"
```

**Optional manual smoke** (recorded in commit message):
- First launch on a fresh simulator: time from app icon tap → tabs visible should be ≤3 seconds. (Production target <2s per FOUND-05; cold-simulator inflation is acceptable.)

## Decisions Honored

- **UI-SPEC § Tab labels:** Verbatim labels and SF Symbols, in the exact order from UI-SPEC.md.
- **UI-SPEC § Color § Accent reserved for / item 2:** Selected `TabView` tab icon + label uses system behavior under `.tint(.accentColor)` — automatic via the asset catalog from plan `00-02`. No per-view `.tint()` modifier.
- **R-12 (RESEARCH Code Example 2 — seed trigger from `RootView.task`):** Verbatim shape: `@Query<Exercise>` + `@State seedComplete` + `.task { importer.seedIfNeeded() }`. `App.init` is synchronous; the seed must be async, so `RootView.task` is the right hook.
- **R-16 (RESEARCH § State of the Art — `TabView` not wrapped in parent `NavigationStack`):** Each tab body that needs navigation owns its own `NavigationStack`. The `TabView` itself is bare.

## Anti-Patterns Avoided

- **Not** wrapping the `TabView` in a parent `NavigationStack` — each tab gets its own (RESEARCH § State of the Art).
- **Not** kicking off the seed from `fitbodApp.init` — `init` is synchronous and runs before SwiftUI scenes exist; `RootView.task` is the documented Apple pattern.
- **Not** blocking the main thread on `try await importer.seedIfNeeded()` outside `.task { ... }` — the modifier handles structured concurrency.
- **Not** showing a generic spinner with no copy — the `ProgressView("Preparing library…")` matches UI-SPEC's terse, prescriptive copywriting stance.
- **Not** introducing a parallel `RootViewModel` class — the view binds to `@Query<Exercise>` and `@State seedComplete` directly (FOUND-06).

## Out of Scope (handled by later plans)

- The real `ExerciseLibraryView` body (filter chips, sectioned list, `.searchable`) → plan `01-PLAN-03-02`. The `LibraryTabHost` placeholder is replaced in a 1-line edit at the start of that plan.
- The real `SettingsView` with the lb/kg toggle → plan `01-PLAN-04-01`.
- Tab re-tap pop-to-root behavior (clear `NavigationPath` when active tab is tapped again) → deferred. UI-SPEC notes this pattern; implementation slipped to Wave 4 if time permits, otherwise deferred to Phase 2 polish. Documented in commit message.
- Error handling UI for catastrophic seed failure (UI-SPEC § Error states / "Library Failed to Load" Alert) → defensive copy locked in UI-SPEC but implementation deferred to Wave 4 polish (since the failure mode is "should never happen" in practice). Documented in commit message.

## Commit Message Template

```
feat(01): RootView TabView + seed trigger + Preparing library splash

- App/RootView.swift: 5-tab TabView with the locked SF Symbols + labels from
  UI-SPEC § Tab labels (Today / Routines / Library / Progress / Settings)
- App/PlaceholderTabView.swift: "Available in Phase N" filler for Today,
  Routines, Progress (Phase 2 and Phase 6 respectively)
- RootView.task triggers ExerciseLibraryImporter.seedIfNeeded() against the
  modelContext.container (RESEARCH Example 2 wire-up); ProgressView
  ("Preparing library…") shows while @Query<Exercise> is empty
- delete fitbod/ContentView.swift (interim stub from plan 01-02 superseded)
- Library and Settings tabs use interim host stubs (plan 03-02 replaces
  LibraryTabHost; plan 04-01 replaces SettingsTabHost — each is a 1-line edit)

Cold-launch observed: <RECORD> seconds icon-tap → tabs visible.
Tab re-tap pop-to-root and seed-failure Alert deferred to Wave 4 polish.
```
