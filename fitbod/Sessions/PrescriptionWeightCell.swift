import SwiftUI

/// The set's editable load. Exercise guidance presents the recommendation and any range.
public struct PrescriptionWeightCell: View {
    @Binding public var weight: Double
    public let prescribed: Double?
    /// A calibrating set keeps the weight its workout seeded until the lifter picks one.
    public let range: ClosedRange<Double>?
    public let unitLabel: String
    @Binding public var wasManualOverride: Bool
    public let isComplete: Bool
    public let onTapEmptyCell: () -> Void
    public let onEditCommitted: () -> Void
    private let enteredWeight: Binding<Double?>?

    @State private var weightText: String
    @FocusState private var weightFocused: Bool

    public init(
        weight: Binding<Double>,
        prescribed: Double?,
        range: ClosedRange<Double>?,
        unitLabel: String,
        wasManualOverride: Binding<Bool>,
        isComplete: Bool = false,
        onTapEmptyCell: @escaping () -> Void = {},
        onEditCommitted: @escaping () -> Void = {},
        enteredWeight: Binding<Double?>? = nil
    ) {
        self._weight = weight
        self.prescribed = prescribed
        self.range = range
        self.unitLabel = unitLabel
        self._wasManualOverride = wasManualOverride
        self.isComplete = isComplete
        self.onTapEmptyCell = onTapEmptyCell
        self.onEditCommitted = onEditCommitted
        self.enteredWeight = enteredWeight
        self._weightText = State(initialValue: Self.text(for: weight.wrappedValue))
    }

    public var body: some View {
        TextField("—", text: $weightText)
            .keyboardType(.decimalPad)
            .focused($weightFocused)
            .selectsAllOnFocus(weightFocused)
            .frame(minWidth: WorkoutSetColumns.weight, minHeight: 44)
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(isComplete ? Color.bruSignalText : Color.bruInk)
            .contentShape(Rectangle())
            .onTapGesture {
                if weightText.isEmpty { onTapEmptyCell() }
                weightFocused = true
            }
            .accessibilityLabel("Weight")
            .accessibilityValue(accessibilityValueText)
            .overlay(alignment: .leading) {
                if wasManualOverride && !weightText.isEmpty { overrideBadge }
            }
            .onChange(of: weightText) { _, text in
                guard weightFocused, let value = Double(text), value.isFinite else { return }
                weight = value
                wasManualOverride = isManualOverride(value)
            }
            .onChange(of: weightFocused) { _, focused in
                guard !focused else { return }
                // Clearing the field keeps the last valid weight. Restore also
                // reflects actions taken while the field was losing focus.
                if Double(weightText) != weight { weightText = Self.text(for: weight) }
                onEditCommitted()
            }
            .onChange(of: weight) { _, newWeight in
                if !weightFocused, Double(weightText) != newWeight {
                    weightText = Self.text(for: newWeight)
                }
            }
            .onChange(of: weightInField) { _, value in
                enteredWeight?.wrappedValue = value
            }
            .onAppear {
                if !isComplete, !wasManualOverride, range == nil, weight == 0, let prescription {
                    weight = prescription
                }
                weightText = Self.text(for: weight)
            }
    }

    private var prescription: Double? {
        guard let prescribed, prescribed.isFinite, prescribed > 0 else { return nil }
        return prescribed
    }

    /// The row uses this value to reveal the focused field above the keyboard.
    private var weightInField: Double? {
        weightFocused ? Double(weightText) ?? 0 : nil
    }

    var accessibilityValueText: String {
        weightText.isEmpty ? "none" : "\(NumberText.weight(weight)) \(unitLabel)"
    }

    /// Keep the override mark within the weight column and out of the tap target.
    private var overrideBadge: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(weightText)
                .font(BRUFont.bodyEmphasis)
                .lineLimit(1)
                .hidden()
                .accessibilityHidden(true)
            Text("M")
                .font(BRUFont.labelMicro)
                .foregroundStyle(Color.bruMuted)
                .tracking(1.0)
                .fixedSize()
                .layoutPriority(1)
                .accessibilityLabel("changed from prescription")
        }
        .allowsHitTesting(false)
    }

    /// A positive load typed over a zero calibration range is a change too.
    func isManualOverride(_ value: Double) -> Bool {
        guard let prescription = prescription ?? (range == nil ? nil : 0) else { return false }
        return abs(value - prescription) > 0.001
    }

    private static func text(for weight: Double) -> String {
        weight > 0 ? NumberText.weight(weight) : ""
    }
}

#Preview("Editable set load during calibration") {
    @Previewable @State var weight = 110.0
    @Previewable @State var wasManualOverride = false
    PrescriptionWeightCell(
        weight: $weight,
        prescribed: 100,
        range: 95...105,
        unitLabel: "lb",
        wasManualOverride: $wasManualOverride
    )
    .padding()
    .background(Color.bruPaper)
}
