//
//  TodayResolver.swift
//  fitbod
//
//  Implements the unified scheduler engine for SPEC-8-RESOLVER.
//
//  `TodayResolution` is the output contract for Phase 9 surfaces; the four
//  cases map 1:1 to the four UI states Phase 9 will render. Do NOT collapse
//  `.emptySplit` into `.restDay` — they render differently (Phase 9).
//
//  `TodayResolver` is a caseless namespace enum following the
//  PreviousMatchingIntent pattern: static funcs, no instantiation.
//
//  Pitfall-1 compliance: all multi-level optional chains
//  (`session.block?.id`, `session.slot?.split?.id`) live in Swift
//  `.first { }` closures, NEVER inside `#Predicate { }`. The `#Predicate`
//  gate is kept to the flat `completedAt != nil` only.
//
//  Pitfall-3 compliance: `guard slotCount >= 1` precedes every `% slotCount`
//  modulo operation. Zero-slot blocks return `.emptySplit`, never crash.
//

import Foundation
import SwiftData

// MARK: - Output enum (§SPEC-8-RESOLVER §5)

/// The exhaustive result of resolving today's scheduled slot for a block.
///
/// Phase 9 renders each case differently — do NOT merge `.emptySplit` into
/// `.restDay`. A mid-block split emptied of all slots shows a "fix-it" surface
/// in Phase 9; a calendar rest day shows a rest copy.
public enum TodayResolution {
    /// A specific slot is scheduled today — pass `slot.sessionTemplate` to the session factory.
    case session(SplitSessionSlot)
    /// fixedWeekly mode: today's weekday is not in the block's `trainingDays`.
    case restDay
    /// The block's split has zero slots; the UI should surface a repair prompt.
    case emptySplit
    /// No split is attached to the block yet (or `block.split == nil`).
    case noBlock
}

// MARK: - Resolver namespace (§SPEC-8-RESOLVER §5)

/// Pure scheduler engine. No SwiftUI coupling; injectable `today` and
/// `calendar` so unit tests can pin both without touching real time.
///
/// Usage:
/// ```swift
/// let resolution = TodayResolver.resolve(block: activeBlock, context: ctx)
/// ```
public enum TodayResolver {

    // MARK: Public entry point

