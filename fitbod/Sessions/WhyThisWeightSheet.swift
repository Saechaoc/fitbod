//
//  WhyThisWeightSheet.swift
//  fitbod
//
//  Phase 3.2-05 — BRU brutalist rewrite of the prescription-disclosure sheet.
//
//  Architecture: NavigationStack → ScrollView → VStack(spacing: 0)
//    1. Hero slab (bruInk background, bruPaper text)
//       - Status line: "● RECOMMENDED · {FORMULA}" in bruSignal labelSmall
//       - Trailing set-type: "{SET TYPE}" in bruPaper 50% opacity labelSmall
//       - Hero weight numeral: 128pt SpaceGrotesk-Bold in bruPaper
//         (Font.custom override justified: BRUFont.displayHero = 56pt enum default;
//          03-UI-SPEC line 87 / why-weight.jsx line 17 mandate 128pt for THIS hero)
//       - Unit suffix: displayLarge bruPaper 60% opacity
//       - 2pt bruPaper top rule → 2-column REPS | RPE sub-band
//    2. BRUSectionHead("Why this weight", right: "−")
//    3. Numbered step blocks (01 / 02 / 03) in VStack(spacing: 8)
//       - When .calibrating: CalibratingProgressMeter between step 02 and step 03
//    4. Footer bar: 2pt bruInk top rule + BRUButton(.ghost) "Override" +
//       BRUButton(.signal) "Use {weight} ▸"
//    5. Bottom safe-area filler: 24pt bruBg rectangle
//
//  Presentation: .presentationDetents([.medium]) — NOT expandable per 03-UI-SPEC line 410.
//
//  Phase 3.1 sessionIntent-prefix logic: calibrating/calibrated status copy is prefixed
//  with "{Intent.capitalized} session — " when explanation.sessionIntent is non-nil.
//  03-UI-SPEC Verification anchor: "\(Intent.capitalized) session — calibrating (n / threshold sets)"
//
//  Visual reference: bru-screens/why-weight.jsx
//  Spec: 03-UI-SPEC.md § WhyThisWeightSheet, lines 157–192, 405–415, 494–498
//

import SwiftUI

// MARK: - WhyThisWeightSheet

public struct WhyThisWeightSheet: View {

    // MARK: - Properties

    public let explanation: PrescriptionExplanation

    /// Called (and the sheet dismissed) when the user taps "Use {weight} ▸".
    /// PrescriptionWeightCell writes `roundedWeight` into the set's weight.
    public var onUseSuggested: (() -> Void)?

    /// Called (and the sheet dismissed) when the user taps "Override".
    /// PrescriptionWeightCell then focuses the weight field.
    public var onOverride: (() -> Void)?

    /// Target reps for the hero slab sub-band. Nil renders "—".
    public let reps: Int?

    /// Target RPE for the hero slab sub-band. Nil renders "—".
    public let rpe: Double?

    /// Set-type label for the hero slab trailing indicator, e.g. "TOP SET".
    /// Defaults satisfy existing 03-08 SessionExerciseCard call sites (threat model T-03.2-10).
    public let setTypeLabel: String

