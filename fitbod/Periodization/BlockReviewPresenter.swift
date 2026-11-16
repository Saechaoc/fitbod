//
//  BlockReviewPresenter.swift
//  fitbod
//
//  Opens a finished block's review as a sheet and records the review as
//  seen when the sheet closes, by any route: ‹ BACK, a swipe, or a next
//  block saved from it (RM-013, O-5). Today's review notice and Block
//  overview's REVIEW ▸ and END BLOCK open reviews through it.
//

import SwiftData
import SwiftUI

/// What one opener of block reviews keeps: the review on screen, the block
/// it opened, kept for the close because the sheet's item is nil by then,
/// and the block whose close last failed to save.
@MainActor
struct BlockReviewPresenter {
    /// Under the row that opened a review whose close did not save.
    static let unsavedMessage = "Couldn't save the review. Open it again to retry."

    /// The review the sheet shows; the sheet sets it nil as it closes.
    var showing: Block?
    private var opened: Block?
    /// The block whose review a close could not record, until a later close saves it.
    private(set) var unsavedID: UUID?

    mutating func open(_ block: Block) {
        opened = block
        showing = block
    }

    /// Records the review the sheet showed as seen. A review seen before
    /// keeps its first date; a failed save leaves it unseen and says so.
    mutating func close(in context: ModelContext, now: Date = .now) {
        guard let block = opened else { return }
        opened = nil
        do {
            #if DEBUG
            if Self.failNextSave, block.reviewedAt == nil {
                Self.failNextSave = false
                // What a failed save does: the write is rolled back, then thrown.
                block.reviewedAt = now
                SessionSetActions.rollBack(context)
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try BlockReviewStatistics.acknowledge(block: block, context: context, now: now)
            unsavedID = nil
        } catch {
            unsavedID = block.id
        }
    }

    /// The last close of `block`'s review did not save.
    func isUnsaved(_ block: Block) -> Bool {
        unsavedID == block.id
    }

    #if DEBUG
    /// `-fitbod-fail-review-save-once`: the next close fails, for captures.
    private static var failNextSave = ProcessInfo.processInfo.arguments.contains("-fitbod-fail-review-save-once")
    #endif
}

extension View {
    /// The block review `presenter` opens, as a sheet whose close records
    /// the review (RM-013). `origin` is the tab this view is on, which New
    /// block over the review names and returns to (RM-016).
    func blockReviewSheet(_ presenter: Binding<BlockReviewPresenter>, origin: BlockBuilderView.Origin) -> some View {
        modifier(BlockReviewSheet(presenter: presenter, origin: origin))
    }
}

private struct BlockReviewSheet: ViewModifier {
    @Binding var presenter: BlockReviewPresenter
    let origin: BlockBuilderView.Origin
    @Environment(\.modelContext) private var ctx

    func body(content: Content) -> some View {
        content.sheet(item: $presenter.showing, onDismiss: { presenter.close(in: ctx) }) { block in
            BlockReviewView(block: block, origin: origin)
                .presentationDetents([.large])
        }
    }
}
