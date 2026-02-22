import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class MembersViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var members = [OrgMemberEntry]()
    @SwiftCrossUI.Published var invites = [OrgInvite]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedMembers: [OrgMemberEntry] = try await client.query(
                "org:members",
                args: ["orgId": orgID]
            )
            members = loadedMembers
            let loadedInvites: [OrgInvite] = try await client.query(
                "org:pendingInvites",
                args: ["orgId": orgID]
            )
            invites = loadedInvites
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func inviteMember(orgID: String, email: String) async {
        do {
            try await client.mutation("org:invite", args: [
                "orgId": orgID,
                "email": email,
                "isAdmin": false,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func revokeInvite(orgID: String, inviteID: String) async {
        do {
            try await client.mutation("org:revokeInvite", args: [
                "orgId": orgID,
                "inviteId": inviteID,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func setAdmin(orgID: String, userID: String, isAdmin: Bool) async {
        do {
            try await client.mutation("org:setAdmin", args: [
                "orgId": orgID,
                "userId": userID,
                "isAdmin": isAdmin,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func removeMember(orgID: String, userID: String) async {
        do {
            try await client.mutation("org:removeMember", args: [
                "orgId": orgID,
                "userId": userID,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct MembersView: View {
    let orgID: String
    let role: String
    @State private var viewModel = MembersViewModel()
    @State private var showInviteForm = false
    @State private var inviteEmail = ""

    var body: some View {
        VStack {
            HStack {
                Text("Members")
                if role == "owner" || role == "admin" {
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
                            Text(member.role.capitalized)
                            if role == "owner" || role == "admin" {
                                Button("Remove") {
                                    Task { await viewModel.removeMember(orgID: orgID, userID: member.userId) }
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
                                if role == "owner" || role == "admin" {
                                    Button("Revoke") {
                                        Task { await viewModel.revokeInvite(orgID: orgID, inviteID: invite._id) }
                                    }
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
