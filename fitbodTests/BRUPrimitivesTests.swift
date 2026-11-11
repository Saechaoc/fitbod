// BRUPrimitivesTests.swift
// fitbodTests
//
// BRUDisplay's three sizes. The banned shapes and tokens are SwiftLint rules
// (.swiftlint.yml), not tests, and a changed primitive signature breaks the
// build at its callers in the app.

import Foundation
import Testing
@testable import fitbod

@Suite("BRUPrimitives")
@MainActor
struct BRUPrimitivesTests {
    @Test("BRUDisplay's hero, large and medium sizes are 56, 32 and 18 points")
    func bruDisplaySizes() {
        #expect(BRUDisplay.Size.hero.pointSize == 56)
        #expect(BRUDisplay.Size.large.pointSize == 32)
        #expect(BRUDisplay.Size.medium.pointSize == 18)
    }
}
