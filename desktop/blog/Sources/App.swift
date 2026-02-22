import ConvexCore
import DefaultBackend
import DesktopShared
import SwiftCrossUI

internal let client = ConvexClient(deploymentURL: convexBaseURL)
internal let auth = AuthClient(convexURL: convexBaseURL)
internal let fileClient = FileClient(client: client)

@main
internal struct BlogApp: App {
    @State private var path = NavigationPath()
    @State private var isAuthenticated = false
    @State private var showCreateForm = false

    var body: some Scene {
        WindowGroup("Blog") {
            VStack {
                if isAuthenticated {
                    HStack {
                        Button("Posts") {
                            path = NavigationPath()
                        }
                        Button("Profile") {
                            path = NavigationPath()
                            path.append(BlogRoute.profile)
                        }
                        Button("New Post") {
                            showCreateForm = true
                        }
                        Button("Sign Out") {
                            auth.signOut()
                            client.setAuth(token: nil)
                            isAuthenticated = false
                        }
                    }
                    .padding(.bottom, 4)

                    if showCreateForm {
                        FormView(mode: .create) {
                            showCreateForm = false
                        }
                    } else {
                        NavigationStack(path: $path) {
                            ListView(path: $path)
                        }
                        .navigationDestination(for: String.self) { blogID in
                            DetailView(blogID: blogID, path: $path)
                        }
                        .navigationDestination(for: BlogRoute.self) { route in
                            switch route {
                            case .profile:
                                ProfileView()
                            }
                        }
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

internal enum BlogRoute: Codable {
    case profile
}
