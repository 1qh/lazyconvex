import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class MessageViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var messages = [Message]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var isAiLoading = false
    @SwiftCrossUI.Published var messageText = ""
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(chatID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded: [Message] = try await client.query(
                "message:list",
                args: ["chatId": chatID]
            )
            messages = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func sendMessage(chatID: String) async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        messageText = ""
        errorMessage = nil

        do {
            let parts: [[String: Any]] = [["type": "text", "text": text]]
            try await client.mutation("message:create", args: [
                "chatId": chatID,
                "parts": parts,
                "role": "user",
            ])

            isAiLoading = true
            try await client.action("mobile-ai:chat", args: ["chatId": chatID])
            isAiLoading = false
            await load(chatID: chatID)
        } catch {
            errorMessage = error.localizedDescription
            isAiLoading = false
        }
    }
}

internal struct MessageView: View {
    let chatID: String
    var path: Binding<NavigationPath>
    @State private var viewModel = MessageViewModel()

    var body: some View {
        VStack {
            Button("Back") {
                path.wrappedValue.removeLast()
            }
            .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading messages...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.messages.isEmpty {
                Text("No messages yet. Start a conversation!")
            } else {
                ScrollView {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.role == "user" {
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
                            if message.role != "user" {
                                Text("")
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }

                if viewModel.isAiLoading {
                    Text("AI is thinking...")
                }
            }

            HStack {
                TextField("Message...", text: $viewModel.messageText)
                Button("Send") {
                    Task { await viewModel.sendMessage(chatID: chatID) }
                }
            }
            .padding(.top, 4)
        }
        .task {
            await viewModel.load(chatID: chatID)
        }
    }
}
