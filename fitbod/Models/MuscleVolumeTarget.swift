//
//  MuscleVolumeTarget.swift
//  fitbod
//
//  Per-muscle weekly working-set targets, RP-style:
//    MV  — maintenance volume (min sets/week to hold gains)
//    MEV — minimum effective volume (start growth)
//    MAV — maximum adaptive volume (peak growth rate)
//    MRV — maximum recoverable volume (above = overtraining)
//
//  Phase 5 (FatigueModel) compares the user's weighted working-set count
//  per muscle per week against these thresholds and renders the volume
//  bars + deload-alert banner. Phase 1 ships the schema only; the seed
//  defaults come from RP's published values and are loaded in Phase 5.
//
//  Defaults here (8/14/22/6) are sensible mid-volume placeholders so
//  the entity doesn't fail an "all defaulted" reflection check; the
//  importer in Phase 5 will overwrite per muscle.
//

import Foundation
import SwiftData

@Model
public final class MuscleVolumeTarget {
    @Attribute(.unique) public var id: UUID = UUID()
    public var muscle: MuscleGroup? = nil
    public var mev: Int = 8
    public var mav: Int = 14
    public var mrv: Int = 22
    public var mv: Int = 6
    public var notes: String? = nil

    public init() {}
}
