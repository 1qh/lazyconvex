import SwiftUI
#if !SKIP
import AuthenticationServices
#else
import SkipAuthenticationServices
#endif
public struct AuthView: View {
    @Environment(\.webAuthenticationSession)
    private var webAuthSession: WebAuthenticationSession

    @State private var isSignUp = false

    @State private var email = ""

    @State private var password = ""

    @State private var isLoading = false

    @State private var errorMessage: String?

    private let convexURL: String

    private let onAuthenticated: () -> Void

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $isSignUp) {
                        Text("Sign In").tag(false)
                        Text("Sign Up").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Email", text: $email)
                    SecureField("Password", text: $password)
                }

                if errorMessage != nil {
                    Section {
                        ErrorBanner(message: errorMessage)
                    }
                }

                Section {
                    Button(action: { Task { await handlePasswordAuth() } }) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }

                Section {
                    Button(action: { Task { await handleGoogleAuth() } }) {
                        HStack {
                            Spacer()
                            Text("Sign in with Google")
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Welcome Back")
        }
    }

    public init(convexURL: String, onAuthenticated: @escaping () -> Void) {
        self.convexURL = convexURL
        self.onAuthenticated = onAuthenticated
    }

    private func handlePasswordAuth() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await AuthService.shared.signUpWithPassword(
                    email: email,
                    password: password,
                    convexURL: convexURL
                )
            } else {
                try await AuthService.shared.signInWithPassword(
                    email: email,
                    password: password,
                    convexURL: convexURL
                )
            }
            if let token = AuthService.shared.currentToken {
                try await ConvexService.shared.setAuth(token: token)
            }
            onAuthenticated()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleGoogleAuth() async {
        isLoading = true
        errorMessage = nil
        do {
            #if !SKIP
            try await AuthService.shared.signInWithGoogle(
                convexURL: convexURL
            )
            #else
            try await AuthService.shared.signInWithGoogle(
                session: webAuthSession,
                convexURL: convexURL
            )
            #endif
            if let token = AuthService.shared.currentToken {
                try await ConvexService.shared.setAuth(token: token)
            }
            onAuthenticated()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
