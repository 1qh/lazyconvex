import ConvexShared
import Foundation
import Observation
import SkipKit
import SwiftUI

internal enum FormMode {
    case create
    case edit(Blog)
}

@MainActor
@Observable
internal final class FormViewModel: Performing {
    var title = ""
    var content = ""
    var category = BlogCategory.tech
    var published = false
    var tags = [String]()
    var newTag = ""
    var isSaving = false
    var isUploadingCover = false
    var coverImageID: String?
    var selectedCoverURL: URL?

    let mode: FormMode
    private var lastSavedTitle = ""
    private var lastSavedContent = ""
    var errorMessage: String?
    var mutationError: String? {
        get { errorMessage }
        set { errorMessage = newValue }
    }

    var autoSaveMessage: String?

    var isValid: Bool {
        !title.trimmed.isEmpty &&
            content.trimmed.count >= 3
    }

    private var autoSaveTask: Task<Void, Never>?

    init(mode: FormMode) {
        self.mode = mode
        if case let .edit(blog) = mode {
            title = blog.title
            content = blog.content
            category = blog.category
            published = blog.published
            tags = blog.tags ?? []
            coverImageID = blog.coverImage
            lastSavedTitle = blog.title
            lastSavedContent = blog.content
        }
    }

    func uploadCoverImage() {
        guard let url = selectedCoverURL else {
            return
        }

        performLoading({ self.isUploadingCover = $0 }) {
            self.coverImageID = try await FileService.shared.uploadImage(url: url)
        }
    }

    func removeCoverImage() {
        coverImageID = nil
        selectedCoverURL = nil
    }

    func addTag() {
        let trimmed = newTag.trimmed.lowercased()
        if !trimmed.isEmpty, !tags.contains(trimmed), tags.count < 5 {
            tags.append(trimmed)
        }
        newTag = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save(onDone: @escaping () -> Void) {
        guard isValid else {
            return
        }

        performLoading({ self.isSaving = $0 }) {
            switch self.mode {
            case .create:
                try await BlogAPI.create(
                    category: self.category,
                    content: self.content.trimmed,
                    coverImage: self.coverImageID,
                    published: self.published,
                    tags: self.tags.isEmpty ? nil : self.tags,
                    title: self.title.trimmed
                )

            case let .edit(blog):
                try await BlogAPI.update(
                    id: blog._id,
                    category: self.category,
                    content: self.content.trimmed,
                    coverImage: self.coverImageID,
                    published: self.published,
                    tags: self.tags.isEmpty ? nil : self.tags,
                    title: self.title.trimmed,
                    expectedUpdatedAt: blog.updatedAt
                )
            }
            onDone()
        }
    }

    func scheduleAutoSave(blog: Blog) {
        autoSaveTask?.cancel()
        guard title != lastSavedTitle || content != lastSavedContent else {
            return
        }

        autoSaveMessage = "Saving..."
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            do {
                try await BlogAPI.update(
                    id: blog._id,
                    category: category,
                    content: content.trimmed,
                    published: published,
                    tags: tags.isEmpty ? nil : tags,
                    title: title.trimmed
                )
                lastSavedTitle = title
                lastSavedContent = content
                autoSaveMessage = "Saved"
            } catch {
                autoSaveMessage = "Save failed"
            }
        }
    }
}

internal struct FormView: View {
    let onDone: () -> Void
    @State private var viewModel: FormViewModel
    @State private var showCoverPicker = false

    @Environment(\.dismiss)
    private var dismiss

    private var isEditMode: Bool {
        if case .edit = viewModel.mode {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("My awesome post", text: $viewModel.title)
                    .onChange(of: viewModel.title) { _, _ in handleAutoSave() }
            }

            Section("Category") {
                Picker("Category", selection: $viewModel.category) {
                    ForEach(BlogCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Content") {
                TextEditor(text: $viewModel.content)
                    .frame(minHeight: 150)
                    .onChange(of: viewModel.content) { _, _ in handleAutoSave() }
            }

            Section("Cover Image") {
                if viewModel.isUploadingCover {
                    ProgressView("Uploading...")
                } else if viewModel.coverImageID != nil {
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Cover image set")
                        Spacer()
                        Button("Remove") { viewModel.removeCoverImage() }
                            .foregroundStyle(.red)
                    }
                }
                Button(viewModel.coverImageID != nil ? "Change Cover" : "Select Cover Image") {
                    showCoverPicker = true
                }
                .withMediaPicker(type: .library, isPresented: $showCoverPicker, selectedImageURL: $viewModel.selectedCoverURL)
                .onChange(of: viewModel.selectedCoverURL) { _, _ in viewModel.uploadCoverImage() }
            }

            Section("Tags") {
                HStack {
                    TextField("Add tag...", text: $viewModel.newTag)
                    Button("Add") { viewModel.addTag() }
                        .disabled(viewModel.newTag.trimmed.isEmpty)
                }
                if !viewModel.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack(spacing: 2) {
                                Text("#\(tag)")
                                    .font(.caption)
                                Button(action: { viewModel.removeTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Section {
                Toggle("Published", isOn: $viewModel.published)
                    .accessibilityIdentifier("publishToggle")
            }

            if viewModel.errorMessage != nil {
                Section {
                    ErrorBanner(message: viewModel.errorMessage)
                }
            }

            if let autoSaveMessage = viewModel.autoSaveMessage {
                Section {
                    Text(autoSaveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(isEditMode ? "Edit Post" : "New Post")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                    onDone()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditMode ? "Save" : "Create") {
                    viewModel.save(onDone: onDone)
                }
                .disabled(!viewModel.isValid || viewModel.isSaving || viewModel.isUploadingCover)
            }
        }
    }

    init(mode: FormMode, onDone: @escaping () -> Void) {
        _viewModel = State(initialValue: FormViewModel(mode: mode))
        self.onDone = onDone
    }

    private func handleAutoSave() {
        if case let .edit(blog) = viewModel.mode {
            viewModel.scheduleAutoSave(blog: blog)
        }
    }
}
