//
//  BlockNumberingTests.swift
//  fitbodTests
//
//  Ticket T12, review item 29: blocks number from 1 in start-date order,
//  with ties broken by name (tradeoffs.md "Block numbers"), instead of by
//  the week of the year they start in. The block overview and the block
//  review both show `BlockNumbering.number(of:among:)`.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockNumbering")
struct BlockNumberingTests {

    /// Monday, Oct 26, 2026, UTC. Every block here starts that week, so
    /// before T12 they all shared one number.
    private let monday = Date(timeIntervalSinceReferenceDate: 814_665_600)

    private func block(_ name: String, startingDaysAfterMonday days: Int, in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = name
        block.startDate = monday.addingTimeInterval(Double(days) * 86_400)
        return block
    }

    @Test("blocks number from 1 in start-date order, in any list order")
    func numbersFollowStartDates() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let third = block("Autumn", startingDaysAfterMonday: 5, in: context)
        let first = block("Winter", startingDaysAfterMonday: 0, in: context)
        let second = block("Spring", startingDaysAfterMonday: 2, in: context)
        let blocks = [third, first, second]

        #expect(BlockNumbering.number(of: first, among: blocks) == 1)
        #expect(BlockNumbering.number(of: second, among: blocks) == 2)
        #expect(BlockNumbering.number(of: third, among: blocks) == 3)
    }

    @Test("blocks that start at the same time number by name")
    func tieOnStartDateBreaksByName() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let beta = block("Beta", startingDaysAfterMonday: 3, in: context)
        let alpha = block("Alpha", startingDaysAfterMonday: 3, in: context)
        let earliest = block("Zulu", startingDaysAfterMonday: 0, in: context)
        let blocks = [beta, alpha, earliest]

        #expect(BlockNumbering.number(of: earliest, among: blocks) == 1)
        #expect(BlockNumbering.number(of: alpha, among: blocks) == 2)
        #expect(BlockNumbering.number(of: beta, among: blocks) == 3)
    }

    @Test("blocks with the same start and name still get two numbers")
    func fullTieGetsDistinctNumbers() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let one = block("Base", startingDaysAfterMonday: 1, in: context)
        let other = block("Base", startingDaysAfterMonday: 1, in: context)
        let blocks = [one, other]

        let numbers = Set(blocks.map { BlockNumbering.number(of: $0, among: blocks) })
        #expect(numbers == [1, 2])
    }
}
