//
//  WeeklyRecapSheet.swift
//  fitbod
//
//  Phase 5.1 Plan 07 — BRU reskin of the VOL-07 weekly recap sheet.
//  Structure: BRUHeaderBar + cover ink slab + 2×2 metric grid +
//  Sessions section + Muscles Hit section + Records broken section +
//  Under-Trained section + Progress section + quote section + footer
//  Start button.
//
//  Two presentations (RM-020). Today shows the recap on its own once a week
//  (O-4), as a sheet with its own stack: ALL RECAPS pushes the week list
//  inside it, DONE and START W{N} close it. A row of the week list reopens a
//  past week's recap, pushed with ‹ BACK and no Start button.
//
//  The recap reads its week off the main actor once when it opens, and
//  again after a History correction, never per render. Its cover and metric
//  grid come from `WeeklyRecaps.recap`, the numbers its row in the week
//  list shows.
//
//  Copywriting Contract verbatim strings preserved per UI-SPEC §WeeklyRecapSheet.
//
//  Banned tokens: zero Color.accentColor, zero Color(.system*),
//  zero Color("Volume*"), zero RoundedRectangle, zero Capsule(),
//  zero Image(systemName:), zero .navigationTitle(, zero .font(.body|.headline|etc).
//

import SwiftData
import SwiftUI

// MARK: - WeeklyRecapTrigger

/// Pure-function trigger guard per RESEARCH §12.1 + Pitfalls #7 / #8.
/// Caller injects all dependencies — testable without a UI fixture.
public enum WeeklyRecapTrigger {

    public struct Decision: Sendable, Equatable {
        public let shouldPresent: Bool
        public let shouldMarkSeen: Bool

        public init(shouldPresent: Bool, shouldMarkSeen: Bool) {
            self.shouldPresent = shouldPresent
            self.shouldMarkSeen = shouldMarkSeen
        }
    }

    /// Decide whether to present the recap sheet (and whether to mark
    /// the current week's seen-flag regardless of presentation).
    public static func evaluate(
        thisMonday: Date,
        lastShown: Date?,
        hasSessionsLastWeek: Bool,
        calendar: Calendar = .current
    ) -> Decision {
        if let lastShown = lastShown,
           calendar.isDate(lastShown, equalTo: thisMonday, toGranularity: .day) {
            return Decision(shouldPresent: false, shouldMarkSeen: false)
        }
        if !hasSessionsLastWeek {
            return Decision(shouldPresent: false, shouldMarkSeen: true)
        }
        return Decision(shouldPresent: true, shouldMarkSeen: true)
    }
}

// MARK: - WeeklyRecapSheet

public struct WeeklyRecapSheet: View {

    // MARK: - Static label constants (tested by WeeklyRecapSheetBRUTests)

    /// Metric cell label constants — locked by 2×2 grid contract.
    public enum MetricCell {
        public static let tonnageLabel: String     = "TONNAGE"
        public static let workingSetsLabel: String = "WORKING SETS"
        public static let avgRPELabel: String      = "AVG RPE"
        public static let musclesHitLabel: String  = "MUSCLES HIT"
    }

    /// Section header strings — §Copywriting Contract verbatim.
    public enum SectionLabels {
        public static let sessions: String      = "Sessions"
        public static let musclesHit: String    = "Muscles Hit"
        public static let underTrained: String  = "Under-Trained"
        public static let progress: String      = "Progress"
        public static let recordsBroken: String = "Records broken"
    }

    /// Empty-state and footnote strings — §Copywriting Contract verbatim.
    public enum EmptyStateCopy {
        public static let musclesHit: String    = "No muscles met the frequency threshold last week."
        public static let underTrained: String  = "All trained muscles reached MEV last week."
        public static let progress: String      = "Not enough data to compute e1RM movement."
        public static let progressFootnote: String = "Top 5 exercises by working-set count last week. e1RM vs same exercise week prior."
    }

    /// BRU palette-mapped delta color function (replaces systemGreen/systemRed/.secondary).
    /// Positive → bruGreen, Negative → bruSignal, Zero (|δ| < 0.1) → bruMuted.
    public nonisolated static func deltaColor(for delta: Double) -> Color {
        if delta > 0.1 {
            return .bruGreen
        } else if delta < -0.1 {
            return .bruSignal
        } else {
            return .bruMuted
        }
    }

