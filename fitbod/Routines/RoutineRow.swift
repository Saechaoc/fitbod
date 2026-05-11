//
//  RoutineRow.swift
//  fitbod
//
//  One row in the Routines tab's sectioned `List`. Renders the routine
//  name (`.body`) on the top line and an "{N} exercises" subtitle on the
//  bottom line per UI-SPEC § Routines tab row format.
//
//  Three interaction surfaces, all driven by closures supplied by the
//  parent (`RoutinesListView`):
//
//    - Tap → `onTap(routine)` — pushes `RoutineBuilderView(routine:)`
//      in edit mode. In plan 03-01 this is a no-op stub; plan 03-02
//      wires the navigation destination.
//
//    - Leading swipe → "Start Workout" (accent fill, white label,
//      `play.fill` glyph). UI-SPEC accent surface #13.
//
//    - Trailing swipe → "Delete" (destructive) + "Duplicate" (secondary,
//      gray tint).
//
//    - Long-press → context menu with the 5 UI-SPEC verbatim actions:
//      "Start Workout" / "Duplicate" / "Move…" / "Edit" / "Delete".
//
//  The "Duplicate" call site is a stub in plan 03-01 — plan 03-03 ships
//  `RoutineDuplicator.duplicate(routine:context:)` and rewires this
//  closure. The "Edit" entry uses the same closure as a row tap.
//

import SwiftUI

public struct RoutineRow: View {
    public let routine: Routine
    public let onTap: (Routine) -> Void
    public let onStart: (Routine) -> Void
    public let onDuplicate: (Routine) -> Void
    public let onMove: (Routine) -> Void
    public let onDelete: (Routine) -> Void

    public init(
        routine: Routine,
        onTap: @escaping (Routine) -> Void,
        onStart: @escaping (Routine) -> Void,
        onDuplicate: @escaping (Routine) -> Void,
        onMove: @escaping (Routine) -> Void,
        onDelete: @escaping (Routine) -> Void
    ) {
        self.routine = routine
        self.onTap = onTap
        self.onStart = onStart
        self.onDuplicate = onDuplicate
        self.onMove = onMove
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name)
                .font(.body)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(routine) }
        .swipeActions(edge: .leading) {
            Button {
                onStart(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            .tint(Color.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onDuplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.gray)
        }
        .contextMenu {
            Button {
                onStart(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            Button {
                onDuplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button {
                onMove(routine)
            } label: {
                Label("Move…", systemImage: "folder.fill.badge.plus")
            }
            Button {
                onTap(routine)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// UI-SPEC § Routines tab row format — bottom line.
    /// Phase 2 ships the basic "{N} exercises" form; the optional
    /// "{N} exercises · {label}" intent-tag variant arrives in plan 03-02
    /// when the routine builder is wired and exercises are addable.
    private var subtitle: String {
        let count = (routine.exercises ?? []).count
        return "\(count) exercises"
    }
}
