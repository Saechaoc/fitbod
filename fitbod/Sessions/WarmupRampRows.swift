//
//  WarmupRampRows.swift
//  fitbod
//
//  Phase 3.2 BRU rewrite — replaces the v1 Apple HIG layout with the
//  brutalist visual system per 03-UI-SPEC v2 and why-weight.jsx lines 95–139.
//
//  Renders:
//    • BRUSectionHead "Warm-up ramp" with right trailing "Plate {smallest plate} · ×2 sides"
//    • Per-row 4-column grid: 36pt W{N} signal · 1fr weight+pct+reps · 1fr mini PlateStackViz · auto plate legend
//    • "WORK SETS BEGIN AT" footer row (labelSmall left, displayMedium right)
//    • "SKIP WARM-UPS" ghost text button in bruMuted
//    • "Warm up however you'd like." placeholder when warmupSets is empty
//
//  Design tokens:
//    W{N} label  — BRUFont.displayMedium (18pt) Color.bruSignal  (03-UI-SPEC reserved-for item 23)
//    Weight      — BRUFont.displayMedium (22pt via .custom) Color.bruInk
//    pct suffix  — BRUFont.bodyDefault (10pt) Color.bruInk opacity 0.5
//    reps/RPE    — BRUFont.bodyDefault (10pt) Color.bruMuted
//    plate legend— BRUFont.labelMicro (9pt) Color.bruMuted tracking 0.5
//    footer L    — BRUFont.labelSmall (10pt) Color.bruInk tracking 1.2 UPPERCASE
//    footer R    — BRUFont.displayMedium (18pt) Color.bruInk
//    skip button — BRUFont.labelSmall (10pt) Color.bruMuted tracking 1.2 UPPERCASE
//
//  Row separators: 1pt Color.bruHair bottom rule per why-weight.jsx line 107.
//
//  Mini PlateStackViz at heightScale 0.3 yields ~18pt tall plates per 03-UI-SPEC line 51.
//  Labels are suppressed at heightScale < 0.5 per PlateStackViz.isMini contract.
//
//  Threat mitigation T-03.2-05: computePlates returns empty array on PlateCalculator.solve
//  failure; PlateStackViz renders sleeve + end cap only — no crash.
//
//  Banned tokens: zero Color(.system*) / zero Capsule / zero RoundedRectangle /
//  zero Image(systemName:) / zero .font(.body|.headline|.caption|.title*).
//
//  File ownership: Wave 2 plan 03.2-03 only. Do NOT modify PlateStackDisclosure
//  or PrescriptionWeightCell (owned by Wave 2 plan 03.2-04).
//

import SwiftUI
import SwiftData

// MARK: - WarmupRampRows

/// The warm-up ramp block rendered inside `SessionExerciseCard` above working set rows.
///
/// Renders a `BRUSectionHead` header, one row per warm-up `SetEntry`, a "WORK SETS BEGIN AT"
/// footer row, and a "SKIP WARM-UPS" ghost text button. When `warmupSets` is empty, renders
/// only the "Warm up however you'd like." placeholder (no header, no footer).
public struct WarmupRampRows: View {

    // MARK: - Public properties

    public let warmupSets: [SetEntry]
    public let onSkip: () -> Void
    /// The parent SessionExercise — used to read prescribedWeight for pct computation.
    public let sessionExercise: SessionExercise
    /// Top working weight, displayed in the "WORK SETS BEGIN AT" footer row.
    /// Defaults to sessionExercise.prescribedWeight if not provided.
    public let topWorkingWeight: Double
    /// Bar weight for the plate math. Pass the same inventory the session
    /// used to generate the ramp, so the plates shown add up to the weight.
    public let barWeight: Double
    /// Plates available per side, from the same inventory as `barWeight`.
    public let plates: [(weight: Double, countPerSide: Int)]
    /// Unit label for every weight in the block ("lb" or "kg").
    public let unitLabel: String

    // MARK: - Init

