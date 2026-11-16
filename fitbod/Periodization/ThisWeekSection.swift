//
//  ThisWeekSection.swift
//  fitbod
//
//  Program's This week, under the active block's slab (RM-015, O-9,
//  docs/design-map/redesign/program-layouts.md).
//
//  A weekday block shows seven day groups from the week start. A group
//  lists each counted workout that started that day, oldest first, which
//  opens its summary; then the open workout, read-only, as IN PROGRESS;
//  then the session the block plans that day, unless a workout that day
//  holds its slot; else Rest.
//
//  A rotation block shows its slots in order instead, each with its latest
//  counted workout in the block, then ALSO THIS WEEK: every counted workout
//  of the week that no slot row shows, so each workout appears once.
//
//  Both read Today's state, queries and calendar, the week start setting
//  included, so TODAY ▸ and NEXT ▸ show exactly while Today is T-TODAY.
//  They start through WorkoutStarter, whose StartSlot credits the slot
//  Today's hero would. A planned session with no exercises reads
//  NO EXERCISES › and opens its detail. No adherence count (RM-039).
//
//  The open workout shows only in the week it started: Program's resume
//  banner is its route. A block with no routine, or a routine with no
//  sessions, plans nothing, so only the week's workouts show, and the
//  section hides when there are none.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - ThisWeek

/// What This week shows, worked out from Today's state.
struct ThisWeek: Equatable {
    /// The head's dates, "NOV 9–15", in a weekday block; nil on rotation,
    /// whose head reads Rotation.
    let range: String?
    /// Empty when there is nothing to show, which hides the section.
    let groups: [Group]

    /// What a group's leading column names.
    enum Label: Equatable {
        /// A weekday group's day, at local midnight.
        case day(Date)
        /// A rotation slot, numbered from its position.
        case slot(SplitSessionSlot)
        /// The week's workouts that no slot row shows.
        case also

        var day: Date? {
            if case .day(let day) = self { day } else { nil }
        }
    }

    enum Row: Equatable {
        /// A counted workout, which opens its summary.
        case logged(Session)
        /// The open workout, read-only: Program's resume banner is its one route.
        case inProgress(Session)
        /// A session the block plans.
        case planned(SplitSessionSlot, Mark)
        /// A day with nothing logged or planned.
        case rest

        /// What the row is called: the workout's own name, the planned session's, or Rest.
        var name: String {
            switch self {
            case .logged(let workout), .inProgress(let workout):
                workout.displayName
            case .planned(let slot, _):
                slot.sessionTemplate.flatMap { $0.name.isEmpty ? nil : $0.name } ?? "Untitled session"
            case .rest:
                "Rest"
            }
        }
    }

    enum Mark: Equatable {
        case plain
        /// TODAY ▸ or NEXT ▸, only while Today is T-TODAY.
        case start
        /// NO EXERCISES ›, which opens the session's detail.
        case repair
    }

    struct Group: Equatable {
        let label: Label
        let rows: [Row]
    }

    /// The week Today's board shows, from the week start setting.
    static func weekStart(_ settings: [UserSettings], now: Date, calendar: Calendar) -> Date {
        now.mondayAtMidnightForToday(weekStartsMonday: settings.first?.weekStartsMonday ?? true, calendar: calendar)
    }

    /// What This week shows for the active `block`, from the queries Today
    /// reads, through Today's own state function. The view's task and the
    /// tests both call this, so they read the same inputs.
    /// - Parameter workouts: every workout, open or finished.
    @MainActor
    static func make(
        block: Block, workouts: [Session], templates: [SessionTemplate], settings: [UserSettings],
        liveRoutines: [Split], readyBlocks: [Block], context: ModelContext, now: Date, calendar: Calendar
    ) -> ThisWeek {
        let finished = workouts.filter { $0.completedAt != nil }
        let resolution = TodayResolver.resolve(block: block, context: context, today: now, calendar: calendar)
        let state = TodayState.resolve(
            openWorkouts: workouts.filter { $0.completedAt == nil }, activeBlock: block, resolution: resolution,
            finishedWorkouts: finished, readyBlocks: readyBlocks, liveRoutines: liveRoutines,
            sessions: templates, now: now, calendar: calendar)
        let start = calendar.startOfDay(for: weekStart(settings, now: now, calendar: calendar))
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return ThisWeek(
            range: block.schedulingMode == .rotation ? nil : TodayWeek.rangeLabel(days),
            groups: groups(
                block: block, state: state, resolution: resolution, workouts: workouts, finished: finished,
                days: days, now: now, calendar: calendar))
    }

