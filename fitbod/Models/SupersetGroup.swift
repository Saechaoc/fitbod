//
//  SupersetGroup.swift
//  fitbod
//
//  Groups two or more `RoutineExercise` rows that should be performed
//  back-to-back as a superset (paired) or giant set (3+). Per CONTEXT.md
//  Area 1, supersets are modeled as a separate entity with soft `UUID`
//  refs in both directions:
//
//    - `SupersetGroup.routineID: UUID` → the Routine that owns the group
//    - `RoutineExercise.supersetGroupID: UUID?` → the group this row joins
//
//  Neither side is a SwiftData relationship, so deleting a Routine does
//  NOT cascade-delete its SupersetGroups automatically; the route-delete
//  handler in plan 03-01 query-and-deletes orphaned groups instead. This
//  keeps the cascade rules predictable and prevents a `Routine` delete
//  from wiping data via an unintended relationship traversal.
//
//  `kindRaw: String` follows the FOUND-03 enum-as-rawString pattern; the
//  matching `SupersetKind` enum + `kind` computed accessor live in this
//  file so the data shape and the consumer shape ship together.
//
//  Every field has a default value (FOUND-02 — iCloud-shape insurance).
//

import Foundation
import SwiftData

@Model
public final class SupersetGroup {
    @Attribute(.unique) public var id: UUID = UUID()
    public var routineID: UUID = UUID()
    public var kindRaw: String = "paired"
    public var sortOrder: Int = 0
    public var createdAt: Date = Date.now

    public init() {}

    public convenience init(routineID: UUID, kindRaw: String = "paired", sortOrder: Int = 0) {
        self.init()
        self.routineID = routineID
        self.kindRaw = kindRaw
        self.sortOrder = sortOrder
    }
}

public enum SupersetKind: String, CaseIterable, Sendable {
    case paired
    case giant

    public static let `default`: SupersetKind = .paired
}

extension SupersetGroup {
    public var kind: SupersetKind { SupersetKind(rawValue: kindRaw) ?? .paired }
}
