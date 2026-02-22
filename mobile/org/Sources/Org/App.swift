import ConvexShared
import Foundation
import OSLog
import SwiftUI

internal let logger = Logger(subsystem: "dev.lazyconvex.org", category: "Org")

internal struct ContentView: View {
    @State private var showOnboarding = false

    @State private var activeOrgID: String?

    @State private var activeOrgName = ""

    @State private var activeRole = ""

    var body: some View {
        AuthenticatedView { signOut in
            if showOnboarding {
                OnboardingView {
                    showOnboarding = false
                }
            } else if let orgID = activeOrgID {
                HomeView(
                    orgID: orgID,
                    orgName: activeOrgName,
                    role: activeRole,
                    onSwitchOrg: {
                        activeOrgID = nil
                    },
                    onSignOut: {
                        activeOrgID = nil
                        signOut()
                    }
                )
            } else {
                // swiftformat:disable trailingClosures
                SwitcherView(
                    onSelectOrg: { orgID, name, role in
                        activeOrgID = orgID
                        activeOrgName = name
                        activeRole = role
                    },
                    onSignOut: signOut
                ) {
                    showOnboarding = true
                }
                // swiftformat:enable trailingClosures
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
