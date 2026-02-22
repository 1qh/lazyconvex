import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class DetailViewModel {
    var isLoading = true

    var blog: Blog?

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription(blogID: String) {
        stopSubscription()
        isLoading = true
        errorMessage = nil

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "blog:read",
            args: ["id": blogID],
            type: Blog.self,
            onUpdate: { [weak self] (result: Blog) in
                self?.blog = result
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribeBlog(
            to: "blog:read",
            args: ["id": blogID],
            onUpdate: { result in
                self.blog = result
                self.isLoading = false
            },
            onError: { error in
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        )
        #endif
    }

    func stopSubscription() {
        cancelSubscription(&subscriptionID)
    }

    func deleteBlog() {
        guard let blog else {
            return
        }

        Task {
            do {
                try await ConvexService.shared.mutate("blog:rm", args: ["id": blog._id])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
                            Text(blog.category)
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
            viewModel.startSubscription(blogID: blogID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
