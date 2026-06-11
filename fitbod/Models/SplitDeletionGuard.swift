//
//  SplitDeletionGuard.swift
//  fitbod
//
//  WR-03 (Phase 7 review): service-layer deny for Split deletion/archive.
//
//  Spec §4 requires: a Split cannot be hard-deleted OR archived while it is
//  referenced by any *non-completed* block (draft / ready / active). A split
//  referenced ONLY by completed blocks may be deleted — completed blocks
//  render from `Block.archivedConfigJSON`, never from the live split, so the
//  nullify on `Block.split` (see Split.swift) takes nothing down.
//
//  This is deliberately a SERVICE-LAYER rule, not a SwiftData schema rule:
//  SwiftData's `@Relationship(deleteRule: .deny)` is unconditional — it would
//  also refuse deletion when only completed blocks remain, which spec §4
//  explicitly wants to allow. Hence the conditional check lives here.
//
//  Phase 7 scope: the helper + its unit test satisfy the spec §4 contract.
//  No UI deletes/archives splits yet; Phase 8 wires this guard into
//  `SplitDetailView` (the archive action) where deletion/archive becomes
//  reachable.
//

import Foundation

/// Thrown when a Split cannot be deleted or archived because a live
/// (non-completed) block still references it.
public enum SplitDeletionError: Error, Equatable, Sendable {
    /// At least one draft / ready / active block references the split.
    case referencedByLiveBlock
}

public enum SplitDeletionGuard {

    /// Returns `true` when `split` may be hard-deleted or archived — i.e. no
    /// referencing block is in a non-completed state.
    ///
    /// A block counts as a live reference when `derivedStatus != .completed`
    /// (draft, ready, or active). Completed blocks are ignored (they survive
    /// via the archive).
    public static func canDelete(_ split: Split) -> Bool {
        !(split.blocks ?? []).contains { $0.derivedStatus != .completed }
    }

    /// Throws `SplitDeletionError.referencedByLiveBlock` when `split` is
    /// referenced by any non-completed block. Call before deleting OR
    /// archiving a split (spec §4 — archiving mirrors the same rule).
    public static func assertDeletable(_ split: Split) throws {
        guard canDelete(split) else {
            throw SplitDeletionError.referencedByLiveBlock
        }
    }
}
