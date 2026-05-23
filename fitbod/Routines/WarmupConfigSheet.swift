//
//  WarmupConfigSheet.swift
//  fitbod
//
//  Plan 03-07 Task 1 — per-exercise warm-up override editor.
//  Presented as a `.medium`-detent sheet from the routine builder's
//  "Edit warm-up…" long-press context-menu entry (Task 2).
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
//  ## Structure (UI-SPEC § WarmupConfigSheet verbatim)
//
//  NavigationStack › Form:
//    Toggle "Auto warm-up"
//    Section footer (switches on draftEnabled)
//    Toggle "Skip warm-ups this session only"
//  .toolbar: Cancel (leading) + Save (trailing)
//  .presentationDetents([.medium]) — caller's responsibility.
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
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto warm-up", isOn: $draftEnabled)
                } footer: {
                    Text(
                        draftEnabled
                            ? "Generates a 4-set ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1) based on your plate inventory."
                            : "No warm-up sets will be generated for this exercise."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Skip warm-ups this session only", isOn: $draftSkipNextSession)
                }
            }
            .navigationTitle("Warm-up Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        commit()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            initializeDraft()
        }
    }

    // MARK: - Draft initialization

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
