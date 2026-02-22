import ConvexCore
import DefaultBackend
import DesktopShared
import SwiftCrossUI

internal let client = ConvexClient(deploymentURL: convexBaseURL)
internal let auth = AuthClient(convexURL: convexBaseURL)

internal enum OrgSection: String {
    case members
    case projects
    case settings
    case wiki
}

@main
internal struct OrgApp: App {
    @State private var isAuthenticated = false
    @State private var activeOrgID: String?
    @State private var activeOrgName = ""
    @State private var activeRole = ""
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup("Org") {
            VStack {
                if isAuthenticated {
                    if showOnboarding {
                        OnboardingView {
                            showOnboarding = false
                        }
                    } else if let orgID = activeOrgID {
                        HomeView(
                            orgID: orgID,
                            orgName: activeOrgName,
                            role: activeRole,
                            onSwitchOrg: { activeOrgID = nil },
                            onSignOut: {
                                activeOrgID = nil
                                auth.signOut()
                                client.setAuth(token: nil)
                                isAuthenticated = false
                            }
                        )
                    } else {
                        SwitcherView(
                            onSelectOrg: { id, name, role in
                                activeOrgID = id
                                activeOrgName = name
                                activeRole = role
                            },
                            onSignOut: {
                                auth.signOut()
                                client.setAuth(token: nil)
                                isAuthenticated = false
                            },
                            onShowOnboarding: { showOnboarding = true }
                        )
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
        .defaultSize(width: 1_000, height: 750)
    }
}

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

internal struct SwitcherView: View {
    var onSelectOrg: (String, String, String) -> Void
    var onSignOut: () -> Void
    var onShowOnboarding: () -> Void
    @State private var orgs = [OrgWithRole]()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateForm = false
    @State private var newOrgName = ""
    @State private var newOrgSlug = ""

    var body: some View {
        VStack {
            HStack {
                Text("Organizations")
                Button("New Org") { showCreateForm = true }
                Button("Sign Out") { onSignOut() }
            }
            .padding(.bottom, 4)

            if showCreateForm {
                VStack {
                    TextField("Organization Name", text: $newOrgName)
                    TextField("Slug", text: $newOrgSlug)
                    HStack {
                        Button("Cancel") { showCreateForm = false }
                        Button("Create") {
                            Task { await createOrg() }
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            if isLoading {
                Text("Loading...")
            } else if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if orgs.isEmpty {
                VStack {
                    Text("No organizations yet")
                    Button("Get Started") { onShowOnboarding() }
                }
            } else {
                ScrollView {
                    ForEach(orgs) { entry in
                        HStack {
                            VStack {
                                Text(entry.org.name)
                                Text(entry.org.slug)
                            }
                            Text(entry.role.capitalized)
                            Button("Select") {
                                onSelectOrg(entry.org._id, entry.org.name, entry.role)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await loadOrgs()
        }
    }

    @MainActor
    private func loadOrgs() async {
        isLoading = true
        do {
            let loaded: [OrgWithRole] = try await client.query("org:myOrgs")
            orgs = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func createOrg() async {
        let name = newOrgName.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = newOrgSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !slug.isEmpty else {
            return
        }

        do {
            try await client.mutation("org:create", args: [
                "data": ["name": name, "slug": slug] as [String: Any],
            ])
            newOrgName = ""
            newOrgSlug = ""
            showCreateForm = false
            await loadOrgs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var step = 0
    @State private var displayName = ""
    @State private var bio = ""
    @State private var orgName = ""
    @State private var orgSlug = ""
    @State private var theme = "system"
    @State private var notifications = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let steps = ["Profile", "Organization", "Appearance", "Preferences"]

    var body: some View {
        VStack {
            HStack {
                Text("Step \(step + 1) of \(steps.count): \(steps[step])")
            }
            .padding(.bottom, 8)

            switch step {
            case 0:
                TextField("Display Name", text: $displayName)
                TextField("Bio", text: $bio)

            case 1:
                TextField("Organization Name", text: $orgName)
                TextField("URL Slug", text: $orgSlug)

            case 2:
                TextField("Theme (light/dark/system)", text: $theme)

            case 3:
                Toggle("Enable Notifications", isOn: $notifications)

            default:
                Text("")
            }

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                if step < steps.count - 1 {
                    Button("Next") { step += 1 }
                } else {
                    Button("Complete") {
                        Task { await submit() }
                    }
                }
            }
            .padding(.top, 4)

            if isSubmitting {
                Text("Submitting...")
            }
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let profileArgs: [String: Any] = [
                "displayName": displayName,
                "bio": bio,
                "theme": theme,
                "notifications": notifications,
            ]
            try await client.mutation("orgProfile:upsert", args: profileArgs)
            try await client.mutation("org:create", args: [
                "data": ["name": orgName, "slug": orgSlug] as [String: Any],
            ])
            isSubmitting = false
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

internal struct HomeView: View {
    let orgID: String
    let orgName: String
    let role: String
    var onSwitchOrg: () -> Void
    var onSignOut: () -> Void
    @State private var section = OrgSection.projects
    @State private var path = NavigationPath()

    var body: some View {
        VStack {
            HStack {
                Text(orgName)
                Button("Projects") { section = .projects; path = NavigationPath() }
                Button("Wiki") { section = .wiki; path = NavigationPath() }
                Button("Members") { section = .members; path = NavigationPath() }
                Button("Settings") { section = .settings; path = NavigationPath() }
                Button("Switch Org") { onSwitchOrg() }
                Button("Sign Out") { onSignOut() }
            }
            .padding(.bottom, 4)

            switch section {
            case .projects:
                NavigationStack(path: $path) {
                    ProjectsView(orgID: orgID, role: role, path: $path)
                }
                .navigationDestination(for: String.self) { projectID in
                    TasksView(orgID: orgID, projectID: projectID, role: role)
                }

            case .wiki:
                NavigationStack(path: $path) {
                    WikiListView(orgID: orgID, role: role, path: $path)
                }
                .navigationDestination(for: String.self) { wikiID in
                    WikiEditView(orgID: orgID, wikiID: wikiID, role: role)
                }

            case .members:
                MembersView(orgID: orgID, role: role)

            case .settings:
                SettingsView(orgID: orgID, orgName: orgName, role: role, onSwitchOrg: onSwitchOrg, onSignOut: onSignOut)
            }
        }
    }
}
