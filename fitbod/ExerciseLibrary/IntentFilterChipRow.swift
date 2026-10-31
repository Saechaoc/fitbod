// IntentFilterChipRow.swift
// fitbod — Phase 2.1 Plan 10
//
// BRU full-bleed intent filter strip for ExerciseHistoryView.
// UI-SPEC v2 § Exercise history view (line 434 + 612) + § Color (line 244).
//
// CRITICAL: selected chip uses bruInk fill + bruPaper text.
// UI-SPEC line 244: "in history rows ink fill, not signal, marks selection."
// This is the OPPOSITE of most BRU chip contexts — intentional per spec.
//
// Labels: "ALL · {N}" / "STRENGTH · {N}" / "HYPER · {N}" /
//         "POWER · {N}" / "ENDUR · {N}" / "TECH · {N}"
// Each chip has equal flex width while every label fits on one line; when
// they do not (the small phone, large text), the strip scrolls sideways and
// each chip keeps its label's width, so no label breaks inside a word.
// 1pt bruInk vertical separators between.
// 2pt bruInk rules top + bottom are drawn by the parent layout; this view
// provides them via BRUDivider(.ink) wrappers.

import SwiftUI

// MARK: - IntentFilterChipRow

/// Full-bleed horizontal strip of intent filter chips for the exercise history view.
///
/// Six chips: ALL + the five `Intent` cases. Selected chip uses `bruInk` fill
/// per UI-SPEC line 244 ("in history rows ink fill, not signal, marks selection").
///
/// - Parameters:
///   - filter: Binding to the current filter. `nil` = "ALL".
///   - counts: Map of intent (nil = all) to set count. Displayed after each label.
public struct IntentFilterChipRow: View {
    @Binding public var filter: Intent?
    public let counts: [Intent?: Int]

    public init(filter: Binding<Intent?>, counts: [Intent?: Int] = [:]) {
        self._filter = filter
        self.counts = counts
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)
            ViewThatFits(in: .horizontal) {
                chips.frame(maxWidth: .infinity)
                ScrollView(.horizontal, showsIndicators: false) { chips }
            }
            BRUDivider(.ink)
        }
    }

    private var chips: some View {
        HStack(spacing: 0) {
            // "ALL" chip
            chipButton(label: "ALL", count: totalCount, isSelected: filter == nil) {
                filter = nil
            }
            Rectangle().fill(Color.bruInk).frame(width: 1)

            // Per-intent chips
            ForEach(IntentFilter.allCases, id: \.rawValue) { item in
                chipButton(
                    label: item.shortLabel,
                    count: counts[item.intent] ?? 0,
                    isSelected: filter == item.intent
                ) {
                    filter = item.intent
                }
                if item != IntentFilter.allCases.last {
                    Rectangle().fill(Color.bruInk).frame(width: 1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Private

    private var totalCount: Int {
        counts.values.reduce(0, +)
    }

    private func chipButton(
        label: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text("\(label) · \(count)")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .fixedSize()
                // UI-SPEC line 244: selected = bruInk fill + bruPaper text (NOT signal)
                .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(isSelected ? Color.bruInk : Color.bruPaper)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        }
        .buttonStyle(.plain)
    }
}

// MARK: - IntentFilter (helper enum for ordered cases + short labels)

/// Internal enumeration for ordered rendering of filter chips.
/// Maps to `Intent?` (nil = ALL) and provides the UI-SPEC short label.
enum IntentFilter: String, CaseIterable {
    case strength
    case hypertrophy
    case power
    case endurance
    case technique

    var shortLabel: String {
        switch self {
        case .strength:   return "STRENGTH"
        case .hypertrophy: return "HYPER"
        case .power:       return "POWER"
        case .endurance:   return "ENDUR"
        case .technique:   return "TECH"
        }
    }

    var intent: Intent {
        switch self {
        case .strength:    return .strength
        case .hypertrophy: return .hypertrophy
        case .power:       return .power
        case .endurance:   return .endurance
        case .technique:   return .technique
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct IntentFilterPreviewWrapper: View {
    @State private var selected: Intent? = nil

    var body: some View {
        VStack(spacing: 0) {
            IntentFilterChipRow(
                filter: $selected,
                counts: [
                    nil: 14,
                    .strength: 5,
                    .hypertrophy: 9,
                    .power: 0,
                    .endurance: 0,
                    .technique: 0
                ]
            )
            Text("Selected: \(selected?.rawValue ?? "ALL")")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .padding(16)
        }
        .background(Color.bruPaper)
    }
}

#Preview("IntentFilterChipRow — All selected") {
    IntentFilterPreviewWrapper()
}
#endif
