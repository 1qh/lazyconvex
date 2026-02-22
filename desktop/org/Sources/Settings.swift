import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal struct SettingsView: View {
    let orgID: String
    let orgName: String
    let role: String
    var onSwitchOrg: () -> Void
    var onSignOut: () -> Void
    @State private var editedName = ""
    @State private var editedSlug = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Text("Settings")
                .padding(.bottom, 8)

            TextField("Organization Name", text: $editedName)
            TextField("Slug", text: $editedSlug)

            if role == "owner" || role == "admin" {
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

            if role != "owner" {
                Button("Leave Organization") {
                    Task { await leaveOrg() }
                }
                .padding(.top, 4)
            }

            if role == "owner" {
                Button("Delete Organization") {
                    Task { await deleteOrg() }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            editedName = orgName
        }
    }

    @MainActor
    private func saveOrg() async {
        isSaving = true
        errorMessage = nil
        do {
            var data: [String: Any] = ["name": editedName]
            if !editedSlug.isEmpty {
                data["slug"] = editedSlug
            }
            try await client.mutation("org:update", args: [
                "orgId": orgID,
                "data": data as [String: Any],
            ] as [String: Any])
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    @MainActor
    private func leaveOrg() async {
        do {
            try await client.mutation("org:leave", args: ["orgId": orgID])
            onSwitchOrg()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteOrg() async {
        do {
            try await client.mutation("org:remove", args: ["orgId": orgID])
            onSwitchOrg()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
