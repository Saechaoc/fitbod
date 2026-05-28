# Coding Conventions

**Analysis Date:** 2026-05-28

CLAUDE.md states "Conventions not yet established." In practice, a strong set of conventions *has* emerged across `fitbod/` (~85 production Swift files) and is enforced informally by the BRU grep-audit tests rather than by a formatter or linter. This document captures what is actually observed.

## Tooling Status — Important

No formatter or linter is wired:

- No `.swift-format` config in repo root.
- No `.swiftlint.yml`, no `Package.swift` plugin wiring.
- No `.editorconfig`, no `.pre-commit-config.yaml`, no `.husky/`.
- `.gitignore` is 29 bytes (effectively empty beyond defaults).
- No Xcode shared scheme for the app target — only `FitbodWidgetsExtension.xcscheme` is shared. No `.xctestplan` files exist.
- No CI (`.github/` is absent; `scripts/` holds only `generate_app_icon.swift`).

The stack docs in `CLAUDE.md` *recommend* swift-format (toolchain-bundled) and optional SwiftLint. Neither is wired. Style enforcement today is: (a) the author's own discipline, and (b) the BRU grep-audit Swift Testing suites (`fitbodTests/BRUGrepAuditTests.swift`, `BRUPhase5GrepAuditTests.swift`, `Phase3BRUGrepAuditTests.swift`, `Phase6/BRU/BRUGrepAuditPhase6Tests.swift`) that walk the source tree and `#expect` zero occurrences of banned tokens (`Capsule()`, `RoundedRectangle`, `Image(systemName:)`, `.accentColor`, `.font(.body/.headline/...)`).

## Naming Patterns

**Files:** One top-level type per file, file name == type name (e.g., `BRUButton.swift` declares `public struct BRUButton`). All Swift files use `.swift`.

**Views:** Suffix `View` (`TodayView`, `BlockBuilderView`, `SessionLoggerView`, `RoutineBuilderView`). The `Screen` suffix is rare — `BlockOverviewScreen.swift` is the only observed case. Treat `*View` as canonical.

**BRU design primitives:** All files in `fitbod/Design/` are prefixed `BRU` (`BRUButton`, `BRUChip`, `BRUDisplay`, `BRUReadout`, `BRUSectionHead`, `BRUHeaderBar`, `BRUDivider`, `BRUPillButton`, `BRUTabBar`, `BRUSpark`, `BRUSupersetBracket`, `BRUActionPopover`, `BRUCornerBadge`, `BRUDashedSlot`, `BRUFont`, `BRUPhoneFrame`). Non-BRU helpers in that folder (`Color+BRU.swift`, `PlateStackViz.swift`, `PlateTallyRow.swift`, `SetCompletionGlyph.swift`, `CalibratingProgressMeter.swift`) are exempt by convention. The BRU prefix marks a design-system primitive; consuming features must not introduce new design primitives outside `fitbod/Design/`.

**Ephemeral form state:** `*Draft` (`RoutineDraft`, `RoutineFolderDraft`, `BlockDraft`, `BlockPhaseDraft`, `CustomExerciseDraft`). All four are `@Observable` classes that hold non-persistent UI state.

**Ephemeral filter / UI state:** `*State` (`FilterState`, `ChartFilterState`, `SeedState`, `InSessionPRState`). Also `@Observable`.

**Engines / pure logic:** `*Engine`, `*Detector`, `*Aggregator`, `*Estimator`, `*Seeder`, `*Factory` (`PeriodizationEngine`, `RestTimerEngine`, `PRDetector`, `PlateauDetector`, `WeeklyTonnageAggregator`, `OneRepMaxEstimator`, `MuscleVolumeTargetSeeder`, `SessionFactory`). These are stateless or main-actor-confined helpers, not views.

**Persistence:** Schema versions are `SchemaV1`...`SchemaV6` in `fitbod/Persistence/`. The migration plan is `FitbodSchemaMigrationPlan`. The shared preview/test container factory is `PreviewModelContainer.make(seedFixture:)`.

**Models:** Single-noun (`Block`, `Routine`, `Session`, `Exercise`, `MuscleGroup`, `SetEntry`, `SupersetGroup`, `WarmupConfig`). All are `public final class` with `@Model`. Raw-string enum bridges are suffixed `Raw` on the property (`intentRaw`, `nameRaw`, `progressionKindRaw`).

**Routes:** Enum cases for typed navigation (`BlockOverviewRoute.summary(blockID:)`, `SessionRoute.logger(_)`). Each tab that drills owns one `NavigationPath`.

## File Header Comment Style

Every file opens with a doc-comment block. Two shapes are in use:

