@testable import DesktopShared
import Foundation
import Testing

@Suite("ConvexClient")
struct ConvexClientTests {
    @Test("Init stores deployment URL")
    func initStoresURL() {
        let client = ConvexClient(deploymentURL: "http://127.0.0.1:3210")
        _ = client
    }

    @Test("Set auth token is callable")
    func setAuthToken() {
        let client = ConvexClient(deploymentURL: "http://127.0.0.1:3210")
        client.setAuth(token: "test-token")
        client.setAuth(token: nil)
    }
}

@Suite("AuthClient")
struct AuthClientTests {
    private let service = "dev.lazyconvex.test.\(ProcessInfo.processInfo.globallyUniqueString)"

    @Test("Init and default state")
    func initDefaultState() {
        let auth = AuthClient(convexURL: "http://127.0.0.1:3210", keychainService: service)
        #expect(auth.token == nil)
        #expect(auth.isAuthenticated == false)
    }

    @Test("Restore returns false when no saved token")
    func restoreNoToken() {
        let auth = AuthClient(convexURL: "http://127.0.0.1:3210", keychainService: service)
        #expect(auth.restore() == false)
        #expect(auth.isAuthenticated == false)
    }

    @Test("Sign out clears state")
    func signOutClearsState() {
        let auth = AuthClient(convexURL: "http://127.0.0.1:3210", keychainService: service)
        auth.signOut()
        #expect(auth.token == nil)
        #expect(auth.isAuthenticated == false)
    }
}

@Suite("ConvexSubscription")
struct ConvexSubscriptionTests {
    @Test("Init and stop without start")
    func initAndStop() {
        let sub = ConvexSubscription<[String]>(
            deploymentURL: "http://127.0.0.1:3210",
            name: "test:query",
            onChange: { _ in }
        )
        sub.stop()
    }

    @Test("Start and immediate stop")
    func startAndStop() {
        let sub = ConvexSubscription<[String]>(
            deploymentURL: "http://127.0.0.1:3210",
            name: "test:query",
            onChange: { _ in }
        )
        sub.start()
        sub.stop()
    }

    @Test("Update auth token")
    func updateAuth() {
        let sub = ConvexSubscription<[String]>(
            deploymentURL: "http://127.0.0.1:3210",
            name: "test:query",
            onChange: { _ in }
        )
        sub.updateAuth(token: "new-token")
        sub.updateAuth(token: nil)
        sub.stop()
    }

    @Test("Double start is idempotent")
    func doubleStart() {
        let sub = ConvexSubscription<[String]>(
            deploymentURL: "http://127.0.0.1:3210",
            name: "test:query",
            onChange: { _ in }
        )
        sub.start()
        sub.start()
        sub.stop()
    }
}

@Suite("FileClient")
struct FileClientTests {
    @Test("Init with ConvexClient")
    func initWithClient() {
        let client = ConvexClient(deploymentURL: "http://127.0.0.1:3210")
        let fileClient = FileClient(client: client)
        _ = fileClient
    }
}