    /// - Parameters:
    ///   - resolution: the resolver's answer for `now`; its slot is a rotation block's NEXT.
    ///   - days: the week's seven local midnights.
    private static func groups(
        block: Block, state: TodayState, resolution: TodayResolution, workouts: [Session], finished: [Session],
        days: [Date], now: Date, calendar: Calendar
    ) -> [Group] {
        guard let first = days.first, let end = days.last.flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) })
        else { return [] }
        let isThisWeek = { (workout: Session) in workout.startedAt >= first && workout.startedAt < end }
        // The week first: counting reads each workout's sets.
        let week = SessionSetActions.countedWorkouts(workouts.filter(isThisWeek)).sorted { $0.startedAt < $1.startedAt }
        let open: Session? = if case .resume(let open) = state, isThisWeek(open) { open } else { nil }
        // T-TODAY's slot, the one start This week offers.
        let startable: SplitSessionSlot? = if case .today(_, let slot) = state { slot } else { nil }
        // None without a routine (T-ATTACH) or with an empty one (T-FIX): then nothing is planned.
        let slots = (block.split?.slots ?? []).sorted { $0.position < $1.position }

        guard block.schedulingMode == .rotation else {
            // The plan starts on the day the block did.
            let firstPlanned = calendar.startOfDay(for: block.startDate)
            return days.compactMap { day in
                let logged = week.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                let started = open.flatMap { calendar.isDate($0.startedAt, inSameDayAs: day) ? $0 : nil }
                var rows = logged.map(Row.logged) + (started.map { [Row.inProgress($0)] } ?? [])
                if day >= firstPlanned,
                   case .session(let slot) = TodayResolver.resolveFixedWeekly(block: block, today: day, calendar: calendar),
                   !(logged + [started].compactMap { $0 }).contains(where: { $0.slot?.id == slot.id }) {
                    let starts = calendar.isDate(day, inSameDayAs: now) && slot.id == startable?.id
                    rows.append(.planned(slot, mark(slot, starts: starts)))
                }
                if rows.isEmpty && !slots.isEmpty {
                    rows = [.rest]
                }
                return rows.isEmpty ? nil : Group(label: .day(day), rows: rows)
            }
        }

        let next = StartSlot.next(in: block, resolution: resolution, finished: finished, now: now, calendar: calendar)
        // Each slot's newest counted workout in this block. Newest first, so
        // only the newest candidates have their sets read, and only until
        // every slot has one.
        let slotIDs = Set(slots.map(\.id))
        var latest: [UUID: Session] = [:]
        for workout in finished.sorted(by: { $0.startedAt > $1.startedAt }) {
            if latest.count == slotIDs.count { break }
            guard workout.block?.id == block.id, let slot = workout.slot?.id, slotIDs.contains(slot),
                  latest[slot] == nil, !SessionSetActions.isEmptyWorkout(workout)
            else { continue }
            latest[slot] = workout
        }
        func row(_ slot: SplitSessionSlot) -> Row {
            if let open, open.slot?.id == slot.id { return .inProgress(open) }
            // NEXT's start, or its repair, comes before its last workout.
            let nextMark = slot.id == next?.id ? mark(slot, starts: slot.id == startable?.id) : .plain
            if nextMark != .plain { return .planned(slot, nextMark) }
            return latest[slot.id].map(Row.logged) ?? .planned(slot, .plain)
        }
        let slotGroups = slots.map { Group(label: .slot($0), rows: [row($0)]) }
        let shown = Set(slotGroups.flatMap(\.rows).compactMap { row -> UUID? in
            if case .logged(let workout) = row { workout.id } else { nil }
        })
        var also = week.filter { !shown.contains($0.id) }.map(Row.logged)
        if let open, !slots.contains(where: { $0.id == open.slot?.id }) {
            also.append(.inProgress(open))
        }
        return slotGroups + (also.isEmpty ? [] : [Group(label: .also, rows: also)])
    }

    /// NO EXERCISES › for a session with none, else TODAY ▸ or NEXT ▸ when it `starts`.
    private static func mark(_ slot: SplitSessionSlot, starts: Bool) -> Mark {
        guard let session = slot.sessionTemplate else { return .plain }
        return !StartSlot.hasExercises(session) ? .repair : starts ? .start : .plain
    }
}

