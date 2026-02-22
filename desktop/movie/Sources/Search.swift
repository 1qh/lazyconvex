import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class SearchViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var query = ""
    @SwiftCrossUI.Published var results = [SearchResult]()
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var posterURLs = [Int: URL]()
    private var searchTask: Task<Void, Never>?

    @MainActor
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            do {
                let found: [SearchResult] = try await client.action(
                    "movie:search",
                    args: ["query": trimmed]
                )
                if !Task.isCancelled {
                    results = found
                    loadPosters(found)
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    @MainActor
    private func loadPosters(_ items: [SearchResult]) {
        for item in items {
            guard let poster = item.poster_path else {
                continue
            }

            if let cached = ImageCache.shared.localURL(for: poster, size: "w185") {
                posterURLs[item.id] = cached
                continue
            }
            Task {
                if let url = await ImageCache.shared.download(poster, size: "w185") {
                    posterURLs[item.id] = url
                }
            }
        }
    }
}

internal struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    var path: Binding<NavigationPath>

    var body: some View {
        VStack {
            HStack {
                TextField("Search movies...", text: $viewModel.query)
                Button("Search") {
                    viewModel.search()
                }
            }
            .padding(.bottom, 8)

            if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }

            if viewModel.isLoading {
                Text("Searching...")
            } else if viewModel.results.isEmpty {
                Text("Search for movies by title")
            } else {
                ScrollView {
                    ForEach(viewModel.results) { result in
                        HStack {
                            if let posterURL = viewModel.posterURLs[result.id] {
                                // swiftlint:disable:next accessibility_label_for_image
                                Image(posterURL)
                                    .resizable()
                                    .frame(width: 60, height: 90)
                            }
                            VStack {
                                Text(result.title)
                                HStack {
                                    if let date = result.release_date {
                                        Text(String(date.prefix(4)))
                                    }
                                    Text(String(format: "%.1f", result.vote_average))
                                }
                                Text(result.overview)
                            }
                            NavigationLink("View", value: result.id, path: path)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }
}