    /// Resolve today's scheduled slot for `block`.
    ///
    /// Spec §5: branches on `block.schedulingMode` after a nil-split early return.
    /// - Parameters:
    ///   - block: The active `Block` to evaluate.
    ///   - context: The live `ModelContext` (needed for rotation's session fetch).
    ///   - today: The date to treat as "today" — defaults to `.now` for production.
    ///   - calendar: The calendar used for weekday extraction — defaults to
    ///     `.current`. Inject a pinned `Calendar` in fixedWeekly tests.
    /// - Returns: A `TodayResolution` case; never throws (fetch failures are treated as empty).
    public static func resolve(
        block: Block,
        context: ModelContext,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> TodayResolution {
        // Spec §5: no split → .noBlock immediately.
        guard block.split != nil else { return .noBlock }

        switch block.schedulingMode {
        case .rotation:
            return resolveRotation(block: block, context: context)
        case .fixedWeekly:
            return resolveFixedWeekly(block: block, today: today, calendar: calendar)
        }
    }

    // MARK: Rotation (spec §5 — unified predicate)

    /// Spec §5 rotation: advance one slot past the latest completed session in
    /// this block whose `slot` is non-nil and whose `slot.split == block.split`.
    /// Ad-hoc sessions (slot == nil), deleted-slot sessions (nullified → reads
    /// as nil), swapped-split sessions, and in-progress sessions all fall out
    /// of the scan identically via the unified post-filter predicate.
    private static func resolveRotation(
        block: Block,
        context: ModelContext
    ) -> TodayResolution {
        // Pitfall-3: guard BEFORE any modulo.
        let slotCount = block.split?.slots?.count ?? 0
        guard slotCount >= 1 else { return .emptySplit }

        // Capture IDs as local lets BEFORE fetch (Pitfall-1 avoidance).
        // Multi-level chains must NOT appear inside #Predicate.
        let targetBlockID = block.id
        let targetSplitID = block.split?.id

        // Broad predicate: only the flat `completedAt != nil` gate.
        // Sort by completedAt desc (spec §5: latest *completed* session is the
        // anchor — not insertion order, not start order). The predicate already
        // filters completedAt != nil, so the SortDescriptor's nil handling is moot.
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\Session.completedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else {
            // Fetch failure treated as no history → start from slot 0.
            let slots = sortedSlots(block)
            return slots.first(where: { $0.position == 0 }).map(TodayResolution.session) ?? .emptySplit
        }

        // Spec §5 unified predicate (Swift post-filter):
        //   - session.block?.id == block.id        → must belong to THIS block
        //   - session.slot != nil                  → must have a live slot (not ad-hoc)
        //   - session.slot?.split?.id == targetSplitID → slot must belong to the CURRENT split
        // Any session failing any clause is skipped silently (ad-hoc, deleted-slot,
        // swapped-split, in-progress are all excluded by completedAt gate or slot check).
        let anchor = all.first { session in
            session.block?.id == targetBlockID
                && session.slot != nil
                && session.slot?.split?.id == targetSplitID
        }

        let slots = sortedSlots(block)

        // Compute next position: anchor's position + 1, wrapping modulo slotCount.
        // Pitfall-3: slotCount is already >= 1 at this point (guarded above).
        let nextPosition: Int
        if let anchorSlot = anchor?.slot {
            nextPosition = (anchorSlot.position + 1) % slotCount
        } else {
            // No qualifying anchor → start from slot 0.
            nextPosition = 0
        }

        return slots.first(where: { $0.position == nextPosition })
            .map(TodayResolution.session) ?? .emptySplit
    }

    // MARK: Fixed-weekly (spec §5)

    /// Spec §5 fixedWeekly: map today's weekday to a stored index in
    /// `block.trainingDays`, then map that index to a slot position via
    /// `storedIndex % slotCount`.
    ///
    /// `block.trainingDays` is read VERBATIM — never re-sorted at read time.
    /// Sort-at-write is performed by `TrainingDaysWriter` (08-02). Re-sorting
    /// here would violate the locale invariant: a region change after write
    /// must NOT remap days to different slots.
    private static func resolveFixedWeekly(
        block: Block,
        today: Date,
        calendar: Calendar
    ) -> TodayResolution {
        // Pitfall-3: guard BEFORE any modulo.
        let slotCount = block.split?.slots?.count ?? 0
        guard slotCount >= 1 else { return .emptySplit }

        // Calendar.component(.weekday) → 1=Sun…7=Sat, matching trainingDays domain.
        let weekday = calendar.component(.weekday, from: today)

        // Read trainingDays VERBATIM (stored order is canonical — do NOT sort here).
        let trainingDays = block.trainingDays
        guard let storedIndex = trainingDays.firstIndex(of: weekday) else {
            // Today's weekday is not in trainingDays → rest day.
            return .restDay
        }

        // Spec §5: mod is the runtime guard for mid-block slot-count drift.
        // storedIndex may exceed slotCount if the split was reduced after write.
        // Pitfall-3: slotCount is already >= 1 at this point (guarded above).
        let position = storedIndex % slotCount

        let slots = sortedSlots(block)
        return slots.first(where: { $0.position == position })
            .map(TodayResolution.session) ?? .emptySplit
    }

    // MARK: Shared utilities

    /// Returns `block.split.slots` sorted ascending by `position`.
    /// Centralised here so both resolvers share the same sort expression.
    private static func sortedSlots(_ block: Block) -> [SplitSessionSlot] {
        (block.split?.slots ?? []).sorted { $0.position < $1.position }
    }
}
