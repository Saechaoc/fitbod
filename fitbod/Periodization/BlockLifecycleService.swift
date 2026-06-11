//
//  BlockLifecycleService.swift
//  fitbod
//
//  Phase 08 Plan 03 — SPEC-8-LIFECYCLE + SPEC-8-ARCHIVE + SPEC-8-GUARDS.
//
//  One-save start / end / swapSplit / attachSplit transactions.
//  Archive string computed BEFORE the transaction so an encoder throw
//  aborts before any SwiftData state is committed (Pitfall 4).
//
//  Atomicity invariants guaranteed by the implementation:
//    - No zero-or-two-actives window during start-swap (T-08-04):
//      All deactivation + activation happens in a single context.transaction.
//    - No completed-without-archive window during end (T-08-05):
//      archive encoded pre-transaction; endDate + archivedConfigJSON
//      assigned together in the same context.save().
//
//  SplitDeletionGuard is THE enforcement seam for split delete/archive (T-08-07).
//  BlockLifecycleService.assertSplitDeletable is a thin delegation wrapper —
//  it must NOT duplicate the predicate from SplitDeletionGuard.
//
//  ArchiveUnreadableError (T-08-06):
//  Phase 9 renders "Archive unreadable" when this error is thrown.
//  decodeArchive(_:) wraps ArchivedBlockConfig.decode with NO live-template fallback.
//

import Foundation
import SwiftData

// MARK: - Typed errors

/// Thrown by lifecycle mutation functions when the operation is refused.
public enum BlockLifecycleError: Error, Equatable, Sendable {
    /// The block is not in `.ready` status and cannot be started.
    case notReady

    /// The block is not in `.active` status and cannot be ended (spec §4 —
    /// only active blocks can be ended; ending a draft/ready block would
    /// stamp an archive with a never-started block's default startDate).
    case notActive

    /// Split swap/attach is refused on an active block — changing the split IS ending the block.
    case splitChangeOnActiveBlock
}

/// Thrown by `decodeArchive(_:)` when the archive JSON cannot be decoded.
///
/// Phase 9 renders an "Archive unreadable" error state when this is thrown.
/// Per spec §6: NO live-template fallback.
public enum ArchiveUnreadableError: Error, Equatable, Sendable {
    /// The archive JSON failed to decode into `ArchivedBlockConfig`.
    case decodeFailed
}

// MARK: - BlockLifecycleService

/// Namespace for all block lifecycle mutations.
///
/// All mutations that change `Block.isActive`, `Block.endDate`, or
/// `Block.archivedConfigJSON` MUST go through this service — never mutate
/// those fields directly from a view.
public enum BlockLifecycleService {

    // MARK: - start

