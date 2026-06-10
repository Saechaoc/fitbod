//
//  BlockOverviewScreen.swift
//  fitbod
//
//  Net-new read-only block summary screen (CONTEXT D-10).
//  Phase 04.1 Wave 6 — BRU composition per 04.1-PATTERNS.md File #13
//
//  Composition (top to bottom):
//    BRUHeaderBar (left: .back, center: "Block · <name>", right: .action("EDIT"))
//    ScrollView { heroBand; weekCarousel; phaseProgressionList; fatigueAdvisoryStrip }
//    editBlockButton
//    safeAreaFiller
//
//  Read-only per CONTEXT D-12. All mutations route through BlockBuilderView.
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
            BRUHeaderBar.slots(
                left: .back,
                center: "Block · \(block.name)",
                right: .action("EDIT", onEdit)
            )

            ScrollView {
                VStack(spacing: 0) {
                    heroBand
                    weekCarousel
                    phaseProgressionList
                    fatigueAdvisoryStrip
                }
            }

            editBlockButton
            safeAreaFiller
        }
        .background(Color.bruBg.ignoresSafeArea())
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
            && (session.block?.id == block.id
                || (block.routines ?? []).contains { $0.id == session.sourceRoutineID })
        }
        if sessionLinked {
            return .done
        }
        if cellDate > todayDate {
            // Heuristic: mark upcoming if there are routines in the block
            let routineCount = (block.routines ?? []).count
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
            && (session.block?.id == block.id
                || (block.routines ?? []).contains { $0.id == session.sourceRoutineID })
        }.map { $0.routineSnapshotName.isEmpty ? nil : $0.routineSnapshotName } ?? nil
    }

    private func hasPR(cellDate: Date) -> Bool {
        // PR detection is Phase 6 scope; always false for v1
        false
    }

    // MARK: - Hero Band

    @ViewBuilder
    private var heroBand: some View {
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
            let scheduledCount = (block.routines ?? []).count

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
                    (block.routines ?? []).contains { $0.id == s.sourceRoutineID } || s.block?.id == block.id
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

    // MARK: - Safe-Area Filler

    private var safeAreaFiller: some View {
        Rectangle()
            .fill(Color.bruBg)
            .frame(height: 24)
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
    let schema = Schema(SchemaV5.models)
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
