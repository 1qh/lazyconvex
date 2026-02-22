import ConvexShared
import SwiftUI

internal enum Tab: String, Hashable {
    case members
    case projects
    case settings
    case wiki
}

internal struct HomeView: View {
    let orgID: String

    let orgName: String

    let role: String

    let onSwitchOrg: () -> Void

    let onSignOut: () -> Void

    @State private var selectedTab = Tab.projects

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProjectsView(orgID: orgID, role: role)
                    .navigationTitle("Projects")
            }
            .tabItem { Label("Projects", systemImage: "folder.fill") }
            .tag(Tab.projects)

            NavigationStack {
                WikiListView(orgID: orgID, role: role)
                    .navigationTitle("Wiki")
            }
            .tabItem { Label("Wiki", systemImage: "doc.text.fill") }
            .tag(Tab.wiki)

            NavigationStack {
                MembersView(orgID: orgID, role: role)
                    .navigationTitle("Members")
            }
            .tabItem { Label("Members", systemImage: "person.3.fill") }
            .tag(Tab.members)

            NavigationStack {
                SettingsView(orgID: orgID, orgName: orgName, role: role, onSwitchOrg: onSwitchOrg, onSignOut: onSignOut)
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(Tab.settings)
        }
    }
}
