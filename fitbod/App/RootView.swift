//
//  RootView.swift
//  fitbod
//
//  App shell (milestone 1). Owns the app-scoped state and wires it into the
//  environment:
//
//    - `AppRouter` — selected tab, per-tab NavigationPaths (re-tap pops to
//      root), and the workout presented full-screen.
//    - `RestTimerEngine` — one rest timer for the whole app, restored from
//      its persisted absolute deadline at launch.
//
//  Tabs: Today · Routines · Library · History · Settings. Each tab owns its
//  NavigationStack (never wrap a TabView in a NavigationStack —
//  RESEARCH § State of the Art).
//
//  The active workout is a full-screen cover above the tabs. On launch,
//  after the one-time exercise seed, an unfinished workout is presented
//  again automatically, so closing and reopening the app lands the lifter
//  exactly where they were — sets, typed values, and rest countdown
//  included.
//

import SwiftUI
import SwiftData
import OSLog

public struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var seedState = SeedState()
    @State private var router = AppRouter()
    @State private var restTimer = RestTimerEngine.makeProduction()
    @State private var didRestoreWorkout = false

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
        .environment(router)
        .environment(restTimer)
        .task {
            await runSeed()
            restoreActiveWorkout()
        }
        .fullScreenCover(item: $router.presentedWorkout, onDismiss: handleWorkoutDismiss) { session in
            WorkoutFlowView(session: session)
                .environment(router)
                .environment(restTimer)
        }
    }

    // MARK: - Splash

    private var shouldShowSplash: Bool {
        guard exercises.isEmpty else { return false }
        switch seedState.phase {
        case .idle, .loading: return true
        case .ready, .failed: return false
        }
    }

    private var splash: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            Text("Fitbod")
                .font(.chalkDisplay)
                .textCase(.uppercase)
                .foregroundStyle(.chalkInk)
            Rectangle()
                .fill(Color.chalkInk)
                .frame(width: 64, height: Chalk.Line.heavy)
            HStack(spacing: Chalk.Space.sm) {
                ProgressView()
                    .tint(Color.chalkInk)
                Text("Preparing library…")
                    .font(.chalkCallout)
                    .foregroundStyle(.chalkInk2)
            }
        }
        .padding(Chalk.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.chalkCanvas)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tabs

    /// Re-tapping the selected tab pops it to root (review WR-07).
    private var tabSelection: Binding<AppRouter.Tab> {
        Binding(
            get: { router.selectedTab },
            set: { router.select($0) }
        )
    }

    private var tabBar: some View {
        TabView(selection: tabSelection) {
            TodayView()
                .tabItem { Label("Today", systemImage: "calendar") }
                .tag(AppRouter.Tab.today)

            RoutinesListView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle.portrait") }
                .tag(AppRouter.Tab.routines)

            LibraryTabHost()
                .tabItem { Label("Library", systemImage: "dumbbell") }
                .tag(AppRouter.Tab.library)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppRouter.Tab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(Color.chalkInk)
    }

    // MARK: - Workout cover

    /// A workout discarded from inside the cover is deleted only after the
    /// cover has gone, so no view reads a deleted model.
    private func handleWorkoutDismiss() {
        if let session = router.pendingDiscard {
            router.pendingDiscard = nil
            WorkoutFinisher.discard(session, context: modelContext)
        }
    }

    /// Relaunch: reopen an unfinished workout, and drop a rest timer whose
    /// workout no longer exists or is finished.
    private func restoreActiveWorkout() {
        guard !didRestoreWorkout else { return }
        didRestoreWorkout = true
        let active = SessionFactory.active(in: modelContext)
        if restTimer.isRunning {
            if let active, restTimer.sessionID == nil || restTimer.sessionID == active.id {
                // keep running
            } else {
                restTimer.stop()
            }
        }
        if let active, router.presentedWorkout == nil {
            router.present(workout: active)
        }
    }

    // MARK: - Seed

    private func runSeed() async {
        seedState.phase = .loading
        do {
            let importer = ExerciseLibraryImporter(modelContainer: modelContext.container)
            try await importer.seedIfNeeded(bundle: .main)

            // PlateInventory seeding uses the user's unit system, falling
            // back to lb when UserSettings was just inserted by the seed.
            let unitSystem = (try? modelContext.fetch(FetchDescriptor<UserSettings>()).first?.weightUnit) ?? .lb
            PlateInventorySeeder.seedIfNeeded(in: modelContext, unitSystem: unitSystem)

            if LaunchConfiguration.current.seedDemoHistory {
                DemoData.seedIfNeeded(in: modelContext)
            }
            seedState.phase = .ready
        } catch {
            Self.log.error("Seed failed: \(error.localizedDescription)")
            seedState.phase = .failed(message: error.localizedDescription)
        }
    }
}

/// Library tab body — the library owns its NavigationStack; its path lives
/// in the router so a tab re-tap can pop it.
private struct LibraryTabHost: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        ExerciseLibraryView(path: $router.libraryPath)
    }
}

// MARK: - Previews

#Preview("RootView (seeded)") {
    RootView()
        .modelContainer(PreviewModelContainer.make())
}