Block-style (older / model files), e.g. `fitbod/Models/Block.swift`:
```
//
//  Block.swift
//  fitbod
//
//  <multi-paragraph rationale: cascade rules, references to CONTEXT.md
//  Area 4 / ARCHITECTURE.md / phase-plan IDs>
//
```

Slash-style (newer / BRU + feature files), e.g. `fitbod/Design/BRUButton.swift`, `fitbod/Sessions/SetRow.swift`:
```
// BRUButton.swift
// fitbod
//
// <one-line purpose>
//
// Source of truth: UI-SPEC v2 § Component Inventory, line 514.
// BRU contract: NO Capsule() / NO RoundedRectangle / ...
// USAGE: <one-line example>
```

Both styles cite the source-of-truth artifact (UI-SPEC line numbers, phase plan IDs, CONTEXT.md sections, PITFALLS.md numbers). Newer files prefer the slash style. Either is acceptable; do not mix within a single file.

## State Management Patterns

The stack guidance ("no `ObservableObject` in new code") is followed strictly. There are zero `@StateObject`, `@ObservedObject`, or `ObservableObject` declarations in production code (`grep` confirms only comments referencing the legacy wrappers).

Observed patterns:

- **Persistent reads in views:** `@Query` declared directly in the `View` struct, with `#Predicate<Entity>` and `\KeyPath` sort descriptors inline. Example, `fitbod/Views/TodayView.swift:46`:
  ```swift
  @Query(filter: #Predicate<Block> { $0.isActive == true })
  private var activeBlocks: [Block]
  @Query(sort: \Session.startedAt, order: .reverse)
  private var allSessions: [Session]
  ```
  ~50 `@Query` declarations exist, all in view files. Never wrap `@Query` in a view model.

- **Persistent writes:** `@Bindable var s = settings` shadow re-bind on a fetched `@Model` instance, with `try? ctx.save()` (or implicit autosave) for write-through. See `fitbod/Settings/SettingsView.swift:173,214,257` and `fitbod/Settings/PlateInventoryEditor.swift:69,95,196`.

- **Ephemeral UI state:** `@State` for value types, `@Observable` class for non-trivial shared state (drafts, filter state, seed state, rest-timer engine).
  ```swift
  @State private var navigationPath = NavigationPath()
  @State private var seedState = SeedState()
  ```

- **Environment:** `@Environment(\.modelContext) private var ctx` (the property is named `ctx` in feature views and `modelContext` in older code — `ctx` is the emerging short form). `@Environment(\.dismiss) private var dismiss` for sheet dismissal.

- **Concurrency:** `@MainActor` is applied at the type level for SwiftUI helpers that touch the model context off-view (`PlateInventorySeeder`), and at the test-suite level (`@MainActor @Suite("PeriodizationEngine", .serialized)`). Swift 6 strict-concurrency mode is on per stack docs; no Sendable conformance is declared on `@Observable` classes (they are reference types intentionally).

## View Composition

- **One view per file.** Sub-views are extracted to sibling files, not nested as `private struct`. Confirmed across `TodayView.swift`, `BRUButton.swift`, `PrescriptionEditorRow.swift` (zero `private struct` nestings). `TodayView`'s sub-components (`TodayStatStrip`, `BlockContextBand`, `ResumeWorkoutSlab`, `BlackSlabCTA`, `LiftListRow`, `LiftListSection`, `IntentChip`, `WeekTickerCells`) each live in their own file under `fitbod/Views/`.

- **MARK headers are mandatory.** Files >50 lines use `// MARK: -` and `// MARK:` to section: `Environment`, `Queries`, `State`, `Body`, then per-feature subsections. See `fitbod/Views/TodayView.swift:35,40,44,59,71,278,293,392,406,440,464,481`.

- **`public` for app-target views**, internal default for sub-views local to a feature folder. `BRUButton`, `RootView`, `TodayView` are `public`. Inner enums (`BRUButton.Kind`, `BRUButton.Size`) are also `public` so previews/tests can construct them.

- **Modifier ordering:** No formal rule, but the de-facto order in BRU surfaces is: layout (frame/padding) → background (BRU color, never `.background(Color.gray)`) → overlay/border → gesture/onTap → accessibility. `.buttonStyle(.plain)` is mandatory on `Button` to suppress Apple HIG chrome (banned by BRU contract).

## Previews

- **158 `#Preview` blocks** across the app target. Every shippable view ships at least one.

- **Convention:** named preview with a matrix layout, wrapped in `#if DEBUG`. Example, `fitbod/Design/BRUButton.swift:152`:
  ```swift
  #if DEBUG
  #Preview("BRUButton") {
      ScrollView {
          VStack(spacing: 24) {
              ForEach(["Primary", "Signal", "Ghost"], id: \.self) { kindName in
                  ...
              }
          }
      }
  }
  #endif
  ```

