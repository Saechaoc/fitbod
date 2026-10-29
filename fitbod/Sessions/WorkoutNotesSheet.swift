// WorkoutNotesSheet.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 38).
// UI-SPEC v2 § Session logger line 361.
//
// Workout-level notes editor. Replaces the default NavigationStack + Form +
// .navigationTitle chrome with BRUHeaderBar + styled TextEditor.
//
// Edit semantics (review item 33):
//   The sheet edits a local copy of session.notes. SAVE writes it back, with
//   empty text stored as nil; CANCEL and swipe-down throw it away.
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct WorkoutNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    public let session: Session
    /// The edited copy; only SAVE writes it back.
    @State private var text: String

    public init(session: Session) {
        self.session = session
        _text = State(initialValue: session.notes ?? "")
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
                        Text("Notes for this session")                             // placeholder hint
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
                    left: HeaderAction("CANCEL") { dismiss() },                    // UI-SPEC verbatim
                    center: "WORKOUT NOTES",                                       // UI-SPEC verbatim
                    right: HeaderAction("SAVE", isSignal: true) { save() }         // UI-SPEC verbatim
                )
            }
        }
    }

    /// Empty text is stored as nil so "has a note?" checks stay a nil check.
    private func save() {
        session.notes = text.isEmpty ? nil : text
        try? ctx.save()
        dismiss()
    }
}

#if DEBUG
#Preview("workout notes sheet") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    session.notes = "Felt strong today"
    ctx.insert(session)
    try? ctx.save()
    return WorkoutNotesSheet(session: session)
        .modelContainer(container)
}
#endif
