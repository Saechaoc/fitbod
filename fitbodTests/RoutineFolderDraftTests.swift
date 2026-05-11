//
//  RoutineFolderDraftTests.swift
//  fitbodTests
//
//  Truth-table coverage for `RoutineFolderDraft.isValid` — the gate that
//  drives the "Save" button enablement in `NewFolderSheet`. Mirrors the
//  `CustomExerciseDraftTests` shape from plan 01-03-04: pure value-type
//  validation, no `ModelContainer` required.
//
//  Three branches:
//    1. Empty name string → invalid.
//    2. Whitespace-only name (the "   " regression case) → invalid.
//    3. Trimmed-non-empty name → valid.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("RoutineFolderDraft")
struct RoutineFolderDraftTests {

    @Test("emptyDraftIsInvalid")
    func emptyDraftIsInvalid() {
        let draft = RoutineFolderDraft()
        #expect(draft.isValid == false)
    }

    @Test("whitespaceOnlyNameIsInvalid")
    func whitespaceOnlyNameIsInvalid() {
        let draft = RoutineFolderDraft()
        draft.name = "   "
        #expect(draft.isValid == false)
    }

    @Test("namedDraftIsValid")
    func namedDraftIsValid() {
        let draft = RoutineFolderDraft()
        draft.name = "Push / Pull / Legs"
        #expect(draft.isValid == true)
    }
}
