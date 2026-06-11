//
//  BlockOverviewScreen.swift
//  fitbod
//
//  Net-new read-only block summary screen (CONTEXT D-10).
//  Phase 04.1 Wave 6 — BRU composition per 04.1-PATTERNS.md File #13
//  Phase 09 Wave 2 — live-mode controls + archived mode (09-04)
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Block · <name>", right: .action("EDIT") [live only])
//    ScrollView {
//      heroBand
//      weekCarousel
//      [live] splitAttachSwapBand (draft/ready only)
//      [live] modePickerSection (all live statuses)
//      [live/fixedWeekly] dayChipSection
//      phaseProgressionList
//      fatigueAdvisoryStrip
//      [completed] archiveContentSection
//    }
//    [ready]  startBlockButton + safeAreaFiller
//    [active] editBlockButton + endBlockButton + safeAreaFiller
//    [draft]  safeAreaFiller
//    [completed] safeAreaFiller
//
//  Read-only in archived (completed) mode per spec §6.
//  All mutations route through BlockLifecycleService / TrainingDaysWriter.
//  weekCarousel uses real @Query<Session> data — NO hardcoded mocks (revision iter 1 B5).
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - BlockOverviewRoute

/// Typed route for pushing BlockOverviewScreen onto a NavigationPath.
/// Uses UUID identity per Swift 6 Sendable safety (Block @Model is not Sendable across actor boundaries).
public enum BlockOverviewRoute: Hashable, Sendable {
    case summary(blockID: UUID)
}

// MARK: - DayState

/// Per-cell state for the week carousel grid.
internal enum DayState: Equatable {
    case done
    case today
    case upcoming
    case rest
}

// MARK: - BlockOverviewScreen

public struct BlockOverviewScreen: View {

    // MARK: - Stored properties

    private let block: Block
    private let onEdit: @MainActor () -> Void
    private let weekStart: Date
    private let weekEnd: Date
    private let todayDate: Date

    // MARK: - Environment

    @Environment(\.modelContext) private var ctx

    // MARK: - Presentation state

    @State private var presentingSplitPicker = false
    @State private var presentingSwapConfirm = false
    @State private var presentingEndConfirm = false

    // MARK: - @Query — real session data, no mocks (revision iter 1 B5)

    @Query private var weekSessions: [Session]

    // MARK: - Init

