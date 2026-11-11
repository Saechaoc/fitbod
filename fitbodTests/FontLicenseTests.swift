// FontLicenseTests.swift
// fitbodTests
//
// The SIL Open Font License requires its text to ship with the bundled
// Space Grotesk and JetBrains Mono fonts (UI-REVIEW Wave G item 71).

import Testing
import Foundation

@Suite("Font licenses")
struct FontLicenseTests {
    @Test("OFL license attribution files present (Wave G item 71)")
    func oflLicenseAttributionPresent() throws {
        let testFilePath = String(describing: #filePath as StaticString)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let licensesDir = projectRoot
            .appendingPathComponent("fitbod/Resources/Fonts/LICENSES")

        let spaceGrotesk = licensesDir.appendingPathComponent("SpaceGrotesk-OFL.txt")
        let jetBrainsMono = licensesDir.appendingPathComponent("JetBrainsMono-OFL.txt")

        #expect(
            FileManager.default.fileExists(atPath: spaceGrotesk.path),
            "SpaceGrotesk-OFL.txt missing from fitbod/Resources/Fonts/LICENSES/"
        )
        #expect(
            FileManager.default.fileExists(atPath: jetBrainsMono.path),
            "JetBrainsMono-OFL.txt missing from fitbod/Resources/Fonts/LICENSES/"
        )
    }
}
