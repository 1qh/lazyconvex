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

        membersSubID = OrgAPI.subscribeMembers(
            orgId: orgID,
            onUpdate: { [weak self] result in
                self?.members = result
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        invitesSubID = OrgAPI.subscribePendingInvites(
            orgId: orgID,
            onUpdate: { [weak self] result in
                self?.invites = result
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
        )
    }

    func stopSubscription() {
        cancelSubscription(&membersSubID)
        cancelSubscription(&invitesSubID)
    }

    func inviteMember(orgID: String, email: String) {
        Task {
            do {
                try await OrgAPI.invite(email: email, isAdmin: false, orgId: orgID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revokeInvite(inviteID: String) {
        Task {
            do {
                try await OrgAPI.revokeInvite(inviteId: inviteID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setAdmin(memberId: String, isAdmin: Bool) {
        Task {
            do {
                try await OrgAPI.setAdmin(isAdmin: isAdmin, memberId: memberId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeMember(memberId: String) {
        Task {
            do {
                try await OrgAPI.removeMember(memberId: memberId)
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
            viewModel.startSubscription(orgID: orgID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
