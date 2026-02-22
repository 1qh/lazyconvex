import Foundation
import SkipKeychain
#if !SKIP
import AuthenticationServices
#else
import SkipAuthenticationServices
#endif

public enum AppAuthState {
    case authenticated(String)
    case loading
    case unauthenticated
}

public final class AuthService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = AuthService()

    public var authState = AppAuthState.unauthenticated

    public var currentToken: String?

    public var authError: String?

    public var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    private let tokenKey = "convex_auth_token"

    private let keychain = Keychain.shared

    private init() {
        _ = ()
    }

    public func restoreFromCache() async {
        authState = .loading
        do {
            if let token = try keychain.string(forKey: tokenKey) {
                currentToken = token
                try await ConvexService.shared.setAuth(token: token)
                authState = .authenticated(token)
                return
            }
        } catch {
            authError = error.localizedDescription
        }
        authState = .unauthenticated
    }

    public func signInWithPassword(email: String, password: String, convexURL: String) async throws {
        authState = .loading
        authError = nil
        do {
            let token = try await passwordAuth(
                email: email,
                password: password,
                flow: "signIn",
                convexURL: convexURL
            )
            try keychain.set(token, forKey: tokenKey)
            currentToken = token
            authState = .authenticated(token)
        } catch {
            authState = .unauthenticated
            authError = error.localizedDescription
            throw error
        }
    }

    public func signUpWithPassword(email: String, password: String, convexURL: String) async throws {
        authState = .loading
        authError = nil
        do {
            let token = try await passwordAuth(
                email: email,
                password: password,
                flow: "signUp",
                convexURL: convexURL
            )
            try keychain.set(token, forKey: tokenKey)
            currentToken = token
            authState = .authenticated(token)
        } catch {
            authState = .unauthenticated
            authError = error.localizedDescription
            throw error
        }
    }

    #if !SKIP
    public func signInWithGoogle(
        convexURL: String,
        callbackScheme: String = "dev.lazyconvex"
    ) async throws {
        authState = .loading
        authError = nil
        do {
            let oauthResult = try await startOAuth(convexURL: convexURL)
            guard let redirectURL = URL(string: oauthResult.redirect) else {
                throw ConvexError.serverError("Invalid redirect URL")
            }

            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: redirectURL,
                    callbackURLScheme: callbackScheme
                ) { url, sessionError in
                    if let sessionError {
                        continuation.resume(throwing: sessionError)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: ConvexError.serverError("No callback URL"))
                    }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
            let code = try extractOAuthCode(from: callbackURL)
            let extractedToken = try await finishOAuth(convexURL: convexURL, code: code, verifier: oauthResult.verifier)
            try keychain.set(extractedToken, forKey: tokenKey)
            currentToken = extractedToken
            try await ConvexService.shared.setAuth(token: extractedToken)
            authState = .authenticated(extractedToken)
        } catch {
            authState = .unauthenticated
            authError = error.localizedDescription
            throw error
        }
    }
    #else
    public func signInWithGoogle(
        session: WebAuthenticationSession,
        convexURL: String,
        callbackScheme: String = "dev.lazyconvex"
    ) async throws {
        authState = .loading
        authError = nil
        do {
            let oauthResult = try await startOAuth(convexURL: convexURL)
            guard let redirectURL = URL(string: oauthResult.redirect) else {
                throw ConvexError.serverError("Invalid redirect URL")
            }

            let callbackURL = try await session.authenticate(
                using: redirectURL,
                callbackURLScheme: callbackScheme
            )
            let code = try extractOAuthCode(from: callbackURL)
            let extractedToken = try await finishOAuth(convexURL: convexURL, code: code, verifier: oauthResult.verifier)
            try keychain.set(extractedToken, forKey: tokenKey)
            currentToken = extractedToken
            try await ConvexService.shared.setAuth(token: extractedToken)
            authState = .authenticated(extractedToken)
        } catch {
            authState = .unauthenticated
            authError = error.localizedDescription
            throw error
        }
    }
    #endif

    public func signOut() async {
        do {
            try keychain.removeValue(forKey: tokenKey)
            try await ConvexService.shared.setAuth(token: nil)
        } catch {
            authError = error.localizedDescription
        }
        currentToken = nil
        authState = .unauthenticated
    }
}
