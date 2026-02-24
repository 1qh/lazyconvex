import ConvexShared
import Foundation
import OSLog
import SwiftUI

internal let logger = Logger(subsystem: "dev.lazyconvex.chat", category: "Chat")

internal struct PublicListRoute: Hashable {}

internal struct PublicChatRoute: Hashable {
    let id: String
}

internal struct ContentView: View {
    var body: some View {
        AuthenticatedView { signOut in
            NavigationStack {
                ListView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: signOut) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .navigationDestination(for: String.self) { chatID in
                        MessageView(chatID: chatID)
                    }
                    .navigationDestination(for: PublicListRoute.self) { _ in
                        PublicListView()
                    }
                    .navigationDestination(for: PublicChatRoute.self) { route in
                        PublicView(chatID: route.id)
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
