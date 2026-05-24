//
//  NewFolderSheet.swift
//  fitbod
//
//  Phase 2.1 Plan 06 — BRU visual rewrite of the new-folder sheet.
//  UI-SPEC v2 § RoutinesListView (lines 313-315).
//
//  ## Composition
//
//  NavigationStack with .navigationBarHidden(true) + .safeAreaInset(edge: .top)
//  mounting BRUHeaderBar with:
//    left:   HeaderAction("CANCEL") → dismiss()
//    center: "NEW FOLDER"
//    right:  HeaderAction("SAVE", isSignal: true) → save() + dismiss()
//
//  Body: VStack > FOLDER NAME label + BRUMono TextField + 2pt bruInk
//  underline per UI-SPEC line 314.
//
//  ## BRU contract
//
//  NO navigationTitle, NO .toolbar, NO Form, NO Capsule, NO RoundedRectangle,
//  NO Color.accentColor, NO Image(systemName:), NO Color(.system*),
//  NO .font(.body/.headline/.title*/caption).
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
            VStack(spacing: 0) {
                // Form area
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOLDER NAME")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .foregroundStyle(Color.bruMuted)

                        // Text field with BRUMono styling (JetBrainsMono-Regular)
                        TextField("Folder name", text: $draft.name)
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruInk)
                            .padding(.vertical, 8)

                        // 2pt bruInk underline per UI-SPEC line 314
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(height: 2)
                    }
                }
                .padding(16)

                Spacer()
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                BRUHeaderBar(
                    left: HeaderAction("CANCEL") { dismiss() },
                    center: "NEW FOLDER",
                    right: HeaderAction("SAVE", isSignal: true) {
                        guard draft.isValid else { return }
                        save()
                    }
                )
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

#if DEBUG
#Preview {
    NewFolderSheet(draft: RoutineFolderDraft())
        .modelContainer(PreviewModelContainer.make())
}
#endif
