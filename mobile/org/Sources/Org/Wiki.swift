import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class WikiListViewModel {
    var wikis = [Wiki]()

    var isLoading = true

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription(orgID: String) {
        stopSubscription()
        isLoading = true

        let args: [String: Any] = [
            "orgId": orgID,
            "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
        ]

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "wiki:list",
            args: args,
            type: PaginatedResult<Wiki>.self,
            onUpdate: { [weak self] (result: PaginatedResult<Wiki>) in
                self?.wikis = result.page
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribePaginatedWikis(
            to: "wiki:list",
            args: args,
            onUpdate: { result in
                self.wikis = Array(result.page)
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

    func createWiki(orgID: String, title: String, slug: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("wiki:create", args: [
                    "orgId": orgID,
                    "title": title,
                    "slug": slug,
                    "status": "draft",
                    "content": "",
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteWiki(orgID: String, id: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("wiki:rm", args: [
                    "orgId": orgID,
                    "id": id,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func restoreWiki(orgID: String, id: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("wiki:restore", args: [
                    "orgId": orgID,
                    "id": id,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

internal struct WikiListView: View {
    let orgID: String

    let role: String

    @State private var viewModel = WikiListViewModel()

    @State private var showCreateSheet = false

    @State private var newWikiTitle = ""

    @State private var newWikiSlug = ""

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.wikis.isEmpty {
                ProgressView()
            } else if viewModel.wikis.isEmpty {
                VStack(spacing: 12) {
                    Text("No wiki pages yet")
                        .foregroundStyle(.secondary)
                    Button("Create Page") {
                        showCreateSheet = true
                    }
                }
            } else {
                List {
                    Section {
                        let activeWikis = viewModel.wikis.filter { w in w.deletedAt == nil }
                        if activeWikis.isEmpty {
                            Text("No active pages")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(activeWikis) { wiki in
                            NavigationLink(value: wiki._id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(wiki.title)
                                        .font(.headline)
                                    HStack {
                                        Text(wiki.slug)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(wiki.status.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(wiki.status == "published" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    let deletedWikis = viewModel.wikis.filter { w in w.deletedAt != nil }
                    if !deletedWikis.isEmpty {
                        Section("Recently Deleted") {
                            ForEach(deletedWikis) { wiki in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(wiki.title)
                                            .font(.headline)
                                            .strikethrough()
                                            .foregroundStyle(.secondary)
                                        Text(wiki.slug)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Restore") {
                                        viewModel.restoreWiki(orgID: orgID, id: wiki._id)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { wikiID in
            WikiEditView(orgID: orgID, wikiID: wikiID, role: role)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    TextField("Page Title", text: $newWikiTitle)
                    TextField("Slug (URL-friendly)", text: $newWikiSlug)
                }
                .navigationTitle("New Wiki Page")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            viewModel.createWiki(orgID: orgID, title: newWikiTitle, slug: newWikiSlug)
                            newWikiTitle = ""
                            newWikiSlug = ""
                            showCreateSheet = false
                        }
                        .disabled(newWikiTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newWikiSlug
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty)
                    }
                }
            }
        }
        .task {
            viewModel.startSubscription(orgID: orgID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}

internal struct WikiEditView: View {
    let orgID: String

    let wikiID: String

    let role: String

    @State private var title = ""

    @State private var slug = ""

    @State private var content = ""

    @State private var status = "draft"

    @State private var isLoading = true

    @State private var saveStatus = ""

    @State private var errorMessage: String?

    @State private var autoSaveTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Form {
                    Section("Details") {
                        TextField("Title", text: $title)
                            .onChange(of: title) { scheduleSave() }
                        TextField("Slug", text: $slug)
                            .onChange(of: slug) { scheduleSave() }
                        Picker("Status", selection: $status) {
                            Text("Draft").tag("draft")
                            Text("Published").tag("published")
                        }
                        .onChange(of: status) { scheduleSave() }
                    }

                    Section("Content") {
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                            .onChange(of: content) { scheduleSave() }
                    }

                    if !saveStatus.isEmpty {
                        Section {
                            Text(saveStatus)
                                .font(.caption)
                                .foregroundStyle(saveStatus == "Error saving" ? .red : .secondary)
                        }
                    }

                    if role == "owner" || role == "admin" {
                        Section("Danger Zone") {
                            Button("Delete Page", role: .destructive) {
                                deleteWiki()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Wiki")
        .task {
            await loadWiki()
        }
    }

    private func scheduleSave() {
        autoSaveTask?.cancel()
        saveStatus = "Editing..."
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                await saveWiki()
            }
        }
    }

    private func saveWiki() async {
        saveStatus = "Saving..."
        do {
            try await ConvexService.shared.mutate("wiki:update", args: [
                "orgId": orgID,
                "id": wikiID,
                "title": title,
                "slug": slug,
                "content": content,
                "status": status,
            ])
            saveStatus = "Saved"
        } catch {
            saveStatus = "Error saving"
            errorMessage = error.localizedDescription
        }
    }

    private func loadWiki() {
        isLoading = false
    }

    private func deleteWiki() {
        Task {
            do {
                try await ConvexService.shared.mutate("wiki:rm", args: [
                    "orgId": orgID,
                    "id": wikiID,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
