import Foundation
import ImageIO
import SwiftData
import Testing
@testable import fitbod

@MainActor
struct ExercisePhotoPrivacyTests {
    @Test func legacyBackupPhotosDoNotCarryLocation() async throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let ctx = container.mainContext
        let exercise = LoggerFixtures.exercise("Photo lift", in: ctx)
        let original = try PhotoFixtures.image(orientation: 6, geotagged: true)
        #expect(PhotoFixtures.properties(original)[kCGImagePropertyGPSDictionary] != nil)
        exercise.imageData = original
        try ctx.save()
        let archive = try await BackupArchiver(modelContainer: container).archiveData()
        let image = try #require(try ZIPReader.read(data: archive).first { $0.path.hasPrefix("images/") })
        #expect(PhotoFixtures.properties(image.data)[kCGImagePropertyGPSDictionary] == nil)
        #expect(exercise.imageData == original, "Export must not replace the stored original")
    }
    @Test(arguments: 1...8)
    func removesMetadataAndPreservesEveryOrientation(_ orientation: Int) throws {
        let source = try PhotoFixtures.image(orientation: orientation, geotagged: true)
        let clean = try ExercisePhoto.sanitized(source)
        let properties = PhotoFixtures.properties(clean)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect((properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake] == nil)
        #expect((properties[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect((properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any])?[kCGImagePropertyIPTCCity] == nil)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == (orientation >= 5 ? 20 : 40))
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == (orientation >= 5 ? 40 : 20))
        let permutations = [[0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
                            [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]]
        let originalCorners = try cornerColors(source)
        let actual = try cornerColors(clean)
        for (index, expectedIndex) in permutations[orientation - 1].enumerated() {
            for channel in 0..<3 {
                #expect(abs(actual[index][channel] - originalCorners[expectedIndex][channel]) <= 2)
            }
        }
        #expect(try ExercisePhoto.sanitized(clean) == clean)
    }

    @Test func failedReplacementPreservesTheOriginalThenRetries() throws {
        enum Failure: Error { case disk }
        let ctx = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let draft = CustomExerciseDraft()
        draft.name = "Photo lift"
        draft.imageData = try PhotoFixtures.image()
        let exercise = try draft.persist(in: ctx, allMuscles: [])
        let original = exercise.imageData
        let edit = CustomExerciseDraft()
        edit.editingExisting = exercise
        edit.name = "Edited lift"
        edit.imageData = try PhotoFixtures.image(orientation: 6, geotagged: true)
        #expect(throws: Failure.self) {
            try edit.persist(in: ctx, allMuscles: [], save: { _ in throw Failure.disk })
        }
        #expect(!ctx.hasChanges)
        #expect(exercise.name == "Photo lift" && exercise.imageData == original)
        let old = try #require(try ModelContext(ctx.container).fetch(FetchDescriptor<Exercise>()).first)
        #expect(old.imageData == original)
        try edit.persist(in: ctx, allMuscles: [])
        let saved = try #require(try ModelContext(ctx.container).fetch(FetchDescriptor<Exercise>()).first)
        #expect(saved.name == "Edited lift")
        #expect(PhotoFixtures.properties(try #require(saved.imageData))[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func existingPhotoUpgradePreservesFailureAndSurvivesReopen() async throws {
        enum Failure: Error { case disk }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("photo-privacy-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        let container = try FitbodModelContainer.make(storeURL: url)
        let ctx = container.mainContext
        let exercise = LoggerFixtures.exercise("Legacy photo", in: ctx)
        let original = try PhotoFixtures.image(orientation: 8, geotagged: true)
        exercise.imageData = original
        try ctx.save()
        let upgrader = ExercisePhotoSanitizer(modelContainer: container)
        await #expect(throws: ExercisePhotoError.self) {
            try await upgrader.run(save: { _ in throw Failure.disk })
        }
        let before = try #require(try ModelContext(container).fetch(FetchDescriptor<Exercise>()).first)
        #expect(before.imageData == original)
        try await upgrader.run()
        let reopened = try FitbodModelContainer.make(storeURL: url)
        let saved = try #require(try ModelContext(reopened).fetch(FetchDescriptor<Exercise>()).first)
        let image = try #require(saved.imageData)
        #expect(PhotoFixtures.properties(image)[kCGImagePropertyGPSDictionary] == nil)
        #expect(PhotoFixtures.properties(image)[kCGImagePropertyPixelWidth] as? Int == 20)
        try await upgrader.run(save: { _ in throw Failure.disk }) // Canonical bytes need no second save.
    }

    @Test func badBackupPhotoIsRejectedBeforeDeletingWorkouts() async throws {
        let source = try FitbodModelContainer.make(inMemory: true)
        let photo = LoggerFixtures.exercise("Backup photo", in: source.mainContext)
        photo.imageData = try PhotoFixtures.image()
        try source.mainContext.save()
        let archive = try await BackupArchiver(modelContainer: source).archiveData()
        let entries = try ZIPReader.read(data: archive).map {
            ZIPWriter.Entry(path: $0.path, data: $0.path.hasPrefix("images/") ? Data([1, 2, 3]) : $0.data, lastModified: .now)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad-photo-\(UUID()).fitbodbackup")
        try ZIPWriter.write(entries: entries).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let target = try FitbodModelContainer.make(inMemory: true)
        let lift = LoggerFixtures.exercise("Keep this workout", in: target.mainContext)
        try LoggerFixtures.session(exercise: lift, startedAt: .now, completedAt: .now,
                                   sets: [(100, 8, true)], in: target.mainContext)
        let restorer = BackupRestorer()
        let manifest = try await restorer.preflight(url: url, context: target.mainContext)
        await #expect(throws: ExercisePhotoError.self) {
            try await restorer.performRestore(url: url, manifest: manifest, currentContainer: target)
        }
        let reader = ModelContext(target)
        #expect(try reader.fetchCount(FetchDescriptor<Session>()) == 1)
        #expect(try reader.fetch(FetchDescriptor<SetEntry>()).first?.weight == 100)
        #expect(try reader.fetch(FetchDescriptor<Exercise>()).first?.name == "Keep this workout")
    }

    @Test func rejectsUnreadableAndOversizedImagesBeforeDecoding() throws {
        #expect(throws: ExercisePhotoError.self) { try ExercisePhoto.sanitized(Data([1, 2, 3])) }
        var image = try PhotoFixtures.image()
        image.replaceSubrange(16..<20, with: [0, 0, 0x4E, 0x20]) // PNG width 20,000.
        var checksum = ZIPWriter.crc32(image.subdata(in: 12..<29)).bigEndian
        image.replaceSubrange(29..<33, with: withUnsafeBytes(of: &checksum) { Array($0) })
        let error = #expect(throws: ExercisePhotoError.self) { try ExercisePhoto.sanitized(image) }
        guard case .tooLarge? = error else { Issue.record("The size guard must reject before pixel decoding"); return }
    }

    private func cornerColors(_ data: Data) throws -> [[Int]] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return try [(2, 2), (image.width - 3, 2), (2, image.height - 3), (image.width - 3, image.height - 3)].map { x, y in
            let pixel = try #require(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
            var rgba = [UInt8](repeating: 0, count: 4)
            try rgba.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(data: buffer.baseAddress, width: 1, height: 1,
                    bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return rgba.prefix(3).map(Int.init)
        }
    }

}
