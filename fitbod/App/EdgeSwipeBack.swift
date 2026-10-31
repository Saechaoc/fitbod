// EdgeSwipeBack.swift
// fitbod
//
// Swipe back on every pushed screen (tradeoffs.md "Swipe-back everywhere").
// BRU screens hide the system navigation bar to draw BRUHeaderBar, and UIKit
// does not start its edge swipe under a hidden bar. This lets the swipe start
// whenever a stack holds a screen to go back to, in every navigation stack
// in the app, sheets included, with no code on each screen.
//
// A pushed screen that asks before it leaves turns the swipe off while it
// has unsaved changes with `.navigationBarBackButtonHidden(hasUnsavedChanges)`,
// the standard switch for UIKit's swipe back.

import ObjectiveC
import UIKit

extension UINavigationController {
    // UINavigationController inherits viewDidLoad from UIViewController, so
    // this override replaces no UIKit code. It runs once for each stack.
    override open func viewDidLoad() {
        super.viewDidLoad()
        EdgeSwipeBack.install(on: self)
    }
}

/// The delegate of a stack's edge swipe. UIKit's own delegate turns the
/// swipe away under a hidden bar before any public delegate method runs, so
/// this one takes its place. The swipe starts only when there is a screen
/// to go back to, no push or pop is under way and the screen has not hidden
/// its back button, so a swipe on a root screen does nothing. UIKit's
/// delegate still answers the public questions it answers for a shown bar.
@MainActor
private final class EdgeSwipeBack: NSObject, UIGestureRecognizerDelegate {
    private static var key: UInt8 = 0

    private weak var navigationController: UINavigationController?
    private weak var systemDelegate: (any UIGestureRecognizerDelegate)?

    private init(navigationController: UINavigationController, systemDelegate: (any UIGestureRecognizerDelegate)?) {
        self.navigationController = navigationController
        self.systemDelegate = systemDelegate
    }

    /// Takes over the edge swipe's delegate. The stack keeps the new
    /// delegate alive, because a gesture's delegate is weak.
    static func install(on navigationController: UINavigationController) {
        guard let swipe = navigationController.interactivePopGestureRecognizer,
              !(swipe.delegate is EdgeSwipeBack) else { return }
        let delegate = EdgeSwipeBack(navigationController: navigationController, systemDelegate: swipe.delegate)
        objc_setAssociatedObject(navigationController, &key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        swipe.delegate = delegate
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController,
              navigationController.viewControllers.count > 1,
              navigationController.transitionCoordinator == nil,
              navigationController.topViewController?.navigationItem.hidesBackButton != true else { return false }
        return systemDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        systemDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        systemDelegate?.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: other) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
        systemDelegate?.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: other) ?? false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        // Scroll views wait for the swipe to fail, as under a shown bar, so
        // a swipe that starts on a row that scrolls sideways still goes back.
        other is UIPanGestureRecognizer && other.view is UIScrollView
    }
}
