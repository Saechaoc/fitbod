//
//  RoutineFolder.swift
//  fitbod
//
//  Single-level folder for grouping routines on the Routines tab. Per
//  CONTEXT.md Area 6, folders are intentionally flat (no nesting in v1).
//
//  `Routine.folderID: UUID?` is a soft reference — NOT a SwiftData
//  relationship — so deleting a folder never cascades into the routines
//  inside it. The folder-delete handler in plan 03-01 query-and-nulls the
//  `folderID` of contained routines back to nil, which surfaces them in
//  "Unfiled" on the Routines tab.
//
//  Every field has a default value so SchemaV2 lightweight migration from
//  SchemaV1 stores does not stall on a missing column (FOUND-02).
//

import Foundation
import SwiftData

@Model
public final class RoutineFolder {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var sortOrder: Int = 0
    public var createdAt: Date = Date.now

    public init() {}

    public convenience init(name: String, sortOrder: Int = 0) {
        self.init()
        self.name = name
        self.sortOrder = sortOrder
    }
}
