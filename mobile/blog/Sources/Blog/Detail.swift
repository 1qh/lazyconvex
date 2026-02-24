import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class DetailViewModel: Performing {
    let sub = Sub<Blog>()
    var mutationError: String?

    var blog: Blog? {
        sub.data
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start(blogID: String) {
        sub.bind { BlogAPI.subscribeRead(id: blogID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func deleteBlog() {
        guard let blog else {
            return
        }

        perform { try await BlogAPI.rm(id: blog._id) }
    }
}

internal struct DetailView: View {
    let blogID: String

    @State private var viewModel = DetailViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.errorMessage != nil {
                ErrorBanner(message: viewModel.errorMessage)
            } else if let blog = viewModel.blog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if let authorName = blog.author?.name {
                                Text(authorName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(blog.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let coverImageUrl = blog.coverImageUrl, let url = URL(string: coverImageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .aspectRatio(1.78, contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                default:
                                    EmptyView()
                                }
                            }
                        }

                        Text(blog.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(blog.content)
                            .font(.body)

                        if let tags = blog.tags, !tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let attachmentsUrls = blog.attachmentsUrls {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(attachmentsUrls, id: \.self) { urlString in
                                    if let url = URL(string: urlString) {
                                        Link(urlString, destination: url)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        HStack {
                            Text(blog.published ? "Published" : "Draft")
                                .font(.caption)
                                .foregroundStyle(blog.published ? .green : .orange)
                            Spacer()
                            Text(formatTimestamp(blog.updatedAt, timeStyle: .short))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: { showEditSheet = true }) {
                            Image(systemName: "pencil")
                                .accessibilityHidden(true)
                        }
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteBlog()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { _ = () }
                }
                .sheet(isPresented: $showEditSheet) {
                    NavigationStack {
                        FormView(mode: .edit(blog)) {
                            showEditSheet = false
                        }
                    }
                }
            } else {
                Text("Blog not found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Detail")
        .task {
            viewModel.start(blogID: blogID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