// MARK: - ThisWeekSection

/// This week under the active block's slab: a weekday block's day groups,
/// or a rotation block's strip.
struct ThisWeekSection: View {
    let block: Block
    /// Today's state reads these too, and Program already queries them.
    let liveRoutines: [Split]
    let readyBlocks: [Block]
    /// False while the section shows nothing, so the next head sits right
    /// under the slab, whose edge is its top rule.
    @Binding var isShown: Bool
    let onOpen: (Session) -> Void
    let onStart: (SessionTemplate) -> Void
    let onRepair: (SessionTemplate) -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    // Today's queries.
    @Query(sort: \Session.startedAt, order: .reverse) private var workouts: [Session]
    @Query(filter: #Predicate<SessionTemplate> { !$0.isArchived }) private var sessions: [SessionTemplate]
    @Query private var settingsList: [UserSettings]

    /// What "today" is, refreshed when Today refreshes its own.
    @State private var now = Date.now
    /// Worked out as Today's board is counted (RM-010): when the workouts, a
    /// History correction, the week or the day change, never per render. The
    /// task also runs each time Program shows, which picks up edits to the
    /// block, its routine and its sessions: all of them are made on other screens.
    @State private var week: ThisWeek? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let week, !week.groups.isEmpty {
                if let range = week.range {
                    BRUSectionHead("This week", right: range, underSlab: true)
                } else {
                    BRUSectionHead("Rotation", underSlab: true)
                }
                ForEach(Array(week.groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        BRUDivider(.hair)
                    }
                    ForEach(Array(group.rows.enumerated()), id: \.offset) { position, row in
                        rowView(row, in: group.label, showsTag: position == 0)
                    }
                }
            }
        }
        .task(id: TodayView.WeekKey(
            finished: workouts.filter { $0.completedAt != nil }.map(\.persistentModelID),
            weekStart: ThisWeek.weekStart(settingsList, now: now, calendar: calendar),
            today: calendar.startOfDay(for: now), edits: historyEdits?.version,
            open: workouts.filter { $0.completedAt == nil }.map(\.persistentModelID)
        )) {
            let week = ThisWeek.make(
                block: block, workouts: workouts, templates: sessions, settings: settingsList,
                liveRoutines: liveRoutines, readyBlocks: readyBlocks, context: ctx, now: now, calendar: calendar)
            self.week = week
            isShown = !week.groups.isEmpty
        }
        .onAppear { now = .now }
        // A History correction can empty a finished workout or fill an empty one.
        .onChange(of: historyEdits?.version) { now = .now }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = .now
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: ThisWeek.Row, in label: ThisWeek.Label, showsTag: Bool) -> some View {
        let (tag, spokenTag) = tag(label)
        // Also this week reads muted, under the slots.
        let isAlso = label == .also
        switch row {
        case .logged(let workout):
            let line = loggedLine(workout, in: label)
            ThisWeekRow(
                tag: tag, showsTag: showsTag, name: line.name, isMuted: isAlso, status: line.status,
                spokenLabel: "\(spokenTag): \(line.name)", spokenValue: line.spoken
            ) { onOpen(workout) }
        case .inProgress:
            ThisWeekRow(
                tag: tag, showsTag: showsTag, name: row.name, isMuted: isAlso,
                status: "In progress", isStatusInk: true,
                spokenLabel: "\(spokenTag): \(row.name)", spokenValue: "In progress"
            )
        case .planned(let slot, let mark):
            let name = row.name
            switch (mark, slot.sessionTemplate) {
            case (.start, let session?):
                ThisWeekRow(
                    tag: tag, showsTag: showsTag, name: name,
                    start: (label.day == nil ? "Next ▸" : "Today ▸", { onStart(session) }),
                    spokenLabel: "\(spokenTag): \(name)", spokenValue: "Planned"
                )
            case (.repair, let session?):
                ThisWeekRow(
                    tag: tag, showsTag: showsTag, name: name, status: "No exercises", isStatusInk: true,
                    spokenLabel: "\(spokenTag): \(name)", spokenValue: "No exercises"
                ) { onRepair(session) }
            default:
                ThisWeekRow(
                    tag: tag, showsTag: showsTag, name: name,
                    spokenLabel: "\(spokenTag): \(name)", spokenValue: "Planned"
                )
            }
        case .rest:
            ThisWeekRow(tag: tag, showsTag: showsTag, name: row.name, isMuted: true, spokenLabel: "\(spokenTag): \(row.name)")
        }
    }

    /// A counted workout's name and what its row says beside it: "52M ✓" in
    /// a day group, "Logged Nov 9" on its slot's row, and its date after its
    /// name under Also this week. Each names the workout itself, so a row
    /// says what its summary opens, a swapped session included.
    private func loggedLine(_ workout: Session, in label: ThisWeek.Label) -> (name: String, status: String?, spoken: String) {
        let date = workout.startedAt.formatted(dateStyle.month(.abbreviated).day())
        switch label {
        case .day:
            let minutes = workout.totalDurationSeconds.map { $0 / 60 }
            let status = [minutes.map { SessionHistoryFormat.duration(minutes: $0) }, "✓"].compactMap { $0 }
            let spoken = ["Done", minutes.map { BRUCountLabel.text($0, "minute") }].compactMap { $0 }
            return (workout.displayName, status.joined(separator: " "), spoken.joined(separator: ", "))
        case .slot:
            return (workout.displayName, "Logged \(date)", "Logged \(date)")
        case .also:
            return ("\(workout.displayName) · \(date)", nil, "Done")
        }
    }

    /// A group's column text and how VoiceOver says it: "MON" and "Monday",
    /// "01" and "1 of 3", or Also this week.
    private func tag(_ label: ThisWeek.Label) -> (text: String, spoken: String) {
        switch label {
        case .day(let day):
            (day.formatted(dateStyle.weekday(.abbreviated)), day.formatted(dateStyle.weekday(.wide)))
        case .slot(let slot):
            (String(format: "%02d", slot.position + 1), "\(slot.position + 1) of \(block.split?.slots?.count ?? 0)")
        case .also:
            ("Also this week", "Also this week")
        }
    }

    /// The app's en_US header style, in the calendar Today reads.
    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: calendar.timeZone)
    }
}

