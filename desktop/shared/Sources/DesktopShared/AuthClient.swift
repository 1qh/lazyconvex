import AppKit
import ConvexCore
import Foundation
import Security

public final class AuthClient: @unchecked Sendable {
    private let convexURL: String
    private let keychainService: String
    private let keychainAccount = "convex_auth_token"
    private let lock = NSLock()
    private var _token: String?
    private var _oauthVerifier: String?

    public var token: String? {
        lock.lock()
        defer { lock.unlock() }
        return _token
    }

    public var isAuthenticated: Bool {
        token != nil
    }

    public init(convexURL: String, keychainService: String = "dev.lazyconvex.desktop") {
        self.convexURL = convexURL
        self.keychainService = keychainService
    }

    public func restore() -> Bool {
        if let saved = keychainRead() {
            lock.lock()
            _token = saved
            lock.unlock()
            return true
        }
        return false
    }

    public func signIn(email: String, password: String) async throws {
        let t = try await passwordAuth(
            email: email,
            password: password,
            flow: "signIn",
            convexURL: convexURL
        )
        save(token: t)
    }

    public func signUp(email: String, password: String) async throws {
        let t = try await passwordAuth(
            email: email,
            password: password,
            flow: "signUp",
            convexURL: convexURL
        )
        save(token: t)
    }

    public func startGoogleOAuth() async throws -> URL {
        let result = try await startOAuth(
            convexURL: convexURL,
            redirectTo: "http://127.0.0.1:9876/oauth/callback"
        )
        setVerifier(result.verifier)
        guard let url = URL(string: result.redirect) else {
            throw ConvexError.serverError("Invalid OAuth redirect URL")
        }

        return url
    }

    public func finishGoogleOAuth(callbackURL: URL) async throws {
        guard let verifier = takeVerifier() else {
            throw ConvexError.serverError("No OAuth verifier — call startGoogleOAuth first")
        }

        let code = try extractOAuthCode(from: callbackURL)
        let t = try await finishOAuth(convexURL: convexURL, code: code, verifier: verifier)
        save(token: t)
    }

    public func openGoogleOAuth() async throws {
        let url = try await startGoogleOAuth()
        await openInBrowser(url: url)
    }

    public func signOut() {
        lock.lock()
        _token = nil
        lock.unlock()
        keychainDelete()
    }

    private func save(token: String) {
        lock.lock()
        _token = token
        lock.unlock()
        keychainWrite(token)
    }

    nonisolated private func setVerifier(_ v: String) {
        lock.lock()
        _oauthVerifier = v
        lock.unlock()
    }

    nonisolated private func takeVerifier() -> String? {
        lock.lock()
        let v = _oauthVerifier
        _oauthVerifier = nil
        lock.unlock()
        return v
    }

    @MainActor
    private func openInBrowser(url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func keychainWrite(_ value: String) {
        keychainDelete()
        guard let data = value.data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainRead() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