- **Previews that need persistence:** use `.modelContainer(PreviewModelContainer.make())` (seeded) or `PreviewModelContainer.make(seedFixture: false)` (empty). The factory always uses `isStoredInMemoryOnly: true` per `fitbod/Persistence/PreviewModelContainer.swift`.

- iOS 18 deployment target is set, but `@Previewable` is not adopted; previews use the simpler closure-only form. Acceptable.

## SwiftData Patterns

- All `@Model` types are `public final class`. Properties have default values so SwiftUI previews / migrations can instantiate them without arg lists. See `fitbod/Models/Block.swift:23-41`:
  ```swift
  @Model
  public final class Block {
      @Attribute(.unique) public var id: UUID = UUID()
      public var name: String = ""
      public var startDate: Date = Date.now
      ...
      @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
      public var phases: [BlockPhase]? = []
      public init() {}
  }
  ```

- **Cascade vs nullify:** Owning relationships use `.cascade` with `inverse:` explicitly named. Non-owning back-references use `@Relationship(inverse: \...)` without a delete rule (default nullify). Cascade direction is documented in the file header comment.

- **Enums are persisted as raw strings.** Property pairs are `(intentRaw: String, intent: ExerciseIntent { get })` with computed accessors. Direct enum properties on `@Model` types are avoided (PIVOT-03 in `fitbod/fitbodApp.swift` header).

- **`#Index` is not used.** iOS 18 supports it, but no models declare it. `@Attribute(.unique)` is used on `id` only.

- **Schema versioning is explicit.** Six schemas (V1-V6) live in `fitbod/Persistence/` as `enum SchemaVN: VersionedSchema`. The migration plan is `FitbodSchemaMigrationPlan: SchemaMigrationPlan`. App `init` binds the latest (`SchemaV6.models`). Previous schemas remain registered so on-disk stores at any version can migrate forward.

## Import Order

No enforced ordering. Observed convention is Apple frameworks first, then third-party (there are none — Charts and Testing are bundled), then `@testable import fitbod` in tests. Examples:
```swift
import Foundation
import SwiftData
import SwiftUI
import OSLog              // when logging
import Charts             // only in fitbod/Progress/ExerciseProgressView.swift, WeeklyTonnageView.swift
import UIKit              // only when bridging to UIHostingController in tests
```

## Logging

`OSLog` only. Pattern (`fitbod/App/RootView.swift:70`):
```swift
private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")
```

No `print()` in production view code. Subsystem is always `com.fitbod.app`; category is per-feature.

## Comments

Comments are heavy and traceability-focused. Every non-trivial decision cites a phase plan, UI-SPEC line, PITFALLS number, or CONTEXT.md anchor. Inline rationale is preferred to bare code; `TodayView.swift` carries 20+ explanatory `// ───` separator banners inside the body. This is the house style — match it.

`/// `-style doc comments on `public` types and members, with `@Kind` enum cases documented inline. Example, `fitbod/Design/BRUButton.swift:37-43`.

## Function Design

- **Body sizes are not policed.** `TodayView.body` exceeds 200 lines; `SettingsView.swift` is the worst-hotspot file in the repo. The project tolerates large view bodies in exchange for explicit composition (no helper-function chasing). Do not introduce sub-view extraction purely for size; extract only when a sub-view is reused.

- **Return-type opacity:** `some View` everywhere. No type-erased `AnyView` in production code.

- **Argument labels:** standard Swift conventions; trailing-closure syntax for `BRUButton("...", kind: .signal) { action() }`. Action closures are `@escaping () -> Void` by convention.

## Where Conventions Are Enforced

Programmatically:
- `BRUGrepAuditTests` / `Phase3BRUGrepAuditTests` / `BRUPhase5GrepAuditTests` / `Phase6/BRU/BRUGrepAuditPhase6Tests` — assert source files under audited directories contain zero banned UIKit/HIG tokens. These tests *are* the linter. They walk the source tree with `FileManager` and `#expect` no matches.
- `Phase6/Support/SchemaNamesRegressionTest.swift` — guards schema rename drift.

Manually:
- File-header doc comments cite the source-of-truth artifact, making review-by-grep feasible.
- The single-developer constraint keeps style drift low.

**Confidence:** High for what is observed in the source tree (naming, file headers, state-management patterns, BRU primitives, preview convention, SwiftData modeling). Medium for unstated rules that the author follows by habit but has not codified — modifier ordering and import ordering have no automated enforcement and could drift.
