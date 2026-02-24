import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class MembersViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var members = [OrgMemberEntry]()
    @SwiftCrossUI.Published var invites = [OrgInvite]()
    @SwiftCrossUI.Published var joinRequests = [JoinRequestEntry]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String) async {
        await performLoading({ isLoading = $0 }) {
            members = try await OrgAPI.members(client, orgId: orgID)
            invites = try await OrgAPI.pendingInvites(client, orgId: orgID)
            joinRequests = try await OrgAPI.pendingJoinRequests(client, orgId: orgID)
        }
    }

    @MainActor
    func inviteMember(orgID: String, email: String) async {
        await perform {
            try await OrgAPI.invite(client, email: email, isAdmin: false, orgId: orgID)
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func revokeInvite(orgID: String, inviteID: String) async {
        await perform {
            try await OrgAPI.revokeInvite(client, inviteId: inviteID)
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func setAdmin(orgID: String, memberId: String, isAdmin: Bool) async {
        await perform {
            try await OrgAPI.setAdmin(client, isAdmin: isAdmin, memberId: memberId)
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func removeMember(orgID: String, memberId: String) async {
        await perform {
            try await OrgAPI.removeMember(client, memberId: memberId)
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func approveRequest(orgID: String, requestId: String, isAdmin: Bool) async {
        await perform {
            try await OrgAPI.approveJoinRequest(client, requestId: requestId, isAdmin: isAdmin)
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func rejectRequest(orgID: String, requestId: String) async {
        await perform {
            try await OrgAPI.rejectJoinRequest(client, requestId: requestId)
            await self.load(orgID: orgID)
        }
    }
}

internal struct MembersView: View {
    let orgID: String
    let role: OrgRole
    @State private var viewModel = MembersViewModel()
    @State private var showInviteForm = false
    @State private var inviteEmail = ""

    var body: some View {
        VStack {
            HStack {
                Text("Members")
                if role.isAdmin {
                    Button("Invite") { showInviteForm = true }
                }
            }
            .padding(.bottom, 4)

            if showInviteForm {
                HStack {
                    TextField("Email address", text: $inviteEmail)
                    Button("Send Invite") {
                        Task {
                            await viewModel.inviteMember(orgID: orgID, email: inviteEmail)
                            inviteEmail = ""
                            showInviteForm = false
                        }
                    }
                    Button("Cancel") { showInviteForm = false }
                }
                .padding(.bottom, 8)
            }

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else {
                ScrollView {
                    ForEach(viewModel.members) { member in
                        HStack {
                            VStack {
                                Text(member.name ?? member.email ?? member.userId)
                                if let email = member.email {
                                    Text(email)
                                }
                            }
                            Text(member.role.displayName)
                            if role.isAdmin {
                                Button("Remove") {
                                    if let mid = member.memberId {
                                        Task { await viewModel.removeMember(orgID: orgID, memberId: mid) }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    if !viewModel.invites.isEmpty {
                        Text("Pending Invites")
                            .padding(.top, 8)
                        ForEach(viewModel.invites) { invite in
                            HStack {
                                Text(invite.email)
                                if role.isAdmin {
                                    Button("Revoke") {
                                        Task { await viewModel.revokeInvite(orgID: orgID, inviteID: invite._id) }
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }

                    if role.isAdmin, !viewModel.joinRequests.isEmpty {
                        Text("Pending Join Requests")
                            .padding(.top, 8)
                        ForEach(viewModel.joinRequests) { entry in
                            HStack {
                                VStack {
                                    Text(entry.user?.name ?? "Unknown")
                                    if let msg = entry.request.message, !msg.isEmpty {
                                        Text(msg)
                                    }
                                }
                                Button("Approve") {
                                    Task { await viewModel.approveRequest(orgID: orgID, requestId: entry.request._id, isAdmin: false) }
                                }
                                Button("Reject") {
                                    Task { await viewModel.rejectRequest(orgID: orgID, requestId: entry.request._id) }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.load(orgID: orgID)
        }
    }
}
