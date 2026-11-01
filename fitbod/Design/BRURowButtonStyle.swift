// BRURowButtonStyle.swift
// fitbod
//
// The button style of a full-width row that opens a screen: Program's
// template rows, History's rows, the PR rows and Library's rows (T106).
// A row opens only on a tap. A plain button opens on any lift inside it,
// so a sideways drag or an edge swipe that started on a row opened the
// row. Here a touch that moves more than 10pt before it lifts opens
// nothing, a vertical drag still scrolls the list, and VoiceOver's
// activate still opens the row.
//
// The row keeps `.plain`'s look: its label as drawn, at 75% opacity while
// pressed, as `.plain` draws a pressed row. The pressed state shows once
// the finger has rested 0.15s, as a UIKit scroll view delays its
// controls, so a scroll that starts on a row does not flash it.
//
// USAGE:
//   NavigationLink(value: route) { SessionHistoryRow(session: session) }
//       .buttonStyle(.bruRow)

import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

public struct BRURowButtonStyle: PrimitiveButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        BRURowButton(configuration: configuration)
    }
}

public extension PrimitiveButtonStyle where Self == BRURowButtonStyle {
    /// `.buttonStyle(.bruRow)`
    static var bruRow: BRURowButtonStyle { BRURowButtonStyle() }
}

// MARK: - BRURowButton

private struct BRURowButton: View {
    /// `.plain`'s pressed opacity, measured on a pressed template row: ink
    /// on paper draws #464645.
    private static let pressedOpacity = 0.75

    let configuration: PrimitiveButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    var body: some View {
        configuration.label
            .opacity(isPressed ? Self.pressedOpacity : 1)
            .contentShape(Rectangle())
            .gesture(RowTap(
                isEnabled: isEnabled,
                onPressingChanged: { isPressed = $0 },
                onTap: { configuration.trigger() }
            ))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { configuration.trigger() }
    }
}

// MARK: - RowTap

/// A row's tap, as UIKit's gesture: it stays possible while the finger
/// rests, so a scroll view's pan or the edge swipe back can still take the
/// touch from it, and it fails once the finger moves more than
/// `RowTapRecognizer.slop`. A SwiftUI gesture that took the touch at
/// touch-down stopped the page scrolling (see SlotReorderPress).
private struct RowTap: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onPressingChanged: (Bool) -> Void
    let onTap: () -> Void

    func makeUIGestureRecognizer(context: Context) -> RowTapRecognizer {
        RowTapRecognizer()
    }

    func updateUIGestureRecognizer(_ recognizer: RowTapRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
        recognizer.onPressingChanged = onPressingChanged
    }

    func handleUIGestureRecognizerAction(_ recognizer: RowTapRecognizer, context: Context) {
        if recognizer.state == .ended {
            onTap()
        }
    }
}

// MARK: - RowTapRecognizer

/// One finger down and up within `slop` points of where it landed. It
/// reports the row pressed once the finger has rested `pressDelay`, and
/// released when the touch lifts, moves too far or is taken by another
/// gesture.
private final class RowTapRecognizer: UIGestureRecognizer {
    /// How far a touch may move, in points, and still open the row.
    static let slop: CGFloat = 10
    /// How long a finger rests before the row shows pressed.
    static let pressDelay: Duration = .milliseconds(150)

    var onPressingChanged: ((Bool) -> Void)?

    /// Where the finger landed, in the window.
    private var start: CGPoint?
    private var pressing: Task<Void, Never>?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard start == nil, touches.count == 1, let touch = touches.first else {
            fail()
            return
        }
        start = touch.location(in: nil)
        pressing = Task { [weak self] in
            try? await Task.sleep(for: Self.pressDelay)
            guard !Task.isCancelled else { return }
            self?.onPressingChanged?(true)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let start, let point = touches.first?.location(in: nil) else { return }
        if hypot(point.x - start.x, point.y - start.y) > Self.slop {
            fail()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if start == nil {
            fail()
        } else {
            state = .ended
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        fail()
    }

    override func reset() {
        super.reset()
        start = nil
        release()
    }

    private func fail() {
        release()
        state = .failed
    }

    private func release() {
        pressing?.cancel()
        pressing = nil
        onPressingChanged?(false)
    }
}

#if DEBUG
#Preview("BRURowButtonStyle") {
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(1...20, id: \.self) { index in
                Button {} label: {
                    Text("Row \(index)")
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bruRow)
                BRUDivider(.hair)
            }
        }
    }
    .background(Color.bruPaper)
}
#endif