    public init(block: Block, onEdit: @escaping @MainActor () -> Void = {}) {
        self.block = block
        self.onEdit = onEdit

        let now = Date.now
        // CR-01 fix: pin to a Monday-first ISO-8601 calendar so the grid's
        // hardcoded `weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]`
        // (see `dayCell(for:offset:)`) lines up with the actual cellDate
        // regardless of the user's locale firstWeekday (en_US = Sunday).
        let cal = Self.mondayFirstCalendar
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        self.weekStart = start
        self.weekEnd = end
        self.todayDate = now

        // CR-03 trade-off: `weekStart` / `weekEnd` / `todayDate` and the
        // `@Query` predicate bounds (`startBound` / `endBound`) are all
        // captured at init. SwiftUI may keep this view's identity stable
        // across body re-evaluations, so if the screen stays mounted past
        // midnight (or worse, across the Sun→Mon ISO week rollover) the
        // entire carousel — grid columns, predicate bounds, and "today"
        // highlight — will continue to render the captured snapshot.
        // The whole screen stays *internally consistent* (everything reads
        // from the same `todayDate`, see `dayState(for:)`), so there's no
        // mismatch between query bounds and the "today" cell. The screen
        // is simply stale until SwiftUI re-instantiates it (typical for a
        // personal app re-opened daily).
        //
        // FIXME(v2): force re-init when the day rolls over, e.g. by passing
        // a snap-day from the parent and applying
        // `.id(Self.mondayFirstCalendar.startOfDay(for: .now))` on the
        // call site so SwiftUI rebuilds the view and refreshes the
        // predicate at the next midnight tick.

        let startBound = start
        let endBound = end
        _weekSessions = Query(
            filter: #Predicate<Session> { session in
                session.startedAt >= startBound && session.startedAt < endBound
            },
            sort: [SortDescriptor(\Session.startedAt)]
        )
    }

    /// Monday-first calendar for week-carousel cell alignment. ISO-8601 always
    /// uses Monday as `firstWeekday`; explicit `.iso8601` identifier removes any
    /// dependence on the device locale.
    private static var mondayFirstCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // 1 = Sunday, 2 = Monday
        return cal
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header: EDIT action hidden on completed blocks
            if block.derivedStatus == .completed {
                BRUHeaderBar.slots(
                    left: .back,
                    center: "Block · \(block.name)",
                    right: nil
                )
            } else {
                BRUHeaderBar.slots(
                    left: .back,
                    center: "Block · \(block.name)",
                    right: .action("EDIT", onEdit)
                )
            }

            ScrollView {
                VStack(spacing: 0) {
                    heroBand
                    weekCarousel

                    if block.derivedStatus != .completed {
                        // Live controls: shown on draft / ready / active
                        if block.derivedStatus == .draft || block.derivedStatus == .ready {
                            splitAttachSwapBand
                        }
                        modePickerSection
                        if block.schedulingMode == .fixedWeekly {
                            dayChipSection
                        }
                        phaseProgressionList
                        fatigueAdvisoryStrip
                    } else {
                        // Archived mode: render from decoded archive only
                        archiveContentSection
                    }
                }
            }

            bottomBar
            safeAreaFiller
        }
        .background(Color.bruBg.ignoresSafeArea())
        .sheet(isPresented: $presentingSplitPicker) {
            SplitPickerSheet(block: block)
        }
        .sheet(isPresented: $presentingSwapConfirm) {
            swapConfirmSheet
        }
        .alert("End block?", isPresented: $presentingEndConfirm) {
            Button("End Block", role: .destructive) {
                try? BlockLifecycleService.end(block: block, context: ctx)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("End this block now? You can review it from the Routines tab.")
        }
    }

    // MARK: - Computed helpers

    private var blockSequenceNumber: Int {
        // Derive from block start date week-of-year as a human-readable sequence label.
        // Full PR detection is Phase 6 scope; placeholder uses ISO week number.
        Calendar.current.component(.weekOfYear, from: block.startDate)
    }

    private var computedDaysRemaining: Int {
        guard let endDate = block.endDate else {
            // Fallback: project from phases if endDate is nil
            let totalDays = MesocycleWeekPage.totalWeeks(of: block) * 7
            let daysSince = Int(floor(Date.now.timeIntervalSince(block.startDate) / 86_400))
            return max(0, totalDays - daysSince)
        }
        return max(0, Int(ceil(endDate.timeIntervalSince(Date.now) / 86_400)))
    }

    private var totalWeeks: Int {
        MesocycleWeekPage.totalWeeks(of: block)
    }

    private var currentWeekIndex: Int {
        PeriodizationEngine.weekIndex(for: block, on: .now) ?? 0
    }

    private var currentWeekContext: MesocycleWeekContext? {
        PeriodizationEngine.weekContext(for: block, weekIndex: currentWeekIndex, on: .now)
    }

    private var phaseKindCapitalized: String {
        (currentWeekContext?.phaseKind.rawValue ?? "Accumulation").capitalized
    }

    private var volMultiplierLabel: String {
        let vol = currentWeekContext?.phaseVolumeMultiplier ?? 1.0
        if abs(vol - 1.0) < 0.01 { return "VOL HOLD" }
        let pct = Int(round((vol - 1.0) * 100))
        return pct > 0 ? "+\(pct)% VOL" : "\(pct)% VOL"
    }

    private var intMultiplierLabel: String {
        let intensity = currentWeekContext?.phaseIntensityMultiplier ?? 1.0
        let pct = Int(round(intensity * 100))
        return "INT \(pct)%"
    }

    private var shouldShowFatigueAdvisory: Bool {
        StubFatigueAdvisory().shouldSuggest(context: SessionContext())
    }

    // MARK: - Day state helpers (accessible for testing via internal shim)

    /// Derives the display state for a given calendar day cell.
    /// - today: the cell date is today
    /// - done: a session linked to this block was logged on that day
    /// - upcoming: future day that likely has a scheduled routine
    /// - rest: everything else
    internal func dayState(for cellDate: Date) -> DayState {
        let cal = Calendar.current
        // CR-03 fix: derive .today and .upcoming from the captured `todayDate`
        // (set in init) rather than `Date.now`, so the carousel grid, the
        // @Query predicate bounds, and the "today" / "upcoming" highlight
        // all use the same captured instant. Prevents internal inconsistency
        // if the view stays mounted past midnight — see init for the
        // FIXME(v2) about re-init on day rollover.
        if cal.isDate(cellDate, inSameDayAs: todayDate) {
            return .today
        }
        let sessionLinked = weekSessions.contains { session in
            cal.isDate(session.startedAt, inSameDayAs: cellDate)
            && (session.slot?.split?.id == block.split?.id
                // Phase 8: slot-based membership is primary (resolver sets session.slot);
                // block?.id fallback covers pre-resolver / legacy-edge sessions
                // (spec §8, RESEARCH Pitfall 7).
                || session.block?.id == block.id)
        }
        if sessionLinked {
            return .done
        }
        if cellDate > todayDate {
            // Heuristic: mark upcoming if there are slots in the block's split
            let routineCount = block.split?.slots?.count ?? 0
            if routineCount > 0 {
                return .upcoming
            }
        }
        return .rest
    }

    /// Returns the routine name for the session logged on a given day, if any.
    private func routineNameForCell(at cellDate: Date) -> String? {
        let cal = Calendar.current
        return weekSessions.first { session in
            cal.isDate(session.startedAt, inSameDayAs: cellDate)
            && (session.slot?.split?.id == block.split?.id
                // Phase 8: slot-based membership is primary (resolver sets session.slot);
                // block?.id fallback covers pre-resolver / legacy-edge sessions
                // (spec §8, RESEARCH Pitfall 7).
                || session.block?.id == block.id)
        }.map { $0.routineSnapshotName.isEmpty ? nil : $0.routineSnapshotName } ?? nil
    }

    private func hasPR(cellDate: Date) -> Bool {
        // PR detection is Phase 6 scope; always false for v1
        false
    }

    // MARK: - Hero Band

    @ViewBuilder
    private var heroBand: some View {
        if block.derivedStatus == .completed {
            completedHeroBand
        } else {
            activeHeroBand
        }
    }

    @ViewBuilder
    private var activeHeroBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: ACTIVE BLOCK label + DAYS REMAINING
            HStack {
                Text("● ACTIVE BLOCK · #\(blockSequenceNumber)")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruPaper.opacity(0.7))
                    .accessibilityHidden(true)
                Spacer()
                Text("\(computedDaysRemaining) DAYS REMAINING")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruSignal)
            }

            // Phase-week hero label (42pt displayHero)
            Text("\(phaseKindCapitalized) week")
                .font(BRUFont.displayHero)
                .foregroundStyle(Color.bruPaper)
                .padding(.top, 6)

            // Bottom row: week position + vol + intensity
            HStack(spacing: 12) {
                Text("W\(currentWeekIndex + 1) / \(totalWeeks)")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruPaper)
                Text("·")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.4))
                    .accessibilityHidden(true)
                Text(volMultiplierLabel)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignal)
                Text("·")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.4))
                    .accessibilityHidden(true)
                Text(intMultiplierLabel)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruPaper)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        // CONTEXT D-15 accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Active block \(blockSequenceNumber): \(block.name), \(phaseKindCapitalized) week, week \(currentWeekIndex + 1) of \(totalWeeks), \(computedDaysRemaining) days remaining."
        )
    }

    @ViewBuilder
    private var completedHeroBand: some View {
        let endedText: String = {
            if let endDate = block.endDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return "ENDED \(formatter.string(from: endDate))"
            }
            return "ENDED"
        }()

        VStack(alignment: .leading, spacing: 0) {
            // Top row: COMPLETED BLOCK label + ENDED date
            HStack {
                Text("● COMPLETED BLOCK · #\(blockSequenceNumber)")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruPaper.opacity(0.7))
                    .accessibilityHidden(true)
                Spacer()
                Text(endedText)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruMuted)
            }

            // Phase-week hero label
            Text(block.name)
                .font(BRUFont.displayHero)
                .foregroundStyle(Color.bruPaper)
                .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completed block \(blockSequenceNumber): \(block.name), \(endedText).")
    }

    // MARK: - Week Carousel

    /// Backed by real @Query<Session> data. Zero hardcoded mock day-state arrays.
    @ViewBuilder
    private var weekCarousel: some View {
        let cal = Calendar.current
        let prevWeek = currentWeekIndex > 0 ? "‹ W\(currentWeekIndex)" : ""
        let nextWeek = (currentWeekIndex + 1 < totalWeeks) ? "W\(currentWeekIndex + 2) ›" : ""

        VStack(spacing: 0) {
            // Week navigation header
            HStack {
                Text(prevWeek)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Text("WEEK \(currentWeekIndex + 1) OF \(totalWeeks)")
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Text(nextWeek)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruInk)
            }
            .padding(.bottom, 10)

            // 7-day M–S grid — state derived from @Query data and Date.now only
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(0..<7, id: \.self) { offset in
                    if let cellDate = cal.date(byAdding: .day, value: offset, to: weekStart) {
                        dayCell(for: cellDate, offset: offset)
                    }
                }
            }

            // Session count footer
            let doneCount = (0..<7).filter { offset in
                guard let cellDate = cal.date(byAdding: .day, value: offset, to: weekStart)
                else { return false }
                return dayState(for: cellDate) == .done
            }.count
            // V7: block.routines removed; slot count from split.
            let scheduledCount = block.split?.slots?.count ?? 0

            HStack {
                Text("\(doneCount) / \(max(doneCount, scheduledCount)) SESSIONS DONE")
                    .font(BRUFont.labelMicro)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
                let leftCount = max(0, scheduledCount - doneCount)
                Text("\(leftCount) LEFT")
                    .font(BRUFont.labelMicro)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    @ViewBuilder
    private func dayCell(for cellDate: Date, offset: Int) -> some View {
        let cal = Calendar.current
        let state = dayState(for: cellDate)
        let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        let dayLetter = offset < weekdayLetters.count ? weekdayLetters[offset] : "?"
        let routineName = routineNameForCell(at: cellDate)

        // Fill color per state
        let fillColor: Color = {
            switch state {
            case .today: return Color.bruSignal
            case .done: return Color.bruInk
            case .upcoming: return Color.bruPaper
            case .rest: return Color.bruFaint
            }
        }()

        // Text color per state
        let textColor: Color = {
            switch state {
            case .today, .done: return Color.bruPaper
            case .upcoming: return Color.bruInk
            case .rest: return Color.bruMuted
            }
        }()

        // Secondary label text
        let secondaryLabel: String = {
            if let name = routineName { return name }
            switch state {
            case .today: return "TODAY"
            case .done: return "DONE"
            case .upcoming: return "NEXT"
            case .rest: return "REST"
            }
        }()

        let weekdayLong = cal.weekdaySymbols[safe: (cal.component(.weekday, from: cellDate) - 1)] ?? dayLetter
        let accessLabel = "\(weekdayLong), \(routineName ?? (state == .rest ? "rest day" : phaseKindCapitalized)), \(state == .done ? "done" : state == .today ? "today" : state == .upcoming ? "upcoming" : "rest")"

        VStack(spacing: 2) {
            Text(dayLetter)
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(textColor)

            Text(secondaryLabel)
                .font(.custom("JetBrainsMono-Bold", size: 9))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(textColor.opacity(state == .rest ? 0.5 : 1.0))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .background(fillColor)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            if hasPR(cellDate: cellDate) {
                BRUCornerBadge("PR", fill: .bruSignal)
                    .offset(x: 3, y: -6)
            }
        }
        .accessibilityLabel(accessLabel)
    }

    // MARK: - Split Attach / Swap Band (draft/ready only)

    @ViewBuilder
    private var splitAttachSwapBand: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Routine", right: nil)
            HStack(spacing: 12) {
                if block.split == nil {
                    BRUButton("+ ATTACH ROUTINE ▸", kind: .ghost) {
                        presentingSplitPicker = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                } else {
                    Text(block.split!.name)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                    Button {
                        presentingSplitPicker = true
                    } label: {
                        Text("SWAP ▸")
                            .font(BRUFont.labelSmall)
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.bruSignal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            BRUDivider(.ink)
        }
    }

    // MARK: - Mode Picker (all live statuses)

    @ViewBuilder
    private var modePickerSection: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Scheduling", right: nil)
            HStack(spacing: 8) {
                ModeChip("ROTATION", selected: block.schedulingMode == .rotation) {
                    block.schedulingMode = .rotation
                    block.trainingDays = TrainingDaysWriter.sort(weekdays: block.trainingDays)
                    try? ctx.save()
                }
                ModeChip("FIXED WEEKLY", selected: block.schedulingMode == .fixedWeekly) {
                    block.schedulingMode = .fixedWeekly
                    block.trainingDays = TrainingDaysWriter.sort(weekdays: block.trainingDays)
                    try? ctx.save()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            BRUDivider(.ink)
        }
    }

    // MARK: - Day Chip Grid (fixedWeekly mode only)

    @ViewBuilder
    private var dayChipSection: some View {
        // Weekday int mapping — Monday-first: Mon=2, Tue=3, Wed=4, Thu=5, Fri=6, Sat=7, Sun=1
        // UI grid index 0=Mon...6=Sun; Calendar weekday: Sun=1, Mon=2, ...Sat=7
        let weekdayForGridIndex: [Int] = [2, 3, 4, 5, 6, 7, 1] // Mon..Sun in Calendar weekday ints
        let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        let slotCount = block.split?.slots?.count ?? 0

        VStack(spacing: 0) {
            BRUSectionHead("Training days", right: nil)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(0..<7, id: \.self) { index in
                    let weekday = weekdayForGridIndex[index]
                    let letter = index < weekdayLetters.count ? weekdayLetters[index] : "?"
                    let isSelected = block.trainingDays.contains(weekday)
                    DayToggleChip(letter: letter, selected: isSelected) {
                        var days = block.trainingDays
                        if isSelected {
                            days.removeAll { $0 == weekday }
                        } else {
                            days.append(weekday)
                        }
                        block.trainingDays = TrainingDaysWriter.sort(weekdays: days)
                        try? ctx.save()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Soft amber mismatch hint
            if block.trainingDays.count != slotCount {
                Text("\(block.trainingDays.count) days / \(slotCount) sessions")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruAmber)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BRUDivider(.ink)
                .padding(.top, 8)
        }
    }

    // MARK: - Phase Progression List

    @ViewBuilder
    private var phaseProgressionList: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Phase progression", right: "WHAT'S NEXT")

            let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
            VStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    phaseRow(phase: phase, index: index, allPhases: phases)
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func phaseRow(phase: BlockPhase, index: Int, allPhases: [BlockPhase]) -> some View {
        // Compute cumulative week range for this phase
        let priorWeeks = allPhases.prefix(index).reduce(0) { $0 + $1.weeks }
        let startWeek = priorWeeks + 1
        let endWeek = priorWeeks + phase.weeks
        let weekRange = startWeek == endWeek ? "W\(startWeek)" : "W\(startWeek)–W\(endWeek)"

        // Determine if this phase is current, past, or upcoming
        let isNow = (currentWeekIndex >= priorWeeks) && (currentWeekIndex < priorWeeks + phase.weeks)
        let isDone = currentWeekIndex >= priorWeeks + phase.weeks
        let isDeload = phase.kind == .deload

        // Kind descriptor per JSX reference
        let kindDescriptor: String = {
            switch phase.kind {
            case .accumulation: return "BUILD VOLUME"
            case .intensification: return "BUILD STRENGTH"
            case .peak: return "PEAK · −20% VOL"
            case .realization: return "REALIZATION · −40% VOL"
            case .deload: return "RECOVER · −50% VOL"
            }
        }()

        // Summary copy
        let summaryText: String = {
            if isNow {
                let done = weekSessions.filter { s in
                    // Phase 8: slot-based membership is primary (resolver sets session.slot);
                    // block?.id fallback covers pre-resolver / legacy-edge sessions
                    // (spec §8, RESEARCH Pitfall 7).
                    s.slot?.split?.id == block.split?.id || s.block?.id == block.id
                }.count
                return "In progress · \(done) sessions"
            } else if isDone {
                return "Completed"
            } else {
                return "\(phase.weeks) week\(phase.weeks == 1 ? "" : "s")"
            }
        }()

        // CR-02 fix: removed orphan ZStack that previously sat above the HStack
        // emitting a stray signal-stripe Rectangle as a sibling view. The
        // `.overlay(alignment: .leading)` on the HStack below is the single
        // source of truth for the NOW row's left-edge signal stripe.
        HStack(alignment: .top, spacing: 10) {
            Text(weekRange)
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(width: 38, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(BlockPhaseColors.phaseLabel(phase.kind).capitalized)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    if isDone {
                        BRUChip("DONE")
                    } else if isNow {
                        BRUChip("NOW", color: .bruSignal, fill: true)
                    } else if isDeload {
                        BRUChip("DELOAD", color: .bruSignal)
                    }
                }

                Text(kindDescriptor)
                    .font(BRUFont.labelSmall)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)

                Text(summaryText)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isNow ? BlockPhaseColors.rowTint(for: .intensification) : Color.clear)
        .overlay(alignment: .leading) {
            if isNow {
                Rectangle()
                    .fill(Color.bruSignal)
                    .frame(width: 4)
            }
        }
    }

    // MARK: - Fatigue Advisory Strip

    @ViewBuilder
    private var fatigueAdvisoryStrip: some View {
        if shouldShowFatigueAdvisory {
            ConsiderDeloadBanner()
        }
    }

    // MARK: - Archive Content (completed blocks)

    @ViewBuilder
    private var archiveContentSection: some View {
        if let jsonString = block.archivedConfigJSON {
            // Non-nil JSON: attempt decode; undecodable → ArchiveUnreadableView (terminal)
            let decodeResult = Result { try BlockLifecycleService.decodeArchive(jsonString) }
            switch decodeResult {
            case .failure:
                ArchiveUnreadableView()
            case .success(let config):
                archivedConfigView(config: config)
            }
        } else {
            // nil archivedConfigJSON → quiet "NO ARCHIVE AVAILABLE" state (not corrupt)
            // Distinct from ArchiveUnreadableView: this is "archive missing", not "archive corrupt"
            VStack(spacing: 12) {
                Text("NO ARCHIVE AVAILABLE")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text("This block was completed before archive support was added.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func archivedConfigView(config: ArchivedBlockConfig) -> some View {
        VStack(spacing: 0) {
            // Archived phase progression from snapshot — HISTORY label, not live WHAT'S NEXT
            BRUSectionHead("Phase progression", right: "HISTORY")
            VStack(spacing: 0) {
                ForEach(Array(config.phases.enumerated()), id: \.offset) { index, phase in
                    archivedPhaseRow(phase: phase, index: index, allPhases: config.phases)
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(height: 1)
                }
            }

            // Archived split slots from snapshot — never from live block.split
            if !config.split.slots.isEmpty {
                BRUSectionHead("Sessions", right: "HISTORY")
                VStack(spacing: 0) {
                    ForEach(Array(config.split.slots.enumerated()), id: \.element.position) { _, slot in
                        HStack(spacing: 12) {
                            Text("\(slot.position + 1)")
                                .font(BRUFont.labelSmall)
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(Color.bruMuted)
                                .frame(width: 32, alignment: .leading)
                            Text(slot.sessionName)
                                .font(BRUFont.bodyEmphasis)
                                .foregroundStyle(Color.bruInk)
                            Spacer()
                            Text("Completed")
                                .font(BRUFont.bodyDefault)
                                .foregroundStyle(Color.bruMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle()
                            .fill(Color.bruHair)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func archivedPhaseRow(phase: ArchivedPhaseDTO, index: Int, allPhases: [ArchivedPhaseDTO]) -> some View {
        let priorWeeks = allPhases.prefix(index).reduce(0) { $0 + $1.weeks }
        let startWeek = priorWeeks + 1
        let endWeek = priorWeeks + phase.weeks
        let weekRange = startWeek == endWeek ? "W\(startWeek)" : "W\(startWeek)–W\(endWeek)"

        HStack(alignment: .top, spacing: 10) {
            Text(weekRange)
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(width: 38, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(phase.kind.capitalized)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    BRUChip("DONE")
                }
                Text("Completed")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        switch block.derivedStatus {
        case .ready:
            startBlockButton
        case .active:
            VStack(spacing: 0) {
                editBlockButton
                endBlockButton
            }
        case .draft, .completed:
            EmptyView()
        }
    }

    // MARK: - Start Block Button

    private var startBlockButton: some View {
        BRUButton("START BLOCK ▸", kind: .signal) {
            onStartTapped()
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    private func onStartTapped() {
        // Fetch any other active block
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.isActive == true })
        let activeBlocks = (try? ctx.fetch(descriptor)) ?? []
        let myID = block.id
        let otherActive = activeBlocks.first { $0.id != myID }
        if otherActive != nil {
            presentingSwapConfirm = true
        } else {
            try? BlockLifecycleService.start(block: block, context: ctx)
        }
    }

    // MARK: - Edit Block Button

    private var editBlockButton: some View {
        BRUButton("EDIT BLOCK ▸", kind: .primary) {
            onEdit()
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - End Block Button

    private var endBlockButton: some View {
        BRUButton("END BLOCK", kind: .ghost) {
            presentingEndConfirm = true
        }
    }

    // MARK: - Swap Confirm Sheet

    @ViewBuilder
    private var swapConfirmSheet: some View {
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.isActive == true })
        let activeBlocks = (try? ctx.fetch(descriptor)) ?? []
        let myID = block.id
        let currentActiveBlock = activeBlocks.first { $0.id != myID }

        SwapConfirmSheet(
            currentActiveBlockName: currentActiveBlock?.name ?? "current block",
            onConfirm: {
                try? BlockLifecycleService.start(block: block, context: ctx)
                presentingSwapConfirm = false
            },
            onCancel: {
                presentingSwapConfirm = false
            }
        )
    }

    // MARK: - Safe-Area Filler

    private var safeAreaFiller: some View {
        Rectangle()
            .fill(Color.bruBg)
            .frame(height: 24)
    }
}

// MARK: - ModeChip (fileprivate)

fileprivate struct ModeChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    init(_ label: String, selected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(selected ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.bruInk : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: selected ? 1.5 : 1.0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) scheduling")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - DayToggleChip (fileprivate)

fileprivate struct DayToggleChip: View {
    let letter: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(letter)
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(selected ? Color.bruPaper : Color.bruMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? Color.bruInk : Color.bruFaint)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: selected ? 1.5 : 1.0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(selected ? "on" : "off")
    }
}

// MARK: - SwapConfirmSheet (fileprivate)

fileprivate struct SwapConfirmSheet: View {
    let currentActiveBlockName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Start Block?")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Ends **\(currentActiveBlockName)** — its config freezes to history.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            BRUButton("Confirm", kind: .signal) {
                onConfirm()
            }

            BRUButton("Cancel", kind: .ghost) {
                onCancel()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.bruPaper)
        .presentationDetents([.fraction(0.4)])
    }
}

// MARK: - SplitPickerSheet (fileprivate)

fileprivate struct SplitPickerSheet: View {
    let block: Block

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<Split> { !$0.isArchived },
        sort: [SortDescriptor(\Split.name)]
    ) private var splits: [Split]

    var body: some View {
        NavigationStack {
            List(splits) { split in
                Button {
                    attachOrSwap(split: split)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(split.name)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Text("\(split.slots?.count ?? 0) sessions")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose Routine")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func attachOrSwap(split: Split) {
        // Explicit nil-conditional branch per plan: attach vs swap
        if block.split == nil {
            try? BlockLifecycleService.attachSplit(split, to: block, context: ctx)
        } else {
            try? BlockLifecycleService.swapSplit(split, on: block, context: ctx)
        }
    }
}

// MARK: - ArchiveUnreadableView (fileprivate)

fileprivate struct ArchiveUnreadableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("ARCHIVE UNREADABLE")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruSignal)
                .textCase(.uppercase)
                .tracking(1.2)
            Text("This block's historical config could not be loaded. The raw data is intact but cannot be decoded.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Archive unreadable. This block's historical config could not be loaded.")
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BlockOverviewScreen") {
    // CR-05: V7 schema — BlockOverviewScreen accesses Split / SplitSessionSlot /
    // SessionTemplate relationships at runtime, which SchemaV5 has no tables for.
    let schema = Schema(SchemaV7.models)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: schema,
        migrationPlan: FitbodSchemaMigrationPlan.self,
        configurations: config
    )
    let ctx = ModelContext(container)

    // Seed a deterministic block for preview
    let block = Block()
    block.name = "Upper Hyp"
    block.startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date.now) ?? Date.now
    block.endDate = Calendar.current.date(byAdding: .day, value: 21, to: block.startDate) ?? Date.now
    block.isActive = true
    ctx.insert(block)

    let accum = BlockPhase()
    accum.block = block
    accum.orderIndex = 0
    accum.nameRaw = BlockPhaseKind.accumulation.rawValue
    accum.weeks = 2
    accum.volumeMultiplier = 1.0
    accum.intensityMultiplier = 0.75
    ctx.insert(accum)

    let intens = BlockPhase()
    intens.block = block
    intens.orderIndex = 1
    intens.nameRaw = BlockPhaseKind.intensification.rawValue
    intens.weeks = 1
    intens.volumeMultiplier = 1.0
    intens.intensityMultiplier = 0.85
    ctx.insert(intens)

    let deload = BlockPhase()
    deload.block = block
    deload.orderIndex = 2
    deload.nameRaw = BlockPhaseKind.deload.rawValue
    deload.weeks = 1
    deload.volumeMultiplier = 0.5
    deload.intensityMultiplier = 0.65
    ctx.insert(deload)

    block.phases = [accum, intens, deload]

    // Seed a session in the current week so the carousel shows a done cell
    let session = Session()
    session.startedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date.now) ?? Date.now
    session.block = block
    session.routineSnapshotName = "Push A"
    ctx.insert(session)

    try? ctx.save()

    return BlockOverviewScreen(block: block, onEdit: {})
        .modelContainer(container)
}
#endif
