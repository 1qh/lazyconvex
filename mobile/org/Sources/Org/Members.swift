import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class MembersViewModel: Performing {
    let membersSub = Sub<[OrgMemberEntry]>()
    let invitesSub = Sub<[OrgInvite]>()
    var mutationError: String?

    var members: [OrgMemberEntry] {
        membersSub.data ?? []
    }

    var invites: [OrgInvite] {
        invitesSub.data ?? []
    }

    var isLoading: Bool {
        membersSub.isLoading
    }

    var errorMessage: String? {
        membersSub.error ?? invitesSub.error ?? mutationError
    }

    func start(orgID: String) {
        membersSub.bind { OrgAPI.subscribeMembers(orgId: orgID, onUpdate: $0, onError: $1) }
        invitesSub.bind { OrgAPI.subscribePendingInvites(orgId: orgID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        membersSub.cancel()
        invitesSub.cancel()
    }

    func inviteMember(orgID: String, email: String) {
        perform { try await OrgAPI.invite(email: email, isAdmin: false, orgId: orgID) }
    }

    func revokeInvite(inviteID: String) {
        perform { try await OrgAPI.revokeInvite(inviteId: inviteID) }
    }

    func setAdmin(memberId: String, isAdmin: Bool) {
        perform { try await OrgAPI.setAdmin(isAdmin: isAdmin, memberId: memberId) }
    }

    func removeMember(memberId: String) {
        perform { try await OrgAPI.removeMember(memberId: memberId) }
    }
}

internal struct MembersView: View {
    let orgID: String

    let role: String

    @State private var viewModel = MembersViewModel()

    @State private var showInviteSheet = false

    @State private var inviteEmail = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                List {
                    Section("Members") {
                        if viewModel.members.isEmpty {
                            Text("No members")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(viewModel.members) { member in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name ?? member.email ?? member.userId)
                                        .font(.headline)
                                    if let email = member.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                RoleBadge(role: member.role)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if !viewModel.invites.isEmpty {
                        Section("Pending Invites") {
                            ForEach(viewModel.invites) { invite in
                                HStack {
                                    Text(invite.email)
                                    Spacer()
                                    if role == "owner" || role == "admin" {
                                        Button("Revoke", role: .destructive) {
                                            viewModel.revokeInvite(inviteID: invite._id)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            if role == "owner" || role == "admin" {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showInviteSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("inviteMemberButton")
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            NavigationStack {
                Form {
                    TextField("Email address", text: $inviteEmail)
                }
                .navigationTitle("Invite Member")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showInviteSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send Invite") {
                            viewModel.inviteMember(orgID: orgID, email: inviteEmail)
                            inviteEmail = ""
                            showInviteSheet = false
                        }
                        .disabled(inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .task {
            viewModel.start(orgID: orgID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
