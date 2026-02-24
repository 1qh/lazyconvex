import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class MembersViewModel: Performing {
    let membersSub = Sub<[OrgMemberEntry]>()
    let invitesSub = Sub<[OrgInvite]>()
    let joinRequestsSub = Sub<[JoinRequestEntry]>()
    var mutationError: String?

    var members: [OrgMemberEntry] {
        membersSub.data ?? []
    }

    var invites: [OrgInvite] {
        invitesSub.data ?? []
    }

    var joinRequests: [JoinRequestEntry] {
        joinRequestsSub.data ?? []
    }

    var isLoading: Bool {
        membersSub.isLoading
    }

    var errorMessage: String? {
        membersSub.error ?? invitesSub.error ?? joinRequestsSub.error ?? mutationError
    }

    func start(orgID: String) {
        membersSub.bind { OrgAPI.subscribeMembers(orgId: orgID, onUpdate: $0, onError: $1) }
        invitesSub.bind { OrgAPI.subscribePendingInvites(orgId: orgID, onUpdate: $0, onError: $1) }
        joinRequestsSub.bind { OrgAPI.subscribePendingJoinRequests(orgId: orgID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        membersSub.cancel()
        invitesSub.cancel()
        joinRequestsSub.cancel()
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

    func approveRequest(requestId: String, isAdmin: Bool) {
        perform { try await OrgAPI.approveJoinRequest(requestId: requestId, isAdmin: isAdmin) }
    }

    func rejectRequest(requestId: String) {
        perform { try await OrgAPI.rejectJoinRequest(requestId: requestId) }
    }
}

internal struct MembersView: View {
    let orgID: String

    let role: OrgRole

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
                                    if role.isAdmin {
                                        Button("Revoke", role: .destructive) {
                                            viewModel.revokeInvite(inviteID: invite._id)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    if role.isAdmin, !viewModel.joinRequests.isEmpty {
                        Section("Pending Join Requests") {
                            ForEach(viewModel.joinRequests) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.user?.name ?? "Unknown")
                                            .font(.headline)
                                        if let message = entry.request.message, !message.isEmpty {
                                            Text(message)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(action: { viewModel.approveRequest(requestId: entry.request._id, isAdmin: false) }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain)
                                    Button(action: { viewModel.rejectRequest(requestId: entry.request._id) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            if role.isAdmin {
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
                        .disabled(inviteEmail.trimmed.isEmpty)
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
