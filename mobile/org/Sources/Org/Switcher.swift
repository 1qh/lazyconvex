import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class SwitcherViewModel: Performing {
    let sub = Sub<[OrgWithRole]>()
    var mutationError: String?

    var orgs: [OrgWithRole] {
        sub.data ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start() {
        sub.bind { OrgAPI.subscribeMyOrgs(onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func createOrg(name: String, slug: String) {
        perform { try await OrgAPI.create(name: name, slug: slug) }
    }
}

internal struct RoleBadge: View {
    let role: OrgRole

    private var badgeColor: Color {
        switch role {
        case .owner:
            .orange

        case .admin:
            .blue

        case .member:
            .green
        }
    }

    var body: some View {
        Text(role.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
}

internal struct CreateOrgSheet: View {
    @Binding var newOrgName: String
    @Binding var newOrgSlug: String
    @Binding var isPresented: Bool
    let viewModel: SwitcherViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("Organization Name", text: $newOrgName)
                TextField("Slug (URL-friendly)", text: $newOrgSlug)
            }
            .navigationTitle("New Organization")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createOrg(name: newOrgName, slug: newOrgSlug)
                        newOrgName = ""
                        newOrgSlug = ""
                        isPresented = false
                    }
                    .disabled(newOrgName.trimmed.isEmpty || newOrgSlug.trimmed.isEmpty)
                }
            }
        }
    }
}

internal struct InviteTokenSheet: View {
    @Binding var inviteToken: String
    @Binding var isPresented: Bool
    let onAccept: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Invite token", text: $inviteToken)
            }
            .navigationTitle("Accept Invite")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") {
                        let token = inviteToken.trimmed
                        inviteToken = ""
                        isPresented = false
                        onAccept(token)
                    }
                    .disabled(inviteToken.trimmed.isEmpty)
                }
            }
        }
    }
}

internal struct JoinOrgSheet: View {
    @Binding var joinSlug: String
    @Binding var isPresented: Bool
    let onJoin: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Organization slug", text: $joinSlug)
            }
            .navigationTitle("Join Organization")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        let slug = joinSlug.trimmed
                        joinSlug = ""
                        isPresented = false
                        onJoin(slug)
                    }
                    .disabled(joinSlug.trimmed.isEmpty)
                }
            }
        }
    }
}

internal struct SwitcherView: View {
    let onSelectOrg: (String, String, OrgRole) -> Void

    let onSignOut: () -> Void

    let onAcceptInvite: (String) -> Void

    let onJoinOrg: (String) -> Void

    @State private var viewModel = SwitcherViewModel()

    @State private var showCreateSheet = false

    @State private var showInviteSheet = false

    @State private var showJoinSheet = false

    @State private var newOrgName = ""

    @State private var newOrgSlug = ""

    @State private var inviteToken = ""

    @State private var joinSlug = ""

    var onShowOnboarding: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.orgs.isEmpty {
                    emptyState
                } else {
                    orgList
                }
            }
            .navigationTitle("Organizations")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCreateSheet) {
                CreateOrgSheet(newOrgName: $newOrgName, newOrgSlug: $newOrgSlug, isPresented: $showCreateSheet, viewModel: viewModel)
            }
            .sheet(isPresented: $showInviteSheet) {
                InviteTokenSheet(inviteToken: $inviteToken, isPresented: $showInviteSheet, onAccept: onAcceptInvite)
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinOrgSheet(joinSlug: $joinSlug, isPresented: $showJoinSheet, onJoin: onJoinOrg)
            }
            .task {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No Organizations")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Create your first organization to get started.")
                .foregroundStyle(.secondary)
            Button("Get Started") {
                onShowOnboarding?()
            }
            .buttonStyle(.borderedProminent)
            Button("Quick Create") {
                showCreateSheet = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var orgList: some View {
        List(viewModel.orgs) { orgWithRole in
            Button(action: {
                onSelectOrg(orgWithRole.org._id, orgWithRole.org.name, orgWithRole.role)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(orgWithRole.org.name)
                            .font(.headline)
                        Text(orgWithRole.org.slug)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RoleBadge(role: orgWithRole.role)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
            }
            .primaryForeground()
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { showCreateSheet = true }) {
                    Label("New Organization", systemImage: "plus")
                }
                Button(action: { showInviteSheet = true }) {
                    Label("Accept Invite", systemImage: "envelope.open")
                }
                Button(action: { showJoinSheet = true }) {
                    Label("Join Organization", systemImage: "person.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
                    .accessibilityHidden(true)
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button(action: onSignOut) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .accessibilityHidden(true)
            }
        }
    }
}
