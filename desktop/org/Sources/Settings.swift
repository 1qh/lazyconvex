#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif
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
    @State private var avatarID: String?
    @State private var isUploadingAvatar = false

    var body: some View {
        VStack {
            Text("Settings")
                .padding(.bottom, 8)

            TextField("Organization Name", text: $editedName)
            TextField("Slug", text: $editedSlug)

            if role.isAdmin {
                HStack {
                    Button(avatarID == nil ? "Choose Avatar" : "Change Avatar") {
                        #if canImport(AppKit)
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.image]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            Task { await uploadAvatar(url: url) }
                        }
                        #endif
                    }
                    if avatarID != nil {
                        Text("Avatar set")
                        Button("Remove") { avatarID = nil }
                    }
                }
                if isUploadingAvatar {
                    Text("Uploading avatar...")
                }
            }

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
                slug: editedSlug.isEmpty ? nil : editedSlug,
                avatarId: avatarID
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

    @MainActor
    private func uploadAvatar(url: URL) async {
        isUploadingAvatar = true
        do {
            avatarID = try await fileClient.uploadImage(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingAvatar = false
    }
}
