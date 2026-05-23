//
//  BackupManifest.swift
//  fitbod
//
//  Wave-5 plan 06-10 — the manifest record that lives at the root of
//  every `.fitbodbackup` ZIP archive. Carries schema-version,
//  format-version, creation timestamp, and a SHA-256 checksum of the
//  store.json payload bytes.
//
//  ## Schema-skew gate (RESEARCH §Security Domain V10)
//
//  Restore-side strict string-equality compares `manifest.schemaVersion`
//  against `ExportDocument.canonicalSchemaVersion` — a mismatch is the
//  blocking gate that prevents "v6 app reads v7 backup" or similar
//  schema-skew restore disasters. Single source of truth for the
//  schema version lives on `ExportDocument`; archiver reads it and
//  embeds it here, restorer reads it back and compares.
//
//  ## Checksum (RESEARCH §Security Domain Known Threat Patterns)
//
//  `checksum` is the SHA-256 of the store.json bytes, hex-encoded
//  lowercase. Restore-side recomputes the hash and rejects on mismatch
//  with `.checksumMismatch`. CryptoKit's `SHA256.hash(data:)` produces
//  a deterministic 32-byte digest; we hex-encode for human readability
//  in the manifest.
//
//  ## Encoding contract
//
//  Encoded via JSONEncoder with `.iso8601` dates + `.sortedKeys` +
//  `.withoutEscapingSlashes` so the manifest is diff-friendly when
//  inspected via macOS Finder unzip or any other ZIP-aware tool.
//
//  [CITED: CONTEXT D-30 + D-32 + RESEARCH §Pattern 5 REVISED +
//   Open Question 1 RESOLVED]
//

import Foundation

public struct BackupManifest: Codable, Equatable, Sendable {
    /// Bumped only if the manifest envelope itself changes shape.
    /// Independent of `schemaVersion` (which tracks the SwiftData
    /// model schema). v1 ships formatVersion = 1.
    public let formatVersion: Int

    /// Mirror of `ExportDocument.canonicalSchemaVersion` at archive
    /// time. Restore-side compares against the current runtime's
    /// canonicalSchemaVersion via strict string equality.
    public let schemaVersion: String

    /// Wall-clock at archive time.
    public let createdAt: Date

    /// SHA-256 of the store.json bytes, hex-encoded lowercase.
    /// 64 hex characters.
    public let checksum: String

    /// Diagnostic count of `images/<uuid>.jpg` entries packed into
    /// the archive. Not load-bearing for validation; useful for
    /// summary UI ("Includes 14 custom images").
    public let imageCount: Int

    public init(
        formatVersion: Int,
        schemaVersion: String,
        createdAt: Date,
        checksum: String,
        imageCount: Int
    ) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.checksum = checksum
        self.imageCount = imageCount
    }

    // MARK: - Codec helpers

    /// Encode to JSON with ISO-8601 dates + sortedKeys.
    /// Diff-friendly output when a user inspects the manifest via
    /// macOS Finder unzip.
    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(self)
    }

    /// Decode from JSON bytes. Throws on schema mismatch or malformed
    /// JSON; restore-side maps the throw to `.zipParseFailed`.
    public static func decode(_ data: Data) throws -> BackupManifest {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(BackupManifest.self, from: data)
    }
}
