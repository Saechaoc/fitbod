import SwiftUI

/// The prescription belongs to the exercise. Set rows hold the load the lifter enters.
struct WorkoutWeightGuidance: View {
    let exercise: SessionExercise
    let explanation: PrescriptionExplanation?
    let unit: WeightUnit
    let loggedWeight: Double?
    let hasSetOffer: Bool

    @State private var expanded = false
    @State private var showingCalculation = false

    var body: some View {
        if let explanation, let suggestion = Self.suggestedLoad(explanation, unit: unit) {
            let summary = guidanceText(suggestion: suggestion)
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    expanded.toggle()
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Text(summary)
                            Spacer(minLength: 0)
                            whyLabel(suggestion)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary)
                            whyLabel(suggestion)
                        }
                    }
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(summary). Why this weight?")
                .accessibilityHint(expanded ? "Hides the reason" : "Shows the reason")
                .accessibilityIdentifier("card.why.\(exercise.orderIndex + 1)")

                if expanded {
                    Text(reason(for: explanation))
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showingCalculation = true
                    } label: {
                        Text("Calculation details")
                            .font(BRUFont.labelSmall)
                            .foregroundStyle(Color.bruSignalText)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("card.weightDetails.\(exercise.orderIndex + 1)")
                }
            }
            .padding(.horizontal, 16)
            .background(Color.bruBg2)
            .sheet(isPresented: $showingCalculation) {
                WhyThisWeightSheet(
                    explanation: explanation,
                    reps: targetReps,
                    rpe: exercise.targetRPE,
                    unitLabel: unit.rawValue,
                    loggedWeight: loggedWeight
                )
                .presentationDetents([.medium])
            }
            BRUDivider(.hair)
        } else {
            let summary = guidanceText(suggestion: nil)
            if !summary.isEmpty {
                Text(summary)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("card.weightGuidance.\(exercise.orderIndex + 1)")
                BRUDivider(.hair)
            }
        }
    }

    /// A recomputed range belongs to the current estimate when the frozen weight differs.
    static func suggestedLoad(_ explanation: PrescriptionExplanation, unit: WeightUnit) -> String? {
        if explanation.changedSinceStartLine == nil,
           let range = explanation.range,
           range.lowerBound.isFinite, range.upperBound.isFinite,
           range.upperBound > 0, range.lowerBound < range.upperBound {
            return "\(NumberText.weight(range.lowerBound))–\(NumberText.weight(range.upperBound)) \(unit.rawValue)"
        }
        guard let weight = explanation.suggestedWeight else { return nil }
        return "\(NumberText.weight(weight)) \(unit.rawValue)"
    }

    private var targetReps: ClosedRange<Int>? {
        SetRow.targetReps(low: exercise.targetRepsLow, high: exercise.targetRepsHigh)
    }

    private func guidanceText(suggestion: String?) -> String {
        var parts: [String] = []
        let programmed = WorkoutSetSuggestions.hasProgram(exercise.session)
        if let suggestion { parts.append("Suggested \(suggestion)") }
        if programmed, let reps = targetReps {
            // "1 rep", "5 reps" or "8–12 reps", as the prescription editor writes them.
            let count = reps.lowerBound == reps.upperBound
                ? BRUCountLabel.text(reps.lowerBound, "rep")
                : "\(reps.lowerBound)–\(BRUCountLabel.text(reps.upperBound, "rep"))"
            parts.append(suggestion == nil ? "Target \(count)" : count)
        }
        if let rpe = exercise.targetRPE, rpe.isFinite {
            parts.append("Target RPE \(NumberText.weight(rpe))")
        }
        if suggestion == nil, loggedWeight == nil {
            let equipment = exercise.exercise?.equipment
            let bodyweight = equipment == .bodyweight || equipment == .weightedBodyweight
            if programmed && !bodyweight {
                parts.append("Choose a starting weight")
            } else if !programmed && !hasSetOffer {
                parts.append(bodyweight ? "Enter your starting reps" : "Enter a starting weight and reps")
            }
        }
        return parts.joined(separator: " · ")
    }

    private func whyLabel(_ suggestion: String) -> some View {
        Text("Why \(suggestion)? \(expanded ? "▾" : "▸")")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruSignalText)
    }

    private func reason(for explanation: PrescriptionExplanation) -> String {
        if explanation.changedSinceStartLine != nil {
            return "This weight was set when the workout started. The calculation details show the current estimate."
        }
        if let deloadNote = explanation.deloadNoteLine { return deloadNote }
        if explanation.bumpOccurred {
            return "You reached \(BRUCountLabel.text(exercise.targetRepsHigh, "rep")) on every working set last time, so the plan targets a weight increase."
        }
        switch exercise.session?.progressionKind ?? .default {
        case .double: return "The plan uses your last workout’s weight while you build reps."
        case .rpe: return "Your past sets help estimate a load for today’s rep and effort targets."
        case .block:
            return explanation.phaseContextLine == nil
                ? "The plan uses your baseline weight for this lift."
                : "The plan uses your baseline and the current phase of your training block."
        case .hybrid: return "The plan checks your available block and effort targets when choosing the weight."
        }
    }
}
