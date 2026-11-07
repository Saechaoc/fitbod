// TodayPlanLine.swift
// fitbod
//
// The one block row on Today: the block's name over its week and phase,
// opening Block overview. Replaces the stat strip, block band and week cells.

import SwiftUI

struct TodayPlanLine: View {
    let block: Block
    let now: Date
    let onOpen: () -> Void

    var body: some View {
        let position = BlockPosition.label(block, on: now)
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(BRUFont.labelSmall)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(position.line)
                        .font(BRUFont.labelSmall)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("›")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.bruHair).frame(height: 1)
            }
        }
        .buttonStyle(.bruRow)
        .accessibilityIdentifier("today.planLine")
        .accessibilityLabel("\(block.name), \(position.spoken)")
    }
}
