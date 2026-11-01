//
//  HostedAccessibility.swift
//  fitbodTests
//
//  Ticket T134, findings F315, F348 and F358. SwiftUI builds a hosted
//  view's accessibility tree only while the test host has accessibility
//  on, which libAccessibility reads from the simulator's
//  com.apple.Accessibility ApplicationAccessibilityEnabled and
//  AccessibilityEnabled: either one at 1 turns it on. A UI test session
//  sets both to 0 when it ends, so a hosted test read no tree unless
//  someone had set them by hand or an earlier test in the run had turned
//  them on.
//
//  A test that reads a hosted view's accessibility tree is marked
//  .hostedAccessibility. While it runs, the test host has accessibility
//  on, whatever the simulator's settings, and when it ends both are as
//  the test found them. It shows the view with HostedAccessibility.show
//  and reads the tree with elements(under:), polling with waitUntil.
//

import Foundation
import SwiftUI
import Testing
import UIKit

/// Shows SwiftUI views in the test host and reads their accessibility
/// trees, for tests marked `.hostedAccessibility`. Main actor, as it
/// works with UIKit windows.
@MainActor
enum HostedAccessibility {
    /// `view` in a window `width` by `height` on the test host's scene,
    /// with accessibility on, so SwiftUI builds the view's accessibility
    /// tree. Hide the window when the test ends.
    static func show(_ view: some View, width: CGFloat = 390, height: CGFloat = 844) throws -> UIWindow {
        try #require(tests > 0, "Mark the test or its suite .hostedAccessibility, so SwiftUI builds its tree")
        try #require(isOn, "The test host's accessibility is off, so SwiftUI builds no accessibility tree")
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        return window
    }

    /// `root` and the accessibility elements and views under it, depth
    /// first, each once: SwiftUI's elements are reached both from the
    /// hosting view and from a scroll view inside it.
    static func elements(under root: NSObject) -> [NSObject] {
        var seen: Set<ObjectIdentifier> = []
        func walk(_ element: NSObject) -> [NSObject] {
            guard seen.insert(ObjectIdentifier(element)).inserted else { return [] }
            let children = (element.accessibilityElements ?? []) + ((element as? UIView)?.subviews ?? [])
            return [element] + children.compactMap { $0 as? NSObject }.flatMap(walk)
        }
        return walk(root)
    }

    /// An accessibility property of `element` by name. SwiftUI's elements
    /// have the properties without declaring the protocols that name them.
    static func property(_ name: String, of element: NSObject) -> Any? {
        element.responds(to: NSSelectorFromString(name)) ? element.value(forKey: name) : nil
    }

    /// Runs the main run loop in 50 ms steps while SwiftUI renders, until
    /// `done` holds or ten seconds pass. A ceiling, not a wait: other
    /// suites' main-actor work, such as a Vision read, can run inside the
    /// run loop and hold it for a second or more.
    static func waitUntil(_ done: () -> Bool) {
        let deadline = Date.now.addingTimeInterval(10)
        while !done(), Date.now < deadline {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
    }

    // MARK: - The test host's accessibility

    /// Whether the test host has accessibility on.
    static var isOn: Bool {
        ["_AXSApplicationAccessibilityEnabled", "_AXSAccessibilityEnabled"].contains { name in
            (function(name, as: Getter.self)?() ?? 0) != 0
        }
    }

    /// The `.hostedAccessibility` tests running now, and whether the
    /// first of them turned accessibility on.
    private static var tests = 0
    private static var turnedOn = false

    /// Turns accessibility on for a hosted test if it is off. SwiftUI sees
    /// it at once. It sets both settings on the simulator, so the last
    /// hosted test to end sets them back.
    fileprivate static func beginTest() {
        if tests == 0, !isOn {
            setApplicationAccessibility(1)
            turnedOn = true
        }
        tests += 1
    }

    fileprivate static func endTest() {
        tests -= 1
        if tests == 0, turnedOn {
            setApplicationAccessibility(0)
            turnedOn = false
        }
    }

    private typealias Getter = @convention(c) () -> UInt8
    private typealias Setter = @convention(c) (Int32) -> Void

    private static func setApplicationAccessibility(_ value: Int32) {
        function("_AXSApplicationAccessibilitySetEnabled", as: Setter.self)?(value)
    }

    /// libAccessibility's C function `name`, private API that UIKit has
    /// loaded into the test host, so it stays in the test target.
    private static func function<Function>(_ name: String, as type: Function.Type) -> Function? {
        // RTLD_DEFAULT: every image loaded in the process.
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name).map { unsafeBitCast($0, to: type) }
    }
}

/// Turns the test host's accessibility on while each test runs, and
/// leaves it as the test found it. See `HostedAccessibility`.
struct HostedAccessibilityTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        await HostedAccessibility.beginTest()
        do {
            try await function()
        } catch {
            await HostedAccessibility.endTest()
            throw error
        }
        await HostedAccessibility.endTest()
    }
}

extension Trait where Self == HostedAccessibilityTrait {
    /// The test reads a hosted SwiftUI view's accessibility tree.
    static var hostedAccessibility: Self { Self() }
}

/// Main actor, as it reads the accessibility the hosted tests share.
@MainActor
@Suite("HostedAccessibility")
struct HostedAccessibilityTests {
    @Test("A hosted test has accessibility on, and leaves it as it found it for the tests after it")
    func hostedTestLeavesAccessibilityAsItFoundIt() async throws {
        let before = HostedAccessibility.isOn
        try await HostedAccessibilityTrait().provideScope(
            for: try #require(Test.current), testCase: Test.Case.current
        ) { @MainActor in
            #expect(HostedAccessibility.isOn, "A hosted test must run with accessibility on")
        }
        #expect(HostedAccessibility.isOn == before, "A hosted test must leave accessibility as it found it")
    }
}
