import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class DetailViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var movie: Movie?
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var posterURL: URL?

    @MainActor
    func loadMovie(tmdbID: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded: Movie = try await client.action(
                "movie:load",
                args: ["tmdb_id": Double(tmdbID)]
            )
            movie = loaded
            if let poster = loaded.poster_path {
                Task {
                    posterURL = await ImageCache.shared.download(poster, size: "w500")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

internal struct DetailView: View {
    let tmdbID: Int
    var path: Binding<NavigationPath>
    @State private var viewModel = DetailViewModel()

    var body: some View {
        VStack {
            Button("Back") {
                path.wrappedValue.removeLast()
            }
            .padding(.bottom, 8)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                VStack {
                    Text(msg)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task { await viewModel.loadMovie(tmdbID: tmdbID) }
                    }
                }
            } else if let movie = viewModel.movie {
                MovieDetail(movie: movie, posterURL: viewModel.posterURL)
            }
        }
        .task {
            await viewModel.loadMovie(tmdbID: tmdbID)
        }
    }
}

internal struct MovieDetail: View {
    let movie: Movie
    let posterURL: URL?

    var body: some View {
        ScrollView {
            VStack {
                if let url = posterURL {
                    // swiftlint:disable:next accessibility_label_for_image
                    Image(url)
                        .resizable()
                        .frame(width: 200, height: 300)
                }

                Text(movie.title)
                if movie.original_title != movie.title {
                    Text(movie.original_title)
                }
                if let tagline = movie.tagline, !tagline.isEmpty {
                    Text(tagline)
                }

                HStack {
                    Text("Release: \(movie.release_date)")
                    if let runtime = movie.runtime {
                        Text("Runtime: \(Int(runtime)) min")
                    }
                }

                HStack {
                    Text(String(format: "Rating: %.1f", movie.vote_average))
                    Text("(\(Int(movie.vote_count)) votes)")
                }

                if let budget = movie.budget, budget > 0 {
                    Text("Budget: $\(String(format: "%.1f", budget / 1_000_000))M")
                }
                if let revenue = movie.revenue, revenue > 0 {
                    Text("Revenue: $\(String(format: "%.1f", revenue / 1_000_000))M")
                }

                Text(movie.overview)
                    .padding(.top, 8)
            }
        }
    }
}
