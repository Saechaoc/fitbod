//
//  AdaptiveColorSourceTests.swift
//  fitbodTests
//
//  T16, review item 9. Program, New Block and the block name field draw
//  only with the adaptive BRU tokens from Color+BRU.swift. A fixed
//  `Color(red:green:blue:)` keeps its light value in dark mode, which left
//  Program light and put white text on cream and black text on black.
//

import Foundation
import Testing

@Suite("Adaptive colors in Program and New Block")
struct AdaptiveColorSourceTests {

    private static func sourceLines(of filename: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Periodization")
            .appendingPathComponent(filename)
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    @Test(
        "Program, New Block and the block name field use no fixed RGB colors",
        arguments: ["ProgramView.swift", "BlockBuilderView.swift", "BlockNameField.swift"]
    )
    func noFixedRGBColors(in filename: String) throws {
        let literals = try Self.sourceLines(of: filename).enumerated()
            .filter { $0.element.contains("Color(red:") }
            .map { "\(filename):\($0.offset + 1): \($0.element.trimmingCharacters(in: .whitespaces))" }

        #expect(
            literals.isEmpty,
            "Use the adaptive BRU tokens from Color+BRU.swift, not fixed colors:\n\(literals.joined(separator: "\n"))"
        )
    }
}
