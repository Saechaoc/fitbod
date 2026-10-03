// SetTypeChip.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 31).
// UI-SPEC v2 § Color line 222 + 257: the system-colored capsules from v1
// (blue / orange / red / purple per type) are deprecated. BRU replaces them
// with uppercase letterspaced labelSmall text inside ink-outlined chips.
// Only the "TOP"-style set (not yet in model: topSet) gets a signal outline
// — all current types use bruInk except `working` which renders NO chip.
//
// Tap cycles set type:  working → warmup → drop → failure → restPause → working
// Long-press presents a .contextMenu for direct selection (UI-SPEC verbatim
// labels "Working" / "Warm-up" / "Drop Set" / "To Failure" / "Rest-Pause").
//
// BRU contract: NO capsule shapes / NO RoundedRectangle / NO accent color
//               NO Image(systemName:) / NO Color(.system*) / NO .font(.caption)
//               NO bordered button style

import SwiftUI

public struct SetTypeChip: View {
    @Binding public var setTypeRaw: String

    public init(setTypeRaw: Binding<String>) {
        self._setTypeRaw = setTypeRaw
    }

    public var body: some View {
        let current = SetType(rawValue: setTypeRaw) ?? .working
        Button {
            cycleType()
        } label: {
            // Working sets render NO chip per UI-SPEC line 378.
            // All other types render a BRUChip with ink outline;
            // bruSignal is reserved for TOP set (future model extension).
            switch current {
            case .working:
                EmptyView()
            case .warmup:
                BRUChip("W/UP", color: .bruInk)
            case .drop:
                BRUChip("DROP", color: .bruInk)
            case .failure:
                BRUChip("FAIL", color: .bruInk)
            case .restPause:
                BRUChip("RP", color: .bruInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: current))
        .accessibilityHint("Tap to cycle set type. Tap and hold for menu")  // UI-SPEC verbatim a11y
        .contextMenu {
            Button("Working")    { setTypeRaw = SetType.working.rawValue }   // UI-SPEC verbatim
            Button("Warm-up")    { setTypeRaw = SetType.warmup.rawValue }
            Button("Drop Set")   { setTypeRaw = SetType.drop.rawValue }
            Button("To Failure") { setTypeRaw = SetType.failure.rawValue }
            Button("Rest-Pause") { setTypeRaw = SetType.restPause.rawValue }
        }
    }

    // MARK: - Private helpers

    /// Cycles through the set types in canonical order.
    /// Order: working → warmup → drop → failure → restPause → working.
    private func cycleType() {
        let order: [SetType] = [.working, .warmup, .drop, .failure, .restPause]
        let current = SetType(rawValue: setTypeRaw) ?? .working
        let idx = order.firstIndex(of: current) ?? 0
        setTypeRaw = order[(idx + 1) % order.count].rawValue
    }

    /// Accessibility label uses the long-press menu label format per UI-SPEC line 692.
    private func accessibilityLabel(for type: SetType) -> String {
        switch type {
        case .working:   return "Working"
        case .warmup:    return "Warm-up"
        case .drop:      return "Drop Set"
        case .failure:   return "To Failure"
        case .restPause: return "Rest-Pause"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("W/UP chip") {
    @Previewable @State var raw = SetType.warmup.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}

#Preview("DROP chip") {
    @Previewable @State var raw = SetType.drop.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}

#Preview("FAIL chip") {
    @Previewable @State var raw = SetType.failure.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}

#Preview("RP chip") {
    @Previewable @State var raw = SetType.restPause.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}

#Preview("working (no chip)") {
    @Previewable @State var raw = SetType.working.rawValue
    return SetTypeChip(setTypeRaw: $raw).padding()
}
#endif
