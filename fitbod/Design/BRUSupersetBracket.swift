// BRUSupersetBracket.swift
// fitbod — Phase 2.1 Plan 03
//
// Left-rail bracket drawn via Path. Used in RoutineBuilderView to group
// superset exercises visually with a 3-edge bruSignal bracket.
//
// Reference: bru-screens/routine-builder.jsx line 98-103
//   borderTop: `2px solid ${BRU.signal}`,
//   borderBottom: `2px solid ${BRU.signal}`,
//   borderLeft: `2px solid ${BRU.signal}`,
//   // NO borderRight — that's the BRU brutalist bracket signature
//
// SIZING NOTE (threat T-02.1-03-02):
//   The Canvas bracket uses `.frame(width: 8)` for explicit width.
//   Vertical height comes from the parent's intrinsic content height.
//   The wrapped content MUST have an intrinsic height or the Canvas
//   collapses to zero. Wrap inside a container with known height.
//
// USAGE:
//   BRUSupersetBracket {
//       ExerciseRow(exercise: bench)
//       ExerciseRow(exercise: row)
//   }

import SwiftUI

// MARK: - BRUSupersetBracket

/// Left-rail bracket that groups superset exercises.
///
/// Draws top-edge + left-edge + bottom-edge of a 2pt bruSignal path.
/// NO right edge — the open right side is the BRU brutalist bracket signature.
///
/// ```
/// ┌──────────────────────────────────────┐
/// ├ ← 8pt bracket   Content (16pt pad)  │
/// │  ┐                                  │
/// │  │ (3-sided: top, left, bottom)      │
/// │  ┘                                  │
/// ├──────────────────────────────────────┤
/// ```
public struct BRUSupersetBracket<Content: View>: View {

    // MARK: Properties

    private let content: Content

    // MARK: Init

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 0) {
            // 3-edge bracket Canvas — explicit width 8pt per interfaces spec
            Canvas { ctx, size in
                var p = Path()
                // Top-right → top-left
                p.move(to: CGPoint(x: size.width, y: 0))
                p.addLine(to: CGPoint(x: 0, y: 0))
                // Top-left → bottom-left
                p.addLine(to: CGPoint(x: 0, y: size.height))
                // Bottom-left → bottom-right (open right — NO right edge closing)
                p.addLine(to: CGPoint(x: size.width, y: size.height))

                ctx.stroke(p, with: .color(Color.bruSignal), lineWidth: 2)
            }
            .frame(width: 8)

            // Wrapped content with 16pt leading inset
            content
                .padding(.leading, 16)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Two grouped exercises") {
    BRUSupersetBracket {
        VStack(spacing: 0) {
            HStack {
                Text("Bench Press")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.bruHair)
                .frame(height: 1)

            HStack {
                Text("Barbell Row")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 16)
    .background(Color.bruPaper)
}

#Preview("Three exercise superset") {
    BRUSupersetBracket {
        VStack(spacing: 0) {
            ForEach(["Squat", "Romanian Deadlift", "Leg Press"], id: \.self) { name in
                VStack(spacing: 0) {
                    HStack {
                        Text(name)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if name != "Leg Press" {
                        Rectangle()
                            .fill(Color.bruHair)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 16)
    .background(Color.bruPaper)
}
#endif
