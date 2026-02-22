import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class DetailViewModel {
    var isLoading = false

    var movie: Movie?

    var errorMessage: String?

    func loadMovie(tmdbID: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            #if !SKIP
            let loaded: Movie = try await ConvexService.shared.action(
                "movie:load",
                args: ["tmdb_id": Double(tmdbID)],
                returning: Movie.self
            )
            #else
            let loaded: Movie = try await ConvexService.shared.actionMovie(
                name: "movie:load",
                args: ["tmdb_id": Double(tmdbID)]
            )
            #endif
            movie = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchByID(_ idText: String) async {
        guard let tmdbID = Int(idText), tmdbID > 0 else {
            errorMessage = "Enter a valid TMDB ID"
            return
        }

        await loadMovie(tmdbID: tmdbID)
    }
}

internal struct FetchByIDView: View {
    @State private var viewModel = DetailViewModel()
    @State private var idText = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("TMDB ID (e.g. 27205)", text: $idText)
                #if !SKIP
                    .textFieldStyle(.roundedBorder)
                #endif

                Button("Fetch") {
                    Task { await viewModel.fetchByID(idText) }
                }
                .disabled(idText.isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)

            Text("Try: 27205 (Inception), 550 (Fight Club), 680 (Pulp Fiction)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if viewModel.errorMessage != nil {
                ErrorBanner(message: viewModel.errorMessage)
                    .padding(.horizontal)
            }

            if viewModel.isLoading {
                ProgressView("Loading...")
                Spacer()
            } else if let movie = viewModel.movie {
                DetailContent(movie: movie)
            } else {
                Spacer()
            }
        }
        .padding(.top)
        .navigationTitle("Fetch by ID")
    }
}

internal struct DetailContent: View {
    let movie: Movie
    private let tmdbImg = "https://image.tmdb.org/t/p/w300"
    private let tmdbBackdrop = "https://image.tmdb.org/t/p/w780"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let backdropPath = movie.backdrop_path {
                    AsyncImage(url: URL(string: "\(tmdbBackdrop)\(backdropPath)")) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)

                        default:
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .aspectRatio(1.78, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        if let posterPath = movie.poster_path {
                            AsyncImage(url: URL(string: "\(tmdbImg)\(posterPath)")) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)

                                default:
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                }
                            }
                            .frame(width: 100, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.title2)
                                .bold()

                            if movie.original_title != movie.title {
                                Text(movie.original_title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let tagline = movie.tagline, !tagline.isEmpty {
                                Text(tagline)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(movie.genres, id: \.id) { genre in
                                        Text(genre.name)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        metaRow(label: "Release", value: movie.release_date)
                        if let runtime = movie.runtime {
                            metaRow(label: "Runtime", value: "\(Int(runtime)) min")
                        }
                        metaRow(label: "Rating", value: "\(String(format: "%.1f", movie.vote_average)) (\(Int(movie.vote_count)) votes)")
                        if let budget = movie.budget, budget > 0 {
                            metaRow(label: "Budget", value: formatMoney(budget))
                        }
                        if let revenue = movie.revenue, revenue > 0 {
                            metaRow(label: "Revenue", value: formatMoney(revenue))
                        }
                    }
                    .font(.subheadline)

                    Text(movie.overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(movie.title)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func formatMoney(_ value: Double) -> String {
        "$\(String(format: "%.1f", value / 1_000_000))M"
    }
}

internal struct DetailView: View {
    let tmdbID: Int
    @State private var viewModel = DetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await viewModel.loadMovie(tmdbID: tmdbID) }
                    }
                }
            } else if let movie = viewModel.movie {
                DetailContent(movie: movie)
            }
        }
        .task {
            await viewModel.loadMovie(tmdbID: tmdbID)
        }
    }
}
