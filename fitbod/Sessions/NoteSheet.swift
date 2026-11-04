// NoteSheet.swift
// fitbod
//
// The note editor behind workout notes, an exercise's pinned note and a
// set's form note: BRUHeaderBar (CANCEL / title / SAVE) over a TextEditor
// with a 2pt bruInk border (UI-SPEC v2 § Session logger lines 361, 380
// and 575; review item 42).
//
// Edit semantics (review item 33): the sheet edits a local copy of the
// note. SAVE hands it to `onSave`, with empty text as nil, so "has a
// note?" checks stay a nil check; CANCEL and swipe-down throw it away.

import SwiftUI
import SwiftData

struct NoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let title: String
    let hint: String
    let onSave: (String?) -> Void
    /// The edited copy; only SAVE writes it back.
    @State private var text: String

    init(title: String, hint: String, text: String?, onSave: @escaping (String?) -> Void) {
        self.title = title
        self.hint = hint
        self.onSave = onSave
        _text = State(initialValue: text ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.bruPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // On paper rather than the system's white text background.
                        TextEditor(text: $text)
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruInk)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .padding(8)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.bruInk, lineWidth: 2)
                            )

                        Text(hint)
                            .font(BRUFont.labelSmall)
                            .tracking(0.5)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .padding(16)
                }
            }
            .navigationBarHidden(true)
            // The inset already places the content below the header.
            .safeAreaInset(edge: .top, spacing: 0) {
                BRUHeaderBar(
                    left: HeaderAction("CANCEL") { dismiss() },
                    center: title,
                    right: HeaderAction("SAVE", isSignal: true) { save() }
                )
            }
        }
    }

    private func save() {
        onSave(text.isEmpty ? nil : text)
        try? ctx.save()
        dismiss()
    }
}

#if DEBUG
#Preview("note sheet") {
    NoteSheet(title: "WORKOUT NOTES", hint: "Notes for this session", text: "Felt strong") { _ in }
        .modelContainer(PreviewModelContainer.make())
}
#endif
