//
//  WarmupConfigSheet.swift
//  fitbod
//
//  Plan 03.2-09 — BRU brutalist reskin of the warm-up override editor.
//  Presented as a `.medium`-detent sheet from the routine builder's
//  "Edit warm-up…" long-press context-menu entry (call site unchanged).
//
//  ## Binding contract
//
//  `config: Binding<WarmupConfig?>` — nil means "no override" (default
//  auto-warm-up behavior). After Save, commit() either:
//    - Sets config back to nil when the user leaves the "auto warm-up on /
//      skip=false" defaults (keeps the model clean per RESEARCH § Pitfall 5).
//    - Sets config to a WarmupConfig when the user has made a real change
//      (warm-up off OR skipNextSession on).
//
//  ## BRU Structure (UI-SPEC v2 § WarmupConfigSheet lines 326-332)
//
//  VStack(spacing: 0):
//    BRUHeaderBar(center: "WARM-UP SETTINGS")
//    Toggle row — Auto warm-up + contextual footer copy
//    Toggle row — Skip warm-ups this session only
//    Spacer
//    Footer bar — BRUButton(.ghost) CANCEL + BRUButton(.signal) SAVE
//    24pt bruBg filler
//  .background(Color.bruPaper)
//
//  ## Threat mitigations (T-03.2-17, T-03.2-18)
//
//  T-03.2-17: Toggle tint uses `.tint(Color.bruInk)` which is a soft preference
//             on iOS — system blue shows through when the tint does not apply.
//             Acceptable: accentColor is explicitly absent, and the toggle still
//             functions correctly. Comment below documents the soft-tint limitation.
//
//  T-03.2-18: Swipe-down dismissal is available (UIKit sheet behavior). The
//             BRUButton(.ghost) CANCEL in the footer provides the explicit cancel
//             affordance, replacing the v1 toolbar Cancel button without removing
//             the user-facing option.
//

import SwiftUI

public struct WarmupConfigSheet: View {
    @Binding public var config: WarmupConfig?
    @Environment(\.dismiss) private var dismiss

    @State private var draftEnabled: Bool = true
    @State private var draftSkipNextSession: Bool = false

    public init(config: Binding<WarmupConfig?>) {
        self._config = config
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header — BRUHeaderBar replaces NavigationStack + .navigationTitle
            // UI-SPEC v2 line 326: "WARM-UP SETTINGS" — BRUHeaderBar center, UPPERCASE
            BRUHeaderBar(center: "WARM-UP SETTINGS")

            // Toggle rows
            toggleRows

            Spacer()

            // Footer — ghost CANCEL (left) + signal SAVE (right)
            footerBar

            // Safe-area / screen-edge filler
            Rectangle()
                .fill(Color.bruBg)
                .frame(height: 24)
        }
        .background(Color.bruPaper)
        .onAppear {
            initializeDraft()
        }
    }

    // MARK: - Toggle Rows

    private var toggleRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            autoWarmupRow
            skipSessionRow
        }
    }

    /// Auto warm-up toggle with contextual footer copy.
    /// UI-SPEC v2 lines 327-329.
    private var autoWarmupRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Auto warm-up")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                // T-03.2-17: `.tint(.bruInk)` is a soft preference — system blue may
                // show through on some iOS 18 hardware variants. Acceptable: the toggle
                // still functions and we do not use Color.accentColor.
                Toggle("", isOn: $draftEnabled)
                    .labelsHidden()
                    .tint(Color.bruInk)
            }
            // UI-SPEC v2 line 328 (enabled): "Generates a ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1) based on your plate inventory."
            // UI-SPEC v2 line 329 (disabled): "No warm-up sets will be generated for this exercise."
            Text(
                draftEnabled
                    ? "Generates a ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1) based on your plate inventory."
                    : "No warm-up sets will be generated for this exercise."
            )
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // 1pt bruHair bottom rule between rows
        .overlay(
            Rectangle()
                .fill(Color.bruHair)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    /// Skip-this-session toggle.
    /// UI-SPEC v2 line 330.
    private var skipSessionRow: some View {
        HStack {
            Text("Skip warm-ups this session only")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Spacer()
            // T-03.2-17: soft tint — see note above.
            Toggle("", isOn: $draftSkipNextSession)
                .labelsHidden()
                .tint(Color.bruInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer Bar

    /// Ghost CANCEL (left) + signal SAVE (right) with 2pt bruInk top rule.
    /// UI-SPEC v2 lines 331-332. Ghost is left per BRU convention (plate-calc.jsx lines 132-134).
    private var footerBar: some View {
        VStack(spacing: 0) {
            // 2pt bruInk top rule
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)

            HStack(spacing: 0) {
                // CANCEL — ghost (left, secondary action)
                BRUButton("CANCEL", kind: .ghost) {
                    dismiss()
                }
                .frame(maxWidth: .infinity)

                // SAVE — signal (right, primary CTA)
                BRUButton("SAVE", kind: .signal) {
                    commit()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Draft Initialization

    /// Populate draft state from the current config value. Called on
    /// appear so the sheet reflects the saved state each time it opens.
    /// nil config → default "auto on / don't skip" (same as the
    /// "no override = default behavior" contract in WarmupConfig.swift).
    private func initializeDraft() {
        if let cfg = config {
            draftEnabled = cfg.enabled
            draftSkipNextSession = cfg.skipNextSession
        } else {
            draftEnabled = true
            draftSkipNextSession = false
        }
    }

    // MARK: - Commit

    /// Compute the next config value and write it through the @Binding.
    ///
    /// Model-cleanliness rule (RESEARCH § Pitfall 5): if the user left
    /// the defaults (auto on, don't skip), write nil back — no override
    /// needed. Only write a non-nil WarmupConfig when the user has
    /// explicitly changed behavior.
    private func commit() {
        if draftEnabled && !draftSkipNextSession {
            // Restored to default behavior — clear the override.
            config = nil
        } else {
            config = WarmupConfig(enabled: draftEnabled, skipNextSession: draftSkipNextSession)
        }
    }
}

// MARK: - Previews

#Preview("No override yet (default state)") {
    @Previewable @State var localConfig: WarmupConfig? = nil
    return Text("Warm-up: default")
        .sheet(isPresented: .constant(true)) {
            WarmupConfigSheet(config: $localConfig)
                .presentationDetents([.medium])
        }
}

#Preview("Existing override — warm-up disabled") {
    @Previewable @State var localConfig: WarmupConfig? = WarmupConfig(enabled: false, skipNextSession: false)
    return Text("Warm-up: disabled")
        .sheet(isPresented: .constant(true)) {
            WarmupConfigSheet(config: $localConfig)
                .presentationDetents([.medium])
        }
}

#Preview("Skip this session") {
    @Previewable @State var localConfig: WarmupConfig? = WarmupConfig(enabled: true, skipNextSession: true)
    return Text("Warm-up: skip session")
        .sheet(isPresented: .constant(true)) {
            WarmupConfigSheet(config: $localConfig)
                .presentationDetents([.medium])
        }
}
