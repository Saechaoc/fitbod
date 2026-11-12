//
//  RoutineDuplicator.swift
//  fitbod
//
//  The session editor's "Duplicate session" (RM-026). The copy is what the
//  editor shows, unsaved changes included: the draft is copied and saved as a
//  new session named "{name} (Copy)", the way Save would write it. The session
//  being edited keeps what it last saved.
//
//  The copy shares nothing with the session it copies. Its lifts and per-set
//  overrides are new rows, and each superset becomes one new group, so editing
//  the copy's supersets never changes the original's. A superset's lifts stay
//  together because the copy keeps the draft's order.
//
//  Fields the editor does not show, such as an exercise's stored notes, start
//  at their defaults, as in a session built from scratch.
//

import Foundation
import SwiftData

public enum RoutineDuplicator {
    /// Saves a copy of `draft` as a new session and returns it. A failed
    /// save rolls the store back and leaves `draft` as it was, for a retry.
    @MainActor
    @discardableResult
    static func duplicate(
        _ draft: RoutineDraft, context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> SessionTemplate {
        let copy = RoutineDraft()
        copy.name = "\(draft.name.trimmingCharacters(in: .whitespacesAndNewlines)) (Copy)"
        copy.notes = draft.notes
        copy.folderID = draft.folderID
        copy.blockID = draft.blockID
        copy.intent = draft.intent
        copy.progressionKind = draft.progressionKind

        var groupIDs: [UUID: UUID] = [:]
        for lift in draft.exercises {
            let clone = lift.copy()
            copy.exercises.append(clone)
            guard let id = lift.supersetGroupID else { continue }
            if let group = groupIDs[id] {
                clone.supersetGroupID = group
            } else {
                groupIDs[id] = copy.addSuperset(for: clone)
            }
        }

        let session = SessionTemplate()
        context.insert(session)
        try copy.persist(into: session, context: context, save: save)
        return session
    }
}
