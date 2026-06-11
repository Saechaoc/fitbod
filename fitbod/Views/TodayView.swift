// TodayView.swift
// fitbod — Phase 2.1 Plan 04
//
// Standalone Today tab root. Extracted from the 219-line `private struct TodayView`
// in fitbod/App/RootView.swift (Wave B audit item #3). All Phase 4 + Phase 5
// behaviors are preserved verbatim — only the presentation shell is replaced with
// BRU primitives.
//
// Composition order (top to bottom per UI-SPEC line 533):
//   safeAreaInset(top): BRUHeaderBar("Fitbod / Today", right: formatted date)
//   ─── inside ScrollView VStack(spacing: 0) ───────────────────────────────
//   [Defensive-top Phase 5 banners]
//     DeloadWeekBanner  (phase.kind == .deload)
//     DeloadAdvisoryBanner  (currentAdvisory != nil)
//   [BRU Layer]
//     TodayStatStrip  (Day streak / Sessions / W{N}/{M} trend)
//     BlockContextBand  (Block chip + name + phase + WeekTickerCells)  — when block active
//     ResumeWorkoutSlab  — when active session (completedAt == nil)
//       OR BlackSlabCTA  — when no active session but routine scheduled
//       OR Start-Block-CTA — when no block at all
//       OR empty-state   — block active but no today routine
//     LiftListSection  (BRUSectionHead + LazyVStack of LiftListRow)
//   [Defensive-bottom Phase 5 surface]
//     FatigueSurfaceView
//
// Navigation: NavigationStack(path: $navigationPath) wraps everything.
// Chrome: BRUHeaderBar via .safeAreaInset(edge: .top) + .navigationBarHidden(true).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - TodayView

