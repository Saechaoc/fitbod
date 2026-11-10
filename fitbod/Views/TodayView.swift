// TodayView.swift
// fitbod — Phase 2.1 Plan 04
//
// Standalone Today tab root. Extracted from the 219-line `private struct TodayView`
// in fitbod/App/RootView.swift (Wave B audit item #3). All Phase 4 + Phase 5
// behaviors are preserved verbatim — only the presentation shell is replaced with
// BRU primitives.
//
// Composition order (top to bottom per UI-SPEC line 533):
//   safeAreaInset(top): BRUHeaderBar("Fitbod / Today", right: formatted date as plain text)
//   ─── inside ScrollView VStack(spacing: 0) ───────────────────────────────
//   [Defensive-top Phase 5 banners]
//     DeloadAdvisoryBanner  (currentAdvisory != nil)
//   [BRU Layer]
//     TodayPlanLine  (block name over week and phase → Block overview)  — when block active
//     ResumeWorkoutSlab  — when active session (completedAt == nil)
//       OR DoneTodaySlab — when today's workout is finished
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
import UIKit

// MARK: - TodayView

/// The Today tab's root view — BRU composition over Phase 4 + Phase 5 wiring.
public struct TodayView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var ctx
    @Environment(\.weightUnit) private var weightUnit
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
    /// Create block, the same choice Program's + NEW opens.
    @State private var presentingCreateBlock = false
    /// A failed block start or end, in plain words.
    @State private var blockError: String? = nil

    // Phase 5 plan 04 — deload advisory state.
    @State private var currentAdvisory: DeloadAdvisory? = nil
    @State private var presentingSignalSheet: Bool = false
    // Phase 5 plan 06 — weekly recap state.
    @State private var presentingWeeklyRecap: Bool = false
    /// The recap was due on a visit that showed a block review; it shows
    /// once the review closes.
    @State private var recapAfterReview: Bool = false
    /// Session detail pushed from the hero's View or the Start-a-workout picker.
    @State private var openedSession: OpenedSession? = nil
    /// A workout already in progress when the user tried to start another.
    @State private var startConflict: Session? = nil
    @State private var startError: String? = nil
    @State private var discardError: String? = nil
    @State private var presentingSettings = false
    /// The block's sessions, to start one other than today's.
    @State private var choosingSession = false
    /// What the session list picked; it starts once the list has gone.
    @State private var pendingChoice: PendingChoice? = nil

    // MARK: - Body

    public var body: some View {
        // Resolved once per render: a rotation resolve fetches every
        // finished workout, and the CTA, picker and lift list all need it.
        let resolution = todaysResolution
        let todaysRoutine = Self.scheduledRoutine(in: resolution)
        let finished = allSessions.filter { $0.completedAt != nil }
        let state = TodayState.resolve(
            openWorkouts: activeSessions, activeBlock: activeBlocks.first, resolution: resolution,
            finishedWorkouts: finished, readyBlocks: waitingBlocks.filter { $0.derivedStatus == .ready },
            liveRoutines: routines, sessions: sessionTemplates, now: now, calendar: calendar)
        let doneToday: Session? = if case .done(let workouts) = state { workouts.first } else { nil }
        let readyBlock: Block? = if case .ready(let block) = state { block } else { nil }
        let pick: StartSlot.Suggestion? = if case .pick(let suggestion) = state { suggestion } else { nil }
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {

                    if let block = activeBlocks.first {
                        TodayPlanLine(block: block, now: now) {
                            navigationPath.append(BlockOverviewRoute.summary(blockID: block.id))
                        }
                    }

                    if let advisory = currentAdvisory,
                       TodayState.showsDeloadAdvisory(state: state, phase: currentPhase) {
                        DeloadAdvisoryBanner(
                            advisory: advisory,
                            onDismiss: { dismissAdvisory() },
                            onTapBody: { presentingSignalSheet = true }
                        )
                    }

                    if activeBlocks.isEmpty, activeSessions.isEmpty, let ready = readyBlock {
                        ReadyBlockCard(
                            block: ready,
                            onStart: { startBlock(ready) },
                            onOpen: { navigationPath.append(BlockOverviewRoute.summary(blockID: ready.id)) }
                        )
                    }

                    // CTA slab — resume-in-progress wins (spec §5); otherwise
                    // branch on the full TodayResolution so .emptySplit gets a
                    // distinct repair surface (CR-02).
                    if let active = activeSessions.first {
                        // Active in-progress session → Resume slab
                        ResumeWorkoutSlab(
                            session: active,
                            onResume: { navigationPath.append(SessionRoute.logger(active)) },
                            onDiscard: {
                                do {
                                    try SessionSetActions.deleteWorkout(active, context: ctx)
                                } catch {
                                    discardError = "The workout wasn't discarded. Try again."
                                }
                            }
                        )
                    } else if let done = doneToday {
                        // Today's workout is done: it, with a way to its
                        // summary, and the next session as upcoming.
                        DoneTodaySlab(
                            session: done,
                            upNext: upNextLabel(resolution),
                            unit: weightUnit,
                            onView: { navigationPath.append(SessionHistoryRoute.summary(sessionID: done.id)) },
                            onChooseSession: canChooseSession ? { @MainActor in choosingSession = true } : nil
                        )
                    } else {
                        switch resolution {
                        case .session(let slot):
                            if let routine = slot.sessionTemplate, let block = activeBlocks.first {
                                // Scheduled session → Black slab CTA. It starts
                                // from the block's routine, so the starter credits
                                // the scheduled slot as the rotation anchor (CR-01).
                                BlackSlabCTA(
                                    routine: routine,
                                    label: BlackSlabCTA.heroLabel(
                                        mode: block.schedulingMode,
                                        position: slot.position,
                                        slotCount: block.split?.slots?.count ?? 0
                                    ),
                                    phase: currentBlockPhase,
                                    onStart: { startWorkout(routine, in: block.split) }
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
                            if !activeBlocks.isEmpty {
                                // Block active but split not yet attached → empty state
                                noWorkoutScheduledEmptyState
                            } else if let pick {
                                // No block, a session to train: the suggested
                                // session leads as the one hero (T-PICK).
                                BlackSlabCTA(
                                    routine: pick.session,
                                    label: BlackSlabCTA.heroLabel(routine: pick.slot?.split),
                                    phase: nil,
                                    onStart: { startWorkout(pick.session, in: pick.slot?.split) }
                                )
                            }
                            // Otherwise the Start-a-workout picker below leads.
                        }
                    }

                    // Start-a-workout picker whenever nothing is scheduled or
                    // suggested and nothing is in progress (a rest day, an
                    // empty split, a ready block, a fresh store).
                    if activeSessions.isEmpty && todaysRoutine == nil && pick == nil {
                        TodaySessionPicker(
                            onOpen: { openedSession = OpenedSession(template: $0, routine: $1) },
                            onStart: { startWorkout($0, in: $1) },
                            onNewRoutine: startNewRoutine,
                            onStartEmpty: startEmptyWorkout
                        )
                    }

                    // Lift list — for a scheduled session not yet done, or
                    // the suggested one with no block
                    if let routine = todaysRoutine, doneToday == nil {
                        LiftListSection(routine: routine, phase: currentBlockPhase, onView: {
                            openedSession = OpenedSession(template: routine, routine: activeBlocks.first?.split)
                        })
                    } else if let pick {
                        LiftListSection(routine: pick.session, phase: nil, onView: {
                            openedSession = OpenedSession(template: pick.session, routine: pick.slot?.split)
                        })
                    }

                    // Under a hero, another session is one row and one tap away.
                    if pick != nil || (todaysRoutine != nil && doneToday == nil && activeSessions.isEmpty) {
                        TodayGhostRow(title: "Choose another session") { choosingSession = true }
                            .accessibilityIdentifier("today.chooseSession")
                    }

                    // No block at all → Start Block CTA (Phase 4 preserved),
                    // after the picker, or the hero and its exercises, so
                    // starting a workout stays primary. A block runs on a
                    // routine, so with none the picker's + New routine is
                    // the one routine action here (FT-15).
                    if activeSessions.isEmpty && activeBlocks.isEmpty && readyBlock == nil && !routines.isEmpty {
                        StartBlockCTA(onStart: { presentingCreateBlock = true })
                    }

                    // ─── DEFENSIVE BOTTOM — Phase 5 FatigueSurfaceView ──
                    FatigueSurfaceView(
                        isAdvisoryActive: currentAdvisory != nil,
                        navigationPath: $navigationPath
                    )
                }
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
            // Phase 5 plan 05 — per-muscle drill-down from heatmap + volume-bar taps.
            .navigationDestination(for: MuscleSlugRoute.self) { route in
                switch route {
                case .detail(let slug):
                    PerMuscleDetailView(muscleSlug: slug)
                }
            }
            // The block overview (CONTEXT D-11), whose EDIT opens the builder,
            // and the routine the .emptySplit fix-it opens on Today's own
            // stack (Phase 09 Plan 03).
            .blockDestinations { pendingBlockBuilder = .edit($0) }
            // The name step "+ New routine" opens; its SAVE swaps it for the
            // routine's SplitDetailView.
            .newRoutineDestination(path: $navigationPath)
            // ─── Sheets (preserved verbatim from Phase 4/5) ──────────────────
            .sheet(item: $pendingBlockBuilder) { route in
                NavigationStack {
                    route.builder(origin: .today)
                }
            }
            .blockCreateFlow(isPresented: $presentingCreateBlock) { pendingBlockBuilder = $0 }
            .modifier(TodayBlockAlerts(blockError: $blockError))
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
                    onOpen: { session in choose(.open(session)) },
                    onStartEmpty: { choose(.empty) }
                )
            }
            .navigationDestination(item: $openedSession) { opened in
                SessionTemplateDetailView(template: opened.template, routine: opened.routine)
            }
            .alert(
                "Workout in progress",
                isPresented: Binding(
                    get: { startConflict != nil },
                    set: { if !$0 { startConflict = nil } }
                ),
                presenting: startConflict
            ) { active in
                Button("Resume \(active.displayName)") {
                    navigationPath.append(SessionRoute.logger(active))
                    startConflict = nil
                }
                Button("Cancel", role: .cancel) { startConflict = nil }
            } message: { _ in
                Text("Finish or discard the current workout before starting another.")
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
                startNewRoutine()
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

    /// CR-02 / spec §5 / Phase 9: fix-it surface for a block whose split was
    /// emptied mid-block (zero slots). Distinct from the rest-day
    /// "No workout scheduled" copy — showing that copy would lie about why
    /// nothing is scheduled. CTA navigates to SplitDetailView on Today's OWN
    /// NavigationStack (no cross-tab navigation).
    @ViewBuilder
    private var emptySplitFixItState: some View {
        if let split = activeBlocks.first?.split {
            EmptySplitFixIt(onGoToRoutine: {
                navigationPath.append(SplitDetailRoute.detail(splitID: split.id))
            })
        } else {
            // Defensive: .emptySplit should only fire when a split is wired but
            // has zero slots; if somehow split is nil, fall back gracefully.
            noWorkoutScheduledEmptyState
        }
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
            try BlockLifecycleService.start(block: block, context: ctx)
        } catch {
            blockError = "The block didn't start. Try again."
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

    /// The session template scheduled for today (nil unless the resolver
    /// returns `.session(slot)` with a non-nil template). Drives
    /// `LiftListSection`'s exercise preview.
    private static func scheduledRoutine(in resolution: TodayResolution) -> SessionTemplate? {
        if case .session(let slot) = resolution {
            return slot.sessionTemplate
        }
        return nil
    }

    /// The done card's next session: the resolver's in a rotation block,
    /// or the next training day's session and date in a weekly block.
    private func upNext(_ resolution: TodayResolution) -> (slot: SplitSessionSlot, day: Date?)? {
        if let block = activeBlocks.first, block.schedulingMode == .fixedWeekly {
            return TodayResolver.nextTrainingDay(block: block, after: now).map { ($0.slot, $0.day) }
        }
        if case .session(let slot) = resolution { return (slot, nil) }
        return nil
    }

    /// The done card's up next, such as "Pull A · Wed".
    private func upNextLabel(_ resolution: TodayResolution) -> String? {
        guard let next = upNext(resolution),
              let name = next.slot.sessionTemplate?.name
        else { return nil }
        guard let day = next.day else { return name }
        let label = Calendar.current.isDateInTomorrow(day)
            ? "Tomorrow"
            : day.formatted(.dateTime.weekday(.abbreviated))
        return "\(name) · \(label)"
    }

    /// The block has sessions to choose from.
    private var canChooseSession: Bool {
        !(activeBlocks.first?.split?.slots ?? []).isEmpty
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
            startConflict = active
        case .emptyTemplate:
            startError = "Add at least one exercise to \(template.name) first."
        case .failed(let message):
            startError = message
        }
    }

    @MainActor
    private func startEmptyWorkout() {
        switch WorkoutStarter.startEmpty(context: ctx) {
        case .started(let session):
            navigationPath.append(SessionRoute.logger(session))
        case .alreadyInProgress(let active):
            startConflict = active
        case .emptyTemplate:
            break
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
        case .empty:
            startEmptyWorkout()
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
        guard let settings = settingsList.first, settings.deloadAlertEnabled else {
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
        case empty
    }

    /// A session's detail and the routine it was opened from, which decides
    /// the slot a start from that detail credits.
    private struct OpenedSession: Hashable {
        let template: SessionTemplate
        let routine: Split?
    }
}

// MARK: - EmptySplitFixIt

/// CR-02 / Phase 9 Plan 03: shown when the active block's split has zero slots.
/// Copy and layout verbatim from UI-SPEC §8 + Copywriting Contract.
/// Caller supplies the navigation action so this view stays stack-agnostic.
fileprivate struct EmptySplitFixIt: View {

    let onGoToRoutine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTINE HAS NO SESSIONS")
                .font(BRUFont.bodyEmphasis)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruInk)

            Text("The routine linked to this block has no sessions scheduled. Add a session to continue.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)

            BRUButton("GO TO ROUTINE ▸", kind: .ghost) {
                onGoToRoutine()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bruPaper)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine has no sessions. The routine linked to this block has no sessions scheduled. Add a session to continue.")
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
private struct TodayBlockAlerts: ViewModifier {
    @Binding var blockError: String?

    func body(content: Content) -> some View {
        content
            .alert("Couldn't Save", isPresented: Binding(
                get: { blockError != nil },
                set: { if !$0 { blockError = nil } }
            )) {
                Button("OK", role: .cancel) { blockError = nil }
            } message: {
                Text(blockError ?? "")
            }
    }
}
