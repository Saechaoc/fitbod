//
//  MoveRoutineSheet.swift
//  fitbod
//
//  Sheet for moving a routine to a different folder (or back to Unfiled).
//  Presented from the routine row's "Move…" context menu entry. Copy is
//  locked verbatim by UI-SPEC § Routines tab (Move-routine sheet title /
//  Save / Cancel).
//
//  The sheet receives the routine and the list of folders from the
//  parent view (which owns the `@Query<RoutineFolder>`). The user picks
//  a destination (or "Unfiled") via Form rows with a trailing checkmark
//  on the currently-selected entry; tapping "Save" writes the chosen
//  folder UUID (or nil for Unfiled) to `routine.folderID` and saves.
//
//  `routine.folderID` is a SOFT reference (UUID? — not a SwiftData
//  relationship; see `Routine.swift` header + CONTEXT.md Area 6), so this
//  is a one-field mutation; no relationship traversal needed.
//

import SwiftUI
import SwiftData

public struct MoveRoutineSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    public let routine: Routine
    public let folders: [RoutineFolder]

    @State private var selected: UUID?

    public init(routine: Routine, folders: [RoutineFolder]) {
        self.routine = routine
        self.folders = folders
        self._selected = State(initialValue: routine.folderID)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        selected = nil
                    } label: {
                        HStack {
                            Text("Unfiled")
                            Spacer()
                            if selected == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    ForEach(folders) { folder in
                        Button {
                            selected = folder.id
                        } label: {
                            HStack {
                                Text(folder.name)
                                Spacer()
                                if selected == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Move Routine")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        routine.folderID = selected
                        try? ctx.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let routine = Routine()
    routine.name = "Push Day"
    ctx.insert(routine)
    let f1 = RoutineFolder(name: "Push / Pull / Legs")
    let f2 = RoutineFolder(name: "Hypertrophy Block")
    ctx.insert(f1)
    ctx.insert(f2)
    return MoveRoutineSheet(routine: routine, folders: [f1, f2])
        .modelContainer(container)
}
