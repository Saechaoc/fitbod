//
//  BlockReviewedAtTests.swift
//  fitbodTests
//
//  Block.reviewedAt persistence and a smoke check that the baseline container opens.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("BlockReviewedAt", .serialized)
struct BlockReviewedAtTests {

    // MARK: - Helpers

    /// Fresh in-memory context over the baseline schema.
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    @Test("Fresh in-memory baseline ModelContainer opens")
    @MainActor
    func freshV5ContainerOpensCleanly() throws {
        // Smoke test: the baseline schema composes into a working container.
        _ = try makeContext()
    }

    @Test("Block reviewedAt defaults nil and persists")
    @MainActor
    func blockReviewedAtDefaultsNilAndPersists() throws {
        let context = try makeContext()
        let block = Block()
        block.name = "Reviewed Block"
        context.insert(block)
        try context.save()

        #expect(block.reviewedAt == nil)

        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        block.reviewedAt = reviewedAt
        try context.save()

        let targetID = block.id
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.id == targetID }
        )
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(fetched.reviewedAt == reviewedAt)
    }

    // MARK: - 6. modeRaw tie-break tests for .strength

    // MARK: - 7. modeRaw tie-break tests for .double

    // MARK: - 8. Routine backfill on V4 intermediate rows

    // MARK: - 9. Session backfill on V4 intermediate rows

    // MARK: - 10. Empty exercise list keeps default values

}
