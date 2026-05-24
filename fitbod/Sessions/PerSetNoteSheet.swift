// PerSetNoteSheet.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 37).
// UI-SPEC v2 § Session logger line 380.
//
// Per-set form-note editor. Presented as a sheet from the SetRow's notes
// button. Replaces the default NavigationStack + Form + .navigationTitle
// chrome with BRUHeaderBar + styled TextEditor.
//
// UI-SPEC verbatim copy:
//   Sheet title:        "SET {N} NOTE"
//   Left action:        "CANCEL"
//   Right action:       "SAVE"  (bruSignal)
//   Placeholder text:   "e.g. right knee caved on rep 7"
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI

public struct PerSetNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var entry: SetEntry

    public init(entry: SetEntry) {
        self.entry = entry
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
                            get: { entry.notes ?? "" },
                            set: { entry.notes = $0.isEmpty ? nil : $0 }
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
                        Text("e.g. right knee caved on rep 7")                    // UI-SPEC verbatim placeholder
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
                    center: "SET \(entry.orderIndex + 1) NOTE",                    // UI-SPEC verbatim format
                    right: HeaderAction("SAVE", isSignal: true) { dismiss() }      // UI-SPEC verbatim
                )
            }
        }
    }
}

#if DEBUG
#Preview("per-set note sheet") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.orderIndex = 2
    entry.notes = "right knee caved on rep 7"
    ctx.insert(entry)
    try? ctx.save()
    return PerSetNoteSheet(entry: entry)
        .modelContainer(container)
}
#endif
