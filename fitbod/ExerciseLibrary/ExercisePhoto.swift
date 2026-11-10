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

@ModelActor
actor ExercisePhotoSanitizer {
    /// Each original stays stored until its replacement has encoded and saved successfully.
    func run(save: @Sendable (ModelContext) throws -> Void = { try $0.save() }) throws {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        for exercise in exercises {
            guard let original = exercise.imageData else { continue }
            do {
                let replacement = try ExercisePhoto.sanitized(original)
                guard replacement != original else { continue }
                exercise.imageData = replacement
                try save(modelContext)
            } catch {
                SessionSetActions.rollBack(modelContext)
                throw ExercisePhotoError.existing(exercise.name)
            }
        }
        // shortcut: canonical PNGs are decoded on each launch; add a migration stamp if startup cost becomes measurable.
    }
}
