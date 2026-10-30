//
//  BlockTemplatesTests.swift
//  fitbodTests
//
//  Phase 4 Wave 0 coverage for stock block templates and RP default
//  multipliers, plus T10's one catalog and New Block's presets built on it.
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

    @Test("5/3/1 Cycle is 4 weeks: one week of each of four phases")
    func fiveThreeOneIsOneWeekPerPhase() {
        let template = BlockTemplates.fiveThreeOne

        #expect(template.name == "5/3/1 Cycle")
        #expect(template.phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(template.phases.map(\.weeks) == [1, 1, 1, 1])
        #expect(template.totalWeeks == 4)
    }

    @Test("the catalog lists the four templates in order")
    func catalogOrder() {
        #expect(BlockTemplates.catalog.map(\.name) == [
            "Hypertrophy Meso", "Generic Strength Meso", "Powerlifting Peak", "5/3/1 Cycle",
        ])
    }

    @Test("a template's phase summary uses the short phase labels")
    func phaseSummaryUsesShortLabels() {
        #expect(BlockTemplates.hypertrophy.phaseSummary == "ACCUM 5 · INTNS 2 · DELOAD 1")
        #expect(BlockTemplates.generic.phaseSummary == "ACCUM 4 · INTNS 2 · REAL 1 · DELOAD 1")
        #expect(BlockTemplates.powerliftingPeak.phaseSummary == "ACCUM 3 · INTNS 3 · REAL 1 · DELOAD 1")
        #expect(BlockTemplates.fiveThreeOne.phaseSummary == "ACCUM 1 · INTNS 1 · REAL 1 · DELOAD 1")
        #expect(BlockTemplates.blank.phaseSummary.isEmpty)
        #expect(BlockPhaseKind.peak.shortLabel == "PEAK")
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
        #expect(BlockTemplates.fiveThreeOne.name == "5/3/1 Cycle")
        #expect(BlockTemplates.blank.name == "Blank Block")
    }

    @Test("D-10 multipliers match each phase kind")
    func d10MultipliersVerbatim() {
        let allPhases = BlockTemplates.catalog.flatMap(\.phases)

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

@Suite("New Block presets")
struct NewBlockPresetTests {
    @Test("the pickers list BLANK, then the catalog in its order")
    func pickersListBlankThenCatalog() {
        #expect(NewBlockPreset.all.map(\.label) == [
            "BLANK", "HYPERTROPHY MESO", "GENERIC STRENGTH MESO", "POWERLIFTING PEAK", "5/3/1 CYCLE",
        ])
        #expect(NewBlockPreset.all.dropFirst().map(\.template.name) == BlockTemplates.catalog.map(\.name))
        #expect(NewBlockPreset.blank.template.phases.isEmpty)
    }

    @Test("a preset names the block only while the name is empty or still the previous preset's")
    func presetNameRule() {
        let hypertrophy = NewBlockPreset(template: BlockTemplates.hypertrophy)
        let peak = NewBlockPreset(template: BlockTemplates.powerliftingPeak)

        #expect(peak.name(replacing: "", previous: .blank) == "Powerlifting Peak")
        #expect(peak.name(replacing: "  ", previous: .blank) == "Powerlifting Peak")
        #expect(peak.name(replacing: "Blank Block", previous: .blank) == "Powerlifting Peak")
        #expect(peak.name(replacing: "Hypertrophy Meso", previous: hypertrophy) == "Powerlifting Peak")
        #expect(NewBlockPreset.blank.name(replacing: "Powerlifting Peak", previous: peak) == "Blank Block")
        // A name the user typed stays, even one that matches another preset.
        #expect(peak.name(replacing: "Summer Base", previous: hypertrophy) == "Summer Base")
        #expect(peak.name(replacing: "Hypertrophy Meso", previous: .blank) == "Hypertrophy Meso")
    }

    @Test("a draft name finds its preset, ignoring case, or BLANK")
    func matchingByName() {
        #expect(NewBlockPreset.matching(name: "hypertrophy meso").template.name == "Hypertrophy Meso")
        #expect(NewBlockPreset.matching(name: " 5/3/1 Cycle ").template.name == "5/3/1 Cycle")
        #expect(NewBlockPreset.matching(name: "Blank Block") == .blank)
        #expect(NewBlockPreset.matching(name: "Summer Base") == .blank)
        #expect(NewBlockPreset.matching(name: "") == .blank)
    }
}
