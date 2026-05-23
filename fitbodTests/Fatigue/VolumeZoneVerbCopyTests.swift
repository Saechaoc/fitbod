//
//  VolumeZoneVerbCopyTests.swift
//  fitbodTests
//
//  Pins the D-06 verbatim verb copy character-for-character. The four
//  strings are the entire user-visible label set on volume bars and in
//  per-muscle detail headers; flipping a character here is a UX
//  regression Phase 2/3 voice conventions explicitly call out.
//
//  Intentional punctuation asymmetry (also pinned):
//    .belowMEV   → "Below MEV — add volume"             (no trailing period)
//    .productive → "Productive range — hold/progress"   (no trailing period)
//    .nearMRV    → "Near MRV — deload soon if performance or recovery drops."
//                                                       (trailing period)
//    .overMRV    → "Over MRV — deload recommended."     (trailing period)
//
//  The first two invite action — short, no terminator. The latter two
//  state a recommendation as a complete sentence. UI-SPEC §Copywriting
//  Contract calls this out explicitly.
//

import Foundation
import Testing
@testable import fitbod

@Suite("VolumeZoneVerbCopy")
struct VolumeZoneVerbCopyTests {

    @Test("D-06 verbatim: .belowMEV → \"Below MEV — add volume\"")
    func belowMEVVerbVerbatim() {
        #expect(VolumeZone.belowMEV.verb == "Below MEV — add volume")
    }

    @Test("D-06 verbatim: .productive → \"Productive range — hold/progress\"")
    func productiveVerbVerbatim() {
        #expect(VolumeZone.productive.verb == "Productive range — hold/progress")
    }

    @Test("D-06 verbatim: .nearMRV → \"Near MRV — deload soon if performance or recovery drops.\"")
    func nearMRVVerbVerbatim() {
        #expect(VolumeZone.nearMRV.verb == "Near MRV — deload soon if performance or recovery drops.")
    }

    @Test("D-06 verbatim: .overMRV → \"Over MRV — deload recommended.\"")
    func overMRVVerbVerbatim() {
        #expect(VolumeZone.overMRV.verb == "Over MRV — deload recommended.")
    }

    @Test("Trailing-period asymmetry: .belowMEV and .productive have NO period; .nearMRV and .overMRV DO have a period")
    func verbPunctuationAsymmetry() {
        #expect(!VolumeZone.belowMEV.verb.hasSuffix("."))
        #expect(!VolumeZone.productive.verb.hasSuffix("."))
        #expect(VolumeZone.nearMRV.verb.hasSuffix("."))
        #expect(VolumeZone.overMRV.verb.hasSuffix("."))
    }
}
