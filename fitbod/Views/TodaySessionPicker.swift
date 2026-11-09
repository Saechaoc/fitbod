// TodaySessionPicker.swift
// fitbod
//
// Today's "Start a workout" section. Shown whenever nothing is scheduled
// and nothing is in progress (no active block, a rest day, an empty split),
// so a workout can always be started without a block.
//
// Lists every session of every non-archived routine, grouped by routine in
// slot order. Each row opens the session detail; its START ▸ control starts
// the workout directly (one tap from Today). An empty workout, with
// exercises added in the logger, is always offered last. With no sessions
// anywhere it becomes the first-run empty state that creates a routine or
// starts an empty workout.

import SwiftUI
import SwiftData

public struct TodaySessionPicker: View {

    @Query(filter: #Predicate<Split> { !$0.isArchived }, sort: \Split.name)
    private var routines: [Split]

    /// A session and the routine it is listed under, which decides its slot.
    let onOpen: (SessionTemplate, Split) -> Void
    let onStart: (SessionTemplate, Split) -> Void
    let onNewRoutine: () -> Void
    let onStartEmpty: () -> Void

    public init(
        onOpen: @escaping (SessionTemplate, Split) -> Void,
        onStart: @escaping (SessionTemplate, Split) -> Void,
        onNewRoutine: @escaping () -> Void,
        onStartEmpty: @escaping () -> Void
    ) {
        self.onOpen = onOpen
        self.onStart = onStart
        self.onNewRoutine = onNewRoutine
        self.onStartEmpty = onStartEmpty
    }

    /// (routine, its live sessions in slot order); routines with no
    /// sessions are dropped so the list never shows empty groups.
    private var groups: [(routine: Split, sessions: [SessionTemplate])] {
        routines.compactMap { routine in
            let sessions = (routine.slots ?? [])
                .sorted { $0.position < $1.position }
                .compactMap(\.sessionTemplate)
                .filter { !$0.isArchived }
            return sessions.isEmpty ? nil : (routine, sessions)
        }
    }

    public var body: some View {
        let groups = groups
        VStack(spacing: 0) {
            BRUSectionHead("Start a workout")
            if groups.isEmpty {
                emptyState
            } else {
                ForEach(groups, id: \.routine.id) { group in
                    Text(group.routine.name)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(group.sessions, id: \.id) { session in
                        row(session, in: group.routine)
                        BRUDivider(.hair)
                    }
                }
                emptyWorkoutRow
            }
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }

    private func row(_ session: SessionTemplate, in routine: Split) -> some View {
        HStack(spacing: 12) {
            Button { onOpen(session, routine) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(SessionTemplateSummary(template: session).line)
                        .font(BRUFont.labelSmall)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)
            .accessibilityHint("Shows the exercises in this session")

            BRUButton("Start ▸", kind: .signal, size: .md) { onStart(session, routine) }
                .frame(width: 104)
                .disabled((session.exercises ?? []).isEmpty)
                .accessibilityLabel("Start \(session.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// An empty workout: exercises are added in the logger.
    private var emptyWorkoutRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Empty workout")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("Add exercises as you go")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityElement(children: .combine)

            BRUButton("Start ▸", kind: .ghost, size: .md, action: onStartEmpty)
                .frame(width: 104)
                .accessibilityLabel("Start an empty workout")
                .accessibilityIdentifier("today.startEmpty")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build your first routine")
                .font(BRUFont.condensedHeading)
                .foregroundStyle(Color.bruInk)
            Text("A routine is your split, like Push / Pull / Legs. Each session in it lists exercises with target sets and reps.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
            BRUButton("+ New routine", kind: .signal, size: .lg, action: onNewRoutine)
            BRUButton("Start an empty workout", kind: .ghost, size: .lg, action: onStartEmpty)
                .accessibilityIdentifier("today.startEmpty")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
