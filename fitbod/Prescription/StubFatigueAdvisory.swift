//
//  StubFatigueAdvisory.swift
//  fitbod
//
//  Phase 4 default implementation. Phase 5 replaces the signal source
//  without changing the UI or protocol surface.
//

import Foundation

public struct StubFatigueAdvisory: FatigueAdvisory {
    public init() {}

    public func shouldSuggest(context: SessionContext) -> Bool {
        false
    }

    public func suggestion(context: SessionContext) -> FatigueSuggestion {
        FatigueSuggestion(reason: "")
    }
}
