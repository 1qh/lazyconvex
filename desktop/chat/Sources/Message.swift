import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class MessageViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var messages = [Message]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var isAiLoading = false
    @SwiftCrossUI.Published var messageText = ""
    @SwiftCrossUI.Published var isPublic = false
    @SwiftCrossUI.Published var errorMessage: String?
    private var subscription: ConvexSubscription<[Message]>?

    @MainActor
    func subscribe(chatID: String) {
        isLoading = true
        subscription = ConvexSubscription<[Message]>(
            deploymentURL: convexBaseURL,
            name: MessageAPI.list,
            args: ["chatId": chatID],
            authToken: auth.token,
            onChange: { [weak self] newMessages in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.messages = newMessages
                    self.isLoading = false
                }
            },
            onError: { [weak self] subscriptionError in
                Task { @MainActor in
                    self?.errorMessage = subscriptionError.localizedDescription
                    self?.isLoading = false
                }
            }
        )
        subscription?.start()
    }

    func unsubscribe() {
        subscription?.stop()
        subscription = nil
    }

    @MainActor
    func loadChat(chatID: String) async {
        await perform {
            let chat = try await ChatAPI.read(client, id: chatID)
            isPublic = chat.isPublic
        }
    }

    @MainActor
    func togglePublic(chatID: String) async {
        let newValue = !isPublic
        isPublic = newValue
        await perform {
            try await ChatAPI.update(client, id: chatID, isPublic: newValue)
        }
    }

    @MainActor
    func sendMessage(chatID: String) async {
        let text = messageText.trimmed
        guard !text.isEmpty else {
            return
        }

        messageText = ""
        errorMessage = nil
        await perform {
            let parts = [MessagePart(type: .text, text: text, image: nil, file: nil, name: nil)]
            try await MessageAPI.create(client, chatId: chatID, parts: parts, role: .user)

            isAiLoading = true
            try await MobileAiAPI.chat(client, chatId: chatID)
            isAiLoading = false
        }
        isAiLoading = false
    }
}

internal struct MessageView: View {
    let chatID: String
    var path: Binding<NavigationPath>
    @State private var viewModel = MessageViewModel()

    var body: some View {
        VStack {
            HStack {
                Button("Back") {
                    path.wrappedValue.removeLast()
                }
                Toggle("Public", isOn: Binding(
                    get: { viewModel.isPublic },
                    set: { _ in Task { await viewModel.togglePublic(chatID: chatID) } }
                ))
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
        .onAppear {
            viewModel.subscribe(chatID: chatID)
            Task { await viewModel.loadChat(chatID: chatID) }
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
    }
}
