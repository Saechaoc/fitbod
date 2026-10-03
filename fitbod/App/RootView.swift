//
//  RootView.swift
//  fitbod
//
//  Wave-3 RootView — replaces the interim stub from plan 01-02. Hosts
//  the 4-tab bar (Today / Program / Progress / Settings) and wires
//  the one-time `ExerciseLibraryImporter.seedIfNeeded()` call
//  off `.task { ... }` so the seed runs the first time the view
//  appears, off the main thread (per the `@ModelActor` macro on the
//  importer).
//
//  ## Splash vs. tabs
//
//  While `@Query<Exercise>` is empty AND the `SeedState` is still
//  `.idle` or `.loading`, the view shows a centered `ProgressView`
//  with the locked UI-SPEC copy "Preparing library…". As soon as the
//  seed task transitions to `.ready` (or `.failed`), the tab bar
//  appears. On second-and-later launches the seed short-circuits in
//  O(1) (UserDefaults version stamp check), so the splash flashes for
//  <100 ms and is functionally invisible.
//
//  ## Why `.task` and not `App.init`
//
//  `App.init` is synchronous and runs before SwiftUI scenes exist —
//  there is no main-actor context for the importer to call back into.
//  `RootView.task` is the documented Apple pattern (RESEARCH Code
//  Example 2): it runs once when the view first appears and gets
//  automatically cancelled if the view goes away mid-seed (which
//  cannot happen for `RootView`, but the structured-concurrency
//  contract still holds).
//
//  ## Why each tab owns its own `NavigationStack`
//
//  RESEARCH § State of the Art and PITFALLS.md both forbid wrapping
//  `TabView` in a parent `NavigationStack`. Each tab that needs a
//  navigation surface owns one. The remaining interim tab host
//  (`SettingsTabHost`) declares its own.
//  (PlaceholderTabView deleted in Phase 2.1 Plan 11 — all tabs are real.
//  LibraryTabHost removed when the Library tab was deleted in quick task
//  260525-g32 follow-up; ExerciseLibraryView is still reachable from the
//  routine builder.)
//
//  ## Tab hosts
//
//  `SettingsTabHost` (plan 04-01 wired) is a one-line wrapper around the
//  real settings view. Kept as a private struct rather than substituting
//  the body directly into `tabBar` so future per-tab wrappers (analytics,
//  tab-re-tap pop-to-root) can attach in one place per tab.
//

import SwiftUI
import SwiftData
import OSLog

public struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var seedState = SeedState()

    /// Currently-selected tab. Bound to the tab-bar binding via a
    /// custom `Binding<Tab>` that detects re-tap of the same tab and
    /// clears the matching `NavigationPath` (review WR-07).
    @State private var selectedTab: Tab = Self.initialSelectedTab()

    /// Wave-5 plan 06-08 — Progress tab NavigationPath. Lives in
    /// RootView so the `tabSelection` setter can clear it on Progress-
    /// tab re-tap.
    @State private var progressPath = NavigationPath()

    /// Library tab NavigationPath, cleared on Library-tab re-tap.
    @State private var libraryPath = NavigationPath()

    private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")

    public init() {}

    /// The 4 tabs in display order. `Hashable` so it can drive the
    /// custom tab-bar binding. `.progress` currently owns a
    /// `NavigationPath` because it has a multi-level drilldown; future
    /// phases will add paths for the other tabs as drilldowns appear.
    ///
    /// `.program` (was `.routines` pre quick-task 260525-gen) hosts the
    /// new ProgramView empty-state surface. The routine builder + folder
    /// CRUD that lived inside RoutinesListView is no longer reachable
    /// from the tab bar; surfaces like ExerciseLibraryView are reached
    /// from within the routine builder, and the routine builder itself
    /// is reached from BlockBuilderView once a block is defined.
    enum Tab: Hashable, CaseIterable {
        case today
        case program
        case progress
        case library
    }

    private static func initialSelectedTab() -> Tab {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fitbod-start-program") {
            return .program
        }
        #endif
        return .today
    }

    public var body: some View {
        Group {
            if shouldShowSplash {
                splash
            } else {
                tabBar
            }
        }
        .task {
            await runSeed()
        }
    }

    /// Splash visibility predicate.
    ///
    /// The splash is shown only while the seed task is in flight (or
    /// has not yet started) AND the store has no exercises. On the
    /// second-and-later launches `@Query<Exercise>` returns the
    /// previously-seeded rows immediately, so even with the seed task
    /// still nominally running (it short-circuits in O(1) but the
    /// `@State` transition is async), the tab bar renders without a
    /// flash of splash.
    private var shouldShowSplash: Bool {
        guard exercises.isEmpty else { return false }
        switch seedState.phase {
        case .idle, .loading:
            return true
        case .ready, .failed:
            return false
        }
    }

    // MARK: - Splash

    private var splash: some View {
        ProgressView("Preparing library…")
            .progressViewStyle(.circular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab bar

    /// Selection binding that detects re-tap of the currently-active
    /// tab and resets that tab's `NavigationPath`. SwiftUI calls the
    /// `set` closure whenever the user taps any tab — including the
    /// already-selected one — so a same-value set is the re-tap
    /// signal (review WR-07; UI-SPEC § Interaction patterns).
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab {
                    // Re-tap on the currently-active tab — pop to root.
                    switch newValue {
                    case .progress:
                        // Wave-5 plan 06-08 — Progress tab pop-to-root.
                        progressPath = NavigationPath()
                    case .library:
                        libraryPath = NavigationPath()
                    case .today, .program:
                        // No NavigationPath wired for these tabs yet —
                        // future polish will add paths as drilldowns appear.
                        break
                    }
                }
                selectedTab = newValue
            }
        )
    }

    private var tabBar: some View {
        // Quick task 260524-ilf — BRU bottom nav.
        //
        // We do NOT use SwiftUI's TabView here: hiding the system tab
        // bar from outside a NavigationStack is not reliably supported
        // (`.toolbar(.hidden, for: .tabBar)` only takes effect on views
        // inside the stack, and `.toolbarBackground(.hidden, …)` hides
        // only the blur layer, not the chrome). Instead we VStack the
        // selected tab's body above `BRUTabBar`, preserving each tab's
        // own NavigationStack and the existing re-tap pop-to-root logic.
        //
        // Quick task 260525-g32 — BRUTabBar now self-extends its
        // background through the bottom safe area via its own
        // `.ignoresSafeArea(.container, edges: .bottom)` layer, so this
        // VStack does NOT need its own bottom-safe-area filler. If a
        // future change introduces a parent that paints behind the bar,
        // re-add `.background(Color.bruTabSurface.ignoresSafeArea(...))`
        // on the outer VStack here as a fallback.
        VStack(spacing: 0) {
            // Every tab stays alive; only the selected one is visible and
            // interactive. A `switch` here would rebuild the tab on each
            // switch and drop its navigation stack (e.g. a logger pushed
            // on Today) and its @State (library filters).
            ZStack {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isSelected = tab == selectedTab
                    tabBody(tab)
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                        .accessibilityHidden(!isSelected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BRUTabBar(active: selectedTab.bru) { bruTab in
                tabSelection.wrappedValue = bruTab.rootTab
            }
            // Cells declare minHeight (no max) so the bar must be
            // vertically fixed-size — otherwise the VStack lets it
            // expand to fill leftover space.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func tabBody(_ tab: Tab) -> some View {
        switch tab {
        case .today:    TodayView()
        case .program:  ProgramView()
        case .progress: ProgressTabHost(path: $progressPath)
        case .library:  ExerciseLibraryView(path: $libraryPath)
        }
    }

    // MARK: - Seed wiring

    /// Run the one-time seed against a freshly-constructed
    /// `ExerciseLibraryImporter` (a `@ModelActor` — see plan 02-02).
    /// The importer's synthesized initializer takes a `ModelContainer`,
    /// which we obtain from the environment-injected `modelContext`.
    ///
    /// Errors are logged but not surfaced — on first launch a failure
    /// is catastrophic (the UI-SPEC § Error states alert is deferred
    /// to Wave 4 polish), and on subsequent launches a stale
    /// `@Query<Exercise>` will still return the previously-seeded rows
    /// so the tabs render normally.
    private func runSeed() async {
        seedState.phase = .loading
        do {
            let importer = ExerciseLibraryImporter(modelContainer: modelContext.container)
            try await importer.seedIfNeeded(bundle: .main)

            // NOTE: PlateInventory seeding uses `.lb` as the unit-system fallback
            // when `UserSettings` is freshly inserted by the exercise seed above.
            // The user can reset any tab to their preferred defaults via the
            // "Reset to Defaults" button in Settings → Smart Progression → Plate Inventory.
            let unitSystem = (try? modelContext.fetch(FetchDescriptor<UserSettings>()).first?.weightUnit) ?? .lb
            PlateInventorySeeder.seedIfNeeded(in: modelContext, unitSystem: unitSystem)

            // Phase 5 — VOL-01: write the curated stimulus weights onto
            // ExerciseMuscleStimulus rows. Runs AFTER the library
            // importer so canonicalName lookups resolve. Row-level
            // idempotency via userEditedWeight; safe to call on every
            // launch (RESEARCH §6.3).
            StimulusWeightSeeder.seedIfNeeded(in: modelContext)

            // Phase 5 plan 06 — VOL-03 / SET-05: seed MEV/MAV/MRV
            // targets from RP landmarks. Runs AFTER MuscleGroup rows
            // are seeded by the library importer. Row-level
            // idempotency via userEdited; safe to call on every
            // launch (RESEARCH §7.3).
            MuscleVolumeTargetSeeder.seedIfNeeded(in: modelContext)
            DemoWorkoutSeed.runIfRequested(in: modelContext) // DEBUG-only E2E hook; no-op without the launch argument

            seedState.phase = .ready
        } catch {
            Self.log.error("Seed failed: \(error.localizedDescription)")
            seedState.phase = .failed(message: error.localizedDescription)
        }
    }
}

// MARK: - BRUTab ↔ Tab mapping
//
// `BRUTabBar` is parameterized on its own `BRUTab` enum (declared in
// fitbod/Design/BRUTabBar.swift) so the chrome component has no
// dependency on `RootView`. Both enums carry the same 4 cases in the
// same order; these helpers do the 1:1 conversion at the wiring site.

private extension RootView.Tab {
    var bru: BRUTab {
        switch self {
        case .today:    return .today
        case .program:  return .program
        case .progress: return .progress
        case .library:  return .library
        }
    }
}

private extension BRUTab {
    var rootTab: RootView.Tab {
        switch self {
        case .today:    return .today
        case .program:  return .program
        case .progress: return .progress
        case .library:  return .library
        }
    }
}

// MARK: - Interim tab hosts

// NOTE: TodayView extracted to fitbod/Views/TodayView.swift — Phase 2.1 Plan 04.
// The inline `private struct TodayView` that lived here (lines 271-489) was moved
// into a standalone file as part of the BRU visual rewrite. The call site at
// line 170 (`TodayView()`) continues to work — Swift resolves TodayView to
// the new file in the same module.

// NOTE: SessionHistoryView (Phase 2.1 Plan 10) is surfaced from the Routines tab's
// "+ NEW" confirmation dialog ("History" button → sheet). The wiring lives in
// RoutinesListView.swift (`presentingSessionHistory` @State + `.sheet(isPresented:)`).
// A future revision can promote SessionHistoryView into a dedicated tab.

/// Progress tab body — wraps the real `ProgressHomeView` (plan 06-08).
/// `ProgressHomeView` owns its own `NavigationStack`, parameterized on
/// the path binding supplied from `RootView` so `tabSelection` can
/// clear it on Progress-tab re-tap.
private struct ProgressTabHost: View {
    @Binding var path: NavigationPath
    var body: some View { ProgressHomeView(path: $path) }
}


// MARK: - Previews

#Preview("RootView (seeded)") {
    RootView()
        .modelContainer(PreviewModelContainer.make())
}

#Preview("RootView (empty / splash)") {
    RootView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
