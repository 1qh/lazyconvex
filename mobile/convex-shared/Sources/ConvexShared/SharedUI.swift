import Foundation
import SwiftUI

public func cancelSubscription(_ subscriptionID: inout String?) {
    if let subID = subscriptionID {
        ConvexService.shared.cancelSubscription(subID)
        subscriptionID = nil
    }
}

public struct ErrorBanner: View {
    let message: String?

    public var body: some View {
        if let message {
            Text(message)
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    public init(message: String?) {
        self.message = message
    }
}

public struct AuthenticatedView<Content: View>: View {
    @State private var isAuthenticated = false

    @State private var isCheckingAuth = true

    private let content: (@escaping () -> Void) -> Content

    public var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView("Loading...")
            } else if isAuthenticated {
                content(signOut)
            } else {
                AuthView(convexURL: convexSiteURL) {
                    isAuthenticated = true
                }
            }
        }
        .task {
            await AuthService.shared.restoreFromCache()
            isAuthenticated = AuthService.shared.isAuthenticated
            isCheckingAuth = false
        }
    }

    public init(@ViewBuilder content: @escaping (@escaping () -> Void) -> Content) {
        self.content = content
    }

    private func signOut() {
        Task {
            await AuthService.shared.signOut()
            isAuthenticated = false
        }
    }
}
