import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal struct SettingsView: View {
    let orgID: String
    let orgName: String
    let role: OrgRole
    var onSwitchOrg: () -> Void
    var onSignOut: () -> Void
    @State private var editedName = ""
    @State private var editedSlug = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var adminMembers: [OrgMemberEntry]?
    @State private var selectedAdminID: String?

    var body: some View {
        VStack {
            Text("Settings")
                .padding(.bottom, 8)

            TextField("Organization Name", text: $editedName)
            TextField("Slug", text: $editedSlug)

            if role.isAdmin {
                Button("Save Changes") {
                    Task { await saveOrg() }
                }
                .padding(.top, 4)
            }

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            if isSaving {
                Text("Saving...")
            }

            HStack {
                Button("Switch Organization") { onSwitchOrg() }
                Button("Sign Out") { onSignOut() }
            }
            .padding(.top, 8)

            if !role.isOwner {
                Button("Leave Organization") {
                    Task { await leaveOrg() }
                }
                .padding(.top, 4)
            }

            if role.isOwner {
                VStack {
                    Text("Transfer Ownership")
                        .padding(.bottom, 4)
                    if let members = adminMembers, !members.isEmpty {
                        VStack {
                            Text("Select new owner:")
                            ForEach(members) { m in
                                Button(m.name ?? m.email ?? m.userId) {
                                    selectedAdminID = m.userId
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        if let selected = selectedAdminID, let member = members.first(where: { $0.userId == selected }) {
                            HStack {
                                Text("Transfer to: \(member.name ?? member.email ?? member.userId)")
                                Button("Confirm") {
                                    Task { await transferOwnership() }
                                }
                            }
                            .padding(.top, 4)
                        }
                    } else if adminMembers != nil {
                        Text("No other admins available")
                            .foregroundColor(.gray)
                    } else {
                        Text("Loading admins...")
                    }
                }
                .padding(.top, 4)
            }

            if role.isOwner {
                Button("Delete Organization") {
                    Task { await deleteOrg() }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            editedName = orgName
            Task { await loadAdminMembers() }
        }
    }

    @MainActor
    private func saveOrg() async {
        isSaving = true
        errorMessage = nil
        do {
            try await OrgAPI.update(
                client,
                orgId: orgID,
                name: editedName,
                slug: editedSlug.isEmpty ? nil : editedSlug
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    @MainActor
    private func leaveOrg() async {
        do {
            try await OrgAPI.leave(client, orgId: orgID)
            onSwitchOrg()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteOrg() async {
        do {
            try await OrgAPI.remove(client, orgId: orgID)
            onSwitchOrg()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadAdminMembers() async {
        do {
            let members: [OrgMemberEntry] = try await OrgAPI.members(client, orgId: orgID)
            var filtered = [OrgMemberEntry]()
            for m in members where m.role.isAdmin {
                filtered.append(m)
            }
            adminMembers = filtered
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func transferOwnership() async {
        guard let newOwnerID = selectedAdminID else {
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            try await OrgAPI.transferOwnership(client, newOwnerId: newOwnerID, orgId: orgID)
            onSwitchOrg()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
