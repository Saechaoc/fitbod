//
//  DeloadAdvisoryBanner.swift
//  fitbod
//
//  The deload advisory on Today: one notice row of at least 44pt.
//  "CONSIDER A DELOAD · 3 SIGNALS ›" (Signal text) opens the signals sheet;
//  DISMISS hides it for the week. Paper background, 1pt hair rule under it.
//
//  Public init UNCHANGED:
//    (advisory: DeloadAdvisory, onDismiss: () -> Void, onTapBody: () -> Void)
//

import SwiftUI

public struct DeloadAdvisoryBanner: View {
    public let advisory: DeloadAdvisory
    public let onDismiss: () -> Void
    public let onTapBody: () -> Void

    public init(
        advisory: DeloadAdvisory,
        onDismiss: @escaping () -> Void,
        onTapBody: @escaping () -> Void
    ) {
        self.advisory = advisory
        self.onDismiss = onDismiss
        self.onTapBody = onTapBody
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapBody) {
                Text("CONSIDER A DELOAD · \(BRUCountLabel.text(advisory.firedSignals.count, "SIGNAL")) ›")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruSignalText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bruRow)

            Button("DISMISS", action: onDismiss)
                .buttonStyle(.plain)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .foregroundStyle(Color.bruInk)
                .bruHitArea()
                .accessibilityLabel("Dismiss deload advisory")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.bruPaper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bruHair).frame(height: 1)
        }
    }
}
