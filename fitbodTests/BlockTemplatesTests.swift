//
//  BlockTemplatesTests.swift
//  fitbodTests
//
//  Phase 4 Wave 0 coverage for stock block templates and RP default
//  multipliers.
//

import Testing
@testable import fitbod

@Suite("BlockTemplates")
struct BlockTemplatesTests {
    @Test("generic template matches D-03 structure")
    func genericMatchesD03Structure() {
        let phases = BlockTemplates.generic.phases

        #expect(BlockTemplates.generic.name == "Generic Strength Meso")
        #expect(phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(phases.map(\.weeks) == [4, 2, 1, 1])
        #expect(phases.reduce(0) { $0 + $1.weeks } == 8)
    }

    @Test("hypertrophy template matches D-03 structure")
    func hypertrophyMatchesD03Structure() {
        let phases = BlockTemplates.hypertrophy.phases

        #expect(BlockTemplates.hypertrophy.name == "Hypertrophy Meso")
        #expect(phases.map(\.kind) == [.accumulation, .intensification, .deload])
        #expect(phases.map(\.weeks) == [5, 2, 1])
        #expect(phases.reduce(0) { $0 + $1.weeks } == 8)
    }

    @Test("powerlifting peak template matches D-03 structure")
    func powerliftingPeakMatchesD03Structure() {
        let phases = BlockTemplates.powerliftingPeak.phases

        #expect(BlockTemplates.powerliftingPeak.name == "Powerlifting Peak")
        #expect(phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(phases.map(\.weeks) == [3, 3, 1, 1])
        #expect(phases.reduce(0) { $0 + $1.weeks } == 8)
    }

    @Test("blank template has no phases")
    func blankHasNoPhases() {
        #expect(BlockTemplates.blank.name == "Blank Block")
        #expect(BlockTemplates.blank.phases.isEmpty)
    }

    @Test(
        "template for phase kind mapping is deterministic",
        arguments: [
            (BlockPhaseKind.accumulation, "Generic Strength Meso"),
            (BlockPhaseKind.intensification, "Hypertrophy Meso"),
            (BlockPhaseKind.peak, "Powerlifting Peak"),
            (BlockPhaseKind.realization, "Powerlifting Peak"),
            (BlockPhaseKind.deload, "Generic Strength Meso"),
        ]
    )
    func templateForKindMappingDeterministic(kind: BlockPhaseKind, expectedName: String) {
        #expect(BlockTemplates.template(for: kind).name == expectedName)
    }

    @Test("template names match UI copy")
    func allTemplateNamesVerbatim() {
        #expect(BlockTemplates.generic.name == "Generic Strength Meso")
        #expect(BlockTemplates.hypertrophy.name == "Hypertrophy Meso")
        #expect(BlockTemplates.powerliftingPeak.name == "Powerlifting Peak")
        #expect(BlockTemplates.blank.name == "Blank Block")
    }

    @Test("D-10 multipliers match each phase kind")
    func d10MultipliersVerbatim() {
        let allPhases = BlockTemplates.generic.phases
            + BlockTemplates.hypertrophy.phases
            + BlockTemplates.powerliftingPeak.phases

        for phase in allPhases {
            switch phase.kind {
            case .accumulation:
                #expect(phase.volumeMultiplier == 1.0)
                #expect(phase.intensityMultiplier == 0.75)
            case .intensification:
                #expect(phase.volumeMultiplier == 0.85)
                #expect(phase.intensityMultiplier == 0.88)
            case .peak:
                // No stock template currently inserts .peak; defaults are exercised by BlockPhaseDraft tests instead.
                break
            case .realization:
                #expect(phase.volumeMultiplier == 0.6)
                #expect(phase.intensityMultiplier == 0.97)
            case .deload:
                #expect(phase.volumeMultiplier == 0.5)
                #expect(phase.intensityMultiplier == 0.75)
            }
        }
    }
}
