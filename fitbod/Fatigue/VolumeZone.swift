//
//  VolumeZone.swift
//  fitbod
//
//  Phase 5 D-05 verbatim: the zone enum + free function the entire fatigue
//  surface keys off. The four cases name the four monotonic regions of the
//  per-muscle weekly weighted set count:
//
//    currentSets < MEV          → .belowMEV     (need more stimulus)
//    MEV ≤ currentSets < MAV    → .productive   (right where you want to be)
//    MAV ≤ currentSets < MRV    → .nearMRV      (first fatigue warning)
//    MRV ≤ currentSets          → .overMRV     (deload now)
//
//  Strict `<` semantics per the user's locked Swift snippet (D-05). Do NOT
//  switch to `<=` anywhere — the asymmetric boundaries are intentional:
//  hitting MEV exactly puts you in `.productive` (you've earned growth);
//  hitting MAV exactly puts you in `.nearMRV` (the warning starts).
//
//  Verb copy per D-06 verbatim (UI-SPEC §Copywriting Contract):
//    .belowMEV   → "Below MEV — add volume"             (no trailing period)
//    .productive → "Productive range — hold/progress"   (no trailing period)
//    .nearMRV    → "Near MRV — deload soon if performance or recovery drops."
//    .overMRV    → "Over MRV — deload recommended."
//
//  Trailing-period asymmetry is intentional and tested in
//  VolumeZoneVerbCopyTests.verbPunctuationAsymmetry. The first two zones
//  invite action; the latter two state a recommendation as a complete
//  sentence.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable (value-type
//  enum / pure function — FOUND-07).
//

import Foundation

/// The four monotonic zones of weekly per-muscle weighted set volume,
/// keyed off the MEV / MAV / MRV thresholds (`MuscleVolumeTarget`).
public enum VolumeZone: Sendable, Equatable {
    case belowMEV
    case productive
    case nearMRV
    case overMRV
}

/// Classify a weighted-set count into a `VolumeZone` using strict `<`
/// boundaries per D-05. Use this everywhere — bar fill, heatmap tint,
/// verb-label selection.
public func volumeZone(currentSets: Int, mev: Int, mav: Int, mrv: Int) -> VolumeZone {
    if currentSets < mev { return .belowMEV }
    if currentSets < mav { return .productive }
    if currentSets < mrv { return .nearMRV }
    return .overMRV
}

extension VolumeZone {
    /// The verbatim D-06 verb copy displayed under the volume bar and in
    /// per-muscle detail headers. Character-for-character — including the
    /// intentional trailing-period asymmetry between the first two and
    /// last two zones. Tested in VolumeZoneVerbCopyTests.
    public var verb: String {
        switch self {
        case .belowMEV:
            return "Below MEV — add volume"
        case .productive:
            return "Productive range — hold/progress"
        case .nearMRV:
            return "Near MRV — deload soon if performance or recovery drops."
        case .overMRV:
            return "Over MRV — deload recommended."
        }
    }
}
