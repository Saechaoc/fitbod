//
//  WeeklyRecapsView.swift
//  fitbod
//
//  RM-020: the approved past recaps mock-up (docs/design-map/mockups/
//  all-recaps.html). Progress → Weekly recaps pushes it, and so does ALL
//  RECAPS on the recap Today shows, inside that sheet. A stat strip and the
//  last eight weeks' tonnage sit over every past week with a workout that
//  counts as a session, newest first. A row reopens that week's recap.
//
//  The weeks are read off the main actor in a `.task(id:)` keyed on the
//  workouts, History corrections and the week now under way, never per
//  render, and not again when a reopened recap pops back to the list.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftData
import SwiftUI

/// Routes to the past weekly recaps. Progress and the recap Today shows
/// register `.weeklyRecapDestinations()` on their stacks.
public enum WeeklyRecapRoute: Hashable, Sendable {
    /// Every past week's recap, newest first.
    case list
    /// One past week's recap, by the first day of the week it covers.
    case week(Date)
}

extension View {
    /// Registers the `WeeklyRecapRoute` destinations on the enclosing
    /// NavigationStack.
    func weeklyRecapDestinations() -> some View {
        navigationDestination(for: WeeklyRecapRoute.self) { route in
            switch route {
            case .list:
                WeeklyRecapsView()
            case .week(let weekStart):
                WeeklyRecapSheet(reopening: weekStart)
            }
        }
    }
}

