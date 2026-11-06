// BlockScheduleControls.swift
// fitbod
//
// The scheduling controls the block builder's routine band and the block
// overview share: the ROTATION / FIXED WEEKLY chips, the training-day chips
// and their grid, the days/sessions mismatch hint, and the routine picker.
// One copy, so an accessibility fix (T25, T38) lands on both screens.

import SwiftUI
import SwiftData

/// ROTATION or FIXED WEEKLY. The chip draws compact inside a 44pt-tall tap
/// target, the height of the row it sits in, and grows to 44pt at
/// accessibility sizes (T25, T38).
struct SchedulingModeChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: String
    let selected: Bool
    let action: () -> Void

    init(_ label: String, selected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.bru(.grotesk, size: 9))
                .tracking(2.1)
                .foregroundStyle(selected ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : nil)
                .background(selected ? Color.bruInk : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: selected ? 1.5 : 1.0)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) scheduling")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One weekday's toggle. At standard sizes the 28pt chip takes taps 44pt
/// tall and 1pt past each side, which makes the 42pt chips of the 390pt
/// phone 44pt wide and leaves 2pt of the 4pt gap between neighbors; at
/// accessibility sizes it grows to its letter and to 44pt (T25, T38).
struct TrainingDayChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let letter: String
    /// The full name, such as "Monday", for VoiceOver.
    let weekdayName: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(letter)
                .font(.bru(.grotesk, size: 9))
                .tracking(2.1)
                .foregroundStyle(selected ? Color.bruPaper : Color.bruMuted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 28)
                .background(selected ? Color.bruInk : Color.bruFaint)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: selected ? 1.5 : 1.0)
                )
                .bruHitArea(
                    horizontal: dynamicTypeSize.isAccessibilitySize ? 0 : 1,
                    vertical: dynamicTypeSize.isAccessibilitySize ? 0 : 8
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekdayName)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(selected ? "on" : "off")
    }
}

/// The week's seven days in Monday-first order: Calendar weekday, chip
/// letter and full name.
let trainingWeekdays: [(weekday: Int, letter: String, name: String)] = [
    (2, "M", "Monday"), (3, "T", "Tuesday"), (4, "W", "Wednesday"),
    (5, "T", "Thursday"), (6, "F", "Friday"), (7, "S", "Saturday"), (1, "S", "Sunday"),
]

/// Lays its subviews out left to right in rows of `columns` equal cells,
/// each row as tall as its tallest subview (T25).
struct DayGridLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? CGFloat(columns) * 44 + CGFloat(columns - 1) * spacing
        let rows = rowHeights(of: subviews, cell: cellWidth(in: width))
        return CGSize(width: width, height: rows.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellWidth(in: bounds.width)
        var y = bounds.minY
        for (row, height) in rowHeights(of: subviews, cell: cell).enumerated() {
            for column in 0..<columns where row * columns + column < subviews.count {
                subviews[row * columns + column].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (cell + spacing), y: y),
                    proposal: ProposedViewSize(width: cell, height: height)
                )
            }
            y += height + spacing
        }
    }

    private func cellWidth(in width: CGFloat) -> CGFloat {
        max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
    }

    private func rowHeights(of subviews: Subviews, cell: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }
                .max() ?? 0
        }
    }
}

extension DayGridLayout {
    /// The seven days in a row, or, at accessibility sizes, four to a row,
    /// so each day stays a 44pt tap target (T25).
    static func days(accessibilitySize: Bool) -> AnyLayout {
        accessibilitySize
            ? AnyLayout(DayGridLayout(columns: 4, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
    }
}

/// "N days / M sessions", shown when a block's training days and its
/// routine's sessions differ. Amber text read at 2.14:1 on light paper, so
/// in light mode the hint is a dark label on an amber fill, drawn past the
/// text without moving it; dark mode keeps amber text (T38, F102).
struct ScheduleMismatchHint: View {
    @Environment(\.colorScheme) private var colorScheme
    let days: Int
    let sessions: Int

    var body: some View {
        Text("\(BRUCountLabel.text(days, "day")) / \(BRUCountLabel.text(sessions, "session"))")
            .font(.bru(.grotesk, size: 10))
            .tracking(2.2)
            .foregroundStyle(colorScheme == .dark ? Color.bruAmber : Color.bruOnSignal)
            .background {
                if colorScheme != .dark {
                    Color.bruAmber
                        .padding(.horizontal, -4)
                        .padding(.vertical, -2)
                }
            }
    }
}

/// Lists the non-archived routines; a tap reports one. The header's CANCEL
/// closes the sheet without one (T38). BRU chrome: BRUHeaderBar and rows
/// with hair dividers, no List or navigation title.
struct RoutinePickerSheet: View {
    @Query(filter: #Predicate<Split> { !$0.isArchived }, sort: \Split.name)
    private var splits: [Split]

    let selectedSplit: Split?
    let onSelect: (Split) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar.slots(left: .cancel, center: "Choose Routine")

                ScrollView {
                    if splits.isEmpty {
                        noRoutines
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(splits) { split in
                            Button {
                                onSelect(split)
                            } label: {
                                HStack {
                                    Text(split.name)
                                        .font(.bru(.grotesk, size: 13))
                                        .foregroundStyle(Color.bruInk)
                                    Spacer()
                                    if split.id == selectedSplit?.id {
                                        Text("✓")
                                            .font(.bru(.grotesk, size: 13))
                                            .foregroundStyle(Color.bruSignalText)
                                    }
                                }
                                .frame(minHeight: 44)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            BRUDivider(.hair)
                        }
                    }
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
    }

    /// With no routine to pick, says why the list is empty and where a
    /// routine is made (D-162).
    private var noRoutines: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No routines yet")
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
            Text("A block runs on a routine. Make one on Program with + NEW, then + New routine, and attach it here.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
