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

    /// Currently-selected tab. Bound to `TabView(selection:)` via a
    /// custom `Binding<Tab>` that detects re-tap of the same tab and
    /// clears the matching `NavigationPath` (review WR-07).
    @State private var selectedTab: Tab = .library

    /// The Library tab owns a navigation stack (Library → Detail). The
    /// path lives here in `RootView` so the tab re-tap binding setter
    /// can clear it without reaching into a child view.
    @State private var libraryPath = NavigationPath()

    private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")

    public init() {}

    /// The 5 tabs in display order. `Hashable` so it can drive
    /// `TabView(selection:)`. Only `.library` currently owns a
    /// `NavigationPath` because it's the only tab with a multi-level
    /// drilldown in Phase 1; future phases will add paths for the
    /// other tabs as drilldowns appear (UI-SPEC § Interaction patterns).
    enum Tab: Hashable {
        case today
        case routines
        case library
        case progress
        case settings
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
                    case .library:
                        libraryPath = NavigationPath()
                    case .today, .routines, .progress, .settings:
                        // No NavigationPath wired for these tabs yet —
                        // Phase 2+ will add paths as drilldowns appear.
                        break
                    }
                }
                selectedTab = newValue
            }
        )
    }

    private var tabBar: some View {
        TabView(selection: tabSelection) {
            // UI-SPEC § Tab labels — verbatim labels + SF Symbols + order.
            //
            // Plan 04-01 wired: Today tab body is now `TodayView` — a
            // real surface that mounts `ResumeWorkoutBanner` at the top
            // and renders the UI-SPEC empty-state ("No workout in
            // progress" / "Start a workout from your Routines tab.")
            // below. Tapping the banner's "Resume" pushes
            // `SessionLoggerView` via the Today tab's NavigationPath.
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(Tab.today)

            // Plan 03-01 wired: replaces the Phase 2 placeholder body
            // with the real `RoutinesListView`. The view owns its own
            // `NavigationStack`, so the wrapper from the placeholder is
            // removed.
            RoutinesListView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(Tab.routines)

            // Plan 03-02 replaces `LibraryTabHost` with `ExerciseLibraryView`.
            // Path is owned by `RootView` so `tabSelection` can clear it
            // on Library-tab re-tap (review WR-07).
            LibraryTabHost(path: $libraryPath)
                .tabItem {
                    Label("Library", systemImage: "dumbbell")
                }
                .tag(Tab.library)

            PlaceholderTabView(phaseNumber: 6)
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.progress)

            // Plan 04-01 wired: `SettingsTabHost` wraps `SettingsView`.
            SettingsTabHost()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
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

            seedState.phase = .ready
        } catch {
            Self.log.error("Seed failed: \(error.localizedDescription)")
            seedState.phase = .failed(message: error.localizedDescription)
        }
    }
}

// MARK: - Interim tab hosts

/// Today tab body — plan 04-01 wired. Hosts `ResumeWorkoutBanner` at the
/// top (renders only when an active session exists) and the UI-SPEC
/// empty-state below ("No workout in progress" / "Start a workout from
/// your Routines tab."). Tapping the banner's "Resume" pushes
/// `SessionLoggerView` via the Today tab's NavigationPath.
///
/// Owns its own `NavigationStack` — each tab manages its own navigation
/// surface per the documented Apple pattern (RESEARCH § State of the Art).
private struct TodayView: View {
    @Environment(\.modelContext) private var ctx

