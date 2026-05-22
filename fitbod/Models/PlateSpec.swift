//
//  PlateSpec.swift
//  fitbod
//
//  A single plate specification within a `PlateInventory`. Each spec
//  describes one plate denomination (weight in kg or lb), how many of
//  that plate are available per side of the bar, and an optional display
//  color string (for plate-stack visualization in Phase 3 UI).
//
//  Stored as an element of `PlateInventory.availablePlates: [PlateSpec]`,
//  which is JSON-encoded into the `availablePlatesData: Data` field on the
//  @Model entity (PATTERNS.md Data-field + computed Codable accessor pattern,
//  lines 228–242).
//

import Foundation

public struct PlateSpec: Codable, Sendable, Equatable, Hashable {
    public let weight: Double
    public let countPerSide: Int
    public let color: String?

    public init(weight: Double, countPerSide: Int, color: String? = nil) {
        self.weight = weight
        self.countPerSide = countPerSide
        self.color = color
    }
}
