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

    @State private var theme = "system"

    @State private var notifications = true

    @State private var isSubmitting = false

    @State private var errorMessage: String?

    @State private var showAvatarPicker = false

    @State private var selectedAvatarURL: URL?

    @State private var avatarID: String?

    @State private var isUploadingAvatar = false

    private let steps = ["Profile", "Organization", "Appearance", "Preferences"]

    private var isStepValid: Bool {
        switch currentStep {
        case 0:
            !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        case 1:
            !orgName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !orgSlug.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty

        default:
            true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { idx in
                        Circle()
                            .fill(idx <= currentStep ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top)

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

                    case 2:
                        Section {
                            Picker("Theme", selection: $theme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
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
                        .disabled(!isStepValid || isUploadingAvatar)
                    } else {
                        Button("Complete") {
                            submit()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSubmitting || !isStepValid || isUploadingAvatar)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
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

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                var profileArgs: [String: Any] = [
                    "displayName": displayName,
                    "bio": bio,
                    "theme": theme,
                    "notifications": notifications,
                ]
                if let aid = avatarID {
                    profileArgs["avatar"] = aid
                }
                try await ConvexService.shared.mutate("orgProfile:upsert", args: profileArgs)
                try await ConvexService.shared.mutate("org:create", args: [
                    "data": [
                        "name": orgName,
                        "slug": orgSlug,
                    ] as [String: Any],
                ])
                isSubmitting = false
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