    /// Weight unit suffix shown in hero and step 03, e.g. "kg" or "lb".
    public let unitLabel: String

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    /// Creates a WhyThisWeightSheet.
    ///
    /// All new parameters have defaults so existing callers compile unchanged
    /// (threat model T-03.2-10 — backward compatibility).
    ///
    /// - Parameters:
    ///   - explanation: The prescription data object from `ProgressionStrategy.prescribe(...)`.
    ///   - onUseSuggested: Optional callback invoked when the user accepts the suggestion.
    ///   - onOverride: Optional callback invoked when the user chooses Override.
    ///   - reps: Target reps for the hero sub-band. Nil = no prior prescription.
    ///   - rpe: Target RPE for the hero sub-band. Nil for double-progression exercises.
    ///   - setTypeLabel: Trailing set-type label in the hero status line (e.g. "TOP SET").
    ///   - unitLabel: Weight unit string appended to numerals (e.g. "kg", "lb").
    public init(
        explanation: PrescriptionExplanation,
        onUseSuggested: (() -> Void)? = nil,
        onOverride: (() -> Void)? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        setTypeLabel: String = "TOP SET",
        unitLabel: String
    ) {
        self.explanation = explanation
        self.onUseSuggested = onUseSuggested
        self.onOverride = onOverride
        self.reps = reps
        self.rpe = rpe
        self.setTypeLabel = setTypeLabel
        self.unitLabel = unitLabel
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        heroSlab
                        BRUSectionHead("Why this weight", right: "−")
                        stepsBlock
                        // Bottom padding inside scroll area
                        Color.clear.frame(height: 16)
                    }
                }

                footerBar
                // Bottom safe-area filler — xl spacing, bruBg fill
                // 03-UI-SPEC line 67 + why-weight.jsx line 145
                Rectangle()
                    .fill(Color.bruBg)
                    .frame(height: 24)
            }
            .background(Color.bruPaper)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Hero Slab

    @ViewBuilder
    private var heroSlab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status line
            HStack(alignment: .center, spacing: 0) {
                // Leading: "● RECOMMENDED · {FORMULA}" in bruSignal
                // The "●" is U+25CF Unicode character in a Text view, NOT a Circle shape (03.2-05 must_have)
                Text("● RECOMMENDED · \(explanation.formulaName.uppercased())")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignal)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                // Trailing: "{SET TYPE}" in bruPaper 50% opacity
                Text(setTypeLabel.uppercased())
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            .padding(.bottom, 6)

            // Hero weight numeral
            // 128pt override: BRUFont.displayHero = 56pt enum default; 03-UI-SPEC line 87
            // and why-weight.jsx line 17 mandate 128pt for this hero context specifically.
            // Font face is BRU-canonical (SpaceGrotesk-Bold) — future font-substitution
            // audits will catch drift. This is the only Font.custom call in this file.
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formatted(explanation.roundedWeight))
                    .font(.bru(.grotesk, size: 128, relativeTo: .largeTitle))
                    .foregroundStyle(Color.bruPaper)

                Text(unitLabel.uppercased())
                    .font(BRUFont.displayLarge)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
                    .padding(.bottom, 12)
            }

            // 2pt bruPaper top rule before REPS | RPE sub-band
            Rectangle()
                .fill(Color.bruPaper)
                .frame(height: 2)
                .padding(.top, 8)

            // REPS | RPE 2-column sub-band
            HStack(spacing: 0) {
                // Left cell: REPS
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruPaper.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(reps.map { "×\($0)" } ?? "×—")
                        .font(BRUFont.displayLarge)
                        .foregroundStyle(Color.bruPaper)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

                // 1pt bruPaper vertical rule
                Rectangle()
                    .fill(Color.bruPaper)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Right cell: RPE
                VStack(alignment: .leading, spacing: 4) {
                    Text("RPE")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruPaper.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(rpe.map { "@\(formattedRPE($0))" } ?? "@—")
                        .font(BRUFont.displayLarge)
                        .foregroundStyle(Color.bruSignal)
                }
                .padding(.vertical, 8)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.bruInk)
        // Accessibility: hero slab as a combined element
        // 03-UI-SPEC line 495
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroAccessibilityLabel: String {
        let weightStr = formatted(explanation.roundedWeight)
        let repsStr = reps.map { "\($0)" } ?? "unknown"
        let rpeStr = rpe.map { formattedRPE($0) } ?? "not applicable"
        return "Recommended weight \(weightStr) \(unitLabel), reps \(repsStr), RPE \(rpeStr), \(setTypeLabel)"
    }

    // MARK: - Steps Block

    @ViewBuilder
    private var stepsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Step 01: Last session
            stepRow(
                index: "01",
                label: "Last session",
                body: explanation.lastSessionLine ?? "No prior data — starting fresh.",
                bodyColor: explanation.lastSessionLine != nil ? Color.bruInk : Color.bruMuted,
                subCopy: step01SubCopy
            )

            // Step 02: Target computation
            stepRow(
                index: "02",
                label: step02Label,
                body: step02Body,
                bodyColor: step02BodyColor,
                subCopy: step02SubCopy
            )

            // Calibration meter between step 02 and step 03 (conditional)
            if case .calibrating(let n, let threshold) = explanation.status {
                CalibratingProgressMeter(
                    current: n,
                    threshold: threshold,
                    rangeText: "± 5 \(unitLabel.uppercased())"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Step 03: Plate rounding
            step03Row
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // 2pt bruInk bottom rule closes the steps section
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Step helpers

    private var step01SubCopy: String? {
        guard explanation.lastSessionLine != nil, let rpeVal = rpe else { return nil }
        let rir = (10.0 - rpeVal) / 2.0
        if rir <= 0 { return nil }
        let formatted = rir == rir.rounded() ? String(Int(rir)) : String(format: "%.1f", rir)
        return "You had ~\(formatted) reps in reserve."
    }

    private var step02Label: String {
        let name = explanation.formulaName.lowercased()
        if name.contains("double") {
            return "Double progression"
        }
        guard let rpe else { return "Target weight" }
        return "Target @ RPE \(formattedRPE(rpe))"
    }

    private var step02Body: String {
        if let computed = explanation.computedLine {
            return computed
        }
        // Double progression branches
        if explanation.bumpOccurred {
            return "All sets cleared top of range last time → bumping by \(incrementText()) \(unitLabel)."
        }
        if explanation.lastSessionLine == nil {
            return "No prior data — starting at prescribed weight."
        }
        // Held (partial reps)
        return "Weight holds."
    }

    private var step02BodyColor: Color {
        if explanation.computedLine != nil { return Color.bruInk }
        if explanation.bumpOccurred { return Color.bruInk }
        // No prior data or held — muted
        return Color.bruMuted
    }

    private var step02SubCopy: String? {
        switch explanation.status {
        case .calibrating(let n, let threshold):
            return calibratingStatusText(current: n, threshold: threshold)
        case .calibrated:
            return calibratedStatusText()
        case .notApplicable:
            return nil
        }
    }

    // Step 03 uses a custom attributed body (signal for rounded weight)
    @ViewBuilder
    private var step03Row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Step index numeral — bruSignal displayMedium 22pt (03-UI-SPEC line 88)
            Text("03")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruSignal)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                // Label
                Text("Rounded to plate \(incrementText()) \(unitLabel)")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .textCase(.uppercase)
                    .tracking(0.8)

                // Body: "{raw} → {rounded} ({plate list})"
                // Rounded weight is bruSignal fontWeight:700; plate list is bruMuted
                // why-weight.jsx lines 74–77; 03-UI-SPEC line 187
                step03Body
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var step03Body: some View {
        // Compute raw weight (un-rounded) from roundedLine if possible
        let raw = rawWeightFromLine ?? explanation.roundedWeight
        let roundedStr = formatted(explanation.roundedWeight)
        let rawStr = formatted(raw)
        let showArrow = abs(raw - explanation.roundedWeight) > 0.01
        let prefix = Text(showArrow ? "\(rawStr) → " : "")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruInk)
        let rounded = Text(roundedStr)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruSignal)
            .bold()
        let suffix = Text(plateListSuffix)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)

        Text("\(prefix)\(rounded)\(suffix)")
    }

    private var plateListSuffix: String {
        // Attempt to extract plate list from roundedLine parenthetical
        let line = explanation.roundedLine
        if let parenStart = line.firstIndex(of: "("),
           let parenEnd = line.lastIndex(of: ")") {
            let inner = String(line[line.index(after: parenStart)..<parenEnd])
            // Filter out "rounded down to X kg plates" style — we want plate counts like "45 + 25 + 10"
            if !inner.lowercased().contains("rounded") {
                return " (\(inner))"
            }
        }
        return ""
    }

    private var rawWeightFromLine: Double? {
        // Try to parse the raw (un-rounded) weight from roundedLine "→ 102.5 kg ..."
        // Format: "→ {rounded} {unit} (rounded down to {increment} {unit} plates)"
        // We infer raw from computedLine if present; otherwise return nil (no arrow shown)
        if let computed = explanation.computedLine {
            // Extract trailing number from computed line
            let components = computed.components(separatedBy: "→")
            if let last = components.last {
                let digits = last.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces).first ?? ""
                return Double(digits)
            }
        }
        return nil
    }

    // MARK: - Generic Step Row

    @ViewBuilder
    private func stepRow(
        index: String,
        label: String,
        body: String,
        bodyColor: Color,
        subCopy: String?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Step index numeral — bruSignal displayMedium 22pt (03-UI-SPEC line 88)
            Text(index)
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruSignal)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                // Step label — bodyEmphasis, UPPERCASE, tracking 0.8
                // 03-UI-SPEC line 89: bodyEmphasis 14pt (BRUFont enum); spec lists 12pt — close
                // enough variation captured under the single bodyEmphasis role (inline justification)
                Text(label)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .textCase(.uppercase)
                    .tracking(0.8)

                // Step body
                Text(body)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(bodyColor)

                // Optional sub-copy
                if let sub = subCopy {
                    Text(sub)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer Bar

    @ViewBuilder
    private var footerBar: some View {
        HStack(spacing: 0) {
            BRUButton("Override", kind: .ghost, size: .md) {
                onOverride?()
                dismiss()
            }
            .frame(maxWidth: .infinity)

            BRUButton("Use \(formatted(explanation.roundedWeight)) ▸", kind: .signal, size: .md) {
                onUseSuggested?()
                dismiss()
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Phase 3.1 Status Text Helpers
    // Preserved verbatim from v1 Phase 3.1 (PIVOT-04 / D-12) — only relocated.
    // UI-SPEC Verification anchor: "\(Intent.capitalized) session — calibrating (n / threshold sets)"

    /// Phase 3.1 calibrating status copy with optional session-intent prefix.
    private func calibratingStatusText(current n: Int, threshold: Int) -> String {
        if let sessionIntent = explanation.sessionIntent {
            return "\(sessionIntent.rawValue.capitalized) session — calibrating (\(n) / \(threshold) sets)"
        }
        return "Tuchscherer prior · calibrating (\(n) sets logged of \(threshold))"
    }

    /// Phase 3.1 calibrated status copy with optional session-intent prefix.
    private func calibratedStatusText() -> String {
        if let sessionIntent = explanation.sessionIntent {
            return "\(sessionIntent.rawValue.capitalized) session — calibrated"
        }
        if case .calibrated = explanation.status {
            // Count is not available in .calibrated — use generic form
            return "Calibrated · weighted-mean e1RM"
        }
        return "Calibrated"
    }

    // MARK: - Formatting Helpers
    // incrementText() preserved verbatim from v1 lines 222-235 — only relocated.

    private func formatted(_ weight: Double) -> String {
        let isWhole = weight.truncatingRemainder(dividingBy: 1) == 0
        return isWhole ? String(Int(weight)) : String(format: "%g", weight)
    }

    private func formattedRPE(_ rpeValue: Double) -> String {
        let isWhole = rpeValue.truncatingRemainder(dividingBy: 1) == 0
        return isWhole ? String(Int(rpeValue)) : String(format: "%g", rpeValue)
    }

    /// Parses the plate increment from roundedLine.
    /// Preserved verbatim from v1 lines 222-235.
    /// Format: "→ 102.5 kg (rounded down to 2.5 kg plates)"
    private func incrementText() -> String {
        let line = explanation.roundedLine
        if let range = line.range(of: #"to (\d+\.?\d*) \w+ plates"#, options: .regularExpression) {
            let match = String(line[range])
            let parts = match.components(separatedBy: " ")
            if parts.count >= 2, let _ = Double(parts[1]) {
                return parts[1]
            }
        }
        return "?"
    }
}

// MARK: - Previews

#if DEBUG
#Preview("calibrating — RPE autoreg") {
    // Phase 3.1 (PIVOT-04 / D-12): sessionIntent: .strength exercises the
    // prefixed status copy "Strength session — calibrating (8 / 10 sets)".
    let explanation = PrescriptionExplanation(
        lastSessionLine: "195 × 8 @ RPE 8.5 (May 16)",
        formulaName: "RPE autoregulation",
        computedLine: "195 × (1 − 0.04 × (9 − 8.5)) → 207 lb",
        roundedWeight: 205.0,
        roundedLine: "→ 205 lb (rounded down to 2.5 lb plates)",
        status: .calibrating(current: 8, threshold: 10),
        bumpOccurred: false,
        range: 200.0...210.0,
        sessionIntent: .strength
    )
    return Color.bruPaper
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                reps: 8,
                rpe: 9.0,
                setTypeLabel: "TOP SET",
                unitLabel: "lb"
            )
            .presentationDetents([.medium])
        }
}

