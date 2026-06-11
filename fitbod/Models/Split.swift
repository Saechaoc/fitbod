//
//  Split.swift
//  fitbod
//
//  A training split — an ordered collection of `SplitSessionSlot` rows,
//  each of which names a session template for that slot position.
//
//  V7 new entity (Phase 7 program-graph migration). A `Block` optionally
//  references a Split via `Block.split`; deleting the Split sets
//  `Block.split = nil` (nullify — completed blocks survive via
//  `Block.archivedConfigJSON`).
//
//  Cascade rules:
//    - Split → SplitSessionSlot: cascade (slots are owned by their split)
//    - Block.split → Split: nullify (default for optional — blocks outlive splits)
//

import Foundation
import SwiftData

@Model
public final class Split {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date.now
    public var isArchived: Bool = false

    // Slots cascade on split delete. Inverse declared here (single-sided convention:
    // SplitSessionSlot.split is a plain var with no @Relationship decorator).
    @Relationship(deleteRule: .cascade, inverse: \SplitSessionSlot.split)
    public var slots: [SplitSessionSlot]? = []

    // Blocks that reference this split (inverse of Block.split).
    // Nullify: deleting a Split nils Block.split; Blocks survive.
    @Relationship(deleteRule: .nullify, inverse: \Block.split)
    public var blocks: [Block]? = []

    public init() {}
}
