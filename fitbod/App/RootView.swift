//
//  RootView.swift
//  fitbod
//
//  Wave-3 RootView — replaces the interim stub from plan 01-02. Hosts
//  the 5-tab `TabView` (Today / Routines / Library / Progress / Settings)
//  and wires the one-time `ExerciseLibraryImporter.seedIfNeeded()` call
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
//  navigation surface owns one. The `PlaceholderTabView` and the two
//  interim tab hosts (`LibraryTabHost`, `SettingsTabHost`) below each
//  declare their own.
//
//  ## Tab hosts
//
//  `LibraryTabHost` (plan 03-02 wired) and `SettingsTabHost` (plan
//  04-01 wired) are one-line wrappers around the real tab body views.
//  Kept as private structs rather than substituting the bodies
//  directly into `tabBar` so future per-tab wrappers (analytics, tab-
//  re-tap pop-to-root) can attach in one place per tab.
//

import SwiftUI
import SwiftData
import OSLog

public struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var seedState = SeedState()

    private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")

    public init() {}

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

    private var tabBar: some View {
        TabView {
            // UI-SPEC § Tab labels — verbatim labels + SF Symbols + order.
            PlaceholderTabView(phaseNumber: 2)
                .tabItem {
                    Label("Today", systemImage: "figure.strengthtraining.traditional")
                }

            PlaceholderTabView(phaseNumber: 2)
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.rectangle.portrait")
                }

            // Plan 03-02 replaces `LibraryTabHost` with `ExerciseLibraryView`.
            LibraryTabHost()
                .tabItem {
                    Label("Library", systemImage: "dumbbell")
                }

            PlaceholderTabView(phaseNumber: 6)
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }

            // Plan 04-01 wired: `SettingsTabHost` wraps `SettingsView`.
            SettingsTabHost()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
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
            seedState.phase = .ready
        } catch {
            Self.log.error("Seed failed: \(error.localizedDescription)")
            seedState.phase = .failed(message: error.localizedDescription)
        }
    }
}

// MARK: - Interim tab hosts

/// Library tab body — wraps the real `ExerciseLibraryView` (plan 03-02).
/// `ExerciseLibraryView` owns its own `NavigationStack`, so this host
/// is now just a thin transparent wrapper. Kept as a private struct
/// rather than substituting `ExerciseLibraryView()` directly into the
/// `tabBar` body so plan 04-01's settings substitution and any future
/// per-tab wrappers stay symmetrical (e.g., wrapping for analytics).
private struct LibraryTabHost: View {
    var body: some View { ExerciseLibraryView() }
}

/// Settings tab body — wraps the real `SettingsView` (plan 04-01).
/// `SettingsView` owns its own `NavigationStack`, so this host is now
/// a thin transparent wrapper. Kept symmetrical with `LibraryTabHost`
/// (one-line `var body: some View { SettingsView() }`) for the same
/// reasons: future per-tab analytics wrappers / tab-re-tap pop-to-root
/// hooks attach to the wrapper without restructuring `RootView`.
private struct SettingsTabHost: View {
    var body: some View { SettingsView() }
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
