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

    @Test("BlockBuilderView wires swipe-to-delete and drag-to-reorder affordances")
    func blockBuilderViewExposesDirectManipulationAffordances() throws {
        let source = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        // Drag-to-reorder: ⋮⋮ handle, long-press-gated drag, commit-on-drop array move,
        // and the reorder lifecycle reported up to the parent.
        #expect(source.contains(#"Text("⋮⋮")"#),
                "Phase rows need the ⋮⋮ drag handle to initiate reorder.")
        #expect(source.contains("LongPressGesture"),
                "Reorder must be gated behind a long press so scrolling isn't hijacked.")
        #expect(source.contains("move(fromOffsets:"),
                "Reorder must commit by moving the phase within draft.phases.")
        #expect(source.contains("onReorderBegan") && source.contains("onReorderEnded"),
                "Phase rows must report the reorder lifecycle up to the parent.")

        // Swipe-to-delete: a custom DragGesture (because .swipeActions is a no-op in a
        // LazyVStack) feeding a single commit path, plus a revealed destructive button.
        #expect(source.contains("DragGesture"),
                "Swipe-to-delete needs a custom horizontal DragGesture.")
        #expect(source.contains("Button(role: .destructive)"),
                "The revealed swipe affordance must be a destructive Delete button.")
        #expect(source.contains("commitDelete"),
                "Swipe and the Delete button should funnel through a single commit path.")
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