#Preview("calibrated — RPE autoreg") {
    // Phase 3.1 (PIVOT-04 / D-12): sessionIntent: .hypertrophy exercises
    // the prefixed "Hypertrophy session — calibrated" copy.
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil,
        sessionIntent: .hypertrophy
    )
    return Color.bruPaper
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                reps: 8,
                rpe: 8.5,
                setTypeLabel: "TOP SET",
                unitLabel: "kg"
            )
            .presentationDetents([.medium])
        }
}

#Preview("bump occurred — double progression") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 × 12 @ RPE 8.5 (May 15)",
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 102.5,
        roundedLine: "→ 102.5 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: true,
        range: nil
    )
    return Color.bruPaper
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                reps: 8,
                rpe: nil,
                setTypeLabel: "TOP SET",
                unitLabel: "kg"
            )
            .presentationDetents([.medium])
        }
}

#Preview("first session — double progression") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: nil,
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 60.0,
        roundedLine: "→ 60 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: false,
        range: nil
    )
    return Color.bruPaper
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                reps: 5,
                rpe: nil,
                setTypeLabel: "WORKING SET",
                unitLabel: "kg"
            )
            .presentationDetents([.medium])
        }
}

#Preview("override active — Use suggested weight button") {
    // Phase 3.1 (PIVOT-04 / D-12): third sessionIntent-bearing preview;
    // covers the .calibrated branch with override-active button visible.
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil,
        sessionIntent: .strength
    )
    return Color.bruPaper
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                onUseSuggested: { /* write back to SetEntry.actualWeight in plan 03-08 */ },
                reps: 8,
                rpe: 8.5,
                setTypeLabel: "TOP SET",
                unitLabel: "kg"
            )
            .presentationDetents([.medium])
        }
}
#endif
