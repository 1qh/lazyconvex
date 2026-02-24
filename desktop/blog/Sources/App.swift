import ConvexCore
import DefaultBackend
import DesktopShared
import Foundation
import SwiftCrossUI

internal let client = ConvexClient(deploymentURL: convexBaseURL)
internal let auth = AuthClient(convexURL: convexBaseURL)
internal let fileClient = FileClient(client: client)

@main
internal struct BlogApp: App {
    @State private var path = NavigationPath()
    @State private var isAuthenticated = false
    @State private var showCreateForm = false

    var body: some Scene {
        WindowGroup("Blog") {
            VStack {
                if isAuthenticated {
                    HStack {
                        Button("Posts") {
                            path = NavigationPath()
                        }
                        Button("Profile") {
                            path = NavigationPath()
                            path.append(BlogRoute.profile)
                        }
                        Button("New Post") {
                            showCreateForm = true
                        }
                        Button("Sign Out") {
                            auth.signOut()
                            client.setAuth(token: nil)
                            isAuthenticated = false
                        }
                    }
                    .padding(.bottom, 4)

                    if showCreateForm {
                        FormView(mode: .create) {
                            showCreateForm = false
                        }
                    } else {
                        NavigationStack(path: $path) {
                            ListView(path: $path)
                        }
                        .navigationDestination(for: String.self) { blogID in
                            DetailView(blogID: blogID, path: $path)
                        }
                        .navigationDestination(for: BlogRoute.self) { route in
                            switch route {
                            case .profile:
                                ProfileView()
                            }
                        }
                    }
                } else {
                    AuthView {
                        isAuthenticated = true
                        client.setAuth(token: auth.token)
                    }
                }
            }
            .padding(10)
        }
        .defaultSize(width: 900, height: 700)
    }
}

internal enum BlogRoute: Codable {
    case profile
}

internal final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cacheDir: URL
    private let session = URLSession.shared
    private var inFlight = [String: Task<URL?, Never>]()
    private let lock = NSLock()

    private init() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("blog-images")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        cacheDir = tmp
    }

    func localURL(for remoteURL: String) -> URL? {
        let filename = remoteURL.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let local = cacheDir.appendingPathComponent(filename)
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

    func download(_ remoteURL: String) async -> URL? {
        let filename = remoteURL.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let local = cacheDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: local.path) {
            return local
        }

        if let existing = getInFlight(remoteURL) {
            return await existing.value
        }
        let task = Task<URL?, Never> {
            guard let url = URL(string: remoteURL) else {
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
        setInFlight(remoteURL, task: task)
        let result = await task.value
        removeInFlight(remoteURL)
        return result
    }
}
