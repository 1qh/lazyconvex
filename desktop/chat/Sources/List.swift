import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ListViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var chats = [Chat]()
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var isLoadingMore = false
    @SwiftCrossUI.Published var isPublic = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var continueCursor: String?
    @SwiftCrossUI.Published var isDone = false

    @MainActor
    func load() async {
        await performLoading({ isLoading = $0 }) {
            let result = try await ChatAPI.list(
                client,
                where: ChatWhere(own: true)
            )
            chats = result.page
            continueCursor = result.continueCursor
            isDone = result.isDone
        }
    }

    @MainActor
    func loadMore() async {
        guard !isDone, let cursor = continueCursor else {
            return
        }

        await performLoading({ isLoadingMore = $0 }) {
            let result = try await ChatAPI.list(
                client,
                cursor: cursor,
                where: ChatWhere(own: true)
            )
            for c in result.page {
                chats.append(c)
            }
            continueCursor = result.continueCursor
            isDone = result.isDone
        }
    }

    @MainActor
    func createChat(isPublic: Bool) async {
        await perform {
            try await ChatAPI.create(client, isPublic: isPublic, title: "New Chat")
            await self.load()
        }
    }

    @MainActor
    func deleteChat(id: String) async {
        await perform {
            try await ChatAPI.rm(client, id: id)
            await self.load()
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
                Toggle("Public", isOn: $viewModel.isPublic)
                Button("New Chat") {
                    Task { await viewModel.createChat(isPublic: viewModel.isPublic) }
                }
                Button("Public Chats") {
                    path.wrappedValue.append("publicChats")
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

                    if !viewModel.isDone {
                        Button("Load More") {
                            Task { await viewModel.loadMore() }
                        }
                        .padding(.top, 4)
                    }

                    if viewModel.isLoadingMore {
                        Text("Loading more...")
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}
