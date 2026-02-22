import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProfileViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var displayName = ""
    @SwiftCrossUI.Published var bio = ""
    @SwiftCrossUI.Published var theme = "system"
    @SwiftCrossUI.Published var notifications = true
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var isSaving = false
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        do {
            let profile: ProfileData = try await client.query("blogProfile:get")
            displayName = profile.displayName
            bio = profile.bio ?? ""
            theme = profile.theme
            notifications = profile.notifications
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func save() async {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Display name is required"
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            var args: [String: Any] = [
                "displayName": displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                "theme": theme,
                "notifications": notifications,
            ]
            if !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args["bio"] = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            try await client.mutation("blogProfile:upsert", args: args)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

internal struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                Text("Loading...")
            } else {
                TextField("Display Name", text: $viewModel.displayName)
                TextField("Bio", text: $viewModel.bio)
                TextField("Theme (light/dark/system)", text: $viewModel.theme)
                Toggle("Notifications", isOn: $viewModel.notifications)

                if let msg = viewModel.errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                }

                Button("Save") {
                    Task { await viewModel.save() }
                }
                .padding(.top, 4)

                if viewModel.isSaving {
                    Text("Saving...")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}
