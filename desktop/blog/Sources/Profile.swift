import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProfileViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var displayName = ""
    @SwiftCrossUI.Published var bio = ""
    @SwiftCrossUI.Published var theme = "system"
    @SwiftCrossUI.Published var notifications = true
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var isSaving = false
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load() async {
        await performLoading({ isLoading = $0 }) {
            guard let profile = try await BlogProfileAPI.get(client) else {
                return
            }

            displayName = profile.displayName
            bio = profile.bio ?? ""
            theme = profile.theme.rawValue
            notifications = profile.notifications
        }
    }

    @MainActor
    func save() async {
        guard !displayName.trimmed.isEmpty else {
            errorMessage = "Display name is required"
            return
        }

        await performLoading({ isSaving = $0 }) {
            try await BlogProfileAPI.upsert(
                client,
                bio: bio.trimmed.isEmpty ? nil : bio.trimmed,
                displayName: displayName.trimmed,
                notifications: notifications,
                theme: BlogProfileTheme(rawValue: theme)
            )
        }
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
