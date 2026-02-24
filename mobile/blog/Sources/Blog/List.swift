import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ListViewModel: Performing {
    let sub = Sub<PaginatedResult<Blog>>()
    var mutationError: String?
    var searchQuery = ""

    var blogs: [Blog] {
        sub.data?.page ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    var displayedBlogs: [Blog] {
        if searchQuery.isEmpty {
            return blogs
        }
        let q = searchQuery.lowercased()
        var filtered = [Blog]()
        for b in blogs {
            if b.title.lowercased().contains(q) || b.content.lowercased().contains(q) {
                filtered.append(b)
            } else if let tags = b.tags {
                var tagMatch = false
                for t in tags where t.lowercased().contains(q) {
                    tagMatch = true
                    break
                }
                if tagMatch {
                    filtered.append(b)
                }
            }
        }
        return filtered
    }

    func start() {
        sub.bind { onUpdate, onError in
            BlogAPI.subscribeList(
                where: BlogWhere(or: [.init(published: true), .init(own: true)]),
                onUpdate: onUpdate,
                onError: onError
            )
        }
    }

    func stop() {
        sub.cancel()
    }

    func deleteBlog(id: String) {
        perform { try await BlogAPI.rm(id: id) }
    }

    func togglePublished(id: String, published: Bool) {
        perform { try await BlogAPI.update(id: id, published: !published) }
    }
}

internal struct CardView: View {
    let blog: Blog

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let authorName = blog.author?.name {
                    Text(authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(blog.category.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
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
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                    default:
                        EmptyView()
                    }
                }
            }

            Text(blog.title)
                .font(.headline)
                .lineLimit(2)

            Text(blog.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let tags = blog.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            HStack {
                Text(blog.published ? "Published" : "Draft")
                    .font(.caption2)
                    .foregroundStyle(blog.published ? .green : .orange)
                Spacer()
                Text(formatTimestamp(blog.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

internal struct ListView: View {
    @State private var viewModel = ListViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search blogs...", text: $viewModel.searchQuery)
                    .roundedBorderTextField()
                    .noAutocorrection()
            }
            .padding()

            if viewModel.isLoading, viewModel.blogs.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.errorMessage != nil {
                Spacer()
                ErrorBanner(message: viewModel.errorMessage)
                    .padding()
                Spacer()
            } else if viewModel.displayedBlogs.isEmpty {
                Spacer()
                Text("No posts yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(viewModel.displayedBlogs) { blog in
                    NavigationLink(value: blog._id) {
                        CardView(blog: blog)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Blog")
        .navigationDestination(for: String.self) { blogID in
            DetailView(blogID: blogID)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                FormView(mode: .create) {
                    showCreateSheet = false
                }
            }
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
