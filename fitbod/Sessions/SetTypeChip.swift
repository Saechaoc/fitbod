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
// Long-press opens a Menu for direct selection (UI-SPEC verbatim labels
// "Working" / "Warm-up" / "Drop Set" / "To Failure" / "Rest-Pause").
// It is a Menu, not a .contextMenu: in a List row a context menu takes a
// hold anywhere in the row, including the RPE chips' hold for a half step.
// A working set has no chip, so `SetRow`'s set label opens the same menu.
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
        Menu {
            SetTypeMenuItems(setTypeRaw: $setTypeRaw)
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
        } primaryAction: {
            cycleType()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.label(for: current))
        .accessibilityHint("Tap to cycle set type. Tap and hold for menu")  // UI-SPEC verbatim a11y
    }

    // MARK: - Helpers

    /// Menu order, and the order a tap cycles through.
    static let order: [SetType] = [.working, .warmup, .drop, .failure, .restPause]

    private func cycleType() {
        let current = SetType(rawValue: setTypeRaw) ?? .working
        let idx = Self.order.firstIndex(of: current) ?? 0
        setTypeRaw = Self.order[(idx + 1) % Self.order.count].rawValue
    }

    /// The menu labels (UI-SPEC verbatim), also the accessibility label per
    /// UI-SPEC line 692.
    static func label(for type: SetType) -> String {
        switch type {
        case .working:   return "Working"
        case .warmup:    return "Warm-up"
        case .drop:      return "Drop Set"
        case .failure:   return "To Failure"
        case .restPause: return "Rest-Pause"
        }
    }
}

/// The set-type menu, shared by the chip and `SetRow`'s set label.
struct SetTypeMenuItems: View {
    @Binding var setTypeRaw: String

    var body: some View {
        ForEach(SetTypeChip.order, id: \.self) { type in
            Button(SetTypeChip.label(for: type)) { setTypeRaw = type.rawValue }
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
