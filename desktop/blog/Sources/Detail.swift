#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif
import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class BlogDetailViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var blog: Blog?
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var coverImageURL: URL?

    @MainActor
    func load(blogID: String) async {
        await performLoading({ isLoading = $0 }) {
            blog = try await BlogAPI.read(client, id: blogID)
        }
        if let remoteURL = blog?.coverImageUrl {
            Task {
                coverImageURL = await ImageCache.shared.download(remoteURL)
            }
        }
    }

    @MainActor
    func deleteBlog(path: Binding<NavigationPath>) async {
        guard let blog else {
            return
        }

        await perform {
            try await BlogAPI.rm(client, id: blog._id)
            path.wrappedValue.removeLast()
        }
    }
}

internal struct DetailView: View {
    let blogID: String
    var path: Binding<NavigationPath>
    @State private var viewModel = BlogDetailViewModel()
    @State private var showEdit = false

    var body: some View {
        VStack {
            Button("Back") {
                path.wrappedValue.removeLast()
            }
            .padding(.bottom, 8)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if let blog = viewModel.blog {
                if showEdit {
                    EditFormView(blog: blog) {
                        showEdit = false
                        Task { await viewModel.load(blogID: blogID) }
                    }
                } else {
                    ScrollView {
                        VStack {
                            Text(blog.title)
                            Text(blog.category.displayName)
                            Text(blog.published ? "Published" : "Draft")
                            if let authorName = blog.author?.name {
                                Text(authorName)
                            }
                            if let coverURL = viewModel.coverImageURL {
                                // swiftlint:disable:next accessibility_label_for_image
                                Image(coverURL)
                                    .resizable()
                                    .frame(width: 200, height: 150)
                            }
                            Text(blog.content)
                                .padding(.top, 4)
                            if let tags = blog.tags, !tags.isEmpty {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                    }
                                }
                            }
                            if let urls = blog.attachmentsUrls, !urls.isEmpty {
                                VStack {
                                    Text("Attachments:")
                                    ForEach(0..<urls.count, id: \.self) { idx in
                                        let filename = URL(string: urls[idx])?
                                            .lastPathComponent ?? "file"
                                        VStack {
                                            Text("[Attachment \(idx + 1): \(filename)]")
                                            Text(urls[idx])
                                        }
                                    }
                                }
                            }
                            Text(formatTimestamp(blog.updatedAt))

                            HStack {
                                Button("Edit") {
                                    showEdit = true
                                }
                                Button("Delete") {
                                    Task { await viewModel.deleteBlog(path: path) }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            } else {
                Text("Blog not found")
            }
        }
        .task {
            await viewModel.load(blogID: blogID)
        }
    }
}

internal struct EditFormView: View {
    let blog: Blog
    let onSave: () -> Void
    @State private var title = ""
    @State private var content = ""
    @State private var category = BlogCategory.tech
    @State private var published = false
    @State private var tags = [String]()
    @State private var newTag = ""
    @State private var coverImageID: String?
    @State private var attachmentIDs = [String]()
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var saveStatus = ""
    @State private var errorMessage: String?
    @State private var isUploadingCover = false
    @State private var isUploadingAttachments = false

    var body: some View {
        VStack {
            Text("Edit Post")
                .padding(.bottom, 8)

            TextField("Title", text: $title)
                .onChange(of: title) { scheduleSave() }
            TextField("Content", text: $content)
                .onChange(of: content) { scheduleSave() }
            HStack {
                ForEach(0..<BlogCategory.allCases.count, id: \.self) { idx in
                    let cat = BlogCategory.allCases[idx]
                    Button(cat.displayName) {
                        category = cat
                        scheduleSave()
                    }
                }
            }

            Toggle("Published", isOn: $published)
                .onChange(of: published) { scheduleSave() }

            HStack {
                Button(coverImageID == nil ? "Add Cover Image" : "Change Cover Image") {
                    selectCoverImage()
                }
                if coverImageID != nil {
                    Text("Cover set")
                    Button("Remove") {
                        coverImageID = nil
                        scheduleSave()
                    }
                }
            }
            if isUploadingCover {
                Text("Uploading cover...")
            }

            VStack {
                HStack {
                    TextField("Add tag", text: $newTag)
                    Button("Add") {
                        addTag()
                    }
                }
                if !tags.isEmpty {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text("#\(tag)")
                                Button("x") {
                                    removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Add Attachments") {
                    selectAttachments()
                }
                if !attachmentIDs.isEmpty {
                    Text("\(attachmentIDs.count) file(s)")
                    Button("Clear") {
                        attachmentIDs = []
                        scheduleSave()
                    }
                }
            }
            if isUploadingAttachments {
                Text("Uploading attachments...")
            }

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .foregroundColor(saveStatus == "Error saving" ? .red : .gray)
            }

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    onSave()
                }
                Button("Done") {
                    autoSaveTask?.cancel()
                    onSave()
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            title = blog.title
            content = blog.content
            category = blog.category
            published = blog.published
            tags = blog.tags ?? []
            coverImageID = blog.coverImage
            attachmentIDs = blog.attachments ?? []
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
    }

    private func scheduleSave() {
        autoSaveTask?.cancel()
        saveStatus = "Editing..."
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                await save()
            }
        }
    }

    @MainActor
    private func save() async {
        saveStatus = "Saving..."
        do {
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
            saveStatus = "Saved"
        } catch {
            saveStatus = "Error saving"
            errorMessage = error.localizedDescription
        }
    }

    private func selectCoverImage() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in // swiftlint:disable:this unhandled_throwing_task
                    await performLoading({ isUploadingCover = $0 }) {
                        coverImageID = try await fileClient.uploadImage(url: url)
                        scheduleSave()
                    }
                }
            }
        }
        #endif
    }

    private func selectAttachments() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            if response == .OK {
                let urls = panel.urls
                Task { @MainActor in // swiftlint:disable:this unhandled_throwing_task
                    await performLoading({ isUploadingAttachments = $0 }) {
                        let ids = try await fileClient.uploadFiles(urls: urls)
                        for id in ids {
                            attachmentIDs.append(id)
                        }
                        scheduleSave()
                    }
                }
            }
        }
        #endif
    }

    private func addTag() {
        let tag = newTag.trimmed.lowercased()
        guard !tag.isEmpty, tags.count < 5, !tags.contains(tag) else {
            return
        }

        tags.append(tag)
        newTag = ""
        scheduleSave()
    }

    private func removeTag(_ tag: String) {
        var updated = [String]()
        for t in tags where t != tag {
            updated.append(t)
        }
        tags = updated
        scheduleSave()
    }

    private func performLoading(_ setter: (Bool) -> Void, _ block: () async throws -> Void) async {
        setter(true)
        do {
            try await block()
        } catch {
            errorMessage = error.localizedDescription
        }
        setter(false)
    }
}
