//
//  EdgeSwipeBackGuardTests.swift
//  fitbodTests
//
//  Ticket T101 (finding F184): EdgeSwipeBack.swift overrides viewDidLoad
//  in an extension of UINavigationController. A category's method replaces
//  the class's own under the same selector, so the override replaces no
//  UIKit code only while UINavigationController inherits viewDidLoad from
//  UIViewController.
//

import ObjectiveC
import Testing
import UIKit
@testable import fitbod

@Suite("EdgeSwipeBackGuard")
struct EdgeSwipeBackGuardTests {

    /// class_copyMethodList lists a category's method and the class's own
    /// under the same selector, so a second viewDidLoad is UIKit's own.
    @Test("UINavigationController's only viewDidLoad is EdgeSwipeBack's override")
    func navigationControllerHasNoViewDidLoadOfItsOwn() {
        let images = viewDidLoadImages(of: UINavigationController.self)
        #expect(
            images.count == 1,
            "UINavigationController has \(images.count) viewDidLoad methods, from \(images): UIKit added its own, which EdgeSwipeBack's override in an extension replaces"
        )
        #expect(
            images.allSatisfy { $0.hasPrefix("fitbod") },
            "UINavigationController's viewDidLoad comes from \(images), not from EdgeSwipeBack's extension in the app"
        )
    }

    /// The file name of the image that holds each viewDidLoad in `cls`'s
    /// own method list, categories included.
    private func viewDidLoadImages(of cls: AnyClass) -> [String] {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &count) else { return [] }
        defer { free(methods) }
        return (0..<Int(count)).map { methods[$0] }
            .filter { method_getName($0) == #selector(UIViewController.viewDidLoad) }
            .map { method in
                var info = Dl_info()
                guard dladdr(UnsafeRawPointer(method_getImplementation(method)), &info) != 0,
                      let file = info.dli_fname else { return "an unknown image" }
                return (String(cString: file) as NSString).lastPathComponent
            }
    }
}
