//
//  BlockReviewView.swift
//  fitbod
//
//  Phase-end review sheet for completed periodization blocks.
//
//  Phase 04.1 (BRU re-skin — NavigationStack+ScrollView+VStack body + ink hero band +
//  GeometryReader e1RM bars + bottom action bar) — see 04.1-PATTERNS.md File #2
//

import Foundation
import SwiftData
import SwiftUI

public struct BlockReviewView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit

    public let block: Block

    /// Every block, for the block number.
    @Query private var allBlocks: [Block]

    @State private var pendingNextBlockBuilder: BlockTemplate? = nil
    @State private var acknowledgeError: String? = nil

    public init(block: Block) {
        self.block = block
    }

    // MARK: - Body

    public var body: some View {
        let blockStart = block.startDate
        let blockEnd = block.endDate ?? Date.now
        let recommendedKind = BlockReviewStatistics.recommendedNextKind(for: block)

        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar.slots(
                    left: .back,
                    center: "Block review",
                    right: .text("EXPORT")
                )

                ScrollView {
                    VStack(spacing: 0) {
                        heroBand(blockStart: blockStart, blockEnd: blockEnd)
                        e1RMSection(blockStart: blockStart, blockEnd: blockEnd)
                        recommendedNextBand(recommendedKind: recommendedKind)
                        if let acknowledgeError {
                            Text(acknowledgeError)
                                .font(BRUFont.labelSmall)
                                .foregroundStyle(Color.bruSignal)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }

                bottomActionBar(recommendedKind: recommendedKind)
                safeAreaFiller
            }
        }
        .sheet(item: $pendingNextBlockBuilder) { template in
            NavigationStack {
                // Only Today presents the review.
                BlockBuilderView(draft: BlockDraft(template: template), origin: .today)
            }
        }
    }

    // MARK: - Hero Band

    private func heroBand(blockStart: Date, blockEnd: Date) -> some View {
        let totalKg = BlockReviewStatistics.totalVolume(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )
        let sessionsCount = BlockReviewStatistics.sessionCount(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )
        let blockNumber = BlockNumbering.number(of: block, among: allBlocks)
        let formattedRange = formattedDateRange(start: blockStart, end: blockEnd)

        return VStack(alignment: .leading, spacing: 0) {
            // Top label row
            Text("BLOCK \(blockNumber) · COMPLETE · \(formattedRange)")
                .font(BRUFont.labelSmall)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.bruPaper.opacity(0.6))

            // Block name
            Text(block.name)
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruPaper)
                .padding(.top, 4)

            // Three-column stat row
            HStack(spacing: 0) {
                statCell(
                    label: "SESSIONS",
                    value: "\(sessionsCount)",
                    subLabel: "LOGGED",
                    valueColor: Color.bruPaper
                )
                Spacer()
                statCell(
                    label: "TONNAGE",
                    value: BlockReviewStatistics.formattedKg(totalKg),
                    subLabel: "\(weightUnit.rawValue.uppercased()) TOTAL",
                    valueColor: Color.bruSignal
                )
                Spacer()
                statCell(
                    label: "PRS",
                    value: "—",
                    subLabel: "COMING IN PHASE 6",
                    valueColor: Color.bruPaper
                )
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.bruPaper.opacity(0.3))
                    .frame(height: 2)
                    .offset(y: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCell(
        label: String,
        value: String,
        subLabel: String? = nil,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BRUFont.labelMicro)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruPaper.opacity(0.6))
            Text(value)
                .font(BRUFont.displayHero)
                .foregroundStyle(valueColor)
            if let subLabel {
                Text(subLabel)
                    .font(BRUFont.labelMicro)
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
            }
        }
    }

    // MARK: - e1RM Movement Section

    private func e1RMSection(blockStart: Date, blockEnd: Date) -> some View {
        let deltas = BlockReviewStatistics.e1RMDeltas(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )
        let positiveCount = deltas.filter { $0.delta > 0 }.count

        return VStack(spacing: 0) {
            BRUSectionHead("e1RM movement", right: "↑ \(positiveCount) LIFTS")

            if deltas.isEmpty {
                Text("Not enough sessions logged to compute deltas.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(deltas, id: \.exerciseID) { delta in
                        e1RMRow(delta: delta)
                        Rectangle()
                            .fill(Color.bruHair)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private func e1RMRow(delta: BlockReviewE1RMDelta) -> some View {
        // Compute start and end e1RM from delta
        // delta.delta = end - start, so we derive a "start" visual from the delta magnitude
        // For display, we show the delta as the progression value
        let pct = min(1.0, abs(delta.delta) / 50.0)
        let isPR = delta.delta > 0  // treat positive delta as PR eligible (Phase 6 will refine)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                // Exercise name + optional PR chip
                HStack(spacing: 6) {
                    Text(delta.exerciseName)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    if isPR {
                        BRUChip("★ PR", color: .bruSignal, fill: true)
                            .accessibilityHidden(true)
                    }
                }
                Spacer()
                // Delta display
                HStack(spacing: 6) {
                    Text(BlockReviewStatistics.formattedDelta(delta.delta, unit: weightUnit))
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(delta.delta > 0 ? Color.bruSignal : Color.bruInk)
                }
            }

            // GeometryReader progress bar per 04.1-PATTERNS.md File #2 lines 322-335
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(height: 4)
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(width: geo.size.width * pct, height: 4)
                    Rectangle()
                        .fill(Color.bruSignal)
                        .frame(width: 3, height: 12)
                        .offset(x: geo.size.width * pct - 1.5, y: -4)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Recommended Next Band

    private func recommendedNextBand(recommendedKind: BlockPhaseKind) -> some View {
        let recommendedKindLabel = BlockPhaseColors.phaseLabel(recommendedKind).capitalized
        let recommendedWeeks = 4  // Phase 6 will compute from block history; placeholder per spec
        let blockNumber = BlockNumbering.number(of: block, among: allBlocks)

        return VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECOMMENDED NEXT BLOCK")
                        .font(BRUFont.labelSmall)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(Color.bruInk)
                    Text("\(recommendedKindLabel) · \(recommendedWeeks) weeks")
                        .font(BRUFont.displayLarge)
                        .foregroundStyle(Color.bruInk)
                }
                Spacer()
                Text("BASED ON BLOCK \(blockNumber)")
                    .font(BRUFont.labelMicro)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.bruBg2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Bottom Action Bar

    private func bottomActionBar(recommendedKind: BlockPhaseKind) -> some View {
        HStack(spacing: 0) {
            BRUButton("Plan custom", kind: .ghost) {
                dismiss()
            }
            Rectangle()
                .fill(Color.bruInk)
                .frame(width: 2)
            BRUButton("Start next ▸", kind: .signal) {
                acknowledge()
                pendingNextBlockBuilder = BlockTemplates.template(for: recommendedKind)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Safe-Area Filler

    private var safeAreaFiller: some View {
        Rectangle()
            .fill(Color.bruBg)
            .frame(height: 24)
    }

    // MARK: - Helpers

    private func formattedDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    // MARK: - Acknowledge Logic
    //
    // Split into acknowledge() (no dismiss) and acknowledgeAndDismiss() (with dismiss)
    // so "Start next ▸" can acknowledge THEN show the next-block sheet without
    // an immediate dismiss interfering with the sheet presentation.
    // "Plan custom" calls dismiss() only (no acknowledge — user is deferring review).

    private func acknowledge() {
        do {
            try BlockReviewStatistics.acknowledge(
                block: block,
                context: ctx,
                now: Date.now
            )
        } catch {
            acknowledgeError = "Couldn't save review. Try again."
        }
    }

    private func acknowledgeAndDismiss() {
        acknowledge()
        dismiss()
    }
}

// MARK: - Supporting Types (Preserved verbatim — DO NOT MODIFY)

public struct BlockReviewE1RMDelta: Sendable, Equatable {
    public let exerciseID: UUID
    public let exerciseName: String
    public let delta: Double

    public init(exerciseID: UUID, exerciseName: String, delta: Double) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.delta = delta
    }
}

public enum BlockReviewStatistics {
    @MainActor
    public static func totalVolume(context: ModelContext, start: Date, end: Date) -> Double {
        completedWorkingSets(context: context, start: start, end: end)
            .reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    @MainActor
    public static func workingSetCount(context: ModelContext, start: Date, end: Date) -> Int {
        completedWorkingSets(context: context, start: start, end: end).count
    }

    @MainActor
    public static func sessionCount(context: ModelContext, start: Date, end: Date) -> Int {
        Set(
            completedWorkingSets(context: context, start: start, end: end)
                .compactMap { $0.sessionExercise?.session?.id }
        ).count
    }

    @MainActor
    public static func completedWorkingSets(
        context: ModelContext,
        start: Date,
        end: Date
    ) -> [SetEntry] {
        let startBound = start
        let endBound = end
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true
                    && entry.isWarmup == false
                    && entry.completedAt >= startBound
                    && entry.completedAt <= endBound
            },
            sortBy: [SortDescriptor(\SetEntry.completedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    public static func e1RMDeltas(
        context: ModelContext,
        start: Date,
        end: Date
    ) -> [BlockReviewE1RMDelta] {
        let sets = completedWorkingSets(context: context, start: start, end: end)
        var topByExerciseSession: [ExerciseSessionKey: SessionTopSet] = [:]

        for set in sets {
            guard
                let sessionExercise = set.sessionExercise,
                let session = sessionExercise.session,
                let exercise = sessionExercise.exercise
            else { continue }

            let e1RM = E1RMHelper.epley(weight: set.weight, reps: set.reps)
            let key = ExerciseSessionKey(exerciseID: exercise.id, sessionID: session.id)
            let candidate = SessionTopSet(
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                sessionID: session.id,
                sessionDate: session.startedAt,
                e1RM: e1RM
            )

            if let existing = topByExerciseSession[key] {
                if candidate.e1RM > existing.e1RM {
                    topByExerciseSession[key] = candidate
                }
            } else {
                topByExerciseSession[key] = candidate
            }
        }

        let grouped = Dictionary(grouping: topByExerciseSession.values) { $0.exerciseID }
        return grouped.compactMap { exerciseID, topSets in
            let sorted = topSets.sorted {
                if $0.sessionDate == $1.sessionDate {
                    return $0.sessionID.uuidString < $1.sessionID.uuidString
                }
                return $0.sessionDate < $1.sessionDate
            }
            guard let first = sorted.first, let last = sorted.last, first.sessionID != last.sessionID else {
                return nil
            }
            return BlockReviewE1RMDelta(
                exerciseID: exerciseID,
                exerciseName: last.exerciseName,
                delta: last.e1RM - first.e1RM
            )
        }
        .sorted {
            let lhsMagnitude = abs($0.delta)
            let rhsMagnitude = abs($1.delta)
            if lhsMagnitude == rhsMagnitude {
                return $0.exerciseName < $1.exerciseName
            }
            return lhsMagnitude > rhsMagnitude
        }
    }

    public static func recommendedNextKind(for block: Block) -> BlockPhaseKind {
        let lastPhase = (block.phases ?? [])
            .sorted { $0.orderIndex > $1.orderIndex }
            .first
        return lastPhase
            .map { PeriodizationEngine.recommendedNextKind(after: $0.kind) }
            ?? .accumulation
    }

    public static func triggerDescriptor(now _: Date = Date.now) -> FetchDescriptor<Block> {
        return FetchDescriptor<Block>(
            predicate: #Predicate<Block> { block in
                block.isActive == true
                    && block.reviewedAt == nil
            },
            sortBy: [SortDescriptor(\Block.endDate)]
        )
    }

    @MainActor
    public static func pendingReviewBlocks(
        context: ModelContext,
        now: Date = Date.now
    ) throws -> [Block] {
        try context.fetch(triggerDescriptor(now: now))
            .filter { block in
                guard let endDate = block.endDate else { return false }
                return endDate < now
            }
    }

    @MainActor
    public static func acknowledge(
        block: Block,
        context: ModelContext,
        now: Date = Date.now
    ) throws {
        try context.transaction {
            block.reviewedAt = now
            block.isActive = false
            try context.save()
        }
    }

    public static func formattedKg(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }

    public static func formattedDelta(_ value: Double, unit: WeightUnit) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) \(unit.rawValue)"
    }
}

private struct ExerciseSessionKey: Hashable {
    let exerciseID: UUID
    let sessionID: UUID
}

private struct SessionTopSet {
    let exerciseID: UUID
    let exerciseName: String
    let sessionID: UUID
    let sessionDate: Date
    let e1RM: Double
}
