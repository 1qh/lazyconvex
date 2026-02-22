import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class BlogDetailViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var blog: Blog?
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(blogID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded: Blog = try await client.query("blog:read", args: ["id": blogID])
            blog = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func deleteBlog(path: Binding<NavigationPath>) async {
        guard let blog else {
            return
        }

        do {
            try await client.mutation("blog:rm", args: ["id": blog._id])
            path.wrappedValue.removeLast()
        } catch {
            errorMessage = error.localizedDescription
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
                    FormView(mode: .edit(blog)) {
                        showEdit = false
                        Task { await viewModel.load(blogID: blogID) }
                    }
                } else {
                    ScrollView {
                        VStack {
                            Text(blog.title)
                            Text(blog.category)
                            Text(blog.published ? "Published" : "Draft")
                            if let authorName = blog.author?.name {
                                Text(authorName)
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
