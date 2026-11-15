// BlockReviewNotice.swift
// fitbod
//
// Today's notice row while the last ended block's review is pending
// (RM-013): "SUMMER BLOCK FINISHED · REVIEW ›" above the hero, opening the
// review. Nothing opens by itself. A long name loses its tail, never the
// action, and at accessibility sizes the action goes under the name.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
// NO Image(systemName:) / NO .font(.body/.headline/.title*/.caption)

import SwiftUI

struct BlockReviewNotice: View {
    let block: Block
    /// The last close did not save, so the row says so until a later close saves.
    let isUnsaved: Bool
    let onReview: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let title = "\(block.programName) finished"
        Button(action: onReview) {
            VStack(alignment: .leading, spacing: 4) {
                layout {
                    Text(title)
                        .foregroundStyle(Color.bruInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 12)
                    }
                    Text("Review ›")
                        .foregroundStyle(Color.bruSignalText)
                        .fixedSize()
                }
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                if isUnsaved {
                    Text(BlockReviewPresenter.unsavedMessage)
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruSignalText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            .background(Color.bruPaper)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.bruHair).frame(height: 1) }
        }
        .buttonStyle(.bruRow)
        .accessibilityLabel(isUnsaved ? "\(title). \(BlockReviewPresenter.unsavedMessage)" : title)
        .accessibilityHint("Opens its review")
        .accessibilityIdentifier("today.reviewNotice")
    }

    /// One row; at accessibility sizes the action goes under the name.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 0))
    }
}
