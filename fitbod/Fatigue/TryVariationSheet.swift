//
//  TryVariationSheet.swift
//  fitbod
//
//  Phase 5 PROG-06 Branch 4 — sheet listing 2-3 alternative exercises
//  by Exercise.mechanic + primary-muscle overlap, excluding the source
//  exercise AND exercises with zero logged SetEntry rows ever (per
//  RESEARCH §10 Pitfall #6 mitigation).
//
//  UI-SPEC §Component Inventory + §Copywriting Contract verbatim copy.
//  Presentation: medium + large detents, navigation title "Try
//  Variation".
//

import SwiftData
import SwiftUI

public struct TryVariationSheet: View {
    public let sourceExercise: Exercise
    public let onSelect: (Exercise?) -> Void

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Exercise] = []
    @State private var hasLoaded = false

    public init(sourceExercise: Exercise, onSelect: @escaping (Exercise?) -> Void) {
        self.sourceExercise = sourceExercise
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Exercises with similar mechanics and muscle targets:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if !hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    VStack(spacing: 8) {
                        Text("No similar exercises found")
                            .font(.headline)
                        Button("View all similar exercises in library") {
                            onSelect(nil)
                            dismiss()
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 32)
                } else {
                    List(candidates, id: \.id) { exercise in
                        HStack {
                            Text(exercise.canonicalName.capitalized)
                            Spacer()
                            if let mostRecent = mostRecentLogDate(for: exercise) {
                                Text(mostRecent, format: .dateTime.month().day())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(exercise)
                            dismiss()
                        }
                    }
                    .listStyle(.plain)

                    Button("View all similar exercises in library") {
                        onSelect(nil)
                        dismiss()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Try Variation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                candidates = loadCandidates()
                hasLoaded = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func loadCandidates() -> [Exercise] {
        let sourceMechanic = sourceExercise.mechanicRaw
        let sourcePrimarySlugs = Set(
            sourceExercise.primaryMuscleSlugsJoined
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        let sourceID = sourceExercise.id

        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.mechanicRaw == sourceMechanic && $0.id != sourceID }
        )
        let mechanicMatches = (try? ctx.fetch(descriptor)) ?? []

        // ≥1 overlapping primary-muscle slug (in-memory set intersection).
        let withOverlap = mechanicMatches.filter { candidate in
            let candidateSlugs = Set(
                candidate.primaryMuscleSlugsJoined
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
            return !candidateSlugs.isDisjoint(with: sourcePrimarySlugs)
        }

        // Per Pitfall #6 mitigation: exclude exercises with zero logged
        // SetEntry rows ever (i.e., never appeared in a SessionExercise).
        let logged = withOverlap.filter { candidate in
            let candidateID = candidate.id
            var d = FetchDescriptor<SessionExercise>(
                predicate: #Predicate<SessionExercise> { $0.exercise?.id == candidateID }
            )
            d.fetchLimit = 1
            return ((try? ctx.fetch(d))?.first) != nil
        }

        return Array(logged.sorted { $0.canonicalName < $1.canonicalName }.prefix(3))
    }

    @MainActor
    private func mostRecentLogDate(for exercise: Exercise) -> Date? {
        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exercise?.id == exerciseID }
        )
        descriptor.fetchLimit = 5
        let candidates = (try? ctx.fetch(descriptor)) ?? []
        return candidates.compactMap { $0.session?.startedAt }.max()
    }
}
