//
//  DebugLaunchResetTests.swift
//  fitbodTests
//
//  `-fitbod-reset-store` must leave nothing behind that would make a UI
//  test start from old data: no store files and no seed or rest-timer
//  stamps. Runs against a temporary directory and a throwaway defaults
//  suite, never the host app's real store.
//

import Foundation
import Testing
@testable import fitbod

@Suite("Debug launch reset")
struct DebugLaunchResetTests {

    @Test("Deletes the store, its siblings and every value in the defaults domain")
    func deletesStoreAndDefaults() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let store = dir.appendingPathComponent("default.store")
        for file in FitbodModelContainer.storeFiles(for: store) {
            if file.hasDirectoryPath {
                try fm.createDirectory(at: file, withIntermediateDirectories: true)
            } else {
                try Data("x".utf8).write(to: file)
            }
        }

        let domain = "DebugLaunchResetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defaults.set(3, forKey: ExerciseLibraryImporter.seedVersionKey)
        defaults.set(true, forKey: FitbodModelContainer.plateInventorySeededKey)
        defaults.set(Date().timeIntervalSince1970, forKey: "restTimer.deadline.test")

        DebugLaunchReset.reset(storeURL: store, defaults: defaults, domain: domain)

        for file in FitbodModelContainer.storeFiles(for: store) {
            #expect(!fm.fileExists(atPath: file.path), "\(file.lastPathComponent) should be deleted")
        }
        #expect(defaults.object(forKey: ExerciseLibraryImporter.seedVersionKey) == nil)
        #expect(defaults.object(forKey: FitbodModelContainer.plateInventorySeededKey) == nil)
        #expect(defaults.object(forKey: "restTimer.deadline.test") == nil)
    }

    @Test("A first launch with no store files does not fail")
    func missingFilesAreFine() throws {
        let store = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("default.store")
        let domain = "DebugLaunchResetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))

        DebugLaunchReset.reset(storeURL: store, defaults: defaults, domain: domain)

        #expect(!FileManager.default.fileExists(atPath: store.path))
    }
}
