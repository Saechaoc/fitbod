// ExerciseHistoryRow.swift
// fitbod — Phase 2.1 Plan 10
//
// BRU rewrite of the per-exercise history row.
// UI-SPEC v2 § Exercise history view (line 437).
//
// Visual contract per UI-SPEC:
//  Top line: date displayMedium 18pt + intent BRUChip + optional '★ PR' BRUChip(.signal, fill:true)
//            right-aligned: 'e1RM {value}' displayMedium 18pt
//  Sub-line: 'TOP {weight × reps @ RPE}' BRUMono 11pt bruMuted + '· {N} sets'
//  Bottom: wrap-flow row of mono set chips — 1pt bruHair outlined Rectangles
//          (NOT capsules) holding BRUMono 11pt numerics
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

// MARK: - ExerciseHistoryRow

/// One date-session block in the exercise history list.
///
/// Receives a pre-computed `HistoryEntry` value (built by ExerciseHistoryView's
/// grouping logic) rather than raw SwiftData objects at render time.
public struct ExerciseHistoryRow: View {
    public let entry: HistoryEntry

    public init(entry: HistoryEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top line
            HStack(alignment: .center, spacing: 8) {
                Text(entry.dateLabel)
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)

                BRUChip(entry.intentLabel)

                if entry.isPR {
                    BRUChip("★ PR", color: .bruSignal, fill: true)
                }

                Spacer()

                Text("e1RM \(entry.e1RMLabel)")
                    .font(BRUFont.displayMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
            }

            // Sub-line: TOP set + set count
            HStack(spacing: 0) {
                Text("TOP ")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                Text(entry.topSetLabel)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                Text(" · \(BRUCountLabel.text(entry.setCount, "set"))")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }

            // Set chips — 1pt bruHair outlined rectangles (NOT capsules per UI-SPEC line 437)
            SetChipFlow(chips: entry.setChips)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - SetChipFlow

/// Wrapping flow of per-set chips — 1pt bruHair outlined sharp rectangles.
/// Uses a simple HStack wrapping via ViewThatFits fallback pattern on iOS 18.
private struct SetChipFlow: View {
    let chips: [String]

    var body: some View {
        FlexWrap(items: chips) { chip in
            Text(chip)
                .font(BRUFont.bodyDefault)
                .tracking(0.3)
                .monospacedDigit()
                .foregroundStyle(Color.bruInk)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruHair, lineWidth: 1)
                )
        }
    }
}

// MARK: - FlexWrap (simple wrapping layout)

/// A simple wrapping horizontal layout built from HStack rows.
/// Used for the set chip wrap-flow in ExerciseHistoryRow.
private struct FlexWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        // iOS 18+ Layout protocol would be ideal, but this simple
        // approach handles the typical 3-6 chips per row correctly.
        var rows: [[Item]] = [[]]
        for item in items {
            rows[rows.count - 1].append(item)
            if rows[rows.count - 1].count >= 4 {
                rows.append([])
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    // A chip's id is its place in the row, so repeated
                    // chips, such as three sets of 100×5 @8, all show.
                    ForEach(rows[rowIndex].indices, id: \.self) { index in
                        content(rows[rowIndex][index])
                    }
                }
            }
        }
    }
}

// MARK: - HistoryEntry (value type for the row)

/// Pre-computed value type for ExerciseHistoryRow — avoids SwiftData
/// optional-chain traversal at render time.
public struct HistoryEntry: Identifiable {
    public let id: UUID
    public let dateLabel: String       // e.g. "TODAY" or "THU MAY 16"
    public let intentLabel: String     // e.g. "HYP" or "STR"
    public let isPR: Bool
    public let e1RMLabel: String       // e.g. "248"
    public let topSetLabel: String     // e.g. "205×8 @9"
    public let setCount: Int
    public let setChips: [String]      // e.g. ["95×8 @4", "135×6 @5", ...]

    public init(
        id: UUID = UUID(),
        dateLabel: String,
        intentLabel: String,
        isPR: Bool,
        e1RMLabel: String,
        topSetLabel: String,
        setCount: Int,
        setChips: [String]
    ) {
        self.id = id
        self.dateLabel = dateLabel
        self.intentLabel = intentLabel
        self.isPR = isPR
        self.e1RMLabel = e1RMLabel
        self.topSetLabel = topSetLabel
        self.setCount = setCount
        self.setChips = setChips
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ExerciseHistoryRow") {
    VStack(spacing: 0) {
        ExerciseHistoryRow(entry: HistoryEntry(
            dateLabel: "TODAY",
            intentLabel: "HYP",
            isPR: true,
            e1RMLabel: "248",
            topSetLabel: "205×8 @9",
            setCount: 6,
            setChips: ["95×8 @4", "135×6 @5", "165×8 @7", "185×8 @8", "205×8 @9", "175×10 @8"]
        ))
        BRUDivider(.hair)
        ExerciseHistoryRow(entry: HistoryEntry(
            dateLabel: "THU MAY 16",
            intentLabel: "HYP",
            isPR: false,
            e1RMLabel: "244",
            topSetLabel: "195×8 @8.5",
            setCount: 5,
            setChips: ["95×8", "135×6", "165×8", "185×8", "195×8"]
        ))
        BRUDivider(.hair)
        ExerciseHistoryRow(entry: HistoryEntry(
            dateLabel: "MON MAY 13",
            intentLabel: "STR",
            isPR: false,
            e1RMLabel: "240",
            topSetLabel: "215×2 @9",
            setCount: 5,
            setChips: ["95×5", "135×5", "185×5", "205×3", "215×2"]
        ))
    }
    .background(Color.bruPaper)
}
#endif
