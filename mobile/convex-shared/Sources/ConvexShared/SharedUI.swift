import Foundation
import Observation
import SwiftUI

public func cancelSubscription(_ subscriptionID: inout String?) {
    if let subID = subscriptionID {
        ConvexService.shared.cancelSubscription(subID)
        subscriptionID = nil
    }
}

@preconcurrency
@MainActor
@Observable
public final class Sub<T> {
    public var data: T?
    public var isLoading = true
    public var error: String?
    private var subID: String?

    // swiftlint:disable:next no_empty_block
    public init() {}
    @preconcurrency
    public func bind(
        _ subscribe: (
            _ onUpdate: @escaping @Sendable @MainActor (T) -> Void,
            _ onError: @escaping @Sendable @MainActor (Error) -> Void
        ) -> String
    ) {
        cancel()
        isLoading = true
        error = nil
        subID = subscribe(
            { [weak self] result in
                self?.data = result
                self?.isLoading = false
            },
            { [weak self] err in
                self?.error = err.localizedDescription
                self?.isLoading = false
            }
        )
    }

    public func cancel() {
        if let id = subID {
            ConvexService.shared.cancelSubscription(id)
            subID = nil
        }
    }
}

@preconcurrency
@MainActor
public protocol Performing: AnyObject {
    var mutationError: String? { get set }
}

extension Performing {
    public func perform(_ action: @escaping () async throws -> Void) {
        Task { [weak self] in
            do {
                try await action()
            } catch {
                self?.mutationError = error.localizedDescription
            }
        }
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
