//
//  SessionSheet.swift
//  fitbod
//
//  Today's "Start a workout" sheet (RM-006), opened by "Choose another
//  session" and the rows like it. It lists every live routine's sessions,
//  each once in the order of its first slot, and a tap starts the workout.
//  One row is marked NEXT. A row that starts past NEXT says which sessions it
//  skips this cycle, which is the only warning before the tap. A session with
//  no exercises is listed and does not start. Sessions that sit in no live
//  routine come last and open their detail, where they are previewed, edited
//  and started.
//
//  `SessionSheetContent` is the pure part. It asks `StartSlot` for NEXT and
//  for each row's slot, so the sheet, the hero and the start agree.
//
//  BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//  NO .font(.body/.headline/.title*/.caption)
//

import SwiftUI
import SwiftData

// MARK: - Content

struct SessionSheetContent: Equatable {

    struct Row: Equatable, Identifiable {
        let session: SessionTemplate
        /// A start here is credited to NEXT. At most one row in the sheet has it.
        let isNext: Bool
        /// The sessions a start here moves the rotation past this cycle.
        let skips: [SessionTemplate]

        var id: UUID { session.id }
        var canStart: Bool { StartSlot.hasExercises(session) }
    }

    struct Group: Equatable, Identifiable {
        let routine: Split
        let rows: [Row]

        var id: UUID { routine.id }
    }

    /// The live routines that hold a session: the block's routine, or with no
    /// block the suggested one, first, then the rest by name.
    let groups: [Group]
    /// The sessions that sit in no live routine, by name.
    let others: [SessionTemplate]

    init(
        liveRoutines: [Split], sessions: [SessionTemplate], block: Block?, resolution: TodayResolution,
        finished: [Session], now: Date, calendar: Calendar
    ) {
        // The one slot marked NEXT: the block's while a block runs, else the suggested routine's.
        let marked: SplitSessionSlot? = if let block {
            StartSlot.next(in: block, resolution: resolution, finished: finished, now: now, calendar: calendar)
        } else {
            StartSlot.suggestion(liveRoutines: liveRoutines, sessions: sessions, finished: finished)?.slot
        }
        let lead = block?.split ?? marked?.split
        // A weekly block maps days to slots, so a start there moves nothing and skips nothing.
        let explainsSkips = block?.schedulingMode != .fixedWeekly

        groups = liveRoutines
            .sorted { a, b in
                if (a.id == lead?.id) != (b.id == lead?.id) { return a.id == lead?.id }
                return Self.inNameOrder(a.name, a.id, b.name, b.id)
            }
            .compactMap { routine in
                var seen = Set<UUID>()
                let listed = (routine.slots ?? [])
                    .sorted { $0.position < $1.position }
                    .compactMap(\.sessionTemplate)
                    .filter { seen.insert($0.id).inserted }
                guard !listed.isEmpty else { return nil }

                let slotted = StartSlot.givesSlots(routine, block: block)
                // The routine's own NEXT, which its rows count their skips from.
                let next = StartSlot.next(
                    in: routine, block: block, resolution: resolution, finished: finished, now: now, calendar: calendar)
                return Group(routine: routine, rows: listed.map { session in
                    let slot = slotted && StartSlot.hasExercises(session)
                        ? StartSlot.slot(for: session, in: routine, next: next) : nil
                    return Row(
                        session: session,
                        isNext: slot != nil && slot?.id == marked?.id,
                        skips: explainsSkips ? slot.map { StartSlot.skipped(startingAt: $0, next: next) } ?? [] : [])
                })
            }

        let slottedIDs = Set(liveRoutines.flatMap { ($0.slots ?? []).compactMap { $0.sessionTemplate?.id } })
        others = sessions
            .filter { !slottedIDs.contains($0.id) }
            .sorted { Self.inNameOrder($0.name, $0.id, $1.name, $1.id) }
    }

    private static func inNameOrder(_ a: String, _ aID: UUID, _ b: String, _ bID: UUID) -> Bool {
        let order = a.localizedStandardCompare(b)
        return order == .orderedSame ? aID.uuidString < bID.uuidString : order == .orderedAscending
    }
}

// MARK: - Sheet

struct SessionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let content: SessionSheetContent
    /// The active block's phase; a deload cuts the sets a start will plan.
    let phase: BlockPhase?
    /// Starts the session from the routine it is listed under.
    let onStart: (SessionTemplate, Split) -> Void
    /// Opens a session that sits in no live routine.
    let onOpen: (SessionTemplate) -> Void

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(left: HeaderAction("Cancel") { dismiss() }, center: "Start a workout")
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(content.groups) { group in
                        header(group.routine.name)
                        ForEach(group.rows) { row in
                            sessionRow(row, in: group.routine)
                            BRUDivider(.hair)
                        }
                    }
                    if !content.others.isEmpty {
                        header("Other sessions")
                        ForEach(content.others, id: \.id) { session in
                            otherRow(session)
                            BRUDivider(.hair)
                        }
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// A routine's session: the whole row starts the workout.
    private func sessionRow(_ row: SessionSheetContent.Row, in routine: Split) -> some View {
        Button { onStart(row.session, routine) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.session.name)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(row.canStart ? Color.bruInk : Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if row.isNext {
                        Text("Next")
                            .font(BRUFont.labelSmall)
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
                // Wraps in full: "skips" is the only warning before the tap starts the workout.
                Text(Self.subline(for: row, phase: phase))
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bruRow)
        .disabled(!row.canStart)
        .accessibilityIdentifier("sessionSheet.start.\(row.session.id)")
        .accessibilityHint(row.canStart ? "Starts this workout" : "Add exercises to this session in Program first")
    }

    /// A session in no live routine: the row opens its detail.
    private func otherRow(_ session: SessionTemplate) -> some View {
        Button { onOpen(session) } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Self.summary(of: session, phase: phase))
                        .font(BRUFont.labelSmall)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("›")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bruRow)
        .accessibilityHint("Shows the exercises in this session")
    }

    // MARK: Row text

    /// "5 exercises · 15 sets", then "skips Pull A, Legs A" for a start past NEXT.
    static func subline(for row: SessionSheetContent.Row, phase: BlockPhase?) -> String {
        let summary = summary(of: row.session, phase: phase)
        guard !row.skips.isEmpty else { return summary }
        return "\(summary) · skips \(row.skips.map(\.name).joined(separator: ", "))"
    }

    /// "5 exercises · 15 sets", counting the working sets the phase yields, as
    /// the hero does; "1 exercise" for cardio alone, which has no sets;
    /// "No exercises yet" for an empty session.
    static func summary(of session: SessionTemplate, phase: BlockPhase?) -> String {
        let exercises = session.exercises ?? []
        guard !exercises.isEmpty else { return "No exercises yet" }
        let sets = exercises.reduce(0) { $0 + $1.workingSetCount(phase: phase) }
        let count = BRUCountLabel.text(exercises.count, "exercise")
        return sets > 0 ? "\(count) · \(BRUCountLabel.text(sets, "set"))" : count
    }
}
