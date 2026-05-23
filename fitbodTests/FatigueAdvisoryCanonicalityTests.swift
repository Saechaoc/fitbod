//
//  FatigueAdvisoryCanonicalityTests.swift
//  fitbodTests
//
//  Phase 4 Wave 0 coverage for the advisory-only deload contract.
//

import Testing
@testable import fitbod

@Suite("FatigueAdvisoryCanonicality")
struct FatigueAdvisoryCanonicalityTests {
    @Test("protocol surface returns only Bool and FatigueSuggestion")
    func protocolReturnsOnlyBoolAndFatigueSuggestion() {
        let advisory = StubFatigueAdvisory()
        let context = SessionContext()

        let shouldSuggest: Bool = advisory.shouldSuggest(context: context)
        let suggestion: FatigueSuggestion = advisory.suggestion(context: context)

        #expect(shouldSuggest == false)
        #expect(suggestion.reason == "")
    }

    @Test("fatigue suggestion carries no block-mutating field")
    func fatigueSuggestionHasNoBlockField() {
        let suggestion = FatigueSuggestion(reason: "test")

        for child in Mirror(reflecting: suggestion).children {
            #expect(child.label != "block")
            #expect((child.value as? Block) == nil)
            #expect((child.value as? BlockPhase) == nil)
        }
    }

    @Test("stub returns false and an empty reason")
    func stubReturnsFalseAndEmptyReason() {
        let advisory = StubFatigueAdvisory()
        let context = SessionContext()

        #expect(advisory.shouldSuggest(context: context) == false)
        #expect(advisory.suggestion(context: context).reason == "")
    }
}
