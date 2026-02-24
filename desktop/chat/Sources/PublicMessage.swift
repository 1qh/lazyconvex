import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class PublicMessageViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var chat: Chat?
    @SwiftCrossUI.Published var messages = [Message]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(chatID: String) async {
        await performLoading({ isLoading = $0 }) {
            chat = try await ChatAPI.pubRead(client, id: chatID)
            messages = try await MessageAPI.pubList(client, chatId: chatID)
        }
    }
}

internal struct PublicMessageView: View {
    let chatID: String
    var path: Binding<NavigationPath>
    @State private var viewModel = PublicMessageViewModel()

    var body: some View {
        VStack {
            HStack {
                Button("Back") {
                    path.wrappedValue.removeLast()
                }
                if let chat = viewModel.chat {
                    Text(chat.title.isEmpty ? "Untitled" : chat.title)
                }
            }
            .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading messages...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.messages.isEmpty {
                Text("No messages yet")
            } else {
                ScrollView {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.role == .user {
                                Text("")
                            }
                            VStack {
                                ForEach(0..<message.parts.count, id: \.self) { idx in
                                    let part = message.parts[idx]
                                    if part.type == .text, let text = part.text {
                                        Text(text)
                                    }
                                }
                            }
                            .padding(8)
                            if message.role != .user {
                                Text("")
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await viewModel.load(chatID: chatID)
        }
    }
}
