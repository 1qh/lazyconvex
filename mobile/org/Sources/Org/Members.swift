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

    func inviteMember(orgID: String, email: String, isAdmin: Bool) {
        perform { try await OrgAPI.invite(email: email, isAdmin: isAdmin, orgId: orgID) }
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

    @State private var inviteAsAdmin = false

    @State private var confirmRemoveMember: OrgMemberEntry?

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
                                if role.isAdmin, !member.role.isOwner, let mid = member.memberId {
                                    Button(action: {
                                        viewModel.setAdmin(memberId: mid, isAdmin: member.role != .admin)
                                    }) {
                                        Image(systemName: member.role == .admin ? "shield.checkered" : "shield")
                                            .foregroundStyle(member.role == .admin ? .blue : .secondary)
                                            .accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("toggleAdmin")
                                    Button(action: { confirmRemoveMember = member }) {
                                        Image(systemName: "person.fill.xmark")
                                            .foregroundStyle(.red)
                                            .accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("removeMember")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if role.isAdmin, !viewModel.invites.isEmpty {
                        PendingInvitesSection(invites: viewModel.invites) { id in
                            viewModel.revokeInvite(inviteID: id)
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
                        .accessibilityIdentifier("inviteEmailField")
                    Toggle("Invite as admin", isOn: $inviteAsAdmin)
                        .accessibilityIdentifier("inviteAsAdminToggle")
                }
                .navigationTitle("Invite Member")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showInviteSheet = false
                            inviteAsAdmin = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send Invite") {
                            viewModel.inviteMember(orgID: orgID, email: inviteEmail, isAdmin: inviteAsAdmin)
                            inviteEmail = ""
                            inviteAsAdmin = false
                            showInviteSheet = false
                        }
                        .disabled(inviteEmail.trimmed.isEmpty)
                    }
                }
            }
        }
        .alert(
            "Remove Member",
            isPresented: Binding(
                get: { confirmRemoveMember != nil },
                set: { newValue in
                    if !newValue {
                        confirmRemoveMember = nil
                    }
                }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let mid = confirmRemoveMember?.memberId {
                    viewModel.removeMember(memberId: mid)
                }
                confirmRemoveMember = nil
            }
            Button("Cancel", role: .cancel) {
                confirmRemoveMember = nil
            }
        } message: {
            Text("Remove \(confirmRemoveMember?.name ?? confirmRemoveMember?.email ?? "this member") from the organization?")
        }
        .task {
            viewModel.start(orgID: orgID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

internal struct PendingInvitesSection: View {
    let invites: [OrgInvite]
    let onRevoke: (String) -> Void

    var body: some View {
        Section("Pending Invites") {
            ForEach(invites) { invite in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(invite.email)
                            .font(.headline)
                        Spacer()
                        RoleBadge(role: invite.isAdmin == true ? .admin : .member)
                    }
                    HStack {
                        Text("Expires \(formatTimestamp(invite.expiresAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let token = invite.token {
                            Button(action: {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = token
                                #endif
                            }) {
                                Label("Copy Link", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("copyInviteLink")
                        }
                        Button("Revoke", role: .destructive) {
                            onRevoke(invite._id)
                        }
                        .font(.caption)
                        .accessibilityIdentifier("revokeInvite")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