    /// Starts `block` by activating it.
    ///
    /// If another block is currently active, that block is ended and archived atomically
    /// in the same transaction (the "swap" path). This guarantees no zero-or-two-actives
    /// window exists between the two operations (spec §4, T-08-04).
    ///
    /// - Precondition: `block.derivedStatus == .ready`
    /// - Throws: `BlockLifecycleError.notReady` when precondition fails.
    /// - Throws: Any encoder error from `ArchivedBlockConfig.write` (abort-before-mutation).
    public static func start(block: Block, context: ModelContext, now: Date = .now) throws {
        guard block.derivedStatus == .ready else {
            throw BlockLifecycleError.notReady
        }

        // Encode archives for currently active blocks BEFORE the transaction.
        // An encoder error here aborts before any state mutation (Pitfall 4).
        let myID = block.id
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.isActive == true })
        let activeBlocks = (try? context.fetch(descriptor)) ?? []
        let othersWithArchive: [(Block, String)] = try activeBlocks
            .filter { $0.id != myID }
            .map { other in
                let json = try ArchivedBlockConfig.write(from: other, endedAt: now)
                return (other, json)
            }

        // Single transaction: deactivate others, activate new block.
        // No context.save() outside this transaction for lifecycle operations.
        try context.transaction {
            for (other, json) in othersWithArchive {
                other.endDate = now
                other.archivedConfigJSON = json
                other.isActive = false
            }
            block.isActive = true
            block.startDate = now
            try context.save()
        }
        // Transition assertion (comment — checked by test 11):
        // After start: block.isActive ⇒ block.split != nil && block.endDate == nil
    }

    // MARK: - end

    /// Ends `block` by setting `endDate` and writing the freeze-#2 archive JSON.
    ///
    /// The archive string is encoded BEFORE the transaction so an encoder throw
    /// aborts before `endDate` is set. `endDate` and `archivedConfigJSON` are
    /// always set in the same `context.save()` — a block can never have `endDate`
    /// without a corresponding archive (spec §6, T-08-05, Pitfall 4).
    ///
    /// - Precondition: `block.derivedStatus == .active`
    /// - Throws: `BlockLifecycleError.notActive` when the block is not active —
    ///   ending a draft/ready block would archive a never-started block with a
    ///   default `startDate`, producing a corrupt completed block (spec §4).
    /// - Throws: Any encoder error from `ArchivedBlockConfig.write`.
    public static func end(block: Block, context: ModelContext, now: Date = .now) throws {
        // WR-04: symmetric guard to start's .ready check — only active blocks
        // can be ended. Checked BEFORE the encode/transaction (abort-before-mutation).
        guard block.derivedStatus == .active else {
            throw BlockLifecycleError.notActive
        }

        // Encode BEFORE entering the transaction — abort-before-mutation guarantee.
        let json = try ArchivedBlockConfig.write(from: block, endedAt: now)

        try context.transaction {
            block.isActive = false
            block.endDate = now
            block.archivedConfigJSON = json
            try context.save()
        }
    }

    // MARK: - attachSplit / swapSplit

    /// Attaches `split` to `block`.
    ///
    /// Refused when `block.derivedStatus == .active` — changing the split
    /// is semantically equivalent to ending the block (spec §4).
    ///
    /// - Throws: `BlockLifecycleError.splitChangeOnActiveBlock` when refused.
    public static func attachSplit(_ split: Split, to block: Block, context: ModelContext) throws {
        guard block.derivedStatus != .active else {
            throw BlockLifecycleError.splitChangeOnActiveBlock
        }
        try context.transaction {
            block.split = split
            try context.save()
        }
    }

    /// Swaps the split on `block` to `split`.
    ///
    /// Semantically identical to `attachSplit(_:to:context:)` — both write
    /// `block.split = split` inside a transaction. Swap is just attach over
    /// an existing split. Refused on active blocks for the same reason.
    ///
    /// - Throws: `BlockLifecycleError.splitChangeOnActiveBlock` when refused.
    public static func swapSplit(_ split: Split, on block: Block, context: ModelContext) throws {
        try attachSplit(split, to: block, context: context)
    }

    // MARK: - assertSplitDeletable

    /// Delegates to `SplitDeletionGuard.assertDeletable` — THE enforcement seam
    /// for split delete AND archive (spec §4 / T-08-07, SPEC-8-GUARDS).
    ///
    /// Wired into Phase 9 `SplitDetailView` delete AND archive actions.
    ///
    /// - Throws: `SplitDeletionError.referencedByLiveBlock` when any non-completed
    ///   block references the split.
    public static func assertSplitDeletable(_ split: Split) throws {
        try SplitDeletionGuard.assertDeletable(split)
    }

    // MARK: - decodeArchive

    /// Decodes `json` into an `ArchivedBlockConfig`.
    ///
    /// Per spec §6: throws `ArchiveUnreadableError.decodeFailed` on failure.
    /// NO live-template fallback — callers must surface an explicit error state.
    /// Phase 9 renders "Archive unreadable" when this throws.
    public static func decodeArchive(_ json: String) throws -> ArchivedBlockConfig {
        let data = Data(json.utf8)
        do {
            return try ArchivedBlockConfig.decode(from: data)
        } catch {
            throw ArchiveUnreadableError.decodeFailed
        }
    }
}
