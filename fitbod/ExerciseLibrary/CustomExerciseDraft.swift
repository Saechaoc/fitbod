//
//  CustomExerciseDraft.swift
//  fitbod
//
//  Wave-3 plan 03-04 — the load-bearing PITFALLS #5 mitigation.
//
//  `@Observable` value-aware form state for the custom-exercise editor.
//  Holds in-memory edits to a not-yet-persisted (or being-edited)
//  custom `Exercise` and gates the Save button via a PURE-VALUE-TYPE
//  `isValid` computed property — testable WITHOUT a `ModelContainer`
//  (FOUND-07 in microcosm; the testability invariant is verified by the
//  10 `CustomExerciseDraftTests` functions).
//
//  ## Why this file is load-bearing (PITFALLS #5)
//
//  Without a hard validation gate, a user could create an `Exercise`
//  with zero primary-muscle stimulus rows. The volume math in Phase 5
//  (RP-style MEV/MAV/MRV against `ExerciseMuscleStimulus.weight`) would
//  then silently count zero sets toward every muscle and the user's
//  weekly totals would drift to zero with no error surface. This drift
//  is the textbook "silent corruption" failure mode the pitfall calls
//  out.
//
//  The fix is a runtime gate at the only authoring surface (this
//  draft): require ≥1 primary muscle with weight ≥0.5 before
//  `materialize(into:)` writes anything. The `Save` button in
//  `CustomExerciseEditor` is `.disabled(!draft.isValid)`, and the test
//  suite verifies every validation branch.
//
//  ## Validation rule (CONTEXT.md Area 3 + R-21)
//
//  `isValid == true` iff:
//    1. `name` (trimmed of whitespace) is non-empty, AND
//    2. at least one `MuscleAssignment` has `role == .primary` AND
//       `weight >= 0.5`.
//
//  Equipment + mechanic always have non-nil defaults (`.barbell` /
//  `.compound`) so they never gate save. Image is genuinely optional.
//  Multiple primaries are allowed (e.g. "Compound Move" with chest
//  primary 1.0 and triceps primary 0.8); the predicate is `contains`,
//  not `count == 1`.
//
//  ## Write boundary (FOUND-06 — single materialization point)
//
//  The draft holds in-memory edits ONLY. There is one persistence
//  boundary — `materialize(into:)` for the "New Exercise" flow and
//  `updateExisting(in:)` for the "Edit Exercise" flow. Both are called
//  from the Save button handler in `CustomExerciseEditor` AFTER
//  `isValid` has gated the button. The Save handler then calls
//  `modelContext.save()` and dismisses. No per-field write-through.
//
//  ## Insert-then-relate ordering (RESEARCH Pitfall 7)
//
//  `materialize(into:)` inserts the parent `Exercise` BEFORE creating
//  the child `ExerciseMuscleStimulus` rows. SwiftData requires the
//  parent to be in the context before a relationship can resolve, or
//  the stimulus row's `exercise` reference points to an unrooted
//  instance and the join fails silently.
//
//  ## Snapshot / dirty detection
//
//  `snapshot()` produces a value-typed `Snapshot` capturing every
//  field. `CustomExerciseEditor` takes a snapshot in `.onAppear` and
//  compares against the live `snapshot()` on Cancel to decide whether
//  to present the "Discard Changes?" confirmation. The `imageData`
//  field is reduced to its `Int` hash for snapshot equality (raw `Data`
//  equality on UIImage-shaped blobs is expensive and unnecessary).
//

import Foundation
import Observation
import SwiftData

/// Mutable in-memory form state for the custom-exercise editor.
///
/// Use `init()` to start a fresh "New Exercise" flow, or set
/// `editingExisting` to an existing custom `Exercise` and pre-populate
/// the fields to start an "Edit Exercise" flow. The view gates Save
/// via `isValid`; `materialize(into:)` writes a brand-new entity, and
/// `updateExisting(in:)` rewrites the targeted entity wholesale.
@Observable
public final class CustomExerciseDraft {

    // MARK: - Fields

    /// User-facing exercise name. Trimmed before the `isValid` check.
    public var name: String = ""

