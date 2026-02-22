import DesktopShared
import Foundation
import SwiftCrossUI

internal struct AuthView: View {
    var onAuth: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Text(isSignUp ? "Sign Up" : "Sign In")
                .padding(.bottom, 8)

            TextField("Email", text: $email)
            TextField("Password", text: $password)

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            HStack {
                Button(isSignUp ? "Create Account" : "Sign In") {
                    Task { await submit() }
                }

                Button(isSignUp ? "Have account? Sign In" : "Need account? Sign Up") {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            }
            .padding(.top, 4)

            if isLoading {
                Text("Loading...")
            }
        }
        .onAppear {
            if auth.restore() {
                onAuth()
            }
        }
    }

    @MainActor
    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                try await auth.signUp(email: email, password: password)
            } else {
                try await auth.signIn(email: email, password: password)
            }
            onAuth()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
