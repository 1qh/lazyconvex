import ConvexShared
import SwiftUI

internal struct PublicView: View {
    let chatID: String

    @State private var messages = [Message]()

    @State private var isLoading = true

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if messages.isEmpty {
                Spacer()
                Text("No messages yet")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }

            if errorMessage != nil {
                ErrorBanner(message: errorMessage)
                    .padding(.horizontal)
            }

            HStack {
                Text("Read-only public chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            }
        }
        .navigationTitle("Public Chat")
    }
}
