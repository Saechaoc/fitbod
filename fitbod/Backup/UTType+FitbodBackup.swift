//
//  UTType+FitbodBackup.swift
//  fitbod
//
//  Wave-5 plan 06-10 — runtime UTType declaration for the
//  `.fitbodbackup` document. Mirrored by Info.plist's
//  UTExportedTypeDeclarations + CFBundleDocumentTypes (the build-time
//  side of the contract — both halves are required for Files app
//  integration per RESEARCH Pitfall 9).
//
//  ## conformingTo: .zip (CONTEXT D-30)
//
//  The archive is a real PKWARE ZIP file (so Finder, macOS `unzip`,
//  and other ZIP-aware tools can open it). Declaring conformance to
//  `.zip` lets `.fileImporter(allowedContentTypes: [.fitbodBackup])`
//  match either `.fitbodbackup`-suffixed files OR generic ZIP files
//  the user might have renamed.
//
//  ## Bundle identifier
//
//  `bodybuilding.fitbod.fitbodbackup` follows the existing
//  `bodybuilding.fitbod` PRODUCT_BUNDLE_IDENTIFIER prefix; CONTEXT
//  D-30 specifies the template form `com.<bundle-id>.fitbodbackup`
//  but our app's bundle ID is `bodybuilding.fitbod` (not
//  `com.fitbod.app`), so we substitute the actual prefix here.
//
//  [CITED: CONTEXT D-30 + RESEARCH Pitfall 9 + Pattern 5 REVISED]
//

import UniformTypeIdentifiers

public extension UTType {
    /// The `.fitbodbackup` archive type. Identifier conforms to
    /// `.zip` (and transitively to `.data`); declared as `exported`
    /// (this app owns the type) so Files / AirDrop / iCloud Drive
    /// know to route `.fitbodbackup` files back to us.
    static let fitbodBackup = UTType(
        exportedAs: "bodybuilding.fitbod.fitbodbackup",
        conformingTo: .zip
    )
}
