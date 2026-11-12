// ReadyBlockCard.swift
// fitbod
//
// The oldest ready block's hero, with its creation date and ready count.
// Start uses the lifecycle service; Open keeps the plan reachable.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
// NO Image(systemName:) / NO .font(.body/.headline/.title*/.caption)

import SwiftUI

struct ReadyBlockCard: View {
    let block: Block
    let readyCount: Int
    let onStart: () -> Void
    let onOpen: () -> Void
    /// START BLOCK ▸ in signal, the page's one action. On Program a workout
    /// in progress holds the signal, so it draws as the ghost (RM-012).
    var isSignal = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSlab.opacity(0.6))
            BRUDisplay(block.name, size: .hero, color: .bruOnSlab)
            Text(Self.summary(of: block))
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSlab)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.created(block) + (readyCount > 1 ? " · 1 of \(readyCount) ready" : ""))
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSlab.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            BRUButton("Start block ▸", kind: isSignal ? .signal : .ghost, size: .lg, action: onStart)
                .accessibilityIdentifier("today.startBlock")
            Button(action: onOpen) {
                Text("Open ›")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruOnSlab)
                    .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.openReadyBlock")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bruSlabBackground()
    }

    /// "Created Oct 3": `startDate` is the creation date until the block starts (O-14).
    static func created(_ block: Block) -> String {
        "Created \(block.startDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    static func summary(of block: Block) -> String {
        let phases = block.phases ?? []
        var parts = [BRUCountLabel.text(phases.reduce(0) { $0 + $1.weeks }, "week"),
                     BRUCountLabel.text(phases.count, "phase")]
        if let routine = block.split?.name, !routine.isEmpty {
            parts.append(routine)
        }
        return parts.joined(separator: " · ")
    }
}