/// The Today tab's root view — BRU composition over Phase 4 + Phase 5 wiring.
public struct TodayView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var ctx

    // MARK: - Queries (preserved verbatim from RootView.TodayView Phase 4/5)

    @Query(filter: #Predicate<Block> { $0.isActive == true })
    private var activeBlocks: [Block]

    @Query private var settingsList: [UserSettings]

    // NEW for BRU — active session detection (completedAt == nil)
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    // ALL sessions for streak + total count computation
    @Query(sort: \Session.startedAt, order: .reverse)
    private var allSessions: [Session]

    // MARK: - Navigation / Sheet State (preserved verbatim from Phase 4/5)

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: PendingBlockBuilder? = nil
    @State private var pendingBlockReview: Block? = nil

    // Phase 5 plan 04 — deload advisory state.
    @State private var currentAdvisory: DeloadAdvisory? = nil
    @State private var presentingSignalSheet: Bool = false
    // Phase 5 plan 06 — weekly recap state.
    @State private var presentingWeeklyRecap: Bool = false

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {

                    // ─── DEFENSIVE TOP — Phase 5 banners (preserved) ─────
                    if let active = activeBlocks.first,
                       let phase = PeriodizationEngine.phase(for: active, on: .now),
                       phase.kind == .deload {
                        DeloadWeekBanner(currentPhaseKind: phase.kind)
                    }

                    if let advisory = currentAdvisory {
                        DeloadAdvisoryBanner(
                            advisory: advisory,
                            onDismiss: { dismissAdvisory() },
                            onTapBody: { presentingSignalSheet = true }
                        )
                    }

                    // ─── BRU LAYER ───────────────────────────────────────

                    // Stat strip — always visible
                    TodayStatStrip(
                        streak: computedStreak,
                        totalSessions: allSessions.filter { $0.completedAt != nil }.count,
                        weekIndex: currentWeekIndex,
                        totalWeeks: currentTotalWeeks,
                        trend: currentTrend
                    )

                    // Block context band — only when a block is active
                    // onTap pushes BlockOverviewRoute.summary per CONTEXT D-11
                    if let block = activeBlocks.first {
                        BlockContextBand(block: block, onTap: {
                            navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
                        })
                    }

                    // CTA slab — resume-in-progress wins (spec §5); otherwise
                    // branch on the full TodayResolution so .emptySplit gets a
                    // distinct repair surface (CR-02) and the resolved slot is
                    // threaded into startWorkout as the rotation anchor (CR-01).
                    if let active = activeSessions.first {
                        // Active in-progress session → Resume slab
                        ResumeWorkoutSlab(
                            session: active,
                            onResume: { navigationPath.append(SessionRoute.logger(active)) },
                            onDiscard: {
                                ctx.delete(active)
                                try? ctx.save()
                            }
                        )
                    } else {
                        switch todaysResolution {
                        case .session(let slot):
                            if let routine = slot.sessionTemplate {
                                // Scheduled routine → Black slab CTA. CR-01: keep
                                // the resolved slot so startWorkout writes it as
                                // the rotation anchor.
                                BlackSlabCTA(
                                    routine: routine,
                                    dayIndex: dayIndexInBlock,
                                    totalDays: totalDaysInBlock,
                                    onStart: { startWorkout(routine, slot: slot) }
                                )
                            } else {
                                noWorkoutScheduledEmptyState
                            }
                        case .emptySplit:
                            // CR-02: split emptied mid-block → distinct repair
                            // surface, NOT the rest-day "No workout scheduled"
                            // copy (spec §5 — the rest-day state would lie).
                            // Phase 9: replace with SplitDetailView fix-it pointer.
                            emptySplitFixItState
                        case .restDay:
                            // fixedWeekly today-not-a-training-day → rest-day empty state.
                            noWorkoutScheduledEmptyState
                        case .noBlock:
                            if activeBlocks.isEmpty {
                                // No block at all → Start Block CTA (Phase 4 preserved)
                                StartBlockCTA(onStart: {
                                    pendingBlockBuilder = .template(BlockTemplates.blank)
                                })
                            } else {
                                // Block active but split not yet attached → empty state
                                noWorkoutScheduledEmptyState
                            }
                        }
                    }

                    // Lift list — empty view when routine is nil
                    LiftListSection(routine: todaysRoutine)

                    // ─── DEFENSIVE BOTTOM — Phase 5 FatigueSurfaceView ──
                    FatigueSurfaceView(
                        isAdvisoryActive: currentAdvisory != nil,
                        navigationPath: $navigationPath
                    )

                    // Phase 4 preserved: BlockCard for active block context
                    // (rendered inside BlockContextBand in BRU layer above)
                    // Phase 4 preserved: Start-Block-CTA (in the else if branch above)
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            // Suppress default Apple navigation bar — BRUHeaderBar replaces it
            .navigationBarHidden(true)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            // BRUHeaderBar floated as a safeArea inset — renders above ScrollView content
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: nil,
                    center: "Fitbod / Today",
                    right: HeaderAction(formattedDate) { /* no-op — date label only */ }
                )
            }
            // ─── Navigation Destinations (preserved verbatim from Phase 4/5) ──
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            // Phase 5 plan 05 — per-muscle drill-down from heatmap + volume-bar taps.
            .navigationDestination(for: MuscleSlugRoute.self) { route in
                switch route {
                case .detail(let slug):
                    PerMuscleDetailView(muscleSlug: slug)
                }
            }
            // Phase 04.1 Plan 07 — BlockOverviewRoute (CONTEXT D-11)
            // Resolves the block by UUID via FetchDescriptor and presents the
            // read-only BlockOverviewScreen. The onEdit closure pushes to
            // BlockBuilderView via pendingBlockBuilder (.edit case).
            .navigationDestination(for: BlockOverviewRoute.self) { route in
                switch route {
                case .summary(let blockID):
                    let blockIDCapture = blockID
                    let fetchedBlock = (try? ctx.fetch(
                        FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.id == blockIDCapture })
                    ))?.first
                    if let resolvedBlock = fetchedBlock {
                        BlockOverviewScreen(block: resolvedBlock, onEdit: {
                            pendingBlockBuilder = .edit(resolvedBlock)
                        })
                    } else {
                        Text("Block not found")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
            }
            // ─── Sheets (preserved verbatim from Phase 4/5) ──────────────────
            .sheet(item: $pendingBlockBuilder) { pending in
                NavigationStack {
                    switch pending {
                    case .template(let template):
                        BlockBuilderView(draft: BlockDraft(template: template))
                    case .edit(let block):
                        BlockBuilderView(draft: BlockDraft(block: block), editing: block)
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
            // ─── Lifecycle (preserved verbatim from Phase 4/5) ───────────────
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

    // MARK: - Empty-state surfaces

    /// Rest-day / no-routine empty state — UI-SPEC line 466 verbatim copy.
    /// Used for `.restDay`, `.noBlock` (with a block active but no split), and
    /// the defensive `.session` with a nil template.
    @ViewBuilder
    private var noWorkoutScheduledEmptyState: some View {
        VStack(spacing: 12) {
            Text("No workout scheduled")
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)

            Text("Build a routine or pick one from your library.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)

            Button {
                // Navigate to RoutinesListView's +NEW routine action
            } label: {
                Text("+ NEW ROUTINE")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }

    /// CR-02 / spec §5: distinct surface for a block whose split was emptied
    /// mid-block (zero slots). Reuses the empty-state visual shell but with
    /// copy that points at the repair path, NOT the rest-day "No workout
    /// scheduled" copy (which would lie about why nothing is scheduled).
    // Phase 9: replace with SplitDetailView fix-it pointer.
    @ViewBuilder
    private var emptySplitFixItState: some View {
        VStack(spacing: 12) {
            Text("Routine has no sessions")
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.center)

            Text("Add sessions in the Program tab.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }

    // MARK: - Formatted Date (BRU header right slot)

    /// "Wed · May 22" — en_US weekday abbreviated + month abbreviated + day.
    private var formattedDate: String {
        let f = Date.now.formatted(
            .dateTime
                .locale(Locale(identifier: "en_US"))
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
        )
        // DateFormatStyle returns e.g. "Wed, May 22" — swap comma+space for " · "
        return f.replacingOccurrences(of: ", ", with: " · ")
    }

    // MARK: - BRU Helper Properties (NEW — stat strip / block context inputs)

    /// Consecutive day streak — count of unique calendar days with at least one
    /// completed session (completedAt != nil), working backwards from today.
    private var computedStreak: Int {
        let completed = allSessions.filter { $0.completedAt != nil }
        guard !completed.isEmpty else { return 0 }

        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: .now)

        for session in completed {
            let sessionDay = cal.startOfDay(for: session.startedAt)
            if sessionDay == checkDate {
                if streak == 0 { streak = 1 }
                // already counted this day
            } else if let expectedPrior = cal.date(byAdding: .day, value: -1, to: checkDate),
                      sessionDay == expectedPrior {
                streak += 1
                checkDate = expectedPrior
            } else {
                break
            }
        }
        return streak
    }

    /// 1-based current week index within the active block (1 when no block).
    private var currentWeekIndex: Int {
        guard let block = activeBlocks.first,
              let idx = PeriodizationEngine.weekIndex(for: block, on: .now) else { return 1 }
        return idx + 1  // weekIndex is 0-based
    }

    /// Total weeks in the active block across all phases (defaults to 1).
    private var currentTotalWeeks: Int {
        guard let block = activeBlocks.first else { return 1 }
        let total = (block.phases ?? []).reduce(0) { $0 + $1.weeks }
        return max(1, total)
    }

    /// Volume trend compared to prior week — .up when this week > last week.
    private var currentTrend: TrendDirection {
        // Simple heuristic: compare completed sessions count this week vs last week.
        guard let settings = settingsList.first else { return .flat }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let thisMonday = today.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday)
        let lastMonday = thisMonday.addingTimeInterval(-7 * 86_400)

        let thisWeekCount = allSessions.filter { s in
            s.completedAt != nil &&
            s.startedAt >= thisMonday &&
            s.startedAt < thisMonday.addingTimeInterval(7 * 86_400)
        }.count

        let lastWeekCount = allSessions.filter { s in
            s.completedAt != nil &&
            s.startedAt >= lastMonday &&
            s.startedAt < thisMonday
        }.count

        if thisWeekCount > lastWeekCount { return .up }
        if thisWeekCount < lastWeekCount { return .down }
        return .flat
    }

    /// The full resolver output for today in the active block.
    ///
    /// V7: block.routines removed; Phase 8 unified resolver drives the CTA.
    /// Phase 8 (CR-01 / CR-02): the body switches on the full four-case
    /// `TodayResolution` so `.emptySplit` is NOT collapsed into the rest-day
    /// empty state (spec §5 / resolver header contract), and so the resolved
    /// `slot` survives to `startWorkout` as the rotation anchor.
    private var todaysResolution: TodayResolution {
        guard let block = activeBlocks.first else { return .noBlock }
        return TodayResolver.resolve(block: block, context: ctx)
    }

    /// The session template scheduled for today (nil unless the resolver
    /// returns `.session(slot)` with a non-nil template). Drives
    /// `LiftListSection`'s exercise preview.
    private var todaysRoutine: SessionTemplate? {
        if case .session(let slot) = todaysResolution {
            return slot.sessionTemplate
        }
        return nil
    }

    /// 1-based day index in the current block (for "DAY 01 / 04" in BlackSlabCTA).
    private var dayIndexInBlock: Int {
        guard let block = activeBlocks.first else { return 1 }
        let daysSince = Calendar.current.dateComponents([.day], from: block.startDate, to: .now).day ?? 0
        let totalDays = currentTotalWeeks * 7
        guard totalDays > 0 else { return 1 }
        return (daysSince % totalDays) + 1
    }

    /// Total days in the current block (for "DAY 01 / 04" in BlackSlabCTA).
    private var totalDaysInBlock: Int {
        max(1, currentTotalWeeks * 7)
    }

    // MARK: - Workout Start

    @MainActor
    private func startWorkout(_ routine: SessionTemplate, slot: SplitSessionSlot? = nil) {
        do {
            // CR-01: thread the resolved slot through so session.slot is the
            // rotation anchor; TodayResolver advances rotation off it.
            let session = try SessionFactory.start(
                template: routine,
                slot: slot,
                activeBlock: activeBlocks.first,
                context: ctx
            )
            navigationPath.append(SessionRoute.logger(session))
        } catch {
            // Session start errors (e.g. routineHasNoExercises) are surfaced
            // by RoutinesListView's conflict alert. TodayView silently skips
            // (the routine will still show the CTA next launch).
        }
    }

    // MARK: - Phase 5 plan 06 weekly recap (preserved verbatim from Phase 4/5)

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

    // MARK: - Phase 5 deload advisory helpers (preserved verbatim from Phase 4/5)

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

    @MainActor
    private func dismissAdvisory() {
        guard let advisory = currentAdvisory, let settings = settingsList.first else { return }
        settings.deloadAdvisoryDismissedWeekStart = advisory.weekStart
        try? ctx.save()
        currentAdvisory = nil
    }

    // MARK: - PendingBlockBuilder (preserved verbatim from Phase 4/5; .edit case added for D-11)

    private enum PendingBlockBuilder: Identifiable {
        case template(BlockTemplate)
        case edit(Block)

        var id: String {
            switch self {
            case .template(let template):
                return "template-\(template.name)"
            case .edit(let block):
                return "edit-\(block.id.uuidString)"
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("TodayView — empty state (no block)") {
    TodayView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("TodayView — seeded") {
    TodayView()
        .modelContainer(PreviewModelContainer.make())
}
#endif
