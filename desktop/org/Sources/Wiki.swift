import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class WikiListViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var wikis = [Wiki]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    var activeWikis: [Wiki] {
        var result = [Wiki]()
        for w in wikis where w.deletedAt == nil {
            result.append(w)
        }
        return result
    }

    var deletedWikis: [Wiki] {
        var result = [Wiki]()
        for w in wikis where w.deletedAt != nil {
            result.append(w)
        }
        return result
    }

    @MainActor
    func load(orgID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await WikiAPI.list(
                client,
                orgId: orgID
            )
            wikis = result.page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createWiki(orgID: String, title: String, slug: String) async {
        do {
            try await WikiAPI.create(
                client,
                orgId: orgID,
                content: "",
                slug: slug,
                status: .draft,
                title: title
            )
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteWiki(orgID: String, id: String) async {
        do {
            try await WikiAPI.rm(client, orgId: orgID, id: id)
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func restoreWiki(orgID: String, id: String) async {
        do {
            try await WikiAPI.restore(client, orgId: orgID, id: id)
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct WikiListView: View {
    let orgID: String
    let role: String
    var path: Binding<NavigationPath>
    @State private var viewModel = WikiListViewModel()
    @State private var showCreateForm = false
    @State private var newTitle = ""
    @State private var newSlug = ""

    var body: some View {
        VStack {
            HStack {
                Text("Wiki")
                Button("New Page") { showCreateForm = true }
            }
            .padding(.bottom, 4)

            if showCreateForm {
                VStack {
                    TextField("Page Title", text: $newTitle)
                    TextField("Slug (URL-friendly)", text: $newSlug)
                    HStack {
                        Button("Cancel") { showCreateForm = false }
                        Button("Create") {
                            Task {
                                await viewModel.createWiki(orgID: orgID, title: newTitle, slug: newSlug)
                                newTitle = ""
                                newSlug = ""
                                showCreateForm = false
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.wikis.isEmpty {
                Text("No wiki pages yet")
            } else {
                ScrollView {
                    ForEach(viewModel.activeWikis) { wiki in
                        HStack {
                            VStack {
                                Text(wiki.title)
                                HStack {
                                    Text(wiki.slug)
                                    Text(wiki.status.rawValue.capitalized)
                                }
                            }
                            Button("Delete") {
                                Task { await viewModel.deleteWiki(orgID: orgID, id: wiki._id) }
                            }
                            NavigationLink("Edit", value: wiki._id, path: path)
                        }
                        .padding(.bottom, 4)
                    }
                    ForEach(viewModel.deletedWikis) { wiki in
                        HStack {
                            Text(wiki.title)
                            Text("(Deleted)")
                            Button("Restore") {
                                Task { await viewModel.restoreWiki(orgID: orgID, id: wiki._id) }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await viewModel.load(orgID: orgID)
        }
    }
}

internal final class WikiEditViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var title = ""
    @SwiftCrossUI.Published var slug = ""
    @SwiftCrossUI.Published var content = ""
    @SwiftCrossUI.Published var status = WikiStatus.draft.rawValue
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var saveStatus = ""
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String, wikiID: String) async {
        isLoading = true
        do {
            let wiki: Wiki = try await WikiAPI.read(client, orgId: orgID, id: wikiID)
            title = wiki.title
            slug = wiki.slug
            content = wiki.content ?? ""
            status = wiki.status.rawValue
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func save(orgID: String, wikiID: String) async {
        saveStatus = "Saving..."
        do {
            try await WikiAPI.update(
                client,
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

    @MainActor
    func deleteWiki(orgID: String, wikiID: String) async {
        do {
            try await WikiAPI.rm(client, orgId: orgID, id: wikiID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct WikiEditView: View {
    let orgID: String
    let wikiID: String
    let role: String
    @State private var viewModel = WikiEditViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                Text("Loading...")
            } else {
                TextField("Title", text: $viewModel.title)
                TextField("Slug", text: $viewModel.slug)
                TextField("Status (draft/published)", text: $viewModel.status)
                TextField("Content", text: $viewModel.content)

                if let msg = viewModel.errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                }

                HStack {
                    Button("Save") {
                        Task { await viewModel.save(orgID: orgID, wikiID: wikiID) }
                    }
                    if role == "owner" || role == "admin" {
                        Button("Delete") {
                            Task { await viewModel.deleteWiki(orgID: orgID, wikiID: wikiID) }
                        }
                    }
                }
                .padding(.top, 4)

                if !viewModel.saveStatus.isEmpty {
                    Text(viewModel.saveStatus)
                }
            }
        }
        .task {
            await viewModel.load(orgID: orgID, wikiID: wikiID)
        }
    }
}
