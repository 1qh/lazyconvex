import ConvexShared
import Foundation
import OSLog
import SwiftUI

internal let logger = Logger(subsystem: "dev.lazyconvex.blog", category: "Blog")

internal enum Tab: String, Hashable {
    case posts
    case profile
}

internal struct ContentView: View {
    @State private var selectedTab = Tab.posts

    var body: some View {
        AuthenticatedView { signOut in
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ListView()
                }
                .tabItem { Label("Posts", systemImage: "doc.text") }
                .tag(Tab.posts)

                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(Tab.profile)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .accessibilityHidden(true)
                    }
                }
            }
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
