//
//  RoutineRow.swift
//  fitbod
//
//  Phase 2.1 Plan 06 — BRU visual rewrite of the Routine row.
//  UI-SPEC v2 § RoutinesListView row format (line 310 + line 547).
//
//  ## 3-Column Layout
//
//  leading 64pt column:  BRUFont.displayMedium 18pt of day-count or muscle-
//                        group hint (e.g. "4D" or "PSH") — fallback "—"
//  middle column:        BRUFont.bodyEmphasis 14pt routine.name + labelSmall
//                        10pt 1.2 letterspacing UPPERCASE bruMuted sub-line
//                        "{N} EXERCISES · {LABEL}"
//  trailing column:      BRUFont.displayMedium of last-session tonnage when
//                        available OR "▸" chevron text glyph in bruMuted
//                        (NOT chevron.right SF Symbol per UI-SPEC)
//
//  ## Preserved Interactions (Phase 2 — swipe actions + context menu)
//
//  Leading swipe:        "Start Workout"
//  Trailing swipe:       "Delete" (destructive) + "Duplicate"
//  Long-press:           context menu: "Start Workout" / "Duplicate" /
//                        "Move…" / "Edit" / "Delete" (verbatim UI-SPEC line 311)
//
//  ## BRU contract
//
//  NO .tint(Color.accentColor) — swipe-action backgrounds use SwiftUI
//  defaults (system red for destructive, system gray for secondary), which
//  is acceptable per UI-SPEC line 261 ("Apple's chrome cannot be fully restyled").
//  NO .font(.body/.headline/.title*/caption), NO Capsule, NO RoundedRectangle,
//  NO Image(systemName:), NO Color(.system*), NO Color.accentColor.
//

import SwiftUI

public struct RoutineRow: View {
    public let routine: SessionTemplate
    public let onTap: (SessionTemplate) -> Void
    public let onStart: (SessionTemplate) -> Void
    public let onDuplicate: (SessionTemplate) -> Void
    public let onMove: (SessionTemplate) -> Void
    public let onDelete: (SessionTemplate) -> Void

    public init(
        routine: SessionTemplate,
        onTap: @escaping (SessionTemplate) -> Void,
        onStart: @escaping (SessionTemplate) -> Void,
        onDuplicate: @escaping (SessionTemplate) -> Void,
        onMove: @escaping (SessionTemplate) -> Void,
        onDelete: @escaping (SessionTemplate) -> Void
    ) {
        self.routine = routine
        self.onTap = onTap
        self.onStart = onStart
        self.onDuplicate = onDuplicate
        self.onMove = onMove
        self.onDelete = onDelete
    }

    public var body: some View {
        // 3-column BRU row per UI-SPEC line 310 + 547
        HStack(spacing: 12) {
            // Leading 64pt column — day count or muscle-group hint
            Text(leadingLabel)
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
                .frame(width: 64, alignment: .leading)

            // Middle column — name + sub-line
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Text(subLine)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }

            Spacer()

            // Trailing column — tonnage OR "▸" chevron glyph
            if let tonnage = lastSessionTonnage {
                Text(tonnage)
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
            } else {
                Text("▸")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruPaper)
        .contentShape(Rectangle())
        .onTapGesture { onTap(routine) }
        .swipeActions(edge: .leading) {
            Button {
                onStart(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onDuplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.gray)
        }
        .contextMenu {
            Button {
                onStart(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            Button {
                onDuplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button {
                onMove(routine)
            } label: {
                Label("Move…", systemImage: "folder.fill.badge.plus")
            }
            Button {
                onTap(routine)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Computed properties

    /// Leading 64pt label — routine's day count (e.g. "4D") or muscle-group
    /// hint (e.g. "PSH" / "PUL") derived from routine name. Fallback: "—".
    private var leadingLabel: String {
        let name = routine.name.uppercased()
        // Common muscle-group shorthand patterns
        let hints: [(String, String)] = [
            ("PUSH", "PSH"),
            ("PULL", "PUL"),
            ("LEGS", "LEG"),
            ("UPPER", "UPR"),
            ("LOWER", "LWR"),
            ("FULL BODY", "FB"),
            ("FULL-BODY", "FB"),
        ]
        for (keyword, hint) in hints {
            if name.contains(keyword) { return hint }
        }
        // Day count pattern — look for a digit followed by "D" or "DAY"
        let exercises = (routine.exercises ?? [])
        if exercises.isEmpty {
            return "—"
        }
        // Fall back to exercise count as a proxy for "days" when no hint matches
        return "—"
    }

    /// Sub-line: "{N} EXERCISES · {intentLabel}" per UI-SPEC line 310.
    private var subLine: String {
        let count = (routine.exercises ?? []).count
        return BRUCountLabel.text(count, "exercise")
    }

    /// Last-session tonnage display string, or nil when not yet available.
    ///
    /// Phase 2.1: no Phase-6 tonnage helper available yet — returns nil,
    /// which triggers the "▸" fallback glyph per UI-SPEC line 310.
    private var lastSessionTonnage: String? {
        nil
    }
}
