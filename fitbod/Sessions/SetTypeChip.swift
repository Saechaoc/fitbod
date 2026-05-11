//
//  SetTypeChip.swift
//  fitbod
//
//  Wave-4 plan 04-01 — per-set type indicator chip used inside `SetRow`.
//
//  Tap cycles the set type:
//      working → warmup → drop → failure → restPause → working
//
//  Long-press surfaces a `contextMenu` for direct selection (UI-SPEC verbatim
//  labels "Working" / "Warm-up" / "Drop Set" / "To Failure" / "Rest-Pause").
//
//  Working sets render `EmptyView()` — the UI-SPEC explicitly states
//  "working sets render no chip at all" (the absence of a chip is the visual
//  signal that the set is a normal working set). Non-working types render a
//  system-colored capsule per the UI-SPEC color contract:
//
//    - warmup    → systemBlue
//    - drop      → systemOrange
//    - failure   → systemRed
//    - restPause → systemPurple
//
//  These are SEMANTIC SYSTEM COLORS, NOT the project accent. The chip never
//  consumes `Color.accentColor` — see UI-SPEC § Color "Explicitly NOT accent"
//  list (line 118 of 02-UI-SPEC.md).
//
//  Bound to a `@Binding<String>` (the raw value) rather than a
//  `@Binding<SetType>` to match the on-disk model field
//  (`SetEntry.setTypeRaw: String`) — the parent `SetRow` projects the binding
//  through `SetEntry`'s raw field without an enum round-trip on every keystroke.
//

import SwiftUI

public struct SetTypeChip: View {
    @Binding public var setTypeRaw: String

    public init(setTypeRaw: Binding<String>) {
        self._setTypeRaw = setTypeRaw
    }

    public var body: some View {
        Button {
            cycleType()
        } label: {
            if let type = SetType(rawValue: setTypeRaw), type != .working {
                Text(label(for: type))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(systemColor(for: type))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            } else {
                EmptyView()                                                    // working sets render no chip
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: SetType(rawValue: setTypeRaw) ?? .working))
        .accessibilityHint("Tap to cycle set type. Tap and hold for menu")     // UI-SPEC verbatim a11y
        .contextMenu {
            Button("Working") { setTypeRaw = SetType.working.rawValue }        // UI-SPEC verbatim
            Button("Warm-up") { setTypeRaw = SetType.warmup.rawValue }
            Button("Drop Set") { setTypeRaw = SetType.drop.rawValue }
            Button("To Failure") { setTypeRaw = SetType.failure.rawValue }
            Button("Rest-Pause") { setTypeRaw = SetType.restPause.rawValue }
        }
    }

    /// Cycles through the set types in the canonical order.
    ///
    /// Order: working → warmup → drop → failure → restPause → working.
    /// Captured as a stable array so the cycle is deterministic across
    /// SwiftUI re-renders.
    private func cycleType() {
        let order: [SetType] = [.working, .warmup, .drop, .failure, .restPause]
        let current = SetType(rawValue: setTypeRaw) ?? .working
        let idx = order.firstIndex(of: current) ?? 0
        setTypeRaw = order[(idx + 1) % order.count].rawValue
    }

    /// UI-SPEC verbatim labels: "Working" / "Warm-up" / "Drop Set" /
    /// "To Failure" / "Rest-Pause". Lowercase variants like "warmup" /
    /// "drop" / "failure" / "rest-pause" appear in the capsule visual
    /// (UI-SPEC § Session logger "Set-type chip — currently selected").
    private func label(for type: SetType) -> String {
        switch type {
        case .warmup: return "warmup"
        case .working: return "Working"
        case .drop: return "drop"
        case .failure: return "failure"
        case .restPause: return "rest-pause"
        }
    }

    /// UI-SPEC § Color "Set-type chip — system-colored per Hevy's convention":
    /// warmup = systemBlue / drop = systemOrange / failure = systemRed /
    /// rest-pause = systemPurple. These are NOT accent — they are semantic
    /// system colors and never broaden the accent reserved-for list.
    private func systemColor(for type: SetType) -> Color {
        switch type {
        case .warmup: return Color(.systemBlue)
        case .drop: return Color(.systemOrange)
        case .failure: return Color(.systemRed)
        case .restPause: return Color(.systemPurple)
        case .working: return .clear
        }
    }
}

#Preview("warmup chip") {
    @Previewable @State var raw = SetType.warmup.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}

#Preview("working (no chip)") {
    @Previewable @State var raw = SetType.working.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}
