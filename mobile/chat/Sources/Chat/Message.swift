import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class MessageViewModel {
    let sub = Sub<[Message]>()
    var isAiLoading = false
    var messageText = ""
    var errorMessage: String?

    var messages: [Message] {
        sub.data ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    func start(chatID: String) {
        sub.bind { MessageAPI.subscribeList(chatId: chatID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func sendMessage(chatID: String) {
        let text = messageText.trimmed
        guard !text.isEmpty else {
            return
        }

        messageText = ""
        Task {
            do {
                try await MessageAPI.create(
                    chatId: chatID,
                    parts: [MessagePart(type: .text, text: text)],
                    role: .user
                )
                isAiLoading = true
                try await MobileAiAPI.chat(chatId: chatID)
                isAiLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isAiLoading = false
            }
        }
    }
}

internal struct MessageBubble: View {
    let message: Message

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser {
                Spacer()
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                ForEach(0..<message.parts.count, id: \.self) { idx in
                    let part = message.parts[idx]
                    if part.type == .text, let text = part.text {
                        Text(text)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? Color.blue : Color.secondary.opacity(0.15))
            .foregroundStyle(isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser {
                Spacer()
            }
        }
    }
}

internal struct MessageView: View {
    @State private var viewModel = MessageViewModel()

    let chatID: String

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                        if viewModel.isAiLoading {
                            HStack {
                                ProgressView()
                                    .padding(.horizontal, 4)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }

                if viewModel.errorMessage != nil {
                    ErrorBanner(message: viewModel.errorMessage)
                        .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    TextField("Message...", text: $viewModel.messageText)
                        .roundedBorderTextField()
                        .onSubmit { viewModel.sendMessage(chatID: chatID) }

                    Button(action: { viewModel.sendMessage(chatID: chatID) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("sendButton")
                    .disabled(viewModel.messageText.trimmed.isEmpty || viewModel.isAiLoading)
                }
                .padding()
            }
        }
        .navigationTitle("Chat")
        .task {
            viewModel.start(chatID: chatID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