// MARK: - ThisWeekRow

/// One This week row: its group's tag on the group's first row only, the
/// name, then what the row says or offers. At accessibility sizes the
/// status moves under the name.
private struct ThisWeekRow: View {
    let tag: String
    let showsTag: Bool
    let name: String
    var isMuted = false
    /// "52M ✓", "Logged Nov 9", "In progress" or "No exercises".
    var status: String? = nil
    /// IN PROGRESS and NO EXERCISES draw in ink; the rest of the statuses are muted.
    var isStatusInk = false
    /// TODAY ▸ or NEXT ▸, and the start it makes.
    var start: (title: String, action: () -> Void)? = nil
    let spokenLabel: String
    var spokenValue = ""
    /// The whole row's tap, which ends the row with ›.
    var onTap: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.bruRow)
                .accessibilityLabel(spokenLabel)
                .accessibilityValue(spokenValue)
        } else if start != nil {
            // The start stays its own button beside the row's words.
            content
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityValue(spokenValue)
        }
    }

    private var content: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(tag)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isMuted ? Color.bruMuted : Color.bruInk)
                .fixedSize()
                .opacity(showsTag ? 1 : 0)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    nameText
                    trailing
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                nameText
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            if onTap != nil {
                ProgramRowChevron()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var nameText: some View {
        Text(name)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(isMuted ? Color.bruMuted : Color.bruInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(spokenLabel)
    }

    @ViewBuilder
    private var trailing: some View {
        if let status {
            Text(status)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isStatusInk ? Color.bruInk : Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let start {
            Button(action: start.action) {
                Text(start.title)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize()
                    .bruHitArea()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Starts \(name)")
            .accessibilityIdentifier("program.thisWeek.start")
        }
    }
}
