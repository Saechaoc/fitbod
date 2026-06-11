//
//  MoveRoutineSheet.swift
//  fitbod
//
//  Phase 2.1 Plan 06 — BRU visual rewrite of the move-routine sheet.
//  UI-SPEC v2 § RoutinesListView (lines 313-322).
//
//  ## Composition
//
//  NavigationStack with .navigationBarHidden(true) + .safeAreaInset(edge: .top)
//  mounting BRUHeaderBar with:
//    left:   HeaderAction("CANCEL") → dismiss()
//    center: "MOVE ROUTINE"
//    right:  nil
//
//  Body: ScrollView > LazyVStack of folder destination rows. Each row is a
//  Button(.plain) with folder name in bodyEmphasis + "✓" text glyph (NOT
//  Image(systemName: "checkmark")) in bruSignal when selected.
//  Tapping a row immediately writes the move and dismisses (no separate Save action).
//
//  ## BRU contract
//
//  NO Image(systemName: "checkmark") — "✓" text glyph only per plan must_haves.
//  NO Color.accentColor. NO navigationTitle. NO Form. NO Capsule.
//  NO RoundedRectangle. NO Color(.system*). NO .font(.body/.headline/.title*/caption).
//

import SwiftUI
import SwiftData

public struct MoveRoutineSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    public let routine: SessionTemplate
    public let folders: [RoutineFolder]

    @State private var selected: UUID?

    public init(routine: SessionTemplate, folders: [RoutineFolder]) {
        self.routine = routine
        self.folders = folders
        self._selected = State(initialValue: routine.folderID)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // "Unfiled" destination row
                    Button {
                        routine.folderID = nil
                        try? ctx.save()
                        dismiss()
                    } label: {
                        HStack {
                            Text("Unfiled")
                                .font(BRUFont.bodyEmphasis)
                                .foregroundStyle(Color.bruInk)
                            Spacer()
                            // "✓" text glyph for currently-selected folder
                            if selected == nil {
                                Text("✓")
                                    .font(BRUFont.displayMedium)
                                    .foregroundStyle(Color.bruSignal)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    BRUDivider(.hair)

                    ForEach(folders) { folder in
                        Button {
                            routine.folderID = folder.id
                            try? ctx.save()
                            dismiss()
                        } label: {
                            HStack {
                                Text(folder.name)
                                    .font(BRUFont.bodyEmphasis)
                                    .foregroundStyle(Color.bruInk)
                                Spacer()
                                // "✓" text glyph (NOT Image(systemName: "checkmark"))
                                if selected == folder.id {
                                    Text("✓")
                                        .font(BRUFont.displayMedium)
                                        .foregroundStyle(Color.bruSignal)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        BRUDivider(.hair)
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: HeaderAction("CANCEL") { dismiss() },
                    center: "MOVE ROUTINE",
                    right: nil
                )
            }
        }
    }
}

#if DEBUG
#Preview {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let routine = SessionTemplate()
    routine.name = "Push Day"
    ctx.insert(routine)
    let f1 = RoutineFolder(name: "Push / Pull / Legs")
    let f2 = RoutineFolder(name: "Hypertrophy Block")
    ctx.insert(f1)
    ctx.insert(f2)
    return MoveRoutineSheet(routine: routine, folders: [f1, f2])
        .modelContainer(container)
}
#endif
