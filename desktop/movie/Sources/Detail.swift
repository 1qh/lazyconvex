import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class DetailViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var movie: Movie?
    @SwiftCrossUI.Published var isLoading = false
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var posterURL: URL?
    @SwiftCrossUI.Published var backdropURL: URL?

    @MainActor
    func loadMovie(tmdbID: Int) async {
        await performLoading({ isLoading = $0 }) {
            let loaded = try await MovieAPI.load(client, tmdbId: tmdbID)
            movie = loaded
            if let poster = loaded.poster_path {
                Task {
                    posterURL = await ImageCache.shared.download(poster, size: "w500")
                }
            }
            if let backdrop = loaded.backdrop_path {
                Task {
                    backdropURL = await ImageCache.shared.download(backdrop, size: "w780")
                }
            }
        }
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
                MovieDetail(movie: movie, posterURL: viewModel.posterURL, backdropURL: viewModel.backdropURL)
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
    let backdropURL: URL?
    var body: some View {
        ScrollView {
            VStack {
                if let url = posterURL {
                    // swiftlint:disable:next accessibility_label_for_image
                    Image(url)
                        .resizable()
                        .frame(width: 200, height: 300)
                }

                if let url = backdropURL {
                    // swiftlint:disable:next accessibility_label_for_image
                    Image(url)
                        .resizable()
                        .frame(width: 400, height: 225)
                }

                Text(movie.title)
                if let cacheHit = movie.cacheHit {
                    Text(cacheHit ? "Cache Hit" : "Cache Miss → Fetched")
                        .foregroundColor(cacheHit ? .green : .orange)
                }
                if movie.original_title != movie.title {
                    Text(movie.original_title)
                }
                if let tagline = movie.tagline, !tagline.isEmpty {
                    Text(tagline)
                }

                if !movie.genres.isEmpty {
                    HStack {
                        ForEach(0..<movie.genres.count, id: \.self) { idx in
                            Text(movie.genres[idx].name)
                        }
                    }
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
