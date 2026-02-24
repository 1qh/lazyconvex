import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ListViewModel: Performing {
    var mutationError: String?
    var searchQuery = ""
    private(set) var allBlogs = [Blog]()
    private(set) var continueCursor: String?
    private(set) var isDone = true
    private(set) var isLoading = true
    private(set) var isLoadingMore = false
    private var subID: String?
    private var loadMoreSubID: String?
    private let blogWhere = BlogWhere(or: [.init(published: true), .init(own: true)])
    var blogs: [Blog] {
        allBlogs
    }

    var errorMessage: String? {
        mutationError
    }

    var displayedBlogs: [Blog] {
        if searchQuery.isEmpty {
            return allBlogs
        }
        let q = searchQuery.lowercased()
        var filtered = [Blog]()
        for b in allBlogs {
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
        isLoading = true
        subID = BlogAPI.subscribeList(
            where: blogWhere,
            onUpdate: { [weak self] result in
                guard let self else {
                    return
                }

                allBlogs = result.page
                continueCursor = result.continueCursor
                isDone = result.isDone
                isLoading = false
                cancelLoadMoreSub()
            },
            onError: { [weak self] err in
                self?.mutationError = err.localizedDescription
                self?.isLoading = false
            }
        )
    }

    func stop() {
        cancelSubscription(&subID)
        cancelLoadMoreSub()
    }

    private func cancelLoadMoreSub() {
        if let id = loadMoreSubID {
            ConvexService.shared.cancelSubscription(id)
            loadMoreSubID = nil
        }
        isLoadingMore = false
    }

    func loadMore() {
        guard !isDone, let cursor = continueCursor, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        let args = BlogAPI.listArgs(cursor: cursor, where: blogWhere)
        #if !SKIP
        loadMoreSubID = ConvexService.shared.subscribe(
            to: BlogAPI.list,
            args: args,
            type: PaginatedResult<Blog>.self,
            onUpdate: { [weak self] result in
                guard let self, loadMoreSubID != nil else {
                    return
                }

                for b in result.page {
                    allBlogs.append(b)
                }
                continueCursor = result.continueCursor
                isDone = result.isDone
                cancelLoadMoreSub()
            },
            onError: { [weak self] err in
                self?.mutationError = err.localizedDescription
                self?.isLoadingMore = false
            }
        )
        #else
        loadMoreSubID = ConvexService.shared.subscribePaginatedBlogs(
            to: BlogAPI.list,
            args: args,
            onUpdate: { [weak self] result in
                guard let self, loadMoreSubID != nil else {
                    return
                }

                for b in result.page {
                    allBlogs.append(b)
                }
                continueCursor = result.continueCursor
                isDone = result.isDone
                cancelLoadMoreSub()
            },
            onError: { [weak self] err in
                self?.mutationError = err.localizedDescription
                self?.isLoadingMore = false
            }
        )
        #endif
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
                List {
                    ForEach(viewModel.displayedBlogs) { blog in
                        NavigationLink(value: blog._id) {
                            CardView(blog: blog)
                        }
                    }

                    if !viewModel.isDone {
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Button("Load More") {
                                viewModel.loadMore()
                            }
                            .frame(maxWidth: .infinity)
                        }
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
