//
//  MuscleVolumeTargetEditor.swift
//  fitbod
//
//  Phase 5.1-06 — BRU reskin of the Settings "Volume Targets" screen.
//  Replaces List(.insetGrouped) host with BRUHeaderBar +
//  ScrollView + LazyVStack per UI-SPEC v2 and 05-UI-SPEC
//  §Copywriting Contract verbatim copy.
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), RoundedRectangle(cornerRadius:),
//    Capsule(), .navigationTitle(, List(.insetGrouped), Image(systemName:)
//    No .foregroundStyle(.red) — replaced by BRUButton(kind: .signal)
//    No .font(.body|.headline|.caption|.subheadline|.footnote|.title)
//
//  Data layer UNCHANGED from Phase 5 baseline:
//    @Query<MuscleGroup>(sort: \MuscleGroup.displayName)
//    @Query<MuscleVolumeTarget>
//    @Environment(\.modelContext)
//
//  Verbatim copy (UI-SPEC §MuscleVolumeTargetEditor):
//    Navigation title:        "Volume Targets"
//    Row trailing preview:    "{mev} / {mav} / {mrv}"
//    Footer:                  "MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks."
//    Global reset button:     "Reset All to RP Defaults" (BRUButton kind: .signal)
//    Alert title:             "Reset all volume targets?"
//    Alert body:              "Your custom values will be replaced with RP defaults for all 17 muscles."
//    Alert buttons:           "Reset All" (destructive) / "Cancel"
//

import SwiftData
import SwiftUI

public struct MuscleVolumeTargetEditor: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MuscleGroup.displayName) private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]
    @State private var expandedSlug: String? = nil
    @State private var showingResetConfirmation: Bool = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: "Volume Targets",
                right: nil
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if allMuscles.isEmpty {
                        emptyMusclesState
                    } else {
                        ForEach(allMuscles, id: \.persistentModelID) { muscle in
                            muscleSectionRow(muscle)
                            BRUDivider(.hair)
                        }

                        BRUButton("Reset All to RP Defaults", kind: .signal) {
                            showingResetConfirmation = true
                        }
                        .padding(16)

                        Text("MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks.")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .background(Color.bruPaper)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Reset all volume targets?", isPresented: $showingResetConfirmation) {
            Button("Reset All", role: .destructive) {
                resetAllToRPDefaults()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your custom values will be replaced with RP defaults for all 17 muscles.")
        }
    }

    // MARK: - Empty state

    private var emptyMusclesState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No muscles found")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Muscles are seeded on first launch. Restart the app if this persists.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(32)
    }

    // MARK: - Muscle section row

    @ViewBuilder
    private func muscleSectionRow(_ muscle: MuscleGroup) -> some View {
        let target = allTargets.first { $0.muscle?.slug == muscle.slug }
        let isExpanded = expandedSlug == muscle.slug

        VStack(spacing: 0) {
            // T38: the row opens in place, so it carries the expand marker
            // other BRU rows use, and VoiceOver reads whether it is open.
            Button {
                expandedSlug = isExpanded ? nil : muscle.slug
            } label: {
                HStack {
                    Text(muscle.displayName.uppercased())
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                    if let t = target {
                        Text("\(t.mev) / \(t.mav) / \(t.mrv)")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                    }
                    Text(isExpanded ? "▴" : "▾")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                if let t = target {
                    MuscleVolumeTargetStepper(target: t, showsResetButton: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    Text("No persisted target row for \(muscle.displayName).")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .padding(16)
                }
            }
        }
    }

    // MARK: - Reset helper (PRESERVED verbatim from Phase 5 baseline)

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
