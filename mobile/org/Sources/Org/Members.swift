import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class MembersViewModel {
    var members = [OrgMemberEntry]()

    var invites = [OrgInvite]()

    var isLoading = true

    var errorMessage: String?

    private var membersSubID: String?

    private var invitesSubID: String?

    func startSubscription(orgID: String) {
        stopSubscription()
        isLoading = true

        #if !SKIP
        membersSubID = ConvexService.shared.subscribe(
            to: "org:members",
            args: ["orgId": orgID],
            type: [OrgMemberEntry].self,
            onUpdate: { [weak self] (result: [OrgMemberEntry]) in
                self?.members = result
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        invitesSubID = ConvexService.shared.subscribe(
            to: "org:pendingInvites",
            args: ["orgId": orgID],
            type: [OrgInvite].self,
            onUpdate: { [weak self] (result: [OrgInvite]) in
                self?.invites = result
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
        )
        #else
        membersSubID = ConvexService.shared.subscribeOrgMembers(
            to: "org:members",
            args: ["orgId": orgID],
            onUpdate: { result in
                self.members = Array(result)
                self.isLoading = false
            },
            onError: { error in
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        )
        invitesSubID = ConvexService.shared.subscribeInvites(
            to: "org:pendingInvites",
            args: ["orgId": orgID],
            onUpdate: { result in
                self.invites = Array(result)
            },
            onError: { error in
                self.errorMessage = error.localizedDescription
            }
        )
        #endif
    }

    func stopSubscription() {
        cancelSubscription(&membersSubID)
        cancelSubscription(&invitesSubID)
    }

    func inviteMember(orgID: String, email: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("org:invite", args: [
                    "orgId": orgID,
                    "email": email,
                    "isAdmin": false,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revokeInvite(orgID: String, inviteID: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("org:revokeInvite", args: [
                    "orgId": orgID,
                    "inviteId": inviteID,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setAdmin(orgID: String, userID: String, isAdmin: Bool) {
        Task {
            do {
                try await ConvexService.shared.mutate("org:setAdmin", args: [
                    "orgId": orgID,
                    "userId": userID,
                    "isAdmin": isAdmin,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeMember(orgID: String, userID: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("org:removeMember", args: [
                    "orgId": orgID,
                    "userId": userID,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
                                            viewModel.revokeInvite(orgID: orgID, inviteID: invite._id)
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
            viewModel.startSubscription(orgID: orgID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