    // MARK: - Properties

    /// The START of the new week — the Monday on which this sheet presents.
    /// Content shows the PRIOR week.
    public let weekStart: Date

    /// Reopened from the week list, pushed on its stack, rather than shown
    /// on its own by Today.
    private let isReopened: Bool

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weightUnit) private var weightUnit
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?
    @Query private var settingsList: [UserSettings]

    /// What the recap shows, read when it opens and after a History
    /// correction, and what it was read for.
    @State private var content: Content?
    @State private var contentKey: ContentKey?
    /// The week list and the recaps it reopens, pushed inside Today's sheet.
    @State private var path = NavigationPath()

    /// The recap Today shows on its own: of the week before the one that
    /// starts at `weekStart`.
    public init(weekStart: Date) {
        self.weekStart = weekStart
        self.isReopened = false
    }

    /// A past week's recap, reopened from the week list: of the week that
    /// starts at `coveredWeekStart`.
    init(reopening coveredWeekStart: Date) {
        self.weekStart = FatigueModel.date(byAddingWeeks: 1, to: coveredWeekStart)
        self.isReopened = true
    }

    // MARK: - Computed helpers

    /// The start of last week, the week the recap covers.
    private var priorWeekStart: Date {
        Self.priorWeekStart(before: weekStart)
    }

    /// Units label ("lb" or "kg").
    private var unitLabel: String { weightUnit.rawValue }

    /// What the recap's content depends on besides its week.
    private struct ContentKey: Equatable {
        let edits: Int
        let unit: WeightUnit
        let minSets: Int
    }

    private var readKey: ContentKey {
        ContentKey(
            edits: historyEdits?.version ?? 0,
            unit: weightUnit,
            minSets: settingsList.first?.frequencyHitMinSets ?? 2
        )
    }

    // MARK: - Body

    public var body: some View {
        if isReopened {
            recap
        } else {
            NavigationStack(path: $path) {
                recap
                    .weeklyRecapDestinations()
            }
            .presentationDetents([.large])
        }
    }

    private var recap: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if let content {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        coverSlab(content.recap)
                        metricGrid(content)
                        sessionsSection(content)
                        musclesHitSection(content.musclesHit)
                        recordsBrokenSection(content.records)
                        underTrainedSection(content.underTrained)
                        progressSection(content.progress)
                        sessionNoteSection(content.note)
                    }
                }
            }
            if !isReopened {
                footerButtonStrip
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: readKey) {
            let key = readKey
            // Not again when the week list pushed over it pops back.
            guard contentKey != key else { return }
            let read = await WeeklyRecaps.content(
                weekStart: weekStart, minSets: key.minSets, unit: key.unit, in: ctx.container
            )
            guard !Task.isCancelled else { return }
            content = read
            contentKey = key
        }
    }

    // MARK: - Header

    /// Non-breaking spaces keep the title on one line: the header fits a
    /// title with no breaking space to its third of the row, where "Week 44
    /// · recap" wrapped before its dot on the small phone. The title names
    /// the week the recap covers (D-176).
    private var header: some View {
        let title = "Week\u{00A0}\(Self.weekNumber(ofWeekStarting: priorWeekStart))\u{00A0}·\u{00A0}recap"
        return Group {
            if isReopened {
                BRUHeaderBar(left: HeaderAction("‹ Back") { dismiss() }, center: title)
            } else {
                BRUHeaderBar(
                    left: HeaderAction("All recaps") { path.append(WeeklyRecapRoute.list) },
                    center: title,
                    right: HeaderAction("Done") { dismiss() }
                )
            }
        }
    }

    // MARK: - Cover slab

    private func coverSlab(_ recap: WeekRecap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.dateRangeCaption(weekStart: weekStart))
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper.opacity(0.6))

            Text(recap.headline)
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(Color.bruPaper)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("recap.headline")

            chipLayout {
                // A signal fill, as on every PR chip, so the label reads on it.
                BRUChip(Self.prChipLabel(records: recap.records), color: .bruSignal, fill: true, textCase: nil)
                    .accessibilityIdentifier("recap.prs")
                BRUChip(Self.sessionsChipLabel(sessions: recap.sessions, target: recap.target),
                        color: .bruPaper, fill: false, textCase: nil)
                    .accessibilityIdentifier("recap.sessions")
                BRUChip("\(Self.tonnageText(recap.tonnage)) \(unitLabel)",
                        color: .bruPaper, fill: false, textCase: nil)
                    .accessibilityIdentifier("recap.tonnage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.bruInk)
    }

    /// The cover's chips in a row, or stacked at accessibility sizes, where
    /// a row of three on the small phone broke "session" inside the word.
    private var chipLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    // MARK: - Cover rules

    /// The start of the week before the one that starts at `weekStart`:
    /// local midnight 7 calendar days earlier, a daylight-saving change
    /// included (F333). The recap's reads of last week, and of the week
    /// before it, take their bounds from here.
    nonisolated static func priorWeekStart(before weekStart: Date, calendar: Calendar = .current) -> Date {
        FatigueModel.date(byAddingWeeks: -1, to: weekStart, calendar: calendar)
    }

    /// The ISO week number of the week that starts at `weekStart`, read on
    /// its last day, so a week that starts on Sunday takes the number of
    /// the six days after it. The recap's title names the week it covers,
    /// its Start button the week after, and the week list each row's week.
    static func weekNumber(ofWeekStarting weekStart: Date, calendar: Calendar = .current) -> Int {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let lastMoment = FatigueModel.date(byAddingWeeks: 1, to: weekStart, calendar: calendar).addingTimeInterval(-1)
        return iso.component(.weekOfYear, from: lastMoment)
    }

    /// The cover's date range, "MAR 2 → MAR 8": the first and last days of
    /// the week before the one that starts at `weekStart`, in the
    /// calendar's time zone and locale.
    static func dateRangeCaption(weekStart: Date, calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.locale = calendar.locale
        df.timeZone = calendar.timeZone
        let endDate = weekStart.addingTimeInterval(-1)  // day before the new Monday
        let start = df.string(from: priorWeekStart(before: weekStart, calendar: calendar)).uppercased()
        let end   = df.string(from: endDate).uppercased()
        return "\(start) → \(end)"
    }

    /// The sessions last week's plan called for: the days of the week
    /// before `weekStart` that a block running that day trains on under
    /// fixed weekly scheduling. A block runs from its start until it ends,
    /// so one that starts or ends during the week plans only its own days,
    /// and a day two blocks share counts once. Rotation plans no weekdays,
    /// so a week without a block, on rotation alone, or with no planned
    /// day has no target.
    nonisolated static func sessionsTarget(weekStart: Date, in context: ModelContext, calendar: Calendar = .current) -> Int? {
        sessionsTarget(
            weekStart: weekStart,
            blocks: (try? context.fetch(FetchDescriptor<Block>())) ?? [],
            calendar: calendar
        )
    }

    /// `sessionsTarget` from blocks already read, for the week list's many weeks.
    nonisolated static func sessionsTarget(weekStart: Date, blocks: [Block], calendar: Calendar = .current) -> Int? {
        let fixedWeekly = blocks.filter {
            $0.schedulingMode == .fixedWeekly && ($0.isActive || $0.endDate != nil)
        }
        let plannedDays = (1...7).compactMap { calendar.date(byAdding: .day, value: -$0, to: weekStart) }
            .filter { day in
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
                let weekday = calendar.component(.weekday, from: day)
                return fixedWeekly.contains { block in
                    block.startDate < nextDay
                        && (block.endDate.map { $0 > day } ?? true)
                        && block.trainingDays.contains(weekday)
                }
            }
        return plannedDays.isEmpty ? nil : plannedDays.count
    }

    /// The sessions chip: "N / M sessions" against a target, or
    /// "N sessions" with none.
    static func sessionsChipLabel(sessions: Int, target: Int?) -> String {
        guard let target else { return BRUCountLabel.text(sessions, "session") }
        return "\(sessions) / \(BRUCountLabel.text(target, "session"))"
    }

    /// The cover's headline. Against a target it weighs the sessions with
    /// it; with none it never claims a target was met, and follows the
    /// sessions and PRs alone.
    nonisolated static func coverHeadline(sessions: Int, target: Int?, prs: Int) -> String {
        guard let target else {
            if prs >= 3 { return "A strong\nweek." }
            return sessions < 2 ? "Light\nweek." : "Solid\nweek."
        }
        // The sessions decide against a target: a first week's first logs
        // set every record (RM-036), and one session of four is no strong week.
        if sessions >= target             { return "A strong\nweek." }
        if sessions >= max(target - 1, 2) { return "Solid\nweek." }
        if sessions < 2                   { return "Light\nweek." }
        return "New week\nahead."
    }

    /// The cover's PR chip: "★ 3 PRs", or "No PRs this wk".
    static func prChipLabel(records: Int) -> String {
        records == 0 ? "No PRs this wk" : "\u{2605} \(BRUCountLabel.text(records, "PR", plural: "PRs"))"
    }

    /// Tonnage as the cover and the week list print it: "24.1K" from a
    /// thousand, "940" below.
    static func tonnageText(_ total: Double) -> String {
        total >= 1_000 ? String(format: "%.1fK", total / 1_000) : String(format: "%.0f", total)
    }

    // MARK: - 2×2 Metric grid

    private struct MetricData {
        let label: String
        let value: String
        let sub: String
        let accent: Bool
    }

    private func metricGrid(_ content: Content) -> some View {
        let items = buildMetrics(content)
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 0),
                GridItem(.flexible(), spacing: 0)
            ],
            spacing: 0
        ) {
            ForEach(0..<4, id: \.self) { i in
                metricCell(
                    items[i],
                    isRightColumn: i % 2 == 1,
                    isBottomRow: i >= 2
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bruInk).frame(height: 2)
        }
    }

    private func buildMetrics(_ content: Content) -> [MetricData] {
        let recap = content.recap
        let tonnageDelta = content.priorTonnage > 0
            ? Int(((recap.tonnage - content.priorTonnage) / content.priorTonnage) * 100)
            : 0
        let tonnageDeltaStr = tonnageDelta > 0 ? "\u{2191} \(tonnageDelta)% VS PRIOR WK"
            : tonnageDelta < 0 ? "\u{2193} \(abs(tonnageDelta))% VS PRIOR WK"
            : "— VS PRIOR WK"
        let setsDelta = recap.workingSets - content.priorWorkingSets
        let setsDeltaStr = setsDelta > 0 ? "\u{2191} \(setsDelta) VS PRIOR WK"
            : setsDelta < 0 ? "\u{2193} \(abs(setsDelta)) VS PRIOR WK"
            : "— VS PRIOR WK"
        let avgRPEStr = recap.averageRPE.map { String(format: "%.1f", $0) } ?? "—"

        return [
            MetricData(label: MetricCell.tonnageLabel,
                       value: Self.tonnageText(recap.tonnage),
                       sub: tonnageDeltaStr,
                       accent: tonnageDelta > 0),
            MetricData(label: MetricCell.workingSetsLabel,
                       value: "\(recap.workingSets)",
                       sub: setsDeltaStr,
                       accent: false),
            MetricData(label: MetricCell.avgRPELabel,
                       value: avgRPEStr,
                       sub: "—",
                       accent: false),
            MetricData(label: MetricCell.musclesHitLabel,
                       value: "\(content.musclesHit.count) / \(content.muscles)",
                       sub: recap.underMEV > 0 ? "\(recap.underMEV) UNDER MEV" : "ALL ABOVE MEV",
                       accent: false)
        ]
    }

    private func metricCell(_ m: MetricData, isRightColumn: Bool, isBottomRow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(m.label)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            Text(m.value)
                .font(.system(size: 38, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(m.accent ? Color.bruSignal : Color.bruInk)
            Text(m.sub)
                .font(BRUFont.labelMicro)
                .tracking(0.5)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .trailing) {
            if !isRightColumn {
                Rectangle().fill(Color.bruInk).frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !isBottomRow {
                Rectangle().fill(Color.bruInk).frame(height: 1)
            }
        }
    }

    // MARK: - Sessions section

    @ViewBuilder
    private func sessionsSection(_ content: Content) -> some View {
        let count = content.recap.sessions
        let routineCount = content.routines
        let sessionWord = count == 1 ? "session" : "sessions"
        let routineWord = routineCount == 1 ? "routine" : "routines"

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.sessions)
            VStack(alignment: .leading, spacing: 6) {
                Text("Last week you logged \(count) \(sessionWord).")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                if routineCount > 1 {
                    Text("Across \(routineCount) \(routineWord).")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Muscles Hit section

    @ViewBuilder
    private func musclesHitSection(_ hits: [MuscleRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.musclesHit)
            if hits.isEmpty {
                Text(EmptyStateCopy.musclesHit)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(hits.enumerated()), id: \.element.slug) { idx, row in
                    HStack {
                        Text(row.displayName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text("\(row.count) \(row.count == 1 ? "session" : "sessions")")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < hits.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
        }
    }

    // MARK: - Records broken section (BRU addition)

    @ViewBuilder
    private func recordsBrokenSection(_ records: [RecordRow]) -> some View {
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                BRUSectionHead(SectionLabels.recordsBroken, right: "\(records.count)")
                VStack(spacing: 0) {
                    // One exercise can hold several records, so rows go by place.
                    ForEach(Array(records.enumerated()), id: \.offset) { idx, record in
                        HStack(spacing: 12) {
                            Text("\u{2605}")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.bruSignal)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(BRUFont.bodyEmphasis)
                                    .foregroundStyle(Color.bruInk)
                                Text(record.kindLabel)
                                    .font(BRUFont.labelMicro)
                                    .tracking(1.0)
                                    .foregroundStyle(Color.bruMuted)
                            }
                            Spacer()
                            Text(record.value)
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.bruInk)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                        if idx < records.count - 1 {
                            BRUDivider(.hair)
                        }
                    }
                }
                BRUDivider(.ink)
            }
        }
    }

    // MARK: - Under-Trained section

    @ViewBuilder
    private func underTrainedSection(_ underTrained: [UnderTrainedRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.underTrained)
            if underTrained.isEmpty {
                Text(EmptyStateCopy.underTrained)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(underTrained.enumerated()), id: \.element.slug) { idx, row in
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.bruAmber)
                            .frame(width: 6, height: 6)
                        Text(row.displayName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text("below MEV — \(row.totalSets) / \(BRUCountLabel.text(row.mev, "set"))")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < underTrained.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
        }
    }

    // MARK: - Progress section

    @ViewBuilder
    private func progressSection(_ progress: [ProgressRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(SectionLabels.progress)
            if progress.isEmpty {
                Text(EmptyStateCopy.progress)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(progress.enumerated()), id: \.element.exerciseID) { idx, row in
                    HStack {
                        Text(row.exerciseName)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text(row.deltaCopy)
                            .font(BRUFont.labelMicro)
                            .tracking(0)
                            .monospacedDigit()
                            .foregroundStyle(row.deltaColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < progress.count - 1 {
                        BRUDivider(.hair)
                    }
                }
            }
            // Footnote verbatim
            Text(EmptyStateCopy.progressFootnote)
                .font(BRUFont.labelMicro)
                .tracking(0.5)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Session note section (BRU addition)

    @ViewBuilder
    private func sessionNoteSection(_ note: SessionNoteData?) -> some View {
        if let note {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{201C}\(note.text)\u{201D}")
                        .font(BRUFont.bodyDefault)
                        .italic()
                        .foregroundStyle(Color.bruMuted)
                    Text("— SESSION NOTE · \(note.dateLabel)")
                        .font(BRUFont.labelMicro)
                        .tracking(1.0)
                        .foregroundStyle(Color.bruMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Footer button strip

    /// Only on the recap Today shows; it names the week just starting.
    private var footerButtonStrip: some View {
        BRUButton("Start W\(Self.weekNumber(ofWeekStarting: weekStart)) \u{25B8}", kind: .primary) {
            dismiss()
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bruInk).frame(height: 2)
        }
    }

    // MARK: - Reading the week

    /// Everything the recap shows for its week, read in one go.
    struct Content: Sendable {
        /// The cover's and the grid's numbers, as the week list shows them.
        let recap: WeekRecap
        let priorTonnage: Double
        let priorWorkingSets: Int
        /// The routines of the week's workouts that count as sessions.
        let routines: Int
        /// How many muscles there are, which Muscles Hit counts against.
        let muscles: Int
        let musclesHit: [MuscleRow]
        let records: [RecordRow]
        let underTrained: [UnderTrainedRow]
        let progress: [ProgressRow]
        let note: SessionNoteData?
    }

    /// The recap of the week before the one that starts at `weekStart`. Its
    /// workouts, its working sets and the week before's are each read once.
    /// The records replay the finished workouts started before the week's
    /// end, as History's do, so a record counts only when it beats every set
    /// before it; later workouts cannot change the week's records.
    nonisolated static func content(
        weekStart: Date,
        muscles: [MuscleGroup],
        targets: [MuscleVolumeTarget],
        minSets: Int,
        unit: WeightUnit,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Content {
        let start = priorWeekStart(before: weekStart, calendar: calendar)
        let end = weekStart
        let sessions = (try? context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.startedAt >= start && $0.startedAt < end }
        ))) ?? []
        let sets = FatigueModel.completedWorkingSets(startedFrom: start, before: end, in: context)
        let priorSets = FatigueModel.completedWorkingSets(
            startedFrom: priorWeekStart(before: start, calendar: calendar), before: start, in: context
        )
        let finished = (try? context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.completedAt != nil && $0.startedAt < end }
        ))) ?? []
        let weekIDs = Set(sessions.map(\.id))
        let records = SessionSummary.records(replaying: finished).filter { weekIDs.contains($0.sessionID) }
        let mev = WeeklyRecaps.mev(muscles: muscles, targets: targets)
        let recap = WeeklyRecaps.recap(
            weekStart: start,
            sessions: sessions,
            sets: sets,
            target: sessionsTarget(weekStart: weekStart, in: context, calendar: calendar),
            mev: mev,
            records: records.count
        )
        let counted = Array(SessionSetActions.countedWorkouts(sessions))

        return Content(
            recap: recap,
            priorTonnage: priorSets.reduce(0.0) { $0 + $1.tonnage },
            priorWorkingSets: FatigueModel.workingSetCount(of: priorSets),
            routines: Set(counted.map(\.routineSnapshotName)).count,
            muscles: muscles.count,
            musclesHit: musclesHit(weekStart: weekStart, muscles: muscles, minSets: minSets, in: context, calendar: calendar),
            records: records.map { RecordRow($0, unit: unit) },
            underTrained: muscles.compactMap { muscle in
                guard let sets = recap.underTrained[muscle.slug], let minimum = mev[muscle.slug] else { return nil }
                return UnderTrainedRow(slug: muscle.slug, displayName: muscle.displayName, totalSets: sets, mev: minimum)
            },
            progress: topExercisesProgress(lastWeek: sets, priorWeek: priorSets, unit: unit),
            note: latestNote(of: sessions)
        )
    }

    /// Last week's Muscles Hit rows: each of `muscles` that a session
    /// last week gave `minSets` or more weighted sets, most sessions
    /// first. `muscles` comes from a query in no set order, so muscles
    /// with the same count go by name, then by slug, and keep one order
    /// between launches (F334).
    nonisolated static func musclesHit(
        weekStart: Date,
        muscles: [MuscleGroup],
        minSets: Int,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [MuscleRow] {
        // One read of the week for every muscle; each count equals
        // `FatigueModel.frequencyHits` for that muscle.
        let contributions = FatigueModel.contributionsPerSession(
            weekStart: priorWeekStart(before: weekStart, calendar: calendar),
            in: context,
            calendar: calendar
        )
        let minContribution = Double(minSets)
        return muscles.compactMap { muscle in
            let count = (contributions[muscle.slug] ?? [:]).values.filter { $0 >= minContribution }.count
            guard count > 0 else { return nil }
            return MuscleRow(slug: muscle.slug, displayName: muscle.displayName, count: count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            switch lhs.displayName.localizedStandardCompare(rhs.displayName) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.slug < rhs.slug
            }
        }
    }

    /// The five exercises with the most working sets last week, each with
    /// its best e1RM against the week before's. Exercises with as many sets
    /// go by name, so a reopened recap keeps its order.
    private nonisolated static func topExercisesProgress(
        lastWeek: [SetEntry],
        priorWeek: [SetEntry],
        unit: WeightUnit
    ) -> [ProgressRow] {
        var setCountByExercise: [UUID: (exercise: Exercise, count: Int)] = [:]
        for entry in lastWeek {
            guard let exercise = entry.sessionExercise?.exercise else { continue }
            var existing = setCountByExercise[exercise.id] ?? (exercise: exercise, count: 0)
            existing.count += 1
            setCountByExercise[exercise.id] = existing
        }
        let top5 = setCountByExercise.values.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.exercise.name != rhs.exercise.name { return lhs.exercise.name < rhs.exercise.name }
            return lhs.exercise.id.uuidString < rhs.exercise.id.uuidString
        }
        .prefix(5)

        return top5.map { entry in
            guard let lw = topSetE1RM(in: lastWeek, exerciseID: entry.exercise.id),
                  let pw = topSetE1RM(in: priorWeek, exerciseID: entry.exercise.id) else {
                return ProgressRow(
                    exerciseID: entry.exercise.id,
                    exerciseName: entry.exercise.name,
                    deltaCopy: "—",
                    deltaColor: .bruMuted
                )
            }
            let delta = lw - pw
            let sign  = delta >= 0 ? "+" : ""
            // The exercise's own unit wins over the lifter's (units relabel, never convert).
            let unit = WeightUnit.effective(for: entry.exercise, default: unit).rawValue
            return ProgressRow(
                exerciseID: entry.exercise.id,
                exerciseName: entry.exercise.name,
                deltaCopy: "\(sign)\(String(format: "%.1f", delta)) \(unit) e1RM",
                deltaColor: deltaColor(for: delta)
            )
        }
    }

    private nonisolated static func topSetE1RM(in entries: [SetEntry], exerciseID: UUID) -> Double? {
        var best: Double?
        for entry in entries where entry.sessionExercise?.exercise?.id == exerciseID {
            if let e = OneRepMaxEstimator.estimate(weight: entry.weight, reps: entry.reps) {
                if best.map({ e > $0 }) ?? true { best = e }
            }
        }
        return best
    }

    /// The note of the latest finished workout of the week that has one.
    private nonisolated static func latestNote(of sessions: [Session]) -> SessionNoteData? {
        let finished = sessions.filter { $0.completedAt != nil }.sorted { $0.startedAt > $1.startedAt }
        for session in finished {
            let note = session.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !note.isEmpty else { continue }
            let df = DateFormatter()
            df.dateFormat = "EEE MMM d"
            df.timeZone = TimeZone.current
            return SessionNoteData(text: note, dateLabel: df.string(from: session.startedAt).uppercased())
        }
        return nil
    }

    // MARK: - Row types

    /// One Muscles Hit row. Internal so WeekWindowCalendarTests can read
    /// the rows `musclesHit` orders.
    struct MuscleRow: Sendable {
        let slug: String
        let displayName: String
        let count: Int
    }

    struct UnderTrainedRow: Sendable {
        let slug: String
        let displayName: String
        let totalSets: Int
        let mev: Int
    }

    struct ProgressRow: Sendable {
        let exerciseID: UUID
        let exerciseName: String
        let deltaCopy: String
        let deltaColor: Color
    }

    /// One record broken: the exercise, the kind, as the in-workout banner
    /// names it, and the record, in the exercise's own unit.
    struct RecordRow: Sendable {
        let exerciseName: String
        let kindLabel: String
        let value: String

        init(_ record: SessionRecord, unit: WeightUnit) {
            let set = record.set
            let unit = WeightUnit.effective(for: set.sessionExercise?.exercise, default: unit).rawValue
            let weight = NumberText.weight(set.weight)
            exerciseName = PRBucketRanking.exerciseName(set)
            switch record.kind {
            case .weight:
                kindLabel = "Weight PR"
                value = "\(weight) \(unit)"
            case .reps:
                kindLabel = "Rep PR"
                value = "\(set.reps) @ \(weight) \(unit)"
            case .volume:
                kindLabel = "Volume PR"
                value = "\(Int((set.weight * Double(set.reps)).rounded()).formatted()) \(unit)"
            case .e1RM:
                kindLabel = "e1RM PR"
                let e1RM = OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) ?? 0
                value = "\(Int(e1RM.rounded()).formatted()) \(unit)"
            }
        }
    }

    struct SessionNoteData: Sendable {
        let text: String
        let dateLabel: String
    }
}
