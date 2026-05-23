//
//  MuscleVolumeTargetEditor.swift
//  fitbod
//
//  Phase 5 SET-05 Settings entry point — sectioned List per muscle
//  with disclosure into MuscleVolumeTargetStepper (plan 05's shared
//  component). Reached from `SettingsView` → "Volume Targets"
//  NavigationLink.
//
//  Global "Reset All to RP Defaults" destructive button + `.alert`
//  confirmation per UI-SPEC §Copywriting Contract verbatim copy.
//
//  Per CONTEXT Claude's Discretion: "Both surfaces edit the same row;
//  Settings is the primary entry point." The inline editor in
//  `PerMuscleDetailView` (plan 05) and this Settings editor edit the
//  same persisted `MuscleVolumeTarget` rows.
//

import SwiftData
import SwiftUI

public struct MuscleVolumeTargetEditor: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \MuscleGroup.displayName) private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]
    @State private var expandedSlug: String? = nil
    @State private var presentingResetAllAlert: Bool = false

    public init() {}

    public var body: some View {
        List {
            if allMuscles.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No muscles found")
                            .font(.headline)
                        Text("Muscles are seeded on first launch. Restart the app if this persists.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(allMuscles, id: \.persistentModelID) { muscle in
                    muscleSection(muscle: muscle)
                }

                Section {
                    Button("Reset All to RP Defaults", role: .destructive) {
                        presentingResetAllAlert = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Volume Targets")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset all volume targets?", isPresented: $presentingResetAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                resetAllToRPDefaults()
            }
        } message: {
            Text("Your custom values will be replaced with RP defaults for all 17 muscles.")
        }
    }

    @ViewBuilder
    private func muscleSection(muscle: MuscleGroup) -> some View {
        let target = allTargets.first { $0.muscle?.slug == muscle.slug }
        let isExpanded = expandedSlug == muscle.slug

        Section {
            Button {
                expandedSlug = isExpanded ? nil : muscle.slug
            } label: {
                HStack {
                    Text(muscle.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let t = target {
                        Text("\(t.mev) / \(t.mav) / \(t.mrv)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let target = target {
                    MuscleVolumeTargetStepper(target: target)
                        .padding(.vertical, 8)
                } else {
                    Text("No persisted target row for \(muscle.displayName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if isExpanded {
                Text("MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func resetAllToRPDefaults() {
        for muscle in allMuscles {
            let slug = muscle.slug
            let landmark = RPVolumeLandmarks.landmark(for: slug)
            if let target = allTargets.first(where: { $0.muscle?.slug == slug }) {
                target.mv = landmark.mv
                target.mev = landmark.mev
                target.mav = landmark.mav
                target.mrv = landmark.mrv
                target.userEdited = false
            }
        }
        try? ctx.save()
    }
}
