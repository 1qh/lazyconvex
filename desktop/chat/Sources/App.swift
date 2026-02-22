import ConvexCore
import DefaultBackend
import DesktopShared
import SwiftCrossUI

internal let client = ConvexClient(deploymentURL: convexBaseURL)
internal let auth = AuthClient(convexURL: convexBaseURL)

@main
internal struct ChatApp: App {
    @State private var path = NavigationPath()
    @State private var isAuthenticated = false

    var body: some Scene {
        WindowGroup("Chat") {
            VStack {
                if isAuthenticated {
                    HStack {
                        Button("Chats") {
                            path = NavigationPath()
                        }
                        Button("Sign Out") {
                            auth.signOut()
                            client.setAuth(token: nil)
                            isAuthenticated = false
                        }
                    }
                    .padding(.bottom, 4)

                    NavigationStack(path: $path) {
                        ListView(path: $path)
                    }
                    .navigationDestination(for: String.self) { chatID in
                        MessageView(chatID: chatID, path: $path)
                    }
                } else {
                    AuthView {
                        isAuthenticated = true
                        client.setAuth(token: auth.token)
                    }
                }
            }
            .padding(10)
        }
        .defaultSize(width: 900, height: 700)
    }
}
