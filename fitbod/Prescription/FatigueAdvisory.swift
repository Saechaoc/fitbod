//
//  FatigueAdvisory.swift
//  fitbod
//
//  Phase 4 BLOCK-06a/BLOCK-08 contract: fatigue-triggered deloads are
//  advisory only. The protocol returns a Bool and a FatigueSuggestion
//  value, never a Block-mutating command, so scheduled block deloads
//  remain canonical at the type level.
//

import Foundation

public protocol FatigueAdvisory: Sendable {
    func shouldSuggest(context: SessionContext) -> Bool
    func suggestion(context: SessionContext) -> FatigueSuggestion
}

public struct FatigueSuggestion: Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public struct SessionContext: Sendable {
    public init() {}
}
