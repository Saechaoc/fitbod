import SwiftUI

/// The set's editable load. Exercise guidance presents the recommendation and any range.
public struct PrescriptionWeightCell: View {
    @Binding public var weight: Double
    public let prescribed: Double?
    /// A calibrating set keeps the weight its workout seeded until the lifter picks one.
    public let range: ClosedRange<Double>?
    public let offeredWeight: Double?
    public let unitLabel: String
    @Binding public var wasManualOverride: Bool
    public let isComplete: Bool
    public let onTapEmptyCell: () -> Void
    public let onEditCommitted: () -> Void
    private let enteredWeight: Binding<Double?>?
    @Environment(\.locale) private var locale

    @State private var weightText: String
    @FocusState private var weightFocused: Bool

    public init(
        weight: Binding<Double>,
        prescribed: Double?,
        range: ClosedRange<Double>?,
        offeredWeight: Double? = nil,
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
        self.offeredWeight = offeredWeight
        self.unitLabel = unitLabel
        self._wasManualOverride = wasManualOverride
        self.isComplete = isComplete
        self.onTapEmptyCell = onTapEmptyCell
        self.onEditCommitted = onEditCommitted
        self.enteredWeight = enteredWeight
        self._weightText = State(initialValue: Self.text(
            for: weight.wrappedValue, enteredZero: wasManualOverride.wrappedValue
        ))
    }

    public var body: some View {
        let prompt = displayedOffer.map { WorkoutLoadInput.text($0, locale: locale) } ?? "—"
        TextField("Weight", text: $weightText, prompt: Text(prompt).foregroundStyle(Color.bruMuted))
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
            .accessibilityHint(displayedOffer == nil ? "" : "Suggested weight. Tap to edit.")
            .overlay(alignment: .leading) {
                if wasManualOverride && !weightText.isEmpty && (weight != 0 || isManualOverride(weight)) {
                    overrideBadge
                }
            }
            .onChange(of: weightText) { _, text in
                guard weightFocused, let value = WorkoutLoadInput.value(text, locale: locale) else { return }
                weight = value
                // Zero can be an intentional unloaded set. Keep it even if
                // a later set's offer changes to a positive load.
                wasManualOverride = value == 0 || isManualOverride(value)
            }
            .onChange(of: weightFocused) { _, focused in
                guard !focused else { return }
                // Clearing the field keeps the last valid weight. Restore also
                // reflects actions taken while the field was losing focus.
                if WorkoutLoadInput.value(weightText, locale: locale) != weight { weightText = enteredWeightText }
                onEditCommitted()
            }
            .onChange(of: weight) { _, newWeight in
                if !weightFocused, WorkoutLoadInput.value(weightText, locale: locale) != newWeight {
                    weightText = enteredWeightText
                }
            }
            .onChange(of: weightInField) { _, value in
                enteredWeight?.wrappedValue = value
            }
            .onAppear {
                weightText = enteredWeightText
            }
            .onChange(of: locale) {
                if !weightFocused { weightText = enteredWeightText }
            }
    }

    private var prescription: Double? {
        guard let prescribed, prescribed.isFinite, prescribed > 0 else { return nil }
        return prescribed
    }

    /// The row uses this value to reveal the focused field above the keyboard.
    private var weightInField: Double? {
        weightFocused ? WorkoutLoadInput.value(weightText, locale: locale) ?? 0 : nil
    }

    var accessibilityValueText: String {
        if let displayedOffer { return "\(WorkoutLoadInput.text(displayedOffer, locale: locale)) \(unitLabel)" }
        return weightText.isEmpty ? "none" : "\(WorkoutLoadInput.text(weight, locale: locale)) \(unitLabel)"
    }

    private var displayedOffer: Double? {
        guard !isComplete, !wasManualOverride, weight == 0 else { return nil }
        return offeredWeight
    }

    private var enteredWeightText: String {
        Self.text(for: weight, enteredZero: wasManualOverride, locale: locale)
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
        guard let prescription = prescription ?? offeredWeight ?? (range == nil ? nil : 0) else { return false }
        return abs(value - prescription) > 0.001
    }

    private static func text(for weight: Double, enteredZero: Bool, locale: Locale = .current) -> String {
        weight != 0 || enteredZero ? WorkoutLoadInput.text(weight, locale: locale) : ""
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
