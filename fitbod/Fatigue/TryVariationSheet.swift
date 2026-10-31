//
//  TryVariationSheet.swift
//  fitbod
//
//  Phase 5.1 Plan 02 — BRU reskin: BRUHeaderBar + BRUSectionHead + BRUDivider rows
//  + BRUButton(.ghost) footer, replacing .navigationTitle + List + accent footer link.
//
//  BRU contract per must_haves:
//   - NavigationStack header replaced with BRUHeaderBar(left: nil, center: "Try
//     Variation", right: HeaderAction("DONE") { dismiss() })
//   - Section subtitle uses BRUFont.bodyDefault
//   - List replaced with VStack + BRUDivider(.hair) between rows
//   - BRUSectionHead at top
//   - Per-row HStack: exercise name (bodyEmphasis bruInk) + date/NEVER LOGGED (labelMicro bruMuted)
//   - Footer: BRUButton("View all similar exercises in library", kind: .ghost)
//   - Empty state: verbatim "No similar exercises found in your library." (bodyDefault bruMuted)
//   - NO .navigationTitle / NO Color.accentColor / NO Color(.system*) /
//     NO RoundedRectangle / NO .font(.body|.headline|.subheadline|.caption|.footnote) /
//     NO Image(systemName:)
//
//  Public init signature UNCHANGED: (sourceExercise: Exercise, onSelect: (Exercise?) -> Void)
//  FetchDescriptor pipeline PRESERVED (mechanic → primary-muscle overlap → logged gate → sort + prefix(3))
//  Sheet detents PRESERVED: [.medium, .large]
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
            VStack(spacing: 0) {
                BRUHeaderBar(
                    left: nil,
                    center: "Try Variation",
                    right: HeaderAction("DONE") { dismiss() }
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        BRUSectionHead("Exercises with similar mechanics and muscle targets:")

                        if !hasLoaded {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 80)
                                .padding(16)
                        } else if candidates.isEmpty {
                            Text("No similar exercises found in your library.")
                                .font(BRUFont.bodyDefault)
                                .foregroundStyle(Color.bruMuted)
                                .padding(16)
                        } else {
                            ForEach(Array(candidates.enumerated()), id: \.element.id) { idx, exercise in
                                TryVariationRow(
                                    exercise: exercise,
                                    lastLogged: mostRecentLogDate(for: exercise)
                                ) {
                                    onSelect(exercise)
                                    dismiss()
                                }
                                BRUDivider(.hair)
                            }
                        }

                        BRUButton("View all similar exercises in library", kind: .ghost) {
                            presentLibraryDeepLink()
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(Color.bruPaper)
        }
        .presentationDetents([.medium, .large])
        .task {
            candidates = loadCandidates()
            hasLoaded = true
        }
    }

    // MARK: - Library deep-link

    private func presentLibraryDeepLink() {
        onSelect(nil)
        dismiss()
    }

    // MARK: - Data pipeline (PRESERVED verbatim)

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

        // >= 1 overlapping primary-muscle slug (in-memory set intersection).
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
        let results = (try? ctx.fetch(descriptor)) ?? []
        return results.compactMap { $0.session?.startedAt }.max()
    }
}

// MARK: - TryVariationRow

private struct TryVariationRow: View {
    let exercise: Exercise
    let lastLogged: Date?
    let onTap: () -> Void

    private var dateLabel: String {
        guard let date = lastLogged else { return "NEVER LOGGED" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(exercise.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Text(dateLabel)
                    .font(BRUFont.labelMicro)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
