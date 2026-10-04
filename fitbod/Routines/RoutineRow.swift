//
//  RoutineRow.swift
//  fitbod
//
//  One routine in the Routines list: name, structured meta line, and a
//  visible START button in thumb reach. The name area opens the routine
//  detail; both are separate hit targets (≥ 44 pt).
//

import SwiftUI

public struct RoutineRow: View {
    public let routine: Routine
    public let lastDone: Date?
    public let onOpen: () -> Void
    public let onStart: () -> Void

    public init(routine: Routine, lastDone: Date?, onOpen: @escaping () -> Void, onStart: @escaping () -> Void) {
        self.routine = routine
        self.lastDone = lastDone
        self.onOpen = onOpen
        self.onStart = onStart
    }

    public var body: some View {
        HStack(spacing: Chalk.Space.md) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                    Text(routine.name)
                        .font(.chalkHeadline)
                        .foregroundStyle(.chalkInk)
                        .multilineTextAlignment(.leading)
                    Text(RoutineSummary.line(for: routine, lastDone: lastDone))
                        .font(.chalkFootnote)
                        .foregroundStyle(.chalkInk2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: Chalk.Size.minTouch, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the routine"))
            .accessibilityIdentifier("routine.row.\(routine.name)")

            Button("Start", action: onStart)
                .buttonStyle(.chalk(.primary, size: .compact))
                .accessibilityLabel(Text("Start \(routine.name)"))
                .accessibilityIdentifier("routine.start.\(routine.name)")
        }
        .padding(.vertical, Chalk.Space.xxs)
    }
}
