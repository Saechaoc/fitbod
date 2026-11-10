import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoFixtures {
    static func image(orientation: Int = 1, geotagged: Bool = false, variant: Bool = false) throws -> Data {
        let colors: [[UInt8]] = variant
            ? [[0, 0, 255, 255], [255, 0, 0, 255], [255, 255, 0, 255], [0, 255, 0, 255]]
            : [[255, 0, 0, 255], [0, 0, 255, 255], [0, 255, 0, 255], [255, 255, 0, 255]]
        var pixels: [UInt8] = []
        for y in 0..<20 {
            for x in 0..<40 { pixels += colors[(y < 10 ? 0 : 2) + (x < 20 ? 0 : 1)] }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: 40, height: 20, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: 160, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let bytes = NSMutableData()
        let type = geotagged ? UTType.jpeg.identifier : UTType.png.identifier
        let destination = CGImageDestinationCreateWithData(bytes, type as CFString, 1, nil)!
        let properties: [CFString: Any] = geotagged ? [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 1.0,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 37.77, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 122.42, kCGImagePropertyGPSLongitudeRef: "W"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Private camera"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:11:10 08:00:00"],
            kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCCity: "Private city"],
        ] : [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return bytes as Data
    }

    static func properties(_ data: Data) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }
}
