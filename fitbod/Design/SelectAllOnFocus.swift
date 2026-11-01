// SelectAllOnFocus.swift
// fitbod
//
// Number entry like a user (ticket T39, Milestone 1 review item 5).
//
// A number field selects its whole value when it takes focus, so the first
// digit typed replaces the value instead of joining it: a target of 6 reps
// once became 16. A screen with a number field also gives its number pad a
// DONE, styled like the workout logger's, since a number pad has no return
// key, and a focused field scrolls clear of the keyboard and its DONE.

import SwiftUI
import UIKit

extension View {
    /// Selects the field's whole text each time `isFocused` turns true.
    /// Apply it to a number field, with the focus state the field is
    /// `.focused` on.
    func selectsAllOnFocus(_ isFocused: Bool) -> some View {
        modifier(SelectAllOnFocus(isFocused: isFocused))
    }

    /// A DONE on the keyboard that ends editing in whichever field has
    /// focus. Put it on the screen, not on each row: every row's toolbar
    /// would add its own DONE.
    func keyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                } label: {
                    Text("DONE")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)
                }
            }
        }
    }

    /// While `isRevealed`, scrolls the list or scroll view this view sits
    /// in until the view shows above the keyboard, with room under it for
    /// the keyboard's DONE. A list scrolls a focused field only just clear
    /// of the keyboard, under DONE, and a scroll view leaves it behind the
    /// keyboard.
    func revealsAboveKeyboard(_ isRevealed: Bool) -> some View {
        background {
            if isRevealed {
                RevealAboveKeyboard()
            }
        }
    }
}

/// Selects a field's whole text as it takes focus.
struct SelectAllOnFocus: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isFocused) { _, focused in
            guard focused else { return }
            // The tap that focused the field places its caret first, so the
            // selection waits for the next turn of the main queue.
            Task { @MainActor in
                UIApplication.shared.sendAction(
                    #selector(UITextField.bruSelectAllText(_:)), to: nil, from: nil, for: nil
                )
            }
        }
    }
}

extension UITextField {
    /// Selects all of the field's text, without the edit menu that
    /// `selectAll(_:)` opens. Sent with no target, it reaches the field
    /// that has focus.
    @objc fileprivate func bruSelectAllText(_ sender: Any?) {
        selectedTextRange = textRange(from: beginningOfDocument, to: endOfDocument)
    }
}

/// Scrolls the list or scroll view it sits in so the view it backs shows
/// above the keyboard and its DONE (ticket T125 for the logger's plates, T39
/// for every number field it backs).
private struct RevealAboveKeyboard: UIViewRepresentable {
    func makeUIView(context: Context) -> Reveal {
        let view = Reveal()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: Reveal, context: Context) {}

    final class Reveal: UIView {
        /// Room between the view and the keyboard's DONE bar.
        private static let margin: CGFloat = 8

        /// The keyboard's frame on screen when it last showed, DONE's bar
        /// included. A list's or scroll view's keyboard inset leaves that bar
        /// out, and on iOS 26 and later the top of the keys as well, so the
        /// inset alone would leave a focused field behind the keyboard.
        private static var keyboardFrame: CGRect?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard window != nil else { return }
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardDidShow(_:)),
                name: UIResponder.keyboardDidShowNotification, object: nil
            )
            // A keyboard already up, as when focus moves from another field.
            perform(#selector(reveal), with: nil, afterDelay: 0)
        }

        @objc private func keyboardDidShow(_ notification: Notification) {
            Self.keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            reveal()
        }

        @objc private func reveal() {
            let scrollView = sequence(first: self as UIView, next: \.superview)
                .lazy.compactMap { $0 as? UIScrollView }.first
            guard let scrollView, window != nil, !bounds.isEmpty else { return }
            var visible = scrollView.bounds.inset(by: scrollView.adjustedContentInset)
            if let keyboardFrame = Self.keyboardFrame {
                // The window fills the screen, so its coordinates are the
                // keyboard frame's.
                let keyboardTop = scrollView.convert(keyboardFrame, from: nil).minY
                visible.size.height = max(0, min(visible.height, keyboardTop - visible.minY))
            }
            var rect = convert(bounds, to: scrollView)
            rect.size.height += Self.margin
            // A view taller than the space above the keyboard, such as a set
            // row at accessibility text sizes, keeps its top, where its
            // fields are, in view.
            rect.size.height = min(rect.height, visible.height)
            let distance: CGFloat
            if rect.maxY > visible.maxY {
                distance = rect.maxY - visible.maxY
            } else if rect.minY < visible.minY {
                distance = rect.minY - visible.minY
            } else {
                return
            }
            var offset = scrollView.contentOffset
            offset.y += distance
            scrollView.setContentOffset(offset, animated: true)
        }
    }
}
