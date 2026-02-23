import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ListViewModel {
    var chats = [Chat]()

    var isLoading = false

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription() {
        stopSubscription()
        isLoading = true
        errorMessage = nil

        subscriptionID = ChatAPI.subscribeList(
            where: ChatWhere(own: true),
            onUpdate: { [weak self] result in
                guard let self else {
                    return
                }

                chats = result.page
                isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
    }

    func stopSubscription() {
        cancelSubscription(&subscriptionID)
    }

    func createChat() {
        Task {
            do {
                try await ChatAPI.create(isPublic: false, title: "New Chat")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteChat(id: String) {
        Task {
            do {
                try await ChatAPI.rm(id: id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

internal struct ListView: View {
    @State private var viewModel = ListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.chats.isEmpty {
                ProgressView()
            } else if viewModel.chats.isEmpty {
                VStack(spacing: 12) {
                    Text("No chats yet")
                        .foregroundStyle(.secondary)
                    Button("Create Chat") {
                        viewModel.createChat()
                    }
                }
            } else {
                List(viewModel.chats) { chat in
                    NavigationLink(value: chat._id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title.isEmpty ? "Untitled" : chat.title)
                                .font(.headline)
                                .lineLimit(1)
                            HStack {
                                if chat.isPublic {
                                    Text("Public")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Capsule())
                                }
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
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.createChat() }) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
            }
        }
        .task {
            viewModel.startSubscription()
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