    public init(
        warmupSets: [SetEntry],
        onSkip: @escaping () -> Void,
        sessionExercise: SessionExercise,
        topWorkingWeight: Double? = nil,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)],
        unitLabel: String
    ) {
        self.warmupSets = warmupSets
        self.onSkip = onSkip
        self.sessionExercise = sessionExercise
        self.topWorkingWeight = topWorkingWeight ?? sessionExercise.prescribedWeight ?? 0
        self.barWeight = barWeight
        self.plates = plates
        self.unitLabel = unitLabel
    }

    /// "Plate 2.5 lb · ×2 sides": the smallest plate in the inventory.
    private var plateNote: String? {
        guard let smallest = plates.map(\.weight).filter({ $0 > 0 }).min() else { return nil }
        return "Plate \(formatted(smallest)) \(unitLabel) · ×2 sides"
    }

    // MARK: - Sorted warmups

    private var sortedWarmups: [SetEntry] {
        warmupSets.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Ramp table (static per orderIndex and set count)

    // Keyed by (count, orderIndex) → (pct, reps, rpe)
    // 4-set barbell: 40%×5@4, 60%×3@5, 75%×2@6, 90%×1@7
    // 2-set dumbbell: 60%×3@5, 90%×1@7
    // per why-weight.jsx lines 98–102 and 03-UI-SPEC line 91

    private static let ramp4: [(pct: Int, reps: Int, rpe: Double)] = [
        (pct: 40, reps: 5, rpe: 4.0),
        (pct: 60, reps: 3, rpe: 5.0),
        (pct: 75, reps: 2, rpe: 6.0),
        (pct: 90, reps: 1, rpe: 7.0),
    ]
    private static let ramp2: [(pct: Int, reps: Int, rpe: Double)] = [
        (pct: 60, reps: 3, rpe: 5.0),
        (pct: 90, reps: 1, rpe: 7.0),
    ]

    // MARK: - Body

    public var body: some View {
        if warmupSets.isEmpty {
            // Placeholder per 03-UI-SPEC line 230 — single row, no row grid, no section head.
            Text("Warm up however you'd like.")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        } else {
            VStack(spacing: 0) {
                // Section head with the smallest plate per 03-UI-SPEC line 222–223.
                BRUSectionHead("Warm-up ramp", right: plateNote)

                // One row per warm-up set entry
                ForEach(sortedWarmups, id: \.id) { warmup in
                    warmupRow(warmup)
                    // 1pt bruHair bottom rule per why-weight.jsx line 107
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(height: 1)
                }

                // "WORK SETS BEGIN AT" footer row per 03-UI-SPEC line 228
                workSetsBeginAtRow

                // "SKIP WARM-UPS" ghost text button per 03-UI-SPEC line 229
                skipWarmUpsButton
            }
        }
    }

    // MARK: - Warmup row (4-column grid)

    @ViewBuilder
    private func warmupRow(_ warmup: SetEntry) -> some View {
        let pct = pctForSet(warmup)
        let reps = repsForSet(warmup)
        let rpe = rpeForSet(warmup)
        let plates = computePlates(weight: warmup.weight, bar: barWeight)

        HStack(spacing: 10) {
            // Column 1 — 36pt: W{N} in displayMedium bruSignal per 03-UI-SPEC reserved-for item 23
            Text("W\(warmup.orderIndex + 1)")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruSignal)
                .frame(width: 36, alignment: .leading)

            // Column 2 — 1fr: weight numeral + pct suffix + reps/rpe sub-line
            VStack(alignment: .leading, spacing: 2) {
                // Weight + pct per 03-UI-SPEC line 225
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // displayMedium at 22pt requires .custom because BRUFont.displayMedium is 18pt
                    // The spec calls for 22pt for the weight numeral (03-UI-SPEC line 88 / why-weight.jsx line 111)
                    Text(formatted(warmup.weight))
                        .font(.bru(.grotesk, size: 22))
                        .foregroundStyle(Color.bruInk)
                    Text("\(pct)%")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk.opacity(0.5))
                }
                // ×reps @ rpe sub-line per 03-UI-SPEC line 226
                Text("×\(reps) @ \(rpeFormatted(rpe))")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 3 — 1fr: mini PlateStackViz at heightScale 0.3 per 03-UI-SPEC line 51
            // "Mini plate viz at 0.3 scale yields ~18pt tall plates per 03-UI-SPEC line 51
            //  'mini PlateStackViz at 18pt height, scaled'."
            PlateStackViz(
                platesPerSide: plates,
                barLabel: "\(formatted(barWeight)) \(unitLabel)",
                heightScale: 0.3,
                showLegend: false
            )
            .frame(maxWidth: .infinity)

            // Column 4 — auto: plate legend "45+25+10" per 03-UI-SPEC line 227
            Text(platesList(plates))
                .font(BRUFont.labelMicro)
                .foregroundStyle(Color.bruMuted)
                .tracking(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Accessibility per 03-UI-SPEC line 500
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Warm-up set \(warmup.orderIndex + 1): \(formatted(warmup.weight)) \(unitLabel) × \(reps) reps at \(pct)% of working weight. Plates: \(platesList(plates))."
        )
    }

    // MARK: - "WORK SETS BEGIN AT" footer row

    private var workSetsBeginAtRow: some View {
        HStack {
            Text("WORK SETS BEGIN AT")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruInk)
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer()
            Text("\(formatted(topWorkingWeight)) \(unitLabel.uppercased())")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // NO border below — this row is the boundary before the first working SetRow
        // per 03-UI-SPEC line 228.
    }

    // MARK: - "SKIP WARM-UPS" ghost text button

    private var skipWarmUpsButton: some View {
        Button {
            onSkip()
        } label: {
            // NOT signal — skipping is structural, not aspirational per 03-UI-SPEC line 229.
            Text("SKIP WARM-UPS")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .accessibilityLabel("Skip all warm-up sets")
        .accessibilityHint("Marks warm-ups as done without logging them.")
    }

    // MARK: - Ramp math helpers

    /// Returns the warm-up percentage label for a given warm-up set.
    private func pctForSet(_ s: SetEntry) -> Int {
        let count = sortedWarmups.count
        switch count {
        case 4:
            return Self.ramp4[min(s.orderIndex, Self.ramp4.count - 1)].pct
        case 2:
            return Self.ramp2[min(s.orderIndex, Self.ramp2.count - 1)].pct
        default:
            // No standard ramp: show the real share of the working weight.
            guard topWorkingWeight > 0 else { return 0 }
            return Int((s.weight / topWorkingWeight * 100).rounded())
        }
    }

    /// Returns the rep count for a given warm-up set.
    private func repsForSet(_ s: SetEntry) -> Int {
        let count = sortedWarmups.count
        switch count {
        case 4:
            return Self.ramp4[min(s.orderIndex, Self.ramp4.count - 1)].reps
        case 2:
            return Self.ramp2[min(s.orderIndex, Self.ramp2.count - 1)].reps
        default:
            return max(1, 5 - s.orderIndex)
        }
    }

    /// Returns the derived RPE for a given warm-up set based on ramp position.
    /// Ramp: 40%→4 RPE, 60%→5, 75%→6, 90%→7 per why-weight.jsx lines 99–102.
    private func rpeForSet(_ s: SetEntry) -> Double {
        let count = sortedWarmups.count
        switch count {
        case 4:
            return Self.ramp4[min(s.orderIndex, Self.ramp4.count - 1)].rpe
        case 2:
            return Self.ramp2[min(s.orderIndex, Self.ramp2.count - 1)].rpe
        default:
            // Linear interpolation for non-standard counts
            let maxIdx = max(count - 1, 1)
            let t = Double(s.orderIndex) / Double(maxIdx)
            return 4.0 + t * 3.0 // 4→7 RPE over the ramp
        }
    }

    // MARK: - Plate helpers

    /// Computes plates-per-side for a warm-up set weight.
    /// Returns empty array on PlateCalculator.solve failure — PlateStackViz degrades
    /// gracefully to sleeve + end cap only (Threat T-03.2-05 mitigation).
    private func computePlates(weight: Double, bar: Double) -> [PlateStackViz.PlateDenomination] {
        guard let stack = PlateCalculator.solve(
            target: weight,
            barWeight: bar,
            plates: plates
        ) else {
            // solve returned nil — degrade to empty (T-03.2-05: no crash)
            return []
        }
        return stack.platesPerSide
    }

    /// Renders the auto plate legend as "45+25+10" per 03-UI-SPEC line 227.
    private func platesList(_ plates: [PlateStackViz.PlateDenomination]) -> String {
        guard !plates.isEmpty else { return "" }
        return plates.flatMap { denomination in
            Array(repeating: formatted(denomination.weight), count: denomination.count)
        }.joined(separator: "+")
    }

    // MARK: - Formatting helpers

    /// Formats a Double weight stripping trailing zeros ("%g").
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }

    /// Formats RPE value: whole numbers as integers, fractions with one decimal.
    private func rpeFormatted(_ rpe: Double) -> String {
        rpe == rpe.rounded() ? String(Int(rpe)) : String(format: "%.1f", rpe)
    }
}

