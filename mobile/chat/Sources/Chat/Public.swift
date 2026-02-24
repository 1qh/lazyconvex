import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class PublicViewModel {
    let sub = Sub<[Message]>()

    var messages: [Message] {
        sub.data ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error
    }

    func start(chatID: String) {
        sub.bind { MessageAPI.subscribePubList(chatId: chatID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }
}

@MainActor
@Observable
internal final class PublicListViewModel {
    let sub = Sub<PaginatedResult<Chat>>()

    var chats: [Chat] {
        sub.data?.page ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error
    }

    func start() {
        sub.bind { ChatAPI.subscribePublicList(onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }
}

internal struct PublicListView: View {
    @State private var viewModel = PublicListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.chats.isEmpty {
                ProgressView()
            } else if viewModel.chats.isEmpty {
                Text("No public chats yet")
                    .foregroundStyle(.secondary)
            } else {
                List(viewModel.chats) { chat in
                    NavigationLink(value: PublicChatRoute(id: chat._id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title.isEmpty ? "Untitled" : chat.title)
                                .font(.headline)
                                .lineLimit(1)
                            HStack {
                                Text(chat.author?.name ?? "Anonymous")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatTimestamp(chat.updatedAt, dateStyle: .short, timeStyle: .short))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Public Chats")
        .overlay(alignment: .bottom) {
            if viewModel.errorMessage != nil {
                ErrorBanner(message: viewModel.errorMessage)
                    .padding(.horizontal)
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

internal struct PublicView: View {
    let chatID: String

    @State private var viewModel = PublicViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.messages.isEmpty {
                Spacer()
                Text("No messages yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }

            if viewModel.errorMessage != nil {
                ErrorBanner(message: viewModel.errorMessage)
                    .padding(.horizontal)
            }

            HStack {
                Text("Read-only public chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            }
        }
        .navigationTitle("Public Chat")
        .task {
            viewModel.start(chatID: chatID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
