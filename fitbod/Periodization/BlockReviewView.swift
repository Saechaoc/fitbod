//
//  BlockReviewView.swift
//  fitbod
//
//  Phase-end review sheet for completed periodization blocks.
//

import Foundation
import SwiftData
import SwiftUI

public struct BlockReviewView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    public let block: Block

    @State private var pendingNextBlockBuilder: BlockTemplate? = nil
    @State private var acknowledgeError: String? = nil

    public init(block: Block) {
        self.block = block
    }

    public var body: some View {
        let blockStart = block.startDate
        let blockEnd = block.endDate ?? Date.now

        NavigationStack {
            Form {
                totalVolumeSection(blockStart: blockStart, blockEnd: blockEnd)
                e1RMDeltasSection(blockStart: blockStart, blockEnd: blockEnd)
                prsHitSectionPlaceholder
                recommendedNextSection
                if let acknowledgeError {
                    Text(acknowledgeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("\(block.name) — review")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        acknowledgeAndDismiss()
                    }
                }
            }
        }
        .sheet(item: $pendingNextBlockBuilder) { template in
            NavigationStack {
                BlockBuilderView(draft: BlockDraft(template: template))
            }
        }
    }

    private func totalVolumeSection(blockStart: Date, blockEnd: Date) -> some View {
        let totalKg = BlockReviewStatistics.totalVolume(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )
        let workingSetCount = BlockReviewStatistics.workingSetCount(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )
        let sessionsCount = BlockReviewStatistics.sessionCount(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )

        return Section("Total volume") {
            if workingSetCount == 0 {
                Text("No logged sets in this block.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(BlockReviewStatistics.formattedKg(totalKg)) kg total")
                    .font(.headline)
                Text("\(workingSetCount) working sets across \(sessionsCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func e1RMDeltasSection(blockStart: Date, blockEnd: Date) -> some View {
        let deltas = BlockReviewStatistics.e1RMDeltas(
            context: ctx,
            start: blockStart,
            end: blockEnd
        )

        return Section("e1RM deltas") {
            if deltas.isEmpty {
                Text("Not enough sessions logged to compute deltas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deltas, id: \.exerciseID) { delta in
                    HStack {
                        Text(delta.exerciseName)
                        Spacer()
                        Text(BlockReviewStatistics.formattedDelta(delta.delta))
                            .foregroundStyle(color(for: delta.delta))
                    }
                }
            }
        }
    }

    private var prsHitSectionPlaceholder: some View {
        Section("PRs hit") {
            Text("Coming in Phase 6. Full PR detection ships with the progress views update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recommendedNextSection: some View {
        let recommendedKind = BlockReviewStatistics.recommendedNextKind(for: block)
        let labelKind = BlockPhaseColors.phaseLabel(recommendedKind).lowercased()

        return Section("Recommended next phase") {
            Text("Start \(labelKind) next.")
            Button {
                pendingNextBlockBuilder = BlockTemplates.template(for: recommendedKind)
            } label: {
                Text("Start \(labelKind.capitalized) Block")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            Button("Not now") {
                dismiss()
            }
            .foregroundStyle(.secondary)
        }
    }

    private func color(for delta: Double) -> Color {
        if delta > 0 { return .green }
        if delta < 0 { return .red }
        return .primary
    }

    private func acknowledgeAndDismiss() {
        do {
            try BlockReviewStatistics.acknowledge(
                block: block,
                context: ctx,
                now: Date.now
            )
            dismiss()
        } catch {
            acknowledgeError = "Couldn't save review. Try again."
        }
    }
}

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

    public static func formattedDelta(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) kg"
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
