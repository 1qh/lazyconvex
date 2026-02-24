#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif
import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProfileViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var displayName = ""
    @SwiftCrossUI.Published var bio = ""
    @SwiftCrossUI.Published var theme = BlogProfileTheme.system
    @SwiftCrossUI.Published var notifications = true
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var isSaving = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var avatarID: String?
    @SwiftCrossUI.Published var isUploadingAvatar = false

    @MainActor
    func load() async {
        await performLoading({ isLoading = $0 }) {
            guard let profile = try await BlogProfileAPI.get(client) else {
                return
            }

            displayName = profile.displayName
            bio = profile.bio ?? ""
            theme = profile.theme
            notifications = profile.notifications
            avatarID = profile.avatar
        }
    }

    func selectAvatar() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in // swiftlint:disable:this unhandled_throwing_task
                    await self.performLoading({ self.isUploadingAvatar = $0 }) {
                        self.avatarID = try await fileClient.uploadImage(url: url)
                    }
                }
            }
        }
        #endif
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
                avatar: avatarID,
                bio: bio.trimmed.isEmpty ? nil : bio.trimmed,
                displayName: displayName.trimmed,
                notifications: notifications,
                theme: theme
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
                HStack {
                    ForEach(0..<BlogProfileTheme.allCases.count, id: \.self) { idx in
                        let t = BlogProfileTheme.allCases[idx]
                        Button(t.displayName) {
                            viewModel.theme = t
                        }
                    }
                }
                Toggle("Notifications", isOn: $viewModel.notifications)

                HStack {
                    Button(viewModel.avatarID == nil ? "Add Avatar" : "Change Avatar") {
                        viewModel.selectAvatar()
                    }
                    if viewModel.avatarID != nil {
                        Text("Avatar set")
                        Button("Remove") {
                            viewModel.avatarID = nil
                        }
                    }
                }
                if viewModel.isUploadingAvatar {
                    Text("Uploading avatar...")
                }

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