struct WeeklyRecapsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.weightUnit) private var weightUnit
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?
    /// Every workout, in one order, so that a workout added, finished or
    /// deleted reads the weeks again.
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @Query private var settingsList: [UserSettings]

    /// Every past week's recap numbers, newest first; nil until first read.
    @State private var weeks: [WeekRecap]?
    /// What `weeks` was read on.
    @State private var weeksKey: WeeksKey?

    private struct WeeksKey: Equatable {
        let sessions: [PersistentIdentifier]
        let finished: [Date?]
        let edits: Int
        let weekStartsMonday: Bool
        let thisWeek: Date
    }

    var body: some View {
        let weekStartsMonday = settingsList.first?.weekStartsMonday ?? true
        let key = WeeksKey(
            sessions: sessions.map(\.persistentModelID),
            finished: sessions.map(\.completedAt),
            edits: historyEdits?.version ?? 0,
            weekStartsMonday: weekStartsMonday,
            thisWeek: Date.now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday)
        )
        VStack(spacing: 0) {
            BRUHeaderBar(left: HeaderAction("‹ Back") { dismiss() }, center: "Weekly recaps")
            ScrollView {
                if let weeks {
                    LazyVStack(spacing: 0) {
                        if weeks.isEmpty {
                            emptyState
                        } else {
                            list(weeks, thisWeek: key.thisWeek)
                        }
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: key) {
            guard weeksKey != key else { return }
            let read = await WeeklyRecaps.weeks(weekStartsMonday: weekStartsMonday, in: ctx.container)
            guard !Task.isCancelled else { return }
            weeks = read
            weeksKey = key
        }
    }

    // MARK: - List

    @ViewBuilder
    private func list(_ weeks: [WeekRecap], thisWeek: Date) -> some View {
        let recent = Self.lastEightWeeks(weeks, before: thisWeek)
        statStrip(weeks, recent: recent)
        BRUDivider(.ink)
        if recent.contains(where: { $0.tonnage > 0 }) {
            WeeklyTonnageSparkCard(
                values: recent.map(\.tonnage),
                deltaPct: Self.deltaPct(recent),
                accent: false
            )
        }
        BRUSectionHead("Past recaps", right: BRUCountLabel.text(weeks.count, "week"))
        ForEach(weeks) { week in
            NavigationLink(value: WeeklyRecapRoute.week(week.weekStart)) {
                WeeklyRecapRow(week: week, unit: weightUnit)
            }
            .buttonStyle(.bruRow)
            .accessibilityIdentifier("recaps.row")
            BRUDivider(.hair)
        }
    }

    /// How many recaps there are and since when, then the last eight weeks'
    /// tonnage, the one signal accent, and their records.
    private func statStrip(_ weeks: [WeekRecap], recent: [WeekRecap]) -> some View {
        let unitName = weightUnit == .kg ? "kilograms" : "pounds"
        return SessionHistoryStatStrip(cells: [
            BRUReadout(
                label: "Recaps",
                value: "\(weeks.count)",
                caption: Self.sinceLabel(weeks.last?.weekStart),
                accessibilityLabel: "Weekly recaps, \(Self.sinceLabel(weeks.last?.weekStart))"
            ),
            BRUReadout(
                label: "Tonnage · \(weightUnit.rawValue)",
                value: WeeklyRecapSheet.tonnageText(recent.reduce(0) { $0 + $1.tonnage }),
                valueColor: .bruSignal,
                caption: "8 weeks",
                accessibilityLabel: "Tonnage in the last 8 weeks, \(unitName)"
            ),
            BRUReadout(
                label: "Records",
                value: "\(recent.reduce(0) { $0 + $1.records })",
                caption: "8 weeks",
                accessibilityLabel: "Records in the last 8 weeks"
            ),
        ])
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No recaps yet")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            Text("A week with a logged workout gets its recap once the week is over.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rules

    /// The eight weeks before `thisWeek`, oldest first, as recaps: a week
    /// with no recap, because nothing counted, reads as an empty one.
    static func lastEightWeeks(
        _ weeks: [WeekRecap],
        before thisWeek: Date,
        calendar: Calendar = .current
    ) -> [WeekRecap] {
        let byStart = Dictionary(weeks.map { ($0.weekStart, $0) }, uniquingKeysWith: { first, _ in first })
        return (1...8).reversed().map { back in
            let start = FatigueModel.date(byAddingWeeks: -back, to: thisWeek, calendar: calendar)
            return byStart[start] ?? WeekRecap(
                weekStart: start, sessions: 0, target: nil, workingSets: 0, tonnage: 0,
                averageRPE: nil, underTrained: [:], records: 0
            )
        }
    }

    /// Last week's tonnage against the week before's, in percent; nil when
    /// the week before had none to compare with.
    static func deltaPct(_ recent: [WeekRecap]) -> Double? {
        guard recent.count >= 2 else { return nil }
        let prior = recent[recent.count - 2].tonnage
        guard prior > 0 else { return nil }
        return (recent[recent.count - 1].tonnage / prior - 1) * 100
    }

    /// "Since Sep 7" for a first recap this year, "Since 2024" for an
    /// earlier one, which keeps the caption on one line in its third.
    static func sinceLabel(_ first: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let first else { return "" }
        if calendar.isDate(first, equalTo: now, toGranularity: .year) {
            return "Since \(first.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "Since \(first.formatted(.dateTime.year()))"
    }
}

// MARK: - Row

/// One past week: its number and first day; its headline, workouts and
/// working sets, average RPE and muscles under MEV; its tonnage and records.
/// The numbers are the ones its recap shows. At accessibility sizes the
/// columns stack, as History's rows do.
struct WeeklyRecapRow: View {
    let week: WeekRecap
    let unit: WeightUnit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        partsLayout {
            VStack(alignment: .leading, spacing: BRUMetrics.Spacing.tight) {
                Text("W\(weekNumber)")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(width: stacks ? nil : 64, alignment: .leading)
            .frame(maxHeight: stacks ? nil : .infinity)
            .overlay(alignment: .trailing) {
                if !stacks {
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(width: 1)
                }
            }

            VStack(alignment: .leading, spacing: BRUMetrics.Spacing.tight) {
                Text(headline)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Text(workLine)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Text(effortLine)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .lineLimit(stacks ? nil : 1)
            // "4 / 4 SESSIONS · 62 SETS" beside "★ 19 PRS" is a little wider than the small phone gives it.
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: stacks ? .leading : .trailing, spacing: BRUMetrics.Spacing.related) {
                Text("\(WeeklyRecapSheet.tonnageText(week.tonnage)) \(unit.rawValue.uppercased())")
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if week.records > 0 {
                    BRUChip(WeeklyRecapSheet.prChipLabel(records: week.records), textCase: nil)
                } else {
                    Text("No PRs")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruMuted)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BRUMetrics.Spacing.gutter)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens the week's recap")
    }

    private var partsLayout: AnyLayout {
        stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BRUMetrics.Spacing.related))
            : AnyLayout(HStackLayout(alignment: .center, spacing: BRUMetrics.Spacing.group))
    }

    private var stacks: Bool { dynamicTypeSize.isAccessibilitySize }

    private var weekNumber: Int { WeeklyRecapSheet.weekNumber(ofWeekStarting: week.weekStart) }

    /// The recap's headline on one line: "A strong week.".
    private var headline: String { week.headline.replacingOccurrences(of: "\n", with: " ") }

    /// "4 / 4 sessions · 62 sets".
    private var workLine: String {
        "\(WeeklyRecapSheet.sessionsChipLabel(sessions: week.sessions, target: week.target)) · "
            + BRUCountLabel.text(week.workingSets, "set")
    }

    /// "RPE 8.2 · 2 under MEV", as the recap's grid reads them.
    private var effortLine: String {
        [
            week.averageRPE.map { "RPE " + String(format: "%.1f", $0) },
            week.underMEV > 0 ? "\(week.underMEV) under MEV" : "All above MEV",
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var accessibilityText: String {
        let unitName = unit == .kg ? "kilograms" : "pounds"
        let start = week.weekStart.formatted(.dateTime.month(.wide).day())
        var parts = [
            "Week \(weekNumber), from \(start)",
            headline,
            workLine,
            effortLine,
            "\(Int(week.tonnage.rounded()).formatted()) \(unitName)",
        ]
        parts.append(week.records > 0 ? BRUCountLabel.text(week.records, "record") : "No records")
        return parts.joined(separator: ", ")
    }
}
