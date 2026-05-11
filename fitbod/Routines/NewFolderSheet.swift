//
//  NewFolderSheet.swift
//  fitbod
//
//  Sheet for creating a new `RoutineFolder` from the Routines tab "+"
//  toolbar Menu. Presented as a `.sheet` from `RoutinesListView`. Copy is
//  locked verbatim by UI-SPEC § Routines tab (New-folder sheet title /
//  placeholder / Save / Cancel toolbar labels).
//
//  Pattern: mirrors Phase 1's `CustomExerciseEditor` Form-in-NavigationStack
//  shape — `@Bindable` draft holds the in-flight name, "Save" is
//  `.disabled(!draft.isValid)` to enforce the non-empty-after-trim rule.
//
//  On Save the sheet inserts a new `RoutineFolder` with the trimmed name
//  into the model context and saves. The `sortOrder` is left at its
//  default (0) — visual ordering by `sortOrder` then by `createdAt` is
//  handled by the `@Query` sort descriptor in `RoutinesListView`.
//

import SwiftUI
import SwiftData

public struct NewFolderSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: RoutineFolderDraft

    public init(draft: RoutineFolderDraft) {
        self.draft = draft
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Push / Pull / Legs", text: $draft.name)
                }
            }
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }

    private func save() {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = RoutineFolder(name: trimmed)
        ctx.insert(folder)
        try? ctx.save()
        dismiss()
    }
}

#Preview {
    NewFolderSheet(draft: RoutineFolderDraft())
        .modelContainer(PreviewModelContainer.make())
}
