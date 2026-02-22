import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ListViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var chats = [Chat]()
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: PaginatedResult<Chat> = try await client.query(
                "chat:list",
                args: [
                    "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
                    "where": ["own": true] as [String: Any],
                ]
            )
            chats = result.page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createChat() async {
        do {
            try await client.mutation("chat:create", args: [
                "title": "New Chat",
                "isPublic": false,
            ])
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteChat(id: String) async {
        do {
            try await client.mutation("chat:rm", args: ["id": id])
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
            HStack {
                Text("Chats")
                Button("New Chat") {
                    Task { await viewModel.createChat() }
                }
            }
            .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.chats.isEmpty {
                Text("No chats yet")
            } else {
                ScrollView {
                    ForEach(viewModel.chats) { chat in
                        HStack {
                            VStack {
                                Text(chat.title.isEmpty ? "Untitled" : chat.title)
                                HStack {
                                    Text(chat.isPublic ? "Public" : "Private")
                                    Text(formatTimestamp(chat.updatedAt))
                                }
                            }
                            Button("Delete") {
                                Task { await viewModel.deleteChat(id: chat._id) }
                            }
                            NavigationLink("Open", value: chat._id, path: path)
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
