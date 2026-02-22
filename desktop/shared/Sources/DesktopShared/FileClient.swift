import ConvexCore
import Foundation
#if canImport(AppKit)
import AppKit
#endif

public final class FileClient: @unchecked Sendable {
    private let client: ConvexClient

    public init(client: ConvexClient) {
        self.client = client
    }

    public func upload(data: Data, contentType: String) async throws -> String {
        let uploadURL: String = try await client.mutation("file:upload")
        return try await postFile(data: data, contentType: contentType, uploadURL: uploadURL)
    }

    public func uploadImage(url: URL, maxSize: Int = 1_920, quality: Double = 0.8) async throws -> String {
        let compressed = try compressImage(url: url, maxSize: maxSize, quality: quality)
        return try await upload(data: compressed, contentType: "image/jpeg")
    }

    public func uploadFile(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let contentType = guessContentType(for: url)
        return try await upload(data: data, contentType: contentType)
    }

    public func uploadFiles(urls: [URL]) async throws -> [String] {
        var ids = [String]()
        for url in urls {
            let storageID = try await uploadFile(url: url)
            ids.append(storageID)
        }
        return ids
    }

    private func compressImage(url: URL, maxSize: Int, quality: Double) throws -> Data {
        #if canImport(AppKit)
        let imageData = try Data(contentsOf: url)
        guard let image = NSImage(data: imageData) else {
            throw ConvexError.decodingError("Could not load image")
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ConvexError.decodingError("Could not get CGImage")
        }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let maxDimension = CGFloat(maxSize)

        var targetWidth = originalWidth
        var targetHeight = originalHeight
        if originalWidth > maxDimension || originalHeight > maxDimension {
            let ratio = min(maxDimension / originalWidth, maxDimension / originalHeight)
            targetWidth = originalWidth * ratio
            targetHeight = originalHeight * ratio
        }

        let resized = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            from: NSRect(x: 0, y: 0, width: originalWidth, height: originalHeight),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            throw ConvexError.decodingError("Could not compress image")
        }

        return jpeg
        #else
        return try Data(contentsOf: url)
        #endif
    }
}
