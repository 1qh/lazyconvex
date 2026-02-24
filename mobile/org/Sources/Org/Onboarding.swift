import ConvexShared
import SkipKit
import SwiftUI

internal struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0

    @State private var displayName = ""

    @State private var bio = ""

    @State private var orgName = ""

    @State private var orgSlug = ""

    @State private var theme = OrgProfileTheme.system

    @State private var notifications = true

    @State private var isSubmitting = false

    @State private var errorMessage: String?

    @State private var showAvatarPicker = false

    @State private var selectedAvatarURL: URL?

    @State private var avatarID: String?

    @State private var isUploadingAvatar = false

    @State private var showOrgAvatarPicker = false

    @State private var selectedOrgAvatarURL: URL?

    @State private var orgAvatarID: String?

    @State private var isUploadingOrgAvatar = false

    private let steps = ["Profile", "Organization", "Appearance", "Preferences"]

    private var isStepValid: Bool {
        switch currentStep {
        case 0:
            !displayName.trimmed.isEmpty

        case 1:
            !orgName.trimmed.isEmpty && !orgSlug.trimmed
                .isEmpty

        default:
            true
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { idx in
                Circle()
                    .fill(idx <= currentStep ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.top)
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if currentStep < steps.count - 1 {
                Button("Next") {
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isStepValid || isUploadingAvatar || isUploadingOrgAvatar)
            } else {
                Button("Complete") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || !isStepValid || isUploadingAvatar || isUploadingOrgAvatar)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                stepIndicator
                Text(steps[currentStep])
                    .font(.title2)
                    .fontWeight(.bold)
                Form {
                    switch currentStep {
                    case 0:
                        Section {
                            TextField("Display Name", text: $displayName)
                            TextEditor(text: $bio)
                                .frame(minHeight: 80)
                        }
                        Section("Avatar") {
                            if isUploadingAvatar {
                                ProgressView("Uploading...")
                            } else if avatarID != nil {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityHidden(true)
                                    Text("Avatar set")
                                    Spacer()
                                    Button("Remove") {
                                        avatarID = nil
                                        selectedAvatarURL = nil
                                    }
                                    .foregroundStyle(.red)
                                }
                            }
                            Button(avatarID != nil ? "Change Avatar" : "Select Avatar") {
                                showAvatarPicker = true
                            }
                            .withMediaPicker(type: .library, isPresented: $showAvatarPicker, selectedImageURL: $selectedAvatarURL)
                            .onChange(of: selectedAvatarURL) { _, _ in uploadAvatar() }
                        }

                    case 1:
                        Section {
                            TextField("Organization Name", text: $orgName)
                            TextField("URL Slug", text: $orgSlug)
                        }
                        Section("Organization Avatar") {
                            if isUploadingOrgAvatar {
                                ProgressView("Uploading...")
                            } else if orgAvatarID != nil {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityHidden(true)
                                    Text("Avatar set")
                                    Spacer()
                                    Button("Remove") {
                                        orgAvatarID = nil
                                        selectedOrgAvatarURL = nil
                                    }
                                    .foregroundStyle(.red)
                                }
                            }
                            Button(orgAvatarID != nil ? "Change Avatar" : "Select Avatar") {
                                showOrgAvatarPicker = true
                            }
                            .withMediaPicker(type: .library, isPresented: $showOrgAvatarPicker, selectedImageURL: $selectedOrgAvatarURL)
                            .onChange(of: selectedOrgAvatarURL) { _, _ in uploadOrgAvatar() }
                        }

                    case 2:
                        Section {
                            Picker("Theme", selection: $theme) {
                                ForEach(OrgProfileTheme.allCases, id: \.self) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                    case 3:
                        Section {
                            Toggle("Enable Notifications", isOn: $notifications)
                        }

                    default:
                        EmptyView()
                    }
                }
                if errorMessage != nil {
                    ErrorBanner(message: errorMessage)
                }

                navigationButtons
            }
            .navigationTitle("Get Started")
        }
    }

    private func uploadAvatar() {
        guard let url = selectedAvatarURL else {
            return
        }

        isUploadingAvatar = true
        errorMessage = nil
        Task {
            do {
                avatarID = try await FileService.shared.uploadImage(url: url)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploadingAvatar = false
        }
    }

    private func uploadOrgAvatar() {
        guard let url = selectedOrgAvatarURL else {
            return
        }

        isUploadingOrgAvatar = true
        errorMessage = nil
        Task {
            do {
                orgAvatarID = try await FileService.shared.uploadImage(url: url)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploadingOrgAvatar = false
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await OrgProfileAPI.upsert(
                    avatar: avatarID,
                    bio: bio.isEmpty ? nil : bio,
                    displayName: displayName,
                    notifications: notifications,
                    theme: theme
                )
                try await OrgAPI.create(name: orgName, slug: orgSlug, avatarId: orgAvatarID)
                isSubmitting = false
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
