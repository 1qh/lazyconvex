import ConvexShared
import Foundation
import Observation
import SkipKit
import SwiftUI

@MainActor
@Observable
internal final class ProfileViewModel: Performing {
    var displayName = ""
    var bio = ""
    var theme = "system"
    var notifications = true
    var isLoading = true
    var isSaving = false
    var isUploadingAvatar = false
    var avatarID: String?
    var selectedAvatarURL: URL?
    let themes = ["light", "dark", "system"]
    var profile: ProfileData?
    var errorMessage: String?
    var mutationError: String? {
        get { errorMessage }
        set { errorMessage = newValue }
    }

    private var subscriptionID: String?

    func startSubscription() {
        stopSubscription()
        isLoading = true

        subscriptionID = BlogProfileAPI.subscribeGet(
            onUpdate: { [weak self] result in
                guard let self else {
                    return
                }

                profile = result
                displayName = result.displayName
                bio = result.bio ?? ""
                theme = result.theme.rawValue
                notifications = result.notifications
                avatarID = result.avatar
                isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            },
            onNull: { [weak self] in
                self?.isLoading = false
            }
        )
    }

    func stopSubscription() {
        cancelSubscription(&subscriptionID)
    }

    func uploadAvatar() {
        guard let url = selectedAvatarURL else {
            return
        }

        performLoading({ self.isUploadingAvatar = $0 }) {
            self.avatarID = try await FileService.shared.uploadImage(url: url)
        }
    }

    func removeAvatar() {
        avatarID = nil
        selectedAvatarURL = nil
    }

    func save() {
        guard !displayName.trimmed.isEmpty else {
            errorMessage = "Display name is required"
            return
        }

        performLoading({ self.isSaving = $0 }) {
            try await BlogProfileAPI.upsert(
                avatar: self.avatarID,
                bio: self.bio.trimmed.isEmpty ? nil : self.bio.trimmed,
                displayName: self.displayName.trimmed,
                notifications: self.notifications,
                theme: BlogProfileTheme(rawValue: self.theme)
            )
        }
    }
}

internal struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showAvatarPicker = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Form {
                    Section("Avatar") {
                        if viewModel.isUploadingAvatar {
                            ProgressView("Uploading...")
                        } else if viewModel.avatarID != nil {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityHidden(true)
                                Text("Avatar set")
                                Spacer()
                                Button("Remove") { viewModel.removeAvatar() }
                                    .foregroundStyle(.red)
                            }
                        }
                        Button(viewModel.avatarID != nil ? "Change Avatar" : "Select Avatar") {
                            showAvatarPicker = true
                        }
                        .withMediaPicker(type: .library, isPresented: $showAvatarPicker, selectedImageURL: $viewModel.selectedAvatarURL)
                        .onChange(of: viewModel.selectedAvatarURL) { _, _ in viewModel.uploadAvatar() }
                    }

                    Section("Display Name") {
                        TextField("Your name", text: $viewModel.displayName)
                    }

                    Section("Bio") {
                        TextEditor(text: $viewModel.bio)
                            .frame(minHeight: 80)
                    }

                    Section("Theme") {
                        Picker("Theme", selection: $viewModel.theme) {
                            ForEach(viewModel.themes, id: \.self) { t in
                                Text(t.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Toggle("Notifications", isOn: $viewModel.notifications)
                    }

                    if viewModel.errorMessage != nil {
                        Section {
                            ErrorBanner(message: viewModel.errorMessage)
                        }
                    }

                    Section {
                        Button(action: { viewModel.save() }) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Save")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(viewModel.isSaving || viewModel.isUploadingAvatar || viewModel.displayName.trimmed
                            .isEmpty)
                    }
                }
            }
        }
        .navigationTitle(viewModel.profile != nil ? "Edit Profile" : "Set Up Profile")
        .task {
            viewModel.startSubscription()
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
