//
//  SplitSessionSlot.swift
//  fitbod
//
//  A slot within a `Split` — associates a position index with a
//  `SessionTemplate`. Acts as the join entity between Split and
//  SessionTemplate, analogous to BlockPhase within a Block.
//
//  V7 new entity (Phase 7 program-graph migration).
//
//  Delete rules (T-07-05):
//    - `sessionTemplate`: `.deny` — hard-deleting a slotted SessionTemplate
//      is refused while any slot references it; callers must unlink first.
//    - `split`: plain var — inverse declared on Split.slots (cascade).
//      Deleting the parent Split cascade-deletes all its slots.
//    - `Session.slot`: nullify (default) — deleting a slot sets
//      Session.slot = nil; session history is never erased.
//
//  No `#Unique` on (split, position) — SwiftData upserts on collision →
//  silent slot merge. Contiguity is enforced via test invariant (spec §3 /
//  PITFALLS #5) and reindex-on-write in Phase 9.
//

import Foundation
import SwiftData

@Model
public final class SplitSessionSlot {
    @Attribute(.unique) public var id: UUID = UUID()

    // Inverse declared on Split.slots (single-sided convention).
    public var split: Split? = nil

    // Explicit order — SwiftData to-many is unordered.
    public var position: Int = 0

    // .deny: refuse hard-delete while slotted; soft-delete (isArchived) unaffected.
    // Session.slot nullifies on slot delete — never cascade into history (Pitfall 6).
    @Relationship(deleteRule: .deny)
    public var sessionTemplate: SessionTemplate? = nil

    public init() {}
}
