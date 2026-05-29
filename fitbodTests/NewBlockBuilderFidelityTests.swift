//
//  NewBlockBuilderFidelityTests.swift
//  fitbodTests
//
//  Source and draft guardrails for the New Block modal fidelity pass.
//

import Foundation
import Testing
@testable import fitbod

@Suite("New Block builder fidelity")
struct NewBlockBuilderFidelityTests {

    private static func projectPath(_ components: [String]) -> URL {
        components.reduce(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        ) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func source(_ components: String...) throws -> String {
        try String(contentsOf: Self.projectPath(components), encoding: .utf8)
    }

    @MainActor
    @Test("New block draft matches the blank modal mock defaults")
    func newBlockDraftMatchesBlankModalDefaults() {
        let draft = BlockDraft.newBlock()

        #expect(draft.name.isEmpty)
        #expect(!draft.isActive)
        #expect(draft.daysPerWeek == 4)
        #expect(draft.totalWeeks == 5)
        #expect(draft.phases.count == 3)

        #expect(draft.phases[0].kind == .accumulation)
        #expect(draft.phases[0].weeks == 2)
        #expect(draft.phases[0].volumeMultiplier == 1.2)
        #expect(draft.phases[0].intensityMultiplier == 0.70)

        #expect(draft.phases[1].kind == .intensification)
        #expect(draft.phases[1].weeks == 2)
        #expect(draft.phases[1].volumeMultiplier == 1.0)
        #expect(draft.phases[1].intensityMultiplier == 0.85)

        #expect(draft.phases[2].kind == .deload)
        #expect(draft.phases[2].weeks == 1)
        #expect(draft.phases[2].volumeMultiplier == 0.5)
        #expect(draft.phases[2].intensityMultiplier == 0.60)
    }

    @Test("Program New block route presents the pixel-match builder full screen")
    func programNewBlockRoutePresentsFullScreenBuilder() throws {
        let source = try source("fitbod", "Periodization", "ProgramView.swift")

        #expect(source.contains(#".fullScreenCover(item: $pendingBlockBuilder)"#),
                "The New Block flow should cover the whole phone frame, not use the default sheet chrome.")
        #expect(source.contains("BlockDraft.newBlock()"),
                "The + New block action should seed the blank modal mock defaults.")
        #expect(source.contains("CREATE BLOCK"),
                "The pre-editor start-choice sheet title should be 'CREATE BLOCK'.")
    }

    @Test("Timeline preview keys unsaved phases by draft identity")
    func timelinePreviewKeysUnsavedPhasesByDraftIdentity() throws {
        let source = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        #expect(source.contains(#"ForEach(phases, id: \.draftID)"#),
                "Unsaved phase drafts have nil persisted ids, so timeline segments must key by draftID.")
    }

    @Test("BlockBuilderView exposes New Block mock structure and copy")
    func blockBuilderViewExposesNewBlockMockStructureAndCopy() throws {
        let source = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        for requiredType in [
            "NewBlockScreenTokens",
            "NewBlockTopBar",
            "NewBlockNameBand",
            "NewBlockPresetChip",
            "NewBlockMetricsBand",
            "NewBlockProgressionChart",
            "NewBlockPhaseEditorRow",
            "NewBlockBottomActionBar",
            "NewBlockTemplateSheet",
        ] {
            #expect(source.contains(requiredType), "Missing New Block structure: \(requiredType)")
        }

        for requiredCopy in [
            "< PROGRAM",
            "NEW BLOCK",
            "SAVE",
            "BLOCK NAME",
            "NAME YOUR BLOCK",
            "HYPERTROPHY MESO",
            "LINEAR STRENGTH",
            "POWERBUILDING",
            "OFF-SEASON",
            "PRE-MEET",
            "TOTAL WEEKS",
            "DAYS PER WEEK",
            "PHASES ·",
            "+ ADD PHASE",
            "PROGRESSION OVERVIEW",
            "Accumulation",
            "BUILD VOLUME",
            "Intensification",
            "BUILD STRENGTH",
            "Deload",
            "RECOVER",
            "CANCEL",
            "NAME FIRST ↑",
            "SAVE TEMPLATE ▸",
        ] {
            #expect(source.contains(requiredCopy), "Missing New Block copy: \(requiredCopy)")
        }
    }

    @Test("BlockBuilderView does not render fake recording status chrome")
    func blockBuilderViewDoesNotRenderFakeRecordingStatusChrome() throws {
        let source = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        #expect(!source.contains("NewBlockStatusChrome"),
                "The fake status chrome should be removed from the New Block screen.")
        #expect(!source.contains(#""9:41""#),
                "The New Block screen should not render a fake time.")
        #expect(!source.contains(#""REC""#),
                "The New Block screen should not render a fake recording indicator.")
    }
}
