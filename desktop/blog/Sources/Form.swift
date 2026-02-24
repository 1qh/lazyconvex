#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif
import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal enum FormMode {
    case create
    case edit(Blog)
}

internal final class FormViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var title = ""
    @SwiftCrossUI.Published var content = ""
    @SwiftCrossUI.Published var category = BlogCategory.tech
    @SwiftCrossUI.Published var published = false
    @SwiftCrossUI.Published var isSaving = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var tags = [String]()
    @SwiftCrossUI.Published var newTag = ""
    @SwiftCrossUI.Published var coverImageID: String?
    @SwiftCrossUI.Published var attachmentIDs = [String]()
    @SwiftCrossUI.Published var isUploadingCover = false
    @SwiftCrossUI.Published var isUploadingAttachments = false

    let mode: FormMode

    var isValid: Bool {
        !title.trimmed.isEmpty &&
            content.trimmed.count >= 3
    }

    init(mode: FormMode) {
        self.mode = mode
        if case let .edit(blog) = mode {
            title = blog.title
            content = blog.content
            category = blog.category
            published = blog.published
            tags = blog.tags ?? []
            coverImageID = blog.coverImage
            attachmentIDs = blog.attachments ?? []
        }
    }

    func selectCoverImage() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in // swiftlint:disable:this unhandled_throwing_task
                    await self.performLoading({ self.isUploadingCover = $0 }) {
                        self.coverImageID = try await fileClient.uploadImage(url: url)
                    }
                }
            }
        }
        #endif
    }

    func selectAttachments() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            if response == .OK {
                let urls = panel.urls
                Task { @MainActor in // swiftlint:disable:this unhandled_throwing_task
                    await self.performLoading({ self.isUploadingAttachments = $0 }) {
                        let ids = try await fileClient.uploadFiles(urls: urls)
                        for id in ids {
                            self.attachmentIDs.append(id)
                        }
                    }
                }
            }
        }
        #endif
    }

    func addTag() {
        let tag = newTag.trimmed.lowercased()
        guard !tag.isEmpty, tags.count < 5, !tags.contains(tag) else {
            return
        }

        tags.append(tag)
        newTag = ""
    }

    func removeTag(_ tag: String) {
        var updated = [String]()
        for t in tags where t != tag {
            updated.append(t)
        }
        tags = updated
    }

    @MainActor
    func save(onDone: () -> Void) async {
        guard isValid else {
            return
        }

        await performLoading({ isSaving = $0 }) {
            switch mode {
            case .create:
                try await BlogAPI.create(
                    client,
                    attachments: attachmentIDs.isEmpty ? nil : attachmentIDs,
                    category: category,
                    content: content.trimmed,
                    coverImage: coverImageID,
                    published: published,
                    tags: tags.isEmpty ? nil : tags,
                    title: title.trimmed
                )

            case let .edit(blog):
                try await BlogAPI.update(
                    client,
                    id: blog._id,
                    attachments: attachmentIDs.isEmpty ? nil : attachmentIDs,
                    category: category,
                    content: content.trimmed,
                    coverImage: coverImageID,
                    published: published,
                    tags: tags.isEmpty ? nil : tags,
                    title: title.trimmed,
                    expectedUpdatedAt: blog.updatedAt
                )
            }
            onDone()
        }
    }
}

internal struct FormView: View {
    let onDone: () -> Void
    @State private var viewModel: FormViewModel

    var body: some View {
        VStack {
            Text(isEditMode ? "Edit Post" : "New Post")
                .padding(.bottom, 8)

            TextField("Title", text: $viewModel.title)
            TextField("Content", text: $viewModel.content)
            HStack {
                ForEach(0..<BlogCategory.allCases.count, id: \.self) { idx in
                    let cat = BlogCategory.allCases[idx]
                    Button(cat.displayName) {
                        viewModel.category = cat
                    }
                }
            }

            Toggle("Published", isOn: $viewModel.published)

            HStack {
                Button(viewModel.coverImageID == nil ? "Add Cover Image" : "Change Cover Image") {
                    viewModel.selectCoverImage()
                }
                if viewModel.coverImageID != nil {
                    Text("Cover set")
                    Button("Remove") {
                        viewModel.coverImageID = nil
                    }
                }
            }
            if viewModel.isUploadingCover {
                Text("Uploading cover...")
            }

            VStack {
                HStack {
                    TextField("Add tag", text: $viewModel.newTag)
                    Button("Add") {
                        viewModel.addTag()
                    }
                }
                if !viewModel.tags.isEmpty {
                    HStack {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack {
                                Text("#\(tag)")
                                Button("x") {
                                    viewModel.removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Add Attachments") {
                    viewModel.selectAttachments()
                }
                if !viewModel.attachmentIDs.isEmpty {
                    Text("\(viewModel.attachmentIDs.count) file(s)")
                    Button("Clear") {
                        viewModel.attachmentIDs = []
                    }
                }
            }
            if viewModel.isUploadingAttachments {
                Text("Uploading attachments...")
            }

            if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    onDone()
                }
                Button(isEditMode ? "Save" : "Create") {
                    Task { await viewModel.save(onDone: onDone) }
                }
            }
            .padding(.top, 4)

            if viewModel.isSaving {
                Text("Saving...")
            }
        }
    }

    // swiftlint:disable:next type_contents_order
    init(mode: FormMode, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _viewModel = State(wrappedValue: FormViewModel(mode: mode))
    }

    private var isEditMode: Bool {
        if case .edit = viewModel.mode {
            return true
        }
        return false
    }
}
