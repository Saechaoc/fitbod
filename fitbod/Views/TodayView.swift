// TodayView.swift
// fitbod — Phase 2.1 Plan 04
//
// Today's resolved state owns its hero, repair/start actions and alternate
// session row. The logger and all pushed details stay on Today's stack.
//
// Navigation: NavigationStack(path: $navigationPath) wraps everything.
// Chrome: BRUHeaderBar via .safeAreaInset(edge: .top) + .navigationBarHidden(true).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData
import UIKit

// MARK: - TodayView

/// The Today tab's root view — BRU composition over Phase 4 + Phase 5 wiring.
public struct TodayView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?
    @Environment(ResumeWorkoutRequest.self) private var resumeRequest: ResumeWorkoutRequest?

    // MARK: - Queries (preserved verbatim from RootView.TodayView Phase 4/5)

    @Query(filter: #Predicate<Block> { $0.isActive == true })
    private var activeBlocks: [Block]

    @Query private var settingsList: [UserSettings]

    /// The routines a block could run on; with none, Today's block card
    /// asks for a routine first.
    @Query(filter: #Predicate<Split> { !$0.isArchived })
    private var routines: [Split]

    /// Blocks that have not started, newest first; the first ready one is
    /// the block Today offers to start.
    @Query(
        filter: #Predicate<Block> { $0.isActive == false && $0.endDate == nil },
        sort: \Block.startDate, order: .reverse
    )
    private var waitingBlocks: [Block]

    // NEW for BRU — active session detection (completedAt == nil)
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    // ALL sessions for streak + total count computation
    @Query(sort: \Session.startedAt, order: .reverse)
    private var allSessions: [Session]

    @Query(filter: #Predicate<SessionTemplate> { !$0.isArchived })
    private var sessionTemplates: [SessionTemplate]

    /// What "today" is; refreshed on appear, on return to the foreground and at a system day change.
    @State private var now = Date.now

    // MARK: - Navigation / Sheet State (preserved verbatim from Phase 4/5)

    @State private var navigationPath = NavigationPath()
    @State private var pendingBlockBuilder: BlockBuilderRoute? = nil
    @State private var pendingBlockReview: Block? = nil
    @State private var failedBlockStart: Block? = nil
    #if DEBUG
    @State private var failNextBlockStart = ProcessInfo.processInfo.arguments.contains("-fitbod-fail-block-start-once")
    #endif

    // Phase 5 plan 04 — deload advisory state.
    @State private var currentAdvisory: DeloadAdvisory? = nil
    @State private var presentingSignalSheet: Bool = false
    // Phase 5 plan 06 — weekly recap state.
    @State private var presentingWeeklyRecap: Bool = false
    /// The recap was due on a visit that showed a block review; it shows
    /// once the review closes.
    @State private var recapAfterReview: Bool = false
    /// Session detail pushed from the hero, repair action or session sheet.
    @State private var openedSession: OpenedSession? = nil
    @State private var startError: String? = nil
    @State private var discardError: String? = nil
    @State private var presentingSettings = false
    /// All live sessions, grouped by routine.
    @State private var choosingSession = false
    /// A sheet choice runs after its dismissal.
    @State private var pendingChoice: PendingChoice? = nil
    /// The week board's days and totals, counted when the finished workouts,
    /// a History correction or the week change, never per render (RM-010).
    @State private var week: TodayWeek? = nil

    // MARK: - Body

    public var body: some View {
        // Resolved once per render: a rotation resolve fetches every
        // finished workout, and the CTA, picker and lift list all need it.
        let resolution = todaysResolution
        let finished = allSessions.filter { $0.completedAt != nil }
        let readyBlocks = waitingBlocks.filter { $0.derivedStatus == .ready }
        let state = TodayState.resolve(
            openWorkouts: activeSessions, activeBlock: activeBlocks.first, resolution: resolution,
            finishedWorkouts: finished, readyBlocks: readyBlocks,
            liveRoutines: routines, sessions: sessionTemplates, now: now, calendar: calendar)
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {

                    if let block = activeBlocks.first {
                        TodayPlanLine(block: block, now: now) {
                            navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
                        }
                    }

                    if let week {
                        TodayWeekBoard(
                            week: week, showsHeader: activeBlocks.isEmpty,
                            todayNote: Self.todayNote(state), isRestDay: Self.isRestDay(state)
                        ) { navigationPath.append(TodayRoute.volume) }
                    }

                    if let advisory = currentAdvisory,
                       TodayState.showsDeloadAdvisory(state: state, phase: currentPhase) {
                        DeloadAdvisoryBanner(
                            advisory: advisory,
                            onDismiss: { dismissAdvisory() },
                            onTapBody: { presentingSignalSheet = true }
                        )
                    }

                    stateContent(state, resolution: resolution, finished: finished, readyCount: readyBlocks.count)
                }
            }
            .task(id: WeekKey(
                finished: finished.map(\.persistentModelID), weekStart: weekStart,
                today: calendar.startOfDay(for: now), edits: historyEdits?.version)) {
                week = TodayWeek.make(finished: finished, weekStart: weekStart, now: now, calendar: calendar)
            }
            .background(Color.bruPaper.ignoresSafeArea())
            // Suppress default Apple navigation bar — BRUHeaderBar replaces it
            .navigationBarHidden(true)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            // BRUHeaderBar floated as a safeArea inset — renders above ScrollView content
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: HeaderAction("Settings") { presentingSettings = true },
                    center: "Fitbod / Today",
                    right: .text(formattedDate)
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("today.root")
            }
            // ─── Navigation Destinations (preserved verbatim from Phase 4/5) ──
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session):
                    SessionLoggerView(session: session)
                }
            }
            // Workout history from the Sessions stat cell.
            .sessionHistoryDestinations()
            // The week board opens Volume on Today's own stack (RM-010).
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .volume:
                    VolumeScreen(path: $navigationPath)
                }
            }
            // Phase 5 plan 05 — per-muscle drill-down from Volume's heatmap + volume-bar taps.
            .navigationDestination(for: MuscleSlugRoute.self) { route in
                switch route {
                case .detail(let slug):
                    PerMuscleDetailView(muscleSlug: slug)
                }
            }
            // The block overview (CONTEXT D-11), whose EDIT opens the builder,
            // and the routine the .emptySplit fix-it opens on Today's own
            // stack (Phase 09 Plan 03).
            .blockDestinations(origin: .today) { pendingBlockBuilder = .edit($0) }
            // The name step "+ New routine" opens; its SAVE swaps it for the
            // routine's SplitDetailView.
            .newRoutineDestination(path: $navigationPath)
            // ─── Sheets (preserved verbatim from Phase 4/5) ──────────────────
            .sheet(item: $pendingBlockBuilder) { route in
                NavigationStack {
                    route.builder(origin: .today)
                }
            }
            .modifier(TodayBlockAlerts(
                failedBlock: $failedBlockStart,
                onRetry: startBlock,
                onOpen: { navigationPath.append(BlockOverviewRoute.summary(blockID: $0.id)) }
            ))
            // A recap due on the same visit waits for the review to close.
            .sheet(item: $pendingBlockReview, onDismiss: showRecapAfterReview) { block in
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
            // Phase 5 plan 06 — VOL-07 weekly recap sheet. The recap is
            // marked seen once it shows, never while it waits.
            .sheet(isPresented: $presentingWeeklyRecap) {
                if let settings = settingsList.first {
                    let weekStart = Date.now.mondayAtMidnightForToday(
                        weekStartsMonday: settings.weekStartsMonday
                    )
                    WeeklyRecapSheet(weekStart: weekStart)
                        .onAppear { markRecapSeen(weekStart, in: settings) }
                }
            }
            .sheet(isPresented: $presentingSettings) {
                SettingsView(onClose: { presentingSettings = false })
            }
            .sheet(isPresented: $choosingSession, onDismiss: startChosenSession) {
                SessionSheet(
                    content: SessionSheetContent(
                        liveRoutines: routines, sessions: sessionTemplates, block: activeBlocks.first,
                        resolution: resolution, finished: finished, now: now, calendar: calendar),
                    phase: currentBlockPhase,
                    onStart: { session, routine in choose(.start(session, routine)) },
                    onOpen: { session in choose(.open(session)) }
                )
            }
            .navigationDestination(item: $openedSession) { opened in
                SessionTemplateDetailView(template: opened.template, routine: opened.routine)
            }
            .alert(
                "Couldn't start workout",
                isPresented: Binding(
                    get: { startError != nil },
                    set: { if !$0 { startError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { startError = nil }
            } message: {
                Text(startError ?? "")
            }
            .alert(
                "Couldn't discard workout",
                isPresented: Binding(
                    get: { discardError != nil },
                    set: { if !$0 { discardError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { discardError = nil }
            } message: {
                Text(discardError ?? "")
            }
            // ─── Lifecycle (preserved verbatim from Phase 4/5) ───────────────
            // Both run on every appearance. The advisory check lives only in
            // onAppear: running it from the task as well repeated the deload
            // evaluation each time Today appeared. The recap check follows
            // the review's, so a review due on the same visit shows first.
            .task {
                pendingBlockReview = (try? BlockReviewStatistics.pendingReviewBlocks(
                    context: ctx,
                    now: Date.now
                ))?.first
                checkWeeklyRecap()
            }
            .onAppear {
                now = .now
                refreshAdvisory()
                openRequestedWorkout()
            }
            .onChange(of: resumeRequest?.isPending) {
                openRequestedWorkout()
            }
            // A History correction can empty a finished workout or fill an
            // empty one, so Today resolves again.
            .onChange(of: historyEdits?.version) { now = .now }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                now = .now
            }
        }
    }

    // MARK: - State content

    @ViewBuilder
    private func stateContent(
        _ state: TodayState, resolution: TodayResolution, finished: [Session], readyCount: Int
    ) -> some View {
        switch state {
        case .resume(let session):
            ResumeWorkoutSlab(
                session: session,
                onResume: { navigationPath.append(SessionRoute.logger(session)) },
                onDiscard: {
                    do { try SessionSetActions.deleteWorkout(session, context: ctx) }
                    catch { discardError = "The workout wasn't discarded. Try again." }
                }
            )
        case .done(let sessions):
            DoneTodaySlab(
                sessions: sessions, history: finished, upNext: upNextLabel(resolution, finished: finished),
                onView: { navigationPath.append(SessionHistoryRoute.summary(sessionID: $0.id)) }
            )
            chooseSessionRow("Start another workout")
        case .ready(let block):
            ReadyBlockCard(
                block: block, readyCount: readyCount,
                onStart: { startBlock(block) },
                onOpen: { navigationPath.append(BlockOverviewRoute.summary(blockID: block.id)) }
            )
            chooseSessionRow("Start a workout instead")
        case .fix(let fix):
            repairSlab(fix)
            if !activeBlocks.isEmpty && canChooseSession {
                chooseSessionRow("Choose another session")
            }
        case .attach(let block):
            TodayRepairSlab(
                title: "Block has no routine",
                message: "End \(block.name) to plan a new one.", actionTitle: "Open block ▸"
            ) { navigationPath.append(BlockOverviewRoute.summary(blockID: block.id)) }
            if canChooseSession { chooseSessionRow("Choose another session") }
        case .rest:
            Text("Rest day")
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay { Rectangle().strokeBorder(Color.bruInk, lineWidth: 2) }
                .padding(16)
            chooseSessionRow("Start a workout anyway")
        case .today(let block, let slot):
            if let session = slot.sessionTemplate {
                BlackSlabCTA(
                    routine: session,
                    label: BlackSlabCTA.heroLabel(
                        mode: block.schedulingMode, position: slot.position, slotCount: block.split?.slots?.count ?? 0),
                    phase: currentBlockPhase, onStart: { startWorkout(session, in: block.split) }
                )
                LiftListSection(routine: session, phase: currentBlockPhase, previewCount: 3) {
                    openedSession = OpenedSession(template: session, routine: block.split)
                }
                chooseSessionRow("Choose another session")
            }
        case .pick(let pick):
            BlackSlabCTA(
                routine: pick.session, label: BlackSlabCTA.heroLabel(routine: pick.slot?.split),
                phase: nil, onStart: { startWorkout(pick.session, in: pick.slot?.split) }
            )
            LiftListSection(routine: pick.session, phase: nil, previewCount: 3) {
                openedSession = OpenedSession(template: pick.session, routine: pick.slot?.split)
            }
            chooseSessionRow("Choose another session")
        case .first:
            firstRoutinePrompt
        }
    }

    private func chooseSessionRow(_ title: String) -> some View {
        TodayGhostRow(title: title) { choosingSession = true }
            .accessibilityIdentifier("today.chooseSession")
    }

    @ViewBuilder
    private func repairSlab(_ fix: TodayState.Fix) -> some View {
        switch fix {
        case .routineHasNoSessions(let routine):
            TodayRepairSlab(
                title: "Routine has no sessions",
                message: "Add a session to \(routine.name) to train from \(activeBlocks.isEmpty ? "it" : "this block").",
                actionTitle: "Go to routine ▸"
            ) { navigationPath.append(SplitDetailRoute.detail(splitID: routine.id)) }
        case .routineHasNoExercises(let routine):
            TodayRepairSlab(
                title: "\(routine.name) has no exercises yet",
                message: "Add exercises to its sessions to train from it.", actionTitle: "Go to routine ▸"
            ) { navigationPath.append(SplitDetailRoute.detail(splitID: routine.id)) }
        case .sessionHasNoExercises(let session):
            TodayRepairSlab(
                title: "\(session.name) has no exercises",
                message: "Add exercises to \(session.name) to train it.", actionTitle: "Add exercises ▸"
            ) { openedSession = OpenedSession(template: session, routine: activeBlocks.first?.split) }
        }
    }

    /// First visit: a workout is one tap away, and planning comes second.
    @ViewBuilder
    private var firstRoutinePrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start lifting today")
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
            Text("Log a workout now and add exercises as you go. Plan a routine or block whenever you are ready.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
            BRUButton("Start workout ▸", kind: .signal, size: .lg, action: startEmptyWorkout)
                .accessibilityIdentifier("today.startEmptyWorkout")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        TodayGhostRow(title: "Plan a routine or block", action: startNewRoutine)
            .accessibilityIdentifier("today.planRoutine")
    }

    // MARK: - Week board

    /// The week the board shows, from the user's week-start setting.
    private var weekStart: Date {
        now.mondayAtMidnightForToday(weekStartsMonday: settingsList.first?.weekStartsMonday ?? true, calendar: calendar)
    }

    static func todayNote(_ state: TodayState) -> String? {
        switch state {
        case .resume: "Live"
        case .rest: "Rest"
        default: nil
        }
    }

    static func isRestDay(_ state: TodayState) -> Bool {
        if case .rest = state { return true }
        return false
    }

    /// What the week board's counts depend on.
    private struct WeekKey: Equatable {
        let finished: [PersistentIdentifier]
        let weekStart: Date
        /// Moves today's tile at a day change within the week.
        let today: Date
        let edits: Int?
    }

    // MARK: - Formatted Date (BRU header right slot)

    /// "Wed · May 22" — en_US weekday abbreviated + month abbreviated + day.
    private var formattedDate: String {
        let f = now.formatted(
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

    /// The active block's current phase, read with Today's date and calendar
    /// so the hero, the rows and the start agree. Nil without a block, and
    /// past its plan, which has no current phase.
    private var currentBlockPhase: BlockPhase? {
        activeBlocks.first.flatMap { PeriodizationEngine.phase(for: $0, on: now, calendar: calendar) }
    }

    /// The current phase's kind, for the deload advisory.
    private var currentPhase: BlockPhaseKind? {
        currentBlockPhase?.kind
    }

    /// START BLOCK ▸ on the ready block's card. No block is active, so
    /// there is nothing to confirm.
    private func startBlock(_ block: Block) {
        do {
            #if DEBUG
            if failNextBlockStart {
                failNextBlockStart = false
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try BlockLifecycleService.start(block: block, context: ctx)
            failedBlockStart = nil
        } catch {
            failedBlockStart = block
        }
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
        return TodayResolver.resolve(block: block, context: ctx, today: now, calendar: calendar)
    }

    /// The same NEXT the sheet marks, with the schedule/routine context the done slab needs.
    private func upNextLabel(_ resolution: TodayResolution, finished: [Session]) -> String? {
        if let block = activeBlocks.first {
            guard let slot = StartSlot.next(
                in: block, resolution: resolution, finished: finished, now: now, calendar: calendar),
                  StartSlot.hasExercises(slot.sessionTemplate), let session = slot.sessionTemplate else { return nil }
            if block.schedulingMode == .fixedWeekly,
               let next = TodayResolver.nextTrainingDay(block: block, after: now, calendar: calendar) {
                return "Next: \(session.name) · \(next.day.formatted(.dateTime.weekday(.wide)))"
            }
            return "Next up: \(session.name)"
        }
        guard let pick = StartSlot.suggestion(liveRoutines: routines, sessions: sessionTemplates, finished: finished) else {
            return nil
        }
        if let routine = pick.slot?.split { return "Next up: \(pick.session.name) · \(routine.name)" }
        return "Next up: \(pick.session.name)"
    }

    private var canChooseSession: Bool {
        sessionTemplates.contains { StartSlot.hasExercises($0) }
    }

    // MARK: - Workout Start

    /// Starts `template` from the routine it is shown in. The starter works
    /// out the slot at the tap, so session.slot is the rotation anchor
    /// TodayResolver and StartSlot move on from (CR-01, O-2).
    @MainActor
    private func startWorkout(_ template: SessionTemplate, in routine: Split?) {
        switch WorkoutStarter.start(template, in: routine, context: ctx, calendar: calendar) {
        case .started(let session):
            navigationPath.append(SessionRoute.logger(session))
        case .alreadyInProgress(let active):
            navigationPath = NavigationPath([SessionRoute.logger(active)])
        case .emptyTemplate:
            startError = "Add at least one exercise to \(template.name) first."
        case .failed(let message):
            startError = message
        }
    }

    /// Keeps what the session sheet picked and closes the sheet.
    @MainActor
    private func choose(_ choice: PendingChoice) {
        pendingChoice = choice
        choosingSession = false
    }

    /// Acts on what the session sheet picked, once the sheet has gone.
    @MainActor
    private func startChosenSession() {
        guard let choice = pendingChoice else { return }
        pendingChoice = nil
        switch choice {
        case .start(let template, let routine):
            startWorkout(template, in: routine)
        case .open(let template):
            openedSession = OpenedSession(template: template, routine: nil)
        }
    }

    /// Program's RESUME ▸, a session's START WORKOUT ▸ or the Live Activity
    /// asked for the workout in progress. The logger lives on Today's stack
    /// only, and Today's stack is reset to just the logger, so ‹ always
    /// lands on Today (FT-02). The workout is read from the store, because
    /// one started a moment ago has not reached `activeSessions` yet. No
    /// logger is open then (RootView ignores the link while one is).
    @MainActor
    private func openRequestedWorkout() {
        guard let resumeRequest, resumeRequest.isPending else { return }
        resumeRequest.isPending = false
        guard let active = WorkoutStarter.inProgressSession(in: ctx) else { return }
        openedSession = nil
        navigationPath = NavigationPath([SessionRoute.logger(active)])
    }

    /// Starts a workout with nothing in it; exercises are added in the logger.
    @MainActor
    private func startEmptyWorkout() {
        switch WorkoutStarter.startEmpty(context: ctx) {
        case .started(let session):
            navigationPath.append(SessionRoute.logger(session))
        case .alreadyInProgress(let active):
            navigationPath = NavigationPath([SessionRoute.logger(active)])
        case .emptyTemplate:
            break
        case .failed(let message):
            startError = message
        }
    }

    /// Opens the name step on Today's own stack. The routine exists only once
    /// the user saves its name there.
    @MainActor
    private func startNewRoutine() {
        navigationPath.append(NewRoutineRoute.name)
    }

    // MARK: - Phase 5 plan 06 weekly recap (preserved verbatim from Phase 4/5)

    @MainActor
    private func checkWeeklyRecap() {
        guard let settings = settingsList.first else { return }
        let thisMonday = Date.now.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday)
        let priorWeekStart = FatigueModel.date(byAddingWeeks: -1, to: thisMonday)
        let hasSessions = lastWeekSessionsCount(start: priorWeekStart, end: thisMonday) > 0

        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMonday,
            lastShown: settings.weeklyRecapShownForWeekStart,
            hasSessionsLastWeek: hasSessions
        )

        // A recap to show is marked seen once it shows. SwiftUI shows one
        // sheet at a time, so it waits for a review due on the same visit.
        if decision.shouldPresent {
            if pendingBlockReview == nil {
                presentingWeeklyRecap = true
            } else {
                recapAfterReview = true
            }
        } else if decision.shouldMarkSeen {
            markRecapSeen(thisMonday, in: settings)
        }
    }

    /// Shows the recap that waited for the block review to close.
    @MainActor
    private func showRecapAfterReview() {
        guard recapAfterReview else { return }
        recapAfterReview = false
        presentingWeeklyRecap = true
    }

    @MainActor
    private func markRecapSeen(_ weekStart: Date, in settings: UserSettings) {
        settings.weeklyRecapShownForWeekStart = weekStart
        try? ctx.save()
    }

    /// Last week's workouts that count as sessions (decision 6), so an
    /// empty workout alone leaves the recap undue.
    @MainActor
    private func lastWeekSessionsCount(start: Date, end: Date) -> Int {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        return SessionSetActions.countedWorkouts((try? ctx.fetch(descriptor)) ?? []).count
    }

    // MARK: - Phase 5 deload advisory helpers (preserved verbatim from Phase 4/5)

    @MainActor
    private func refreshAdvisory() {
        guard let settings = settingsList.first else {
            currentAdvisory = nil
            return
        }
        let thisMonday = now.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday)
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

    private enum PendingChoice {
        /// A routine's row: start the session from that routine.
        case start(SessionTemplate, Split)
        /// A session in no routine: open its detail.
        case open(SessionTemplate)
    }

    /// A session's detail and the routine it was opened from, which decides
    /// the slot a start from that detail credits.
    private struct OpenedSession: Hashable {
        let template: SessionTemplate
        let routine: Split?
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

/// A failed block start, kept out of TodayView's body so the compiler can type-check it.
/// Program's ready slab shows the same alert (RM-011).
struct TodayBlockAlerts: ViewModifier {
    @Binding var failedBlock: Block?
    let onRetry: (Block) -> Void
    let onOpen: (Block) -> Void

    func body(content: Content) -> some View {
        content
            .alert("Couldn't start block", isPresented: Binding(
                get: { failedBlock != nil },
                set: { if !$0 { failedBlock = nil } }
            ), presenting: failedBlock) { block in
                Button("Try again") { onRetry(block) }
                Button("Open block") { onOpen(block) }
            } message: { _ in
                Text("Try again, or open the block to review its setup.")
            }
    }
}
