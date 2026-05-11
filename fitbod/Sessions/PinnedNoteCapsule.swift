//
//  PinnedNoteCapsule.swift
//  fitbod
//
//  Wave-4 plan 04-03 — the inline yellow capsule that displays a
//  `SessionExercise.pinnedNote` value above the column-header row in
//  `SessionExerciseCard`. Tapping it opens `PinnedNoteSheet` for editing.
//
//  ## UI-SPEC § Session logger verbatim contract
//
//      Symbol:       `pin.fill` (UI-SPEC Asset Contract — "Pinned per-
//                    exercise note marker")
//      Background:   `Color(.systemYellow).opacity(0.15)`
//      Foreground:   pin icon = `Color(.systemYellow)`; text = `.primary`
//      Typography:   `.caption` body text
//      A11y label:   "Pinned note: {note text}"
//      A11y hint:    "Tap to edit"
//
//  ## Anti-patterns explicitly avoided
//
//  - Do NOT use `Color.yellow` (the SwiftUI literal) for the capsule
//    background. UI-SPEC verbatim is `Color(.systemYellow)` (the asset-
//    catalog system yellow). The 15% alpha keeps the capsule readable on
//    both light and dark mode (matches the system Reminders / Mail
//    "yellow tag" treatment).
//  - Do NOT render at full opacity — that would compete with the accent
//    color for attention and break the 60/30/10 split.
//

import SwiftUI

public struct PinnedNoteCapsule: View {
    public let note: String
    public let onTap: () -> Void

    public init(note: String, onTap: @escaping () -> Void) {
        self.note = note
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")                                  // UI-SPEC Asset Contract
                    .foregroundStyle(Color(.systemYellow))
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemYellow).opacity(0.15))                   // UI-SPEC verbatim pinned-note background
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pinned note: \(note)")                            // UI-SPEC verbatim a11y
        .accessibilityHint("Tap to edit")
    }
}
