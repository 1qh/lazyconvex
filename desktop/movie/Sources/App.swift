import ConvexCore
import DefaultBackend
import DesktopShared
import Foundation
import SwiftCrossUI

internal let client = ConvexClient(deploymentURL: convexBaseURL)

internal final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cacheDir: URL
    private let session = URLSession.shared
    private var inFlight = [String: Task<URL?, Never>]()
    private let lock = NSLock()

    private init() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("movie-posters")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        cacheDir = tmp
    }

    func localURL(for remotePath: String, size: String = "w342") -> URL? {
        let filename = remotePath.replacingOccurrences(of: "/", with: "_")
        let local = cacheDir.appendingPathComponent("\(size)_\(filename)")
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        return nil
    }

    nonisolated private func getInFlight(_ key: String) -> Task<URL?, Never>? {
        lock.lock()
        let task = inFlight[key]
        lock.unlock()
        return task
    }

    nonisolated private func setInFlight(_ key: String, task: Task<URL?, Never>) {
        lock.lock()
        inFlight[key] = task
        lock.unlock()
    }

    nonisolated private func removeInFlight(_ key: String) {
        lock.lock()
        inFlight.removeValue(forKey: key)
        lock.unlock()
    }

    func download(_ remotePath: String, size: String = "w342") async -> URL? {
        let filename = remotePath.replacingOccurrences(of: "/", with: "_")
        let local = cacheDir.appendingPathComponent("\(size)_\(filename)")
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }

        let key = "\(size)_\(remotePath)"
        if let existing = getInFlight(key) {
            return await existing.value
        }
        let task = Task<URL?, Never> {
            guard let url = URL(string: "https://image.tmdb.org/t/p/\(size)\(remotePath)") else {
                return nil
            }

            do {
                let (data, _) = try await session.data(from: url)
                try data.write(to: local)
                return local
            } catch {
                return nil
            }
        }
        setInFlight(key, task: task)
        let result = await task.value
        removeInFlight(key)
        return result
    }
}

@main
internal struct MovieApp: App {
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup("Movie") {
            NavigationStack(path: $path) {
                SearchView(path: $path)
            }
            .navigationDestination(for: Int.self) { tmdbID in
                DetailView(tmdbID: tmdbID, path: $path)
            }
            .padding(10)
        }
        .defaultSize(width: 900, height: 700)
    }
}
