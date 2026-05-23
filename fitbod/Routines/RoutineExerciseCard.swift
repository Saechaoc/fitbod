//
//  RoutineExerciseCard.swift
//  fitbod
//
//  Wave-3 plan 03-02 — one row in the routine builder's exercise list.
//  Renders a `DisclosureGroup` whose label is the exercise's name +
//  intent chip + collapsed prescription summary ("3×8–12 · 180s") and
//  whose body is the inline `PrescriptionEditorRow`.
//
//  The intent chip uses the UI-SPEC § Color § Accent surface #15
//  treatment — `Color.accentColor.opacity(0.15)` capsule fill with
//  accent-colored caption label.
//
//  ## Plan 03-03 additions
//
//  1. **Leading accent rail** — when `draft.supersetGroupID != nil`, a
//     4pt-wide accent-color bar renders on the left edge of the card
//     (UI-SPEC accent surface #9 / spacing token "xs"). This is the
//     visual signal that the exercise is paired into a superset / giant
//     set with another row. The rail is meaning-bearing — render ONLY
//     when grouped, never as decoration.
//
//  2. **Long-press context menu** — `.contextMenu { ... }` exposes the
//     UI-SPEC verbatim entries: "Edit Prescription" / "Move to
//     Superset…" (when ungrouped) or "Remove from Superset" (when
//     grouped) / "Make Superset" / "Duplicate Exercise" / "Remove"
//     (destructive). The menu actions take callback closures injected
//     by the parent `RoutineBuilderView` so the card itself stays
//     pure-presentational.
//

import SwiftUI

public struct RoutineExerciseCard: View {
    @Bindable public var draft: RoutineExerciseDraft
    @Binding public var isExpanded: Bool

    public let onAssignSuperset: (RoutineExerciseDraft) -> Void
    public let onRemoveFromSuperset: (RoutineExerciseDraft) -> Void
    public let onDuplicate: (RoutineExerciseDraft) -> Void
    public let onRemove: (RoutineExerciseDraft) -> Void
    public let onEditWarmup: (RoutineExerciseDraft) -> Void

    public init(
        draft: RoutineExerciseDraft,
        isExpanded: Binding<Bool>,
        onAssignSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemoveFromSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onDuplicate: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemove: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onEditWarmup: @escaping (RoutineExerciseDraft) -> Void = { _ in }
    ) {
        self.draft = draft
        self._isExpanded = isExpanded
        self.onAssignSuperset = onAssignSuperset
        self.onRemoveFromSuperset = onRemoveFromSuperset
        self.onDuplicate = onDuplicate
        self.onRemove = onRemove
        self.onEditWarmup = onEditWarmup
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // UI-SPEC accent surface #9 — 4pt-wide accent rail on the
            // left edge of any card whose supersetGroupID != nil. Render
            // ONLY when grouped; the rail is meaning-bearing, not
            // decorative.
            if draft.supersetGroupID != nil {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.vertical, 2)
                    .padding(.trailing, 8)
                    .accessibilityLabel("Part of a superset")
            }

            VStack(alignment: .leading, spacing: 12) {
                // Header — exercise name + intent chip + summary always
                // pinned to the TOP of the card, full-width. Tapping the
                // header toggles the inline prescription editor; the
                // chevron mirrors the toggle state. We avoid
                // `DisclosureGroup` because in an active-edit-mode List
                // the disclosure label and body are squeezed into a
                // narrow center column, which broke label wrapping and
                // detached the header visually.
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.exercise?.name ?? "Exercise")
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 8) {
                                intentChip
                                Text(prescriptionSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isExpanded ? "Collapses prescription editor" : "Expands prescription editor")

                if isExpanded {
                    PrescriptionEditorRow(draft: draft)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button("Edit Prescription") {
                isExpanded.toggle()
            }
            Button {
                onEditWarmup(draft)
            } label: {
                Label("Edit warm-up…", systemImage: "flame")
            }
            if draft.supersetGroupID == nil {
                Button("Move to Superset…") { onAssignSuperset(draft) }
            } else {
                Button("Remove from Superset") { onRemoveFromSuperset(draft) }
            }
            Button("Make Superset") { onAssignSuperset(draft) }
            Button("Duplicate Exercise") { onDuplicate(draft) }
            Divider()
            Button("Remove", role: .destructive) { onRemove(draft) }
        }
    }

    /// UI-SPEC § Color § Accent surface #15 — intent chip on the
    /// builder exercise card. Capsule fill in 15%-opacity accent +
    /// accent-colored caption label.
    private var intentChip: some View {
        Text(draft.intent.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.accentColor.opacity(0.15))
            }
            .accessibilityLabel("Intent: \(draft.intent.rawValue.capitalized)")
    }

    /// "3×8–12 · 180s" — sets × reps · rest. When `targetRepsLow ==
    /// targetRepsHigh` the en-dash collapses to a single value.
    private var prescriptionSummary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        return "\(draft.targetSets)×\(reps) · \(draft.prescribedRestSeconds)s"
    }
}
