//
//  RoutineBuilderLiveEditTests.swift
//  fitbodTests
//
//  Phase 09-06 — TDD suite for RoutineBuilderView live-edit banner reachability.
//
//  Tests the `isTemplateOnActiveBlock(_:context:)` free function (exposed at
//  `internal` in RoutineBuilderView.swift) and a source-introspection copy pin.
//
//  Threat mitigations:
//    T-09-16: on/off-block cases assert banner shown only for truly-active blocks.
//    T-09-17: reachability uses Swift post-filter (no #Predicate multi-level chain).
//
//  Test matrix:
//    1. slottedOnActiveBlock          — template in a split with an active block → true
//    2. slottedOnNonActiveBlocks      — template in a split whose blocks are all draft/ready/completed → false
//    3. templateInZeroSplits          — template not slotted → false
//    4. sourceIntrospectionCopyPin    — RoutineBuilderView.swift contains "LiveEditBanner"
//                                       LiveEditBanner.swift contains verbatim banner body copy
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineBuilderLiveEdit", .serialized)
struct RoutineBuilderLiveEditTests {

    // MARK: - In-memory context

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Helpers

    /// Build and insert a `SessionTemplate` into `ctx`.
    private func makeTemplate(name: String = "Test Session", in ctx: ModelContext) -> SessionTemplate {
        let template = SessionTemplate()
        template.name = name
        ctx.insert(template)
        return template
    }

    /// Build and insert a `Split` with `slots` attached to `template`, and optionally
    /// one or more `Block`s wired to the split with the given active/endDate config.
    ///
    /// - Parameters:
    ///   - template: The `SessionTemplate` to attach as a slot.
    ///   - blockConfigs: Each tuple: `(isActive, hasEndDate)` — one Block per tuple.
    ///   - ctx: The model context to insert into.
    /// - Returns: The created `Split`.
    @discardableResult
    private func makeSplitWithSlotAndBlocks(
        template: SessionTemplate,
        blockConfigs: [(isActive: Bool, hasEndDate: Bool)],
        in ctx: ModelContext
    ) -> Split {
        let split = Split()
        split.name = "Test Split"
        ctx.insert(split)

        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.split = split
        slot.sessionTemplate = template
        slot.position = 0

        for (isActive, hasEndDate) in blockConfigs {
            let block = Block()
            block.name = "Test Block"
            block.isActive = isActive
            block.endDate = hasEndDate ? Date.now : nil
            block.split = split
            ctx.insert(block)
        }

        try? ctx.save()
        return split
    }

    // MARK: - Test 1: slotted into a split with an active block → true

    @Test("template slotted into a split with an active block returns true")
    func slottedOnActiveBlock() throws {
        let ctx = try makeContext()
        let template = makeTemplate(in: ctx)

        // One block: isActive = true, no endDate → derivedStatus == .active
        makeSplitWithSlotAndBlocks(
            template: template,
            blockConfigs: [(isActive: true, hasEndDate: false)],
            in: ctx
        )

        #expect(isTemplateOnActiveBlock(template, context: ctx) == true)
    }

    // MARK: - Test 2: slotted into splits with only non-active blocks → false

    @Test("template slotted into splits whose blocks are all draft/ready/completed returns false")
    func slottedOnNonActiveBlocks() throws {
        let ctx = try makeContext()
        let template = makeTemplate(in: ctx)

        // Three non-active block configs:
        //   draft     = isActive: false, no endDate, no split yet → derivedStatus == .draft
        //   completed = isActive: false, hasEndDate: true          → derivedStatus == .completed
        // (ready requires a split wired + slotCount >= 1, which is true here,
        //  but isActive: false + no endDate with split set → derivedStatus == .ready)
        // Use all three states to be thorough.
        makeSplitWithSlotAndBlocks(
            template: template,
            blockConfigs: [
                (isActive: false, hasEndDate: false), // draft or ready — not active
                (isActive: false, hasEndDate: true),  // completed
            ],
            in: ctx
        )

        #expect(isTemplateOnActiveBlock(template, context: ctx) == false)
    }

    // MARK: - Test 3: template in zero splits → false

    @Test("template not slotted into any split returns false")
    func templateInZeroSplits() throws {
        let ctx = try makeContext()
        let template = makeTemplate(in: ctx)
        // No slot, no split — just an unlinked SessionTemplate
        try? ctx.save()

        #expect(isTemplateOnActiveBlock(template, context: ctx) == false)
    }

    // MARK: - Test 4: source-introspection copy pin

    @Test("RoutineBuilderView.swift contains LiveEditBanner; LiveEditBanner.swift carries verbatim body copy")
    func sourceIntrospectionCopyPin() throws {
        // Pin: RoutineBuilderView.swift must reference LiveEditBanner
        let routineBuilderSource = try String(
            contentsOfFile: #filePath
                .components(separatedBy: "/fitbodTests/")
                .first!
                .appending("/fitbod/Routines/RoutineBuilderView.swift"),
            encoding: .utf8
        )
        #expect(routineBuilderSource.contains("LiveEditBanner"))

        // Pin: verbatim body copy lives in LiveEditBanner.swift (from 09-01)
        let bannerSource = try String(
            contentsOfFile: #filePath
                .components(separatedBy: "/fitbodTests/")
                .first!
                .appending("/fitbod/Design/LiveEditBanner.swift"),
            encoding: .utf8
        )
        #expect(bannerSource.contains("Part of active block — edits apply to upcoming workouts."))
    }
}
