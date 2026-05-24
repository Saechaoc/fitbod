// RoutineBuilderDayTabs.swift
// fitbod — Phase 2.1 Plan 05
//
// The horizontal day-tab strip in the routine builder.
//
// Layout:
//   HStack(spacing: 0):
//     [DAY A tab] 1pt ink | [DAY B tab] 1pt ink | … | [+ tab in signal]
//   2pt bruInk bottom rule via BRUDivider(.ink)
//
// Active tab: bruInk fill, bruPaper text.
// Inactive tab: transparent (bruPaper) fill, bruInk text.
// "+" trailing tab: bruSignal text.
//
// Reference: bru-screens/routine-builder.jsx lines 20-38.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//
// NOTE: RoutineDay is a local value type defined in this file.
// The current data model (RoutineDraft) is single-day; day tabs are a
// forward-compatible visual shell — the RoutineBuilderView binds a static
// [RoutineDay] derived from the routine name / session label. Multi-day
// routing will be wired in a future plan without changing this component's API.

import SwiftUI

// MARK: - RoutineDay

/// A single day entry displayed in the `RoutineBuilderDayTabs` strip.
///
/// `label` is rendered UPPERCASE in `BRUFont.labelSmall` + 1.2 letterspacing.
/// `id` uniquely identifies the tab; `selectedDayID` binding selects it.
public struct RoutineDay: Identifiable, Hashable {
    public let id: UUID
    public let label: String

    public init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

// MARK: - RoutineBuilderDayTabs

/// Horizontal tab strip of routine-day entries with a trailing "+" entry for adding a day.
///
/// Active tab: `bruInk` fill + `bruPaper` text.
/// Inactive tab: transparent fill + `bruInk` text.
/// Trailing "+" tab: `bruSignal` text, always 36pt wide (matching JSX `flex: 0 0 36px`).
/// Tabs are separated by 1pt `bruInk` vertical rectangles.
/// A 2pt `bruInk` bottom rule spans the full width.
public struct RoutineBuilderDayTabs: View {

    // MARK: Properties

    public let days: [RoutineDay]
    @Binding public var selectedDayID: UUID?
    public let onAddDay: () -> Void

    // MARK: Init

    public init(
        days: [RoutineDay],
        selectedDayID: Binding<UUID?>,
        onAddDay: @escaping () -> Void
    ) {
        self.days = days
        self._selectedDayID = selectedDayID
        self.onAddDay = onAddDay
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Day tabs
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isActive = selectedDayID == day.id
                    let isLast = index == days.count - 1

                    // Tab button
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.label)
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isActive ? Color.bruInk : Color.clear)
                    }
                    .buttonStyle(.plain)

                    // 1pt bruInk vertical separator between tabs (not after last tab before "+")
                    if !isLast || !days.isEmpty {
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(width: 1)
                    }
                }

                // Trailing "+" add-day button — 36pt wide per JSX reference
                Button(action: onAddDay) {
                    Text("+")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruSignal)
                        .frame(width: 36, minHeight: 40)
                }
                .buttonStyle(.plain)
            }

            // 2pt bruInk bottom rule — section boundary per UI-SPEC v2 line 82
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RoutineBuilderDayTabs — 4 days") {
    @Previewable @State var selectedID: UUID? = nil
    let days = [
        RoutineDay(label: "Push A"),
        RoutineDay(label: "Pull A"),
        RoutineDay(label: "Push B"),
        RoutineDay(label: "Pull B"),
    ]
    let _ = { selectedID = days[0].id }()
    VStack(spacing: 0) {
        RoutineBuilderDayTabs(
            days: days,
            selectedDayID: $selectedID,
            onAddDay: {}
        )
        Color.bruBg
    }
    .onAppear { selectedID = days[0].id }
}

#Preview("RoutineBuilderDayTabs — empty (no days yet)") {
    @Previewable @State var selectedID: UUID? = nil
    VStack(spacing: 0) {
        RoutineBuilderDayTabs(
            days: [],
            selectedDayID: $selectedID,
            onAddDay: {}
        )
        Color.bruBg
    }
}
#endif
