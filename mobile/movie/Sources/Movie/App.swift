import ConvexShared
import Foundation
import OSLog
import SwiftUI

internal let logger = Logger(subsystem: "dev.lazyconvex.movie", category: "Movie")

internal enum AppTab: String, Hashable {
    case fetch
    case search
}

internal struct ContentView: View {
    @State private var selectedTab = AppTab.search

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SearchView()
                    .navigationDestination(for: Int.self) { tmdbID in
                        DetailView(tmdbID: tmdbID)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                FetchByIDView()
            }
            .tabItem { Label("Fetch", systemImage: "arrow.down.circle") }
            .tag(AppTab.fetch)
        }
    }
}

public struct RootView: View {
    public var body: some View {
        ContentView()
            .task {
                ConvexService.shared.initialize(url: convexBaseURL)
                logger.info("ConvexService initialized")
            }
    }

    public init() {
        _ = ()
    }
}

public final class AppDelegate: Sendable {
    public static let shared = AppDelegate()

    private init() {
        _ = ()
    }

    public func onInit() {
        logger.debug("onInit")
    }

    public func onLaunch() {
        logger.debug("onLaunch")
    }

    public func onResume() {
        logger.debug("onResume")
    }

    public func onPause() {
        logger.debug("onPause")
    }

    public func onStop() {
        logger.debug("onStop")
    }

    public func onDestroy() {
        logger.debug("onDestroy")
    }

    public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
