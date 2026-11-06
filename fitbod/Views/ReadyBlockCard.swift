// ReadyBlockCard.swift
// fitbod
//
// Today's block band for a ready block while none is active (gap B4,
// missing screen today-ready-block): the block's name, weeks, routine and
// days, and START BLOCK ▸, which starts it in one tap. A tap on the band
// opens the block's overview.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
// NO Image(systemName:) / NO .font(.body/.headline/.title*/.caption)

import SwiftUI

struct ReadyBlockCard: View {
    let block: Block
    let onStart: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        BRUChip("Block").fixedSize()
                        name
                        Spacer(minLength: 8)
                        BRUChip("Ready", color: .bruSignal).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            BRUChip("Block").fixedSize()
                            BRUChip("Ready", color: .bruSignal).fixedSize()
                        }
                        name
                    }
                }
                Text(Self.summary(of: block))
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Ready block: \(block.name). \(Self.summary(of: block))")

            BRUButton("START BLOCK ▸", kind: .signal, action: onStart)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.bruInk).frame(height: 2)
                }
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }

    private var name: some View {
        Text(block.name.uppercased())
            .font(.bru(.grotesk, size: 11))
            .tracking(1.2)
            .foregroundStyle(Color.bruInk)
    }

    /// "4 weeks · States Routine · Mon, Thu", or "· Rotation".
    static func summary(of block: Block, calendar: Calendar = .current) -> String {
        let weeks = (block.phases ?? []).reduce(0) { $0 + $1.weeks }
        var parts = [BRUCountLabel.text(weeks, "week")]
        if let routine = block.split?.name, !routine.isEmpty {
            parts.append(routine)
        }
        switch block.schedulingMode {
        case .rotation:
            parts.append("Rotation")
        case .fixedWeekly:
            let symbols = calendar.shortWeekdaySymbols
            parts.append(block.trainingDays.compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
                .joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }
}
