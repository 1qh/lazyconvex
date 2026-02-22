import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ListViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var blogs = [Blog]()
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var searchQuery = ""
    @SwiftCrossUI.Published var errorMessage: String?

    var displayedBlogs: [Blog] {
        if searchQuery.isEmpty {
            return blogs
        }
        let q = searchQuery.lowercased()
        var filtered = [Blog]()
        for b in blogs {
            if b.title.lowercased().contains(q) || b.content.lowercased().contains(q) {
                filtered.append(b)
            }
        }
        return filtered
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: PaginatedResult<Blog> = try await client.query(
                "blog:list",
                args: [
                    "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
                    "where": ["or": [["published": true], ["own": true]] as [[String: Any]]] as [String: Any],
                ]
            )
            blogs = result.page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func deleteBlog(id: String) async {
        do {
            try await client.mutation("blog:rm", args: ["id": id])
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct ListView: View {
    @State private var viewModel = ListViewModel()
    var path: Binding<NavigationPath>

    var body: some View {
        VStack {
            TextField("Search blogs...", text: $viewModel.searchQuery)
                .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.displayedBlogs.isEmpty {
                Text("No posts yet")
            } else {
                ScrollView {
                    ForEach(viewModel.displayedBlogs) { blog in
                        HStack {
                            VStack {
                                Text(blog.title)
                                Text(blog.category)
                                Text(blog.published ? "Published" : "Draft")
                                Text(formatTimestamp(blog.updatedAt))
                            }
                            NavigationLink("View", value: blog._id, path: path)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}
