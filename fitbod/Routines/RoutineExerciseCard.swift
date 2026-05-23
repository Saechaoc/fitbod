//
//  RoutineExerciseCard.swift
//  fitbod
//
//  One row in the routine builder's exercise list. Renders the
//  exercise name + collapsed prescription summary ("3×8–12 · 180s")
//  as the always-pinned header; tapping toggles the inline
//  `PrescriptionEditorRow` body.
//
//  ## Phase 3.1 (PIVOT-04 / D-11) — per-exercise intent chip removed
//
//  In Phase 2 the card's header rendered an inline accent intent
//  capsule next to the prescription summary, using UI-SPEC § Color §
//  Accent surface #15 (`Color.accentColor.opacity(0.15)` fill with
//  accent caption label). Phase 3.1 hoisted Intent from per-exercise
//  to session-level, so the per-card chip has no field to read from
//  anymore — its data source moved to `Session.intent`. The
//  user-facing chip surface is now `SessionLoggerView`'s header
//  `IntentChip` (Plan 06), surfaced once per session instead of once
//  per exercise. UI-SPEC accent surface #15 is deprecated; #22 (the
//  SessionLoggerView header chip) is its replacement. Per UI-SPEC §
//  RoutineExerciseCard header — intent chip REMOVED: the header's
//  bottom row collapses from `[exercise name] / [chip][summary]` to
//  `[exercise name] / [summary]`.
//
//  The builder cards focus exclusively on the prescription summary —
//  intent is no longer a per-exercise concept in the data model.
//
//  ## Other card features (carried forward from Phase 2)
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
    public let hasBlock: Bool
    @Binding public var isExpanded: Bool

    public let onAssignSuperset: (RoutineExerciseDraft) -> Void
    public let onRemoveFromSuperset: (RoutineExerciseDraft) -> Void
    public let onDuplicate: (RoutineExerciseDraft) -> Void
    public let onRemove: (RoutineExerciseDraft) -> Void
    public let onEditWarmup: (RoutineExerciseDraft) -> Void

    public init(
        draft: RoutineExerciseDraft,
        hasBlock: Bool = false,
        isExpanded: Binding<Bool>,
        onAssignSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemoveFromSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onDuplicate: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemove: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onEditWarmup: @escaping (RoutineExerciseDraft) -> Void = { _ in }
    ) {
        self.draft = draft
        self.hasBlock = hasBlock
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
                // Header — exercise name + prescription summary always
                // pinned to the TOP of the card, full-width. Tapping the
                // header toggles the inline prescription editor; the
                // chevron mirrors the toggle state. We avoid
                // `DisclosureGroup` because in an active-edit-mode List
                // the disclosure label and body are squeezed into a
                // narrow center column, which broke label wrapping and
                // detached the header visually. (Phase 3.1 removed the
                // per-exercise intent chip that used to live between the
                // name and the summary — see file header.)
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
                            Text(prescriptionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
                    PrescriptionEditorRow(draft: draft, hasBlock: hasBlock)
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

    /// "3×8–12 · 180s" — sets × reps · rest. When `targetRepsLow ==
    /// targetRepsHigh` the en-dash collapses to a single value.
    private var prescriptionSummary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        return "\(draft.targetSets)×\(reps) · \(draft.prescribedRestSeconds)s"
    }
}
