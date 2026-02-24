import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ListViewModel: Performing {
    var mutationError: String?
    private(set) var isLoading = true
    private(set) var isLoadingMore = false

    private var currentResult: PaginatedResult<Chat>?
    private var subscriptionID: String?
    private var numItems = 50
    private var subError: String?

    var chats: [Chat] {
        currentResult?.page ?? []
    }

    var isDone: Bool {
        currentResult?.isDone ?? true
    }

    var errorMessage: String? {
        subError ?? mutationError
    }

    func start() {
        stop()
        numItems = 50
        isLoading = true
        currentResult = nil
        refreshSubscription()
    }

    func stop() {
        cancelSubscription(&subscriptionID)
    }

    func loadMore() {
        guard !isDone, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        numItems += 50
        refreshSubscription()
    }

    func createChat(isPublic: Bool) {
        perform { try await ChatAPI.create(isPublic: isPublic, title: "New Chat") }
    }

    func deleteChat(id: String) {
        perform { try await ChatAPI.rm(id: id) }
    }

    private func refreshSubscription() {
        cancelSubscription(&subscriptionID)
        let args = ChatAPI.listArgs(numItems: numItems, where: ChatWhere(own: true))
        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: ChatAPI.list,
            args: args,
            type: PaginatedResult<Chat>.self,
            onUpdate: { [weak self] result in
                self?.currentResult = result
                self?.isLoading = false
                self?.isLoadingMore = false
            },
            onError: { [weak self] err in
                self?.subError = err.localizedDescription
                self?.isLoading = false
                self?.isLoadingMore = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribePaginatedChats(
            to: ChatAPI.list,
            args: args,
            onUpdate: { [weak self] result in
                self?.currentResult = result
                self?.isLoading = false
                self?.isLoadingMore = false
            },
            onError: { [weak self] err in
                self?.subError = err.localizedDescription
                self?.isLoading = false
                self?.isLoadingMore = false
            }
        )
        #endif
    }
}

internal struct ListView: View {
    @State private var isPublic = false
    @State private var showDeleteConfirm = false
    @State private var chatToDelete: String?
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
                        viewModel.createChat(isPublic: isPublic)
                    }
                }
            } else {
                List {
                    ForEach(viewModel.chats) { chat in
                        HStack {
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
                            Button(action: {
                                chatToDelete = chat._id
                                showDeleteConfirm = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .accessibilityHidden(true)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("deleteChat")
                        }
                    }
                    if !viewModel.isDone {
                        Button(action: { viewModel.loadMore() }) {
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Load More")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .accessibilityIdentifier("loadMore")
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.createChat(isPublic: isPublic) }) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
            }
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $isPublic) {
                    Image(systemName: isPublic ? "globe" : "lock.fill")
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("togglePublic")
            }
            ToolbarItem(placement: .automatic) {
                NavigationLink(value: PublicListRoute()) {
                    Image(systemName: "globe")
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("publicChats")
            }
        }
        .confirmationDialog("Delete this chat?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = chatToDelete {
                    viewModel.deleteChat(id: id)
                    chatToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
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
