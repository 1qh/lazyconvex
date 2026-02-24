import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class PublicListViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var chats = [Chat]()
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load() async {
        await performLoading({ isLoading = $0 }) {
            let result = try await ChatAPI.list(
                client,
                where: ChatWhere(isPublic: true)
            )
            chats = result.page
        }
    }
}

internal struct PublicListView: View {
    @State private var viewModel = PublicListViewModel()
    var path: Binding<NavigationPath>

    var body: some View {
        VStack {
            HStack {
                Button("Back") {
                    path.wrappedValue.removeLast()
                }
                Text("Public Chats")
            }
            .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.chats.isEmpty {
                Text("No public chats")
            } else {
                ScrollView {
                    ForEach(viewModel.chats) { chat in
                        HStack {
                            VStack {
                                Text(chat.title.isEmpty ? "Untitled" : chat.title)
                                Text(formatTimestamp(chat.updatedAt))
                            }
                            NavigationLink("View", value: "pub:\(chat._id)", path: path)
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
