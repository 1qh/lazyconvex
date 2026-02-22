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

        let args: [String: Any] = [
            "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
            "where": ["own": true] as [String: Any],
        ]

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "chat:list",
            args: args,
            type: PaginatedResult<Chat>.self,
            onUpdate: { [weak self] (result: PaginatedResult<Chat>) in
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
        #else
        subscriptionID = ConvexService.shared.subscribePaginatedChats(
            to: "chat:list",
            args: args,
            onUpdate: { result in
                self.chats = Array(result.page)
                self.isLoading = false
            },
            onError: { error in
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        )
        #endif
    }

    func stopSubscription() {
        cancelSubscription(&subscriptionID)
    }

    func createChat() {
        Task {
            do {
                try await ConvexService.shared.mutate("chat:create", args: [
                    "title": "New Chat",
                    "isPublic": false,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteChat(id: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("chat:rm", args: ["id": id])
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