// MARK: - Previews

#Preview("4-set barbell ramp") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 100
    ctx.insert(exercise)

    let specs: [(pct: Double, reps: Int)] = [(0.40, 5), (0.60, 3), (0.75, 2), (0.90, 1)]
    let sets: [SetEntry] = specs.enumerated().map { idx, spec in
        let s = SetEntry()
        s.orderIndex = idx
        s.weight = (100.0 * spec.pct).rounded()
        s.reps = spec.reps
        s.isWarmup = true
        s.setTypeRaw = "warmup"
        s.sessionExercise = exercise
        ctx.insert(s)
        return s
    }
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: sets,
            onSkip: {},
            sessionExercise: exercise,
            topWorkingWeight: 100,
            barWeight: 20,
            plates: [(25, 4), (20, 4), (10, 4), (5, 4), (2.5, 4), (1.25, 4)],
            unitLabel: "kg"
        )
        .background(Color.bruPaper)
    }
    .modelContainer(container)
}

#Preview("2-set dumbbell ramp") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 30
    ctx.insert(exercise)

    let specs: [(pct: Double, reps: Int)] = [(0.60, 3), (0.90, 1)]
    let sets: [SetEntry] = specs.enumerated().map { idx, spec in
        let s = SetEntry()
        s.orderIndex = idx
        s.weight = (30.0 * spec.pct).rounded()
        s.reps = spec.reps
        s.isWarmup = true
        s.setTypeRaw = "warmup"
        s.sessionExercise = exercise
        ctx.insert(s)
        return s
    }
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: sets,
            onSkip: {},
            sessionExercise: exercise,
            topWorkingWeight: 30,
            barWeight: 10,
            plates: [(5, 4), (2.5, 4), (1.25, 4)],
            unitLabel: "kg"
        )
        .background(Color.bruPaper)
    }
    .modelContainer(container)
}

#Preview("empty warmups — placeholder shown") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 25
    ctx.insert(exercise)
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: [],
            onSkip: {},
            sessionExercise: exercise,
            barWeight: 45,
            plates: [(45, 4), (25, 2), (10, 4), (5, 4), (2.5, 4)],
            unitLabel: "lb"
        )
        .background(Color.bruPaper)
    }
    .modelContainer(container)
}
