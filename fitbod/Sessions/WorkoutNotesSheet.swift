// WorkoutNotesSheet.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 38).
// UI-SPEC v2 § Session logger line 361.
//
// Workout-level notes editor. Replaces the default NavigationStack + Form +
// .navigationTitle chrome with BRUHeaderBar + styled TextEditor.
//
// Binding semantics:
//   Binds directly to @Bindable session.notes: String? via a Binding(get:set:)
//   that normalizes empty strings to nil on write — keeps the persisted column
//   free of blank entries so any downstream "has notes?" predicate stays simple.
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI

public struct WorkoutNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var session: Session

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.bruPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Spacer for BRUHeaderBar height (46pt = 44pt + 2pt rule)
                        Color.clear.frame(height: 46)

                        // TextEditor with 2pt bruInk border per UI-SPEC line 575
                        TextEditor(text: Binding(
                            get: { session.notes ?? "" },
                            set: { session.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                BRUHeaderBar(
                    left: HeaderAction("CANCEL") { dismiss() },                    // UI-SPEC verbatim
                    center: "WORKOUT NOTES",                                       // UI-SPEC verbatim
                    right: HeaderAction("SAVE", isSignal: true) { dismiss() }      // UI-SPEC verbatim
                )
            }
        }
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
