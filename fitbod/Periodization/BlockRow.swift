//
//  BlockRow.swift
//  fitbod
//
//  Row for one periodization block in the Routines tab.
//

import SwiftUI

public struct BlockRow: View {
    public let block: Block
    public let onTap: (Block) -> Void
    public let onDelete: (Block) -> Void

    public init(
        block: Block,
        onTap: @escaping (Block) -> Void,
        onDelete: @escaping (Block) -> Void
    ) {
        self.block = block
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 8) {
            if block.isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(block.name)
                    .font(.body)
                Text(Self.captionText(for: block))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Self.weekBadgeText(for: block))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(block) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(block)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(Self.accessibilityLabelText(for: block))
        .accessibilityHint("Tap to edit. Swipe left to delete.")
    }

    public static func sortedForDisplay(_ blocks: [Block]) -> [Block] {
        blocks.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.startDate > rhs.startDate
        }
    }

    public static func captionText(for block: Block, now: Date = .now) -> String {
        if let endDate = block.endDate, endDate < now {
            return "Ended \(formattedDate(endDate))"
        }
        if block.startDate > now {
            return "Starting \(formattedDate(block.startDate))"
        }
        return "Started \(formattedDate(block.startDate))"
    }

    public static func weekBadgeText(for block: Block, now: Date = .now) -> String {
        let totalWeeks = totalWeeks(for: block)
        guard block.isActive else {
            return "\(totalWeeks) \(totalWeeks == 1 ? "week" : "weeks")"
        }

        let index = PeriodizationEngine.weekIndex(for: block, on: now) ?? 0
        let displayIndex = min(max(index + 1, 1), max(totalWeeks, 1))
        return "Week \(displayIndex) of \(totalWeeks)"
    }

    public static func accessibilityLabelText(for block: Block, now: Date = .now) -> String {
        let status = block.isActive ? "active" : "inactive"
        return "\(block.name), \(status), \(weekBadgeText(for: block, now: now))"
    }

    private static func totalWeeks(for block: Block) -> Int {
        (block.phases ?? []).reduce(0) { $0 + $1.weeks }
    }

    private static func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