    /// Equipment kind. Always non-nil (default `.barbell`); per UI-SPEC
    /// the picker exposes all 9 `Equipment` cases.
    public var equipment: Equipment = .barbell

    /// Mechanic kind. Always non-nil (default `.compound`); per UI-SPEC
    /// the picker is a segmented control over the 2 `Mechanic` cases.
    public var mechanic: Mechanic = .compound

    /// Ordered list of muscle assignments. Each carries the slug, role
    /// (primary / secondary), and stimulus weight (0.0–1.0). At least
    /// one must be `role == .primary` with `weight >= 0.5` for the
    /// draft to be `isValid`.
    public var muscles: [MuscleAssignment] = []

    /// Optional attached image data (from `PhotosPicker`). Stored on
    /// the materialized `Exercise.imageData` (which is
    /// `@Attribute(.externalStorage)` so the blob lives outside the
    /// SQLite store).
    public var imageData: Data? = nil

    /// Set by the editor when an existing custom `Exercise` is being
    /// edited (rather than created). When non-nil:
    ///   - the navigation title becomes "Edit Exercise",
    ///   - the delete affordance is shown,
    ///   - `updateExisting(in:)` rewrites this entity rather than
    ///     creating a new one.
    /// `nil` for "New Exercise" mode.
    public var editingExisting: Exercise? = nil

    public init() {}

    // MARK: - MuscleAssignment

    /// One row in the muscles section of the custom-exercise editor.
    /// Identifiable by a UUID so SwiftUI's `ForEach($draft.muscles)`
    /// can produce stable bindings even when the user reorders or
    /// removes rows.
    public struct MuscleAssignment: Identifiable, Equatable, Sendable {
        public var id: UUID
        public var slug: String
        public var role: Role
        /// Stimulus weight in 0.0–1.0. UI exposes a slider with step
        /// 0.05; primary default = 1.0, secondary default = 0.5.
        public var weight: Double

        public init(
            id: UUID = UUID(),
            slug: String,
            role: Role,
            weight: Double
        ) {
            self.id = id
            self.slug = slug
            self.role = role
            self.weight = weight
        }

        public enum Role: String, Equatable, CaseIterable, Sendable {
            case primary
            case secondary
        }
    }

    // MARK: - Validation (PITFALLS #5 mitigation)