    @Query(filter: #Predicate<Block> { $0.isActive == true })
    private var activeBlocks: [Block]

    @Query private var settingsList: [UserSettings]

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: PendingBlockBuilder? = nil
    @State private var pendingBlockReview: Block? = nil

    // Phase 5 plan 04 — deload advisory state.
    @State private var currentAdvisory: DeloadAdvisory? = nil
    @State private var presentingSignalSheet: Bool = false
    // Phase 5 plan 06 — weekly recap state.
    @State private var presentingWeeklyRecap: Bool = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    if let active = activeBlocks.first,
                       let phase = PeriodizationEngine.phase(for: active, on: .now),
                       phase.kind == .deload {
                        DeloadWeekBanner(currentPhaseKind: phase.kind)
                    }
                    // Phase 5 plan 04 — DeloadAdvisoryBanner replaces
                    // Phase 4's ConsiderDeloadBanner stub. Renders only
                    // when DeloadAdvisor.evaluate returns non-nil AND
                    // not dismissed for the current week (D-17).
                    if let advisory = currentAdvisory {
                        DeloadAdvisoryBanner(
                            advisory: advisory,
                            onDismiss: { dismissAdvisory() },
                            onTapBody: { presentingSignalSheet = true }
                        )
                    }
                    if let active = activeBlocks.first {
                        BlockCard(block: active)
                    } else if activeBlocks.isEmpty {
                        StartBlockCTA(onStart: {
                            pendingBlockBuilder = .template(BlockTemplates.blank)
                        })
                    }
                    ResumeWorkoutBanner(
                        onResume: { session in
                            navigationPath.append(SessionRoute.logger(session))
                        },
                        onDiscard: { session in
                            ctx.delete(session)
                            try? ctx.save()
                        }
                    )
                    // Phase 5 — VOL-04 + VOL-05 host. Stacks below the
                    // deload banner, BlockCard, and ResumeWorkoutBanner
                    // per UI-SPEC §Phase 4 ↔ Phase 5 boundary order.
                    // isAdvisoryActive lights the amber ring overlay
                    // on every MuscleVolumeBar while the deload
                    // advisory is active (plan 04 wires the source).
                    FatigueSurfaceView(
                        isAdvisoryActive: currentAdvisory != nil,
                        navigationPath: $navigationPath
                    )
                    if activeBlocks.isEmpty {
                        Spacer().frame(height: 24)
                        Text("No workout in progress")                         // UI-SPEC verbatim
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Start a workout from your Routines tab.")        // UI-SPEC verbatim
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Today")
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            // Phase 5 plan 05 — per-muscle drill-down from heatmap +
            // volume-bar taps.
            .navigationDestination(for: MuscleSlugRoute.self) { route in
                switch route {
                case .detail(let slug):
                    PerMuscleDetailView(muscleSlug: slug)
                }
            }
            .sheet(item: $pendingBlockBuilder) { pending in
                NavigationStack {
                    switch pending {
                    case .template(let template):
                        BlockBuilderView(draft: BlockDraft(template: template))
                    }
                }
            }
            .sheet(item: $pendingBlockReview) { block in
                BlockReviewView(block: block)
                    .presentationDetents([.large])
            }
            // Phase 5 plan 04 — fatigue signal detail sheet.
            .sheet(isPresented: $presentingSignalSheet) {
                if let advisory = currentAdvisory,
                   let settings = settingsList.first {
                    let report = DeloadAdvisor.signalReport(
                        weekStart: advisory.weekStart,
                        in: ctx,
                        settings: settings
                    )
                    DeloadSignalDetailSheet(report: report)
                }
            }
            // Phase 5 plan 06 — VOL-07 weekly recap sheet.
            .sheet(isPresented: $presentingWeeklyRecap) {
                if let settings = settingsList.first {
                    let weekStart = Date.now.mondayAtMidnightForToday(
                        weekStartsMonday: settings.weekStartsMonday
                    )
                    WeeklyRecapSheet(weekStart: weekStart)
                }
            }
            .task {
                pendingBlockReview = (try? BlockReviewStatistics.pendingReviewBlocks(
                    context: ctx,
                    now: Date.now
                ))?.first
                refreshAdvisory()
                checkWeeklyRecap()
            }
            .onAppear {
                refreshAdvisory()
                checkWeeklyRecap()
            }
        }
    }

    // MARK: - Phase 5 plan 06 weekly recap

    /// Decide whether to present the weekly recap sheet using
    /// `WeeklyRecapTrigger.evaluate` (pure-function helper). Marks
    /// the recap as seen for this week per Pitfall #8 even when the
    /// sheet is suppressed (zero-sessions short-circuit).
    @MainActor
    private func checkWeeklyRecap() {
        guard let settings = settingsList.first else { return }
        let thisMonday = Date.now.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday)
        let priorWeekStart = thisMonday.addingTimeInterval(-7 * 86_400)
        let hasSessions = lastWeekSessionsCount(start: priorWeekStart, end: thisMonday) > 0

        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMonday,
            lastShown: settings.weeklyRecapShownForWeekStart,
            hasSessionsLastWeek: hasSessions
        )

        if decision.shouldMarkSeen {
            settings.weeklyRecapShownForWeekStart = thisMonday
            try? ctx.save()
        }
        if decision.shouldPresent {
            presentingWeeklyRecap = true
        }
    }

    @MainActor
    private func lastWeekSessionsCount(start: Date, end: Date) -> Int {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        return (try? ctx.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Phase 5 deload advisory helpers

    /// Recompute the deload advisory on Today-tab appearance. Reads
    /// settings.deloadAlertEnabled as the user-facing kill switch.
    @MainActor
    private func refreshAdvisory() {
        guard let settings = settingsList.first, settings.deloadAlertEnabled else {
            currentAdvisory = nil
            return
        }
        let thisMonday = Date.now.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday)
        currentAdvisory = DeloadAdvisor.evaluate(
            weekStart: thisMonday,
            in: ctx,
            settings: settings
        )
    }

    /// Persist the dismissal date and hide the banner immediately
    /// (without waiting for the next refresh). Per D-17, the dismissal
    /// applies only to the current calendar week — next Monday's
    /// `refreshAdvisory` re-evaluates.
    @MainActor
    private func dismissAdvisory() {
        guard let advisory = currentAdvisory, let settings = settingsList.first else { return }
        settings.deloadAdvisoryDismissedWeekStart = advisory.weekStart
        try? ctx.save()
        currentAdvisory = nil
    }

    private enum PendingBlockBuilder: Identifiable {
        case template(BlockTemplate)

        var id: String {
            switch self {
            case .template(let template):
                return "template-\(template.name)"
            }
        }
    }
}

/// Library tab body — wraps the real `ExerciseLibraryView` (plan 03-02).
///
/// `ExerciseLibraryView` still owns its `NavigationStack`, but the
/// stack's path is supplied from outside via the `path` binding so
/// `RootView.tabSelection` can clear it on Library-tab re-tap
/// (review WR-07).
private struct LibraryTabHost: View {
    @Binding var path: NavigationPath
    var body: some View { ExerciseLibraryView(path: $path) }
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
