import ConvexShared
import SwiftUI

internal struct SettingsView: View {
    let orgID: String

    let orgName: String

    let role: OrgRole

    let onSwitchOrg: () -> Void

    let onSignOut: () -> Void

    @State private var editedName = ""

    @State private var editedSlug = ""

    @State private var isSaving = false

    @State private var showDeleteConfirm = false

    @State private var deleteConfirmText = ""

    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Organization") {
                TextField("Name", text: $editedName)
                TextField("Slug", text: $editedSlug)

                if role.isAdmin {
                    Button("Save Changes") {
                        saveOrg()
                    }
                    .disabled(isSaving || editedName.trimmed.isEmpty)
                }
            }

            Section("Account") {
                Button("Switch Organization") {
                    onSwitchOrg()
                }
                Button("Sign Out") {
                    onSignOut()
                }
            }

            if !role.isOwner {
                Section("Danger Zone") {
                    Button("Leave Organization", role: .destructive) {
                        leaveOrg()
                    }
                }
            }

            if role.isOwner {
                Section("Danger Zone") {
                    Button("Delete Organization", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }

            if errorMessage != nil {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }
        }
        .alert("Delete Organization", isPresented: $showDeleteConfirm) {
            TextField("Type organization name to confirm", text: $deleteConfirmText)
            Button("Delete", role: .destructive) {
                if deleteConfirmText == orgName {
                    deleteOrg()
                }
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmText = ""
            }
        } message: {
            Text("This action cannot be undone. Type \"\(orgName)\" to confirm.")
        }
        .onAppear {
            editedName = orgName
        }
    }

    private func saveOrg() {
        isSaving = true
        Task {
            do {
                try await OrgAPI.update(
                    orgId: orgID,
                    name: editedName,
                    slug: editedSlug.isEmpty ? nil : editedSlug
                )
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func leaveOrg() {
        Task {
            do {
                try await OrgAPI.leave(orgId: orgID)
                onSwitchOrg()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteOrg() {
        Task {
            do {
                try await OrgAPI.remove(orgId: orgID)
                onSwitchOrg()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
