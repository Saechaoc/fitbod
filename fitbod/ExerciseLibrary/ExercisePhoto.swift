import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

enum ExercisePhotoError: LocalizedError {
    case unreadable, tooLarge, encodingFailed
    case existing(String)

    var errorDescription: String? {
        switch self {
        case .unreadable, .encodingFailed:
            "This photo couldn't be prepared. Choose another photo or remove it. Your original is unchanged."
        case .tooLarge:
            "This photo is too large to prepare. Choose a smaller copy. Your original is unchanged."
        case .existing(let name):
            "The photo for “\(name)” couldn't be prepared. Its original is still stored. Try again or replace that photo."
        }
    }
}

enum ExercisePhoto {
    /// Decode pixels and encode a new PNG, carrying no source metadata or embedded thumbnail.
    static func sanitized(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw ExercisePhotoError.unreadable }
        // Bound decoding without shrinking the photo's pixels (48MP phone photos fit).
        guard width <= 16_384, height <= 16_384, width <= 64_000_000 / height else {
            throw ExercisePhotoError.tooLarge
        }
        // Exercise photos display one static frame; apply all EXIF rotations/mirrors to its pixels.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ExercisePhotoError.unreadable
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw ExercisePhotoError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ExercisePhotoError.encodingFailed }
        return output as Data
    }
}

/// Re-encodes stored photos that still carry their source metadata. The actor
/// reads and re-encodes off the main actor; the main context writes, since a
/// second writer leaves the main context an older copy that its next save of
/// that exercise writes back, location included (RM-004).
@ModelActor
actor ExercisePhotoSanitizer {
    /// The exercises with a stored photo.
    func exercisesWithPhotos() throws -> [PersistentIdentifier] {
        try modelContext.fetch(FetchDescriptor<Exercise>()).filter { $0.imageData != nil }.map(\.persistentModelID)
    }

    /// The exercise's stored photo and its sanitized bytes, or nil when they
    /// are the same or the exercise is gone.
    func replacement(for id: PersistentIdentifier) throws -> (original: Data, sanitized: Data)? {
        guard let exercise = try modelContext.fetch(FetchDescriptor<Exercise>(
                  predicate: #Predicate { $0.persistentModelID == id }
              )).first,
              let original = exercise.imageData else { return nil }
        do {
            let sanitized = try ExercisePhoto.sanitized(original)
            return sanitized == original ? nil : (original, sanitized)
        } catch {
            throw ExercisePhotoError.existing(exercise.name)
        }
    }

    /// Each original stays stored until its replacement has encoded and saved
    /// successfully. A photo changed since it was read keeps the change.
    @MainActor
    static func run(in context: ModelContext, save: (ModelContext) throws -> Void = { try $0.save() }) async throws {
        let sanitizer = ExercisePhotoSanitizer(modelContainer: context.container)
        for id in try await sanitizer.exercisesWithPhotos() {
            guard let photo = try await sanitizer.replacement(for: id),
                  let exercise = try context.fetch(FetchDescriptor<Exercise>(
                      predicate: #Predicate { $0.persistentModelID == id }
                  )).first,
                  exercise.imageData == photo.original else { continue }
            exercise.imageData = photo.sanitized
            do {
                try save(context)
            } catch {
                SessionSetActions.rollBack(context)
                throw ExercisePhotoError.existing(exercise.name)
            }
        }
        // shortcut: canonical PNGs are decoded on each launch; add a migration stamp if startup cost becomes measurable.
    }
}
