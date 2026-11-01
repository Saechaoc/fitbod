//
//  BackupArchiverTests.swift
//  fitbodTests
//
//  Wave-5 plan 06-10 Task 7 — proves the Archiver produces a real
//  PKWARE ZIP whose parsed entries include the right shapes, with a
//  valid SHA-256 checksum + canonical schemaVersion. Pairs with
//  BackupVersionSkewTests (security gates) and BackupRoundTripTests
//  (the D-33 acceptance canary in Task 8).
//
//  [CITED: 06-10 PLAN Task 7 + CONTEXT D-30 + EXP-03 +
//   06-VALIDATION §EXP-03 verification row]
//

import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BackupArchiver (EXP-03 + CONTEXT D-30)", .serialized)
struct BackupArchiverTests {

    @Test("manifestShapeAndChecksum — manifest fields + SHA-256 match")
    func manifestShapeAndChecksum() async throws {
        let container = try InMemoryContainer.makeCurrent()
        _ = try PRFixtures.seedKnownPRHistory(ctx: container.mainContext)

        let archiver = BackupArchiver(modelContainer: container)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archiver-shape-\(UUID().uuidString).fitbodbackup")
        let file = try await archiver.archive(outputURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let data = try Data(contentsOf: file.url)
        let entries = try ZIPReader.read(data: data)
        let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0.data) })
        #expect(byPath["manifest.json"] != nil)
        #expect(byPath["store.json"] != nil)

        let manifest = try BackupManifest.decode(byPath["manifest.json"]!)
        #expect(manifest.formatVersion == 2)
        #expect(manifest.schemaVersion == ExportDocument.canonicalSchemaVersion)

        // checksum recompute on the actual store.json bytes from the
        // archive — must match the manifest's recorded hex digest.
        let computed = SHA256.hash(data: byPath["store.json"]!)
            .map { String(format: "%02x", $0) }
            .joined()
        #expect(computed == manifest.checksum)
    }

    @Test("imagesEntryPerExerciseImage — one images/{uuid}.jpg per Exercise.imageData")
    func imagesEntryPerExerciseImage() async throws {
        let container = try InMemoryContainer.makeCurrent()
        let ctx = container.mainContext

        // Two custom Exercise rows with hand-injected JPEG bytes.
        let bench = Exercise(name: "Bench", canonicalName: "bench", equipmentRaw: "barbell", mechanicRaw: "compound")
        let squat = Exercise(name: "Squat", canonicalName: "squat", equipmentRaw: "barbell", mechanicRaw: "compound")
        ctx.insert(bench)
        ctx.insert(squat)
        bench.imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        squat.imageData = Data([0xFF, 0xD8, 0xFF, 0xE1])
        try ctx.save()

        let archiver = BackupArchiver(modelContainer: container)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archiver-images-\(UUID().uuidString).fitbodbackup")
        _ = try await archiver.archive(outputURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let data = try Data(contentsOf: tmpURL)
        let entries = try ZIPReader.read(data: data)

        let imageEntries = entries.filter { $0.path.hasPrefix("images/") }
        #expect(imageEntries.count == 2)
        let byPath = Dictionary(uniqueKeysWithValues: imageEntries.map { ($0.path, $0.data) })
        #expect(byPath["images/\(bench.id.uuidString).jpg"] == bench.imageData)
        #expect(byPath["images/\(squat.id.uuidString).jpg"] == squat.imageData)

        // Manifest carries imageCount=2.
        let manifest = try BackupManifest.decode(entries.first { $0.path == "manifest.json" }!.data)
        #expect(manifest.imageCount == 2)
    }

    @Test("archiveIsValidZIP — EOCD signature + entries parseable by ZIPReader")
    func archiveIsValidZIP() async throws {
        let container = try InMemoryContainer.makeCurrent()
        let archiver = BackupArchiver(modelContainer: container)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archiver-valid-\(UUID().uuidString).fitbodbackup")
        _ = try await archiver.archive(outputURL: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let data = try Data(contentsOf: tmpURL)
        // EOCD signature is little-endian 0x06054b50 (PK\x05\x06).
        // Scan the last 1KB for the marker.
        let tail = data.suffix(1024)
        let marker: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        var found = false
        if tail.count >= 4 {
            for i in 0...(tail.count - 4) {
                let idx = tail.startIndex + i
                if data[idx] == marker[0] && data[idx + 1] == marker[1] &&
                    data[idx + 2] == marker[2] && data[idx + 3] == marker[3] {
                    found = true
                    break
                }
            }
        }
        #expect(found, "EOCD signature must be present at archive end")

        // Parse via ZIPReader — must yield at least manifest.json +
        // store.json (no images seeded in this test).
        let entries = try ZIPReader.read(data: data)
        #expect(entries.count >= 2)
    }
}
