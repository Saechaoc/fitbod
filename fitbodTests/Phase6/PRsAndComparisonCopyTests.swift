//
//  PRsAndComparisonCopyTests.swift
//  fitbodTests
//
//  T102: Compare's numbers. e1RM changes read to one decimal, and set
//  weights and weight changes read as logged.
//

import Testing
@testable import fitbod

@Suite("PRsAndComparisonCopy")
struct PRsAndComparisonCopyTests {

    /// The estimate keeps every digit of its formula, which "%g" printed,
    /// such as "+3.16667 e1RM lb". A change under 0.05 reads "0", which
    /// Compare shows as no change.
    @MainActor
    @Test("Compare reads e1RM changes to one decimal and weights as logged")
    func e1RMChangesReadToOneDecimal() {
        #expect(SessionComparisonView.formatE1RMChange(3.16667) == "3.2")
        #expect(SessionComparisonView.formatE1RMChange(2.8125) == "2.8")
        #expect(SessionComparisonView.formatE1RMChange(5) == "5")
        #expect(SessionComparisonView.formatE1RMChange(0.04) == "0")
        #expect(NumberText.weight(102.25) == "102.25")
    }
}