    /// `true` iff the draft satisfies every save precondition:
    /// 1. `name` (trimmed of whitespace) is non-empty.
    /// 2. At least one `MuscleAssignment` has `role == .primary` AND
    ///    `weight >= 0.5`.
    ///
    /// Pure value-type computation — does not touch SwiftData, so
    /// `CustomExerciseDraftTests` exercises every branch without a
    /// `ModelContainer`. This is the FOUND-07 invariant.
    public var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        return muscles.contains { $0.role == .primary && $0.weight >= 0.5 }
    }

    // MARK: - Snapshot / dirty detection

    /// Value-typed copy of the current field values. The editor takes
    /// a snapshot on `.onAppear` and compares against the live
    /// `snapshot()` to decide whether to present the "Discard Changes?"
    /// confirmation on Cancel.
    public func snapshot() -> Snapshot {
        Snapshot(
            name: name,
            equipment: equipment,
            mechanic: mechanic,
            muscles: muscles,
            imageDataHash: imageData?.hashValue
        )
    }

    public struct Snapshot: Equatable, Sendable {
        public let name: String
        public let equipment: Equipment
        public let mechanic: Mechanic
        public let muscles: [MuscleAssignment]
        /// Reduced to `Int?` because raw `Data` equality on
        /// UIImage-shaped blobs is needlessly expensive — the hash is
        /// sufficient signal for "did the image change?"
        public let imageDataHash: Int?
    }

    // MARK: - Materialization (insert-then-relate, RESEARCH Pitfall 7)

    /// Insert a NEW `Exercise` + its `ExerciseMuscleStimulus` rows
    /// into the supplied context. Called from the Save button handler
    /// when `editingExisting == nil`.
    ///
    /// The parent `Exercise` is `ctx.insert(_)`-ed BEFORE the stimulus
    /// rows reference it — required by SwiftData's relationship
    /// resolution (RESEARCH § Pitfall 7).
    ///
    /// `primaryMuscleSlugsJoined` is populated to the
    /// `"|chest|triceps|"` shape so the denormalized muscle-filter
    /// predicate (`Exercise.primaryMuscleSlugsJoined.contains("|slug|")`)
    /// works against this custom exercise the same as any seeded one
    /// (PITFALLS #3).
    ///
    /// - Parameters:
    ///   - ctx: The `ModelContext` to insert into (typically
    ///     `@Environment(\.modelContext)`).
    ///   - allMuscles: The known `MuscleGroup` rows (the editor passes
    ///     `@Query<MuscleGroup>` here). Stimulus rows are created only
    ///     for muscles present in this map; unknown slugs are skipped
    ///     defensively (matching the seed-pipeline's resilient
    ///     behavior — see plan 02-02 D-2).
    /// - Returns: The newly inserted `Exercise` (caller may then
    ///   `try ctx.save()` and dismiss).
    @discardableResult
    public func materialize(
        into ctx: ModelContext,
        allMuscles: [MuscleGroup]
    ) -> Exercise {
        let canonical = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        let primarySlugs = muscles.filter { $0.role == .primary }.map(\.slug)
        let joined = primarySlugs.isEmpty
            ? ""
            : "|" + primarySlugs.joined(separator: "|") + "|"

        let ex = Exercise(
            name: name,
            canonicalName: canonical,
            equipmentRaw: equipment.rawValue,
            mechanicRaw: mechanic.rawValue,
            category: "strength",
            isCustom: true,
            primaryMuscleSlugsJoined: joined
        )
        ex.imageData = imageData
        ctx.insert(ex)

        // Use the failable `uniquingKeysWith:` initializer rather than
        // `Dictionary(uniqueKeysWithValues:)` — the latter trap-crashes
        // on duplicate keys, and a transiently-buggy seed pipeline could
        // leave duplicate `MuscleGroup` rows that `@Query<MuscleGroup>`
        // would then surface here (see review WR-06). First-wins is
        // safe: duplicates share the same `slug` and the stimulus row
        // only reads `slug` from the muscle.
        let muscleBySlug = Dictionary(
            allMuscles.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for assignment in muscles {
            guard let mg = muscleBySlug[assignment.slug] else { continue }
            let stim = ExerciseMuscleStimulus(
                exercise: ex,
                muscle: mg,
                role: assignment.role.rawValue,
                weight: assignment.weight
            )
            ctx.insert(stim)
        }
        return ex
    }

    /// Rewrite an existing custom `Exercise` (set via `editingExisting`)
    /// to match the current draft. Called from the Save button handler
    /// when `editingExisting != nil`.
    ///
    /// Stimulus rows are replaced wholesale (drop existing, insert from
    /// draft) — simpler and safer than diff-merging since the user has
    /// already had the chance to edit each row before tapping Save.
    /// Cascade rule `Exercise → ExerciseMuscleStimulus: cascade` does
    /// NOT auto-clean here because the parent isn't being deleted; we
    /// explicitly `ctx.delete(_)` each existing stimulus.
    public func updateExisting(
        in ctx: ModelContext,
        allMuscles: [MuscleGroup]
    ) {
        guard let target = editingExisting else { return }
        target.name = name
        target.canonicalName = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        target.equipmentRaw = equipment.rawValue
        target.mechanicRaw = mechanic.rawValue
        target.imageData = imageData

        // Replace stimulus rows wholesale.
        for old in target.muscleStimuli ?? [] {
            ctx.delete(old)
        }

        // See WR-06 note in `materialize(into:allMuscles:)` — duplicate
        // slugs from a transient seed-pipeline bug must not trap-crash
        // this save flow.
        let muscleBySlug = Dictionary(
            allMuscles.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for assignment in muscles {
            guard let mg = muscleBySlug[assignment.slug] else { continue }
            let stim = ExerciseMuscleStimulus(
                exercise: target,
                muscle: mg,
                role: assignment.role.rawValue,
                weight: assignment.weight
            )
            ctx.insert(stim)
        }

        let primarySlugs = muscles.filter { $0.role == .primary }.map(\.slug)
        target.primaryMuscleSlugsJoined = primarySlugs.isEmpty
            ? ""
            : "|" + primarySlugs.joined(separator: "|") + "|"
    }
}
