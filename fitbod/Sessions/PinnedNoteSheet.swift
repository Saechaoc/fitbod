// PinnedNoteSheet.swift
// fitbod
//
// BRU rewrite — Milestone 1 review item 42.
// Mirrors WorkoutNotesSheet: BRUHeaderBar + styled TextEditor.
//
// Per-exercise pinned-note editor. Presented as a sheet from the
// SessionExerciseCard's long-press menu "Edit Pinned Note" entry and from
// tapping the inline PinnedNoteCapsule once a note exists.
//
// Edit semantics (review item 33):
//   The sheet edits a local copy of sessionExercise.pinnedNote. SAVE writes it back, with
//   empty text stored as nil; CANCEL and swipe-down throw it away.
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct PinnedNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    public let sessionExercise: SessionExercise
    /// The edited copy; only SAVE writes it back.
    @State private var text: String

    public init(sessionExercise: SessionExercise) {
        self.sessionExercise = sessionExercise
        _text = State(initialValue: sessionExercise.pinnedNote ?? "")
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.bruPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // TextEditor with 2pt bruInk border per UI-SPEC line 575,
                        // on paper rather than the system's white text background
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

                        // Placeholder hint
                        Text("Shown above this exercise's sets")                  // placeholder hint
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
                    center: "PINNED NOTE",                                         // UI-SPEC "Pinned Note", BRU caps
                    right: HeaderAction("SAVE", isSignal: true) { save() }
                )
            }
        }
    }

    /// Empty text is stored as nil so "has a note?" checks stay a nil check.
    private func save() {
        sessionExercise.pinnedNote = text.isEmpty ? nil : text
        try? ctx.save()
        dismiss()
    }
}

#if DEBUG
#Preview("pinned note sheet") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let se = SessionExercise()
    se.pinnedNote = "Pause one second on the chest"
    ctx.insert(se)
    try? ctx.save()
    return PinnedNoteSheet(sessionExercise: se)
        .modelContainer(container)
}
#endif
