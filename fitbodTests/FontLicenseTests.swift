// FontLicenseTests.swift
// fitbodTests
//
// The SIL Open Font License requires its text to ship with each bundled
// font (UI-REVIEW Wave G item 71).

import Testing
import Foundation

@Suite("Font licenses")
struct FontLicenseTests {
    @Test("Each font in the app ships with its family's OFL license (Wave G item 71)")
    func eachFontShipsWithItsLicense() {
        let fonts = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        #expect(!fonts.isEmpty, "The app bundles no fonts")
        for font in fonts {
            // BebasNeue-Regular.ttf ships with BebasNeue-OFL.txt.
            let family = font.deletingPathExtension().lastPathComponent.prefix { $0 != "-" }
            #expect(
                Bundle.main.url(forResource: "\(family)-OFL", withExtension: "txt") != nil,
                "\(font.lastPathComponent) ships without \(family)-OFL.txt"
            )
        }
    }
}
