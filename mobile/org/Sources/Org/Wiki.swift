import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class WikiListViewModel: Performing {
    let sub = Sub<PaginatedResult<Wiki>>()
    var mutationError: String?

    var wikis: [Wiki] {
        sub.data?.page ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start(orgID: String) {
        sub.bind { WikiAPI.subscribeList(orgId: orgID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func createWiki(orgID: String, title: String, slug: String) {
        perform { try await WikiAPI.create(orgId: orgID, content: "", slug: slug, status: .draft, title: title) }
    }

    func deleteWiki(orgID: String, id: String) {
        perform { try await WikiAPI.rm(orgId: orgID, id: id) }
    }

    func restoreWiki(orgID: String, id: String) {
        perform { try await WikiAPI.restore(orgId: orgID, id: id) }
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
                                        Text(wiki.status.rawValue.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(wiki.status == .published ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
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
            viewModel.start(orgID: orgID)
        }
        .onDisappear {
            viewModel.stop()
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
            try await WikiAPI.update(
                orgId: orgID,
                id: wikiID,
                content: content,
                slug: slug,
                status: WikiStatus(rawValue: status),
                title: title
            )
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
                try await WikiAPI.rm(orgId: orgID, id: wikiID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
