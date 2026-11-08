// SetTypeChip.swift
// fitbod
//
// The set-type labels and the shared set-type picker.
//
// The set label in `SetRow` ("S2", "W1") is the one set-type control
// (FT-10): a type other than working shows its tag under the label, and
// a tap opens the picker, which marks the current type. The chip that
// sat on a row's second line and cycled the type on a tap is gone, so
// one control shows and changes the type. The name stays from the chip
// days, so the audits that list the file still find it.
//
// Labels are UI-SPEC verbatim: "Working" / "Warm-up" / "Drop Set" /
// "To Failure" / "Rest-Pause"; tags "W/UP" / "DROP" / "FAIL" / "RP"
// (UI-SPEC line 378). A working set carries no tag.
//
// BRU contract: NO capsule shapes / NO RoundedRectangle / NO accent color
//               NO Image(systemName:) / NO Color(.system*) / NO .font(.caption)

import SwiftUI

public enum SetTypeChip {
    /// Picker order.
    static let order: [SetType] = [.working, .warmup, .drop, .failure, .restPause]

    /// The picker labels (UI-SPEC verbatim), also the set label's
    /// accessibility value per UI-SPEC line 692.
    static func label(for type: SetType) -> String {
        switch type {
        case .working:   return "Working"
        case .warmup:    return "Warm-up"
        case .drop:      return "Drop Set"
        case .failure:   return "To Failure"
        case .restPause: return "Rest-Pause"
        }
    }

    /// The tag under a set label, or nil for a working set.
    static func tag(for type: SetType) -> String? {
        switch type {
        case .working:   return nil
        case .warmup:    return "W/UP"
        case .drop:      return "DROP"
        case .failure:   return "FAIL"
        case .restPause: return "RP"
        }
    }
}

/// The set-type picker inside the set label's menu: every type, the
/// current one marked.
struct SetTypeMenuItems: View {
    @Binding var setTypeRaw: String

    var body: some View {
        Picker("Set type", selection: $setTypeRaw) {
            ForEach(SetTypeChip.order, id: \.self) { type in
                Text(SetTypeChip.label(for: type)).tag(type.rawValue)
            }
        }
    }
}
