import Foundation
#if !SKIP
#if canImport(UIKit)
import UIKit
#endif
#else
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
#endif
public final class FileService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = FileService()

    private init() {
        _ = ()
    }

    public func uploadFile(data: Data, contentType: String) async throws -> String {
        let uploadURL = try await getUploadURL()
        return try await postFile(data: data, contentType: contentType, uploadURL: uploadURL)
    }

    public func uploadImage(url: URL, maxSize: Int = 1_920, quality: Double = 0.8) async throws -> String {
        let imageData = try await compressImage(url: url, maxSize: maxSize, quality: quality)
        return try await uploadFile(data: imageData, contentType: "image/jpeg")
    }

    public func uploadFiles(urls: [URL]) async throws -> [String] {
        var ids = [String]()
        for url in urls {
            let data = try Data(contentsOf: url)
            let contentType = guessContentType(for: url)
            let storageID = try await uploadFile(data: data, contentType: contentType)
            ids.append(storageID)
        }
        return ids
    }

    private func getUploadURL() async throws -> String {
        #if !SKIP
        return try await ConvexService.shared.mutate(
            "file:upload",
            args: [:],
            returning: String.self
        )
        #else
        return try await ConvexService.shared.mutateReturningString(
            name: "file:upload",
            args: [:]
        )
        #endif
    }

    private func compressImage(url: URL, maxSize: Int, quality: Double) throws -> Data {
        #if !SKIP
        #if canImport(UIKit)
        let imageData = try Data(contentsOf: url)
        guard let image = UIImage(data: imageData) else {
            throw ConvexError.decodingError("Could not load image")
        }

        let maxDimension = CGFloat(maxSize)
        var targetSize = image.size
        if targetSize.width > maxDimension || targetSize.height > maxDimension {
            let widthRatio = maxDimension / targetSize.width
            let heightRatio = maxDimension / targetSize.height
            let ratio = min(widthRatio, heightRatio)
            targetSize = CGSize(
                width: targetSize.width * ratio,
                height: targetSize.height * ratio
            )
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let compressed = resized.jpegData(compressionQuality: quality) else {
            throw ConvexError.decodingError("Could not compress image")
        }

        return compressed
        #else
        return try Data(contentsOf: url)
        #endif
        #else
        let imageData = try Data(contentsOf: url)
        let bytes = imageData.platformValue
        guard let original = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) else {
            throw ConvexError.decodingError("Could not decode image")
        }

        var targetWidth = original.width
        var targetHeight = original.height
        let maxDimension = maxSize
        if targetWidth > maxDimension || targetHeight > maxDimension {
            let widthRatio = Double(maxDimension) / Double(targetWidth)
            let heightRatio = Double(maxDimension) / Double(targetHeight)
            let ratio = min(widthRatio, heightRatio)
            targetWidth = Int(Double(targetWidth) * ratio)
            targetHeight = Int(Double(targetHeight) * ratio)
        }
        let scaled = Bitmap.createScaledBitmap(original, targetWidth, targetHeight, true)
        let outputStream = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, Int(quality * 100.0), outputStream)
        return Data(platformValue: outputStream.toByteArray())
        #endif
    }
}
