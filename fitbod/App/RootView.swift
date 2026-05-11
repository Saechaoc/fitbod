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
//  ## Interim hosts
//
//  `LibraryTabHost` and `SettingsTabHost` are 1-line edit-points:
//  plan 03-02 swaps `LibraryTabHost` for `ExerciseLibraryView`; plan
//  04-01 swaps `SettingsTabHost` for `SettingsView`. The interim text
//  is locked to "{tab} — coming in {plan}" per the execution rules.
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

            // Plan 04-01 replaces `SettingsTabHost` with `SettingsView`.
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

/// Library tab body — interim placeholder until plan 03-02 wires
/// `ExerciseLibraryView`. Importantly: this view is NOT a `@Query`
/// consumer, so swapping it for `ExerciseLibraryView` is a 1-line edit.
private struct LibraryTabHost: View {
    var body: some View {
        NavigationStack {
            Text("Library — coming in 03-02")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Exercises")
        }
    }
}

/// Settings tab body — interim placeholder until plan 04-01.
private struct SettingsTabHost: View {
    var body: some View {
        NavigationStack {
            Text("Settings — coming in 04-01")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Settings")
        }
    }
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
