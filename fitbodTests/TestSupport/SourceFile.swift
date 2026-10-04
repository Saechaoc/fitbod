//
//  SourceFile.swift
//  fitbodTests
//
//  Reads an app source file by repository-relative path for the
//  copy-anchor suites. UI copy is part of the screen spec
//  (docs/design/screens.md); these suites pin the load-bearing strings and
//  wiring in source so a careless edit trips a test instead of silently
//  changing the product. Rendering itself is covered by the XCUITest
//  journey and its screenshots.
//

import Foundation

enum SourceFile {
    /// `relativePath` is relative to the repository root, e.g.
    /// "fitbod/Sessions/SessionLoggerView.swift".
    static func read(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TestSupport
            .deletingLastPathComponent()   // fitbodTests
            .deletingLastPathComponent()   // repository root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
