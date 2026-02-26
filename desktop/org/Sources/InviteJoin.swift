import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal struct AcceptInviteView: View {
    let token: String
    var onAccepted: () -> Void
    @State private var accepted = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if accepted {
                Text("You're in!")
                    .foregroundColor(.green)
                Text("Redirecting to organization...")
            } else if let msg = errorMessage {
                Text("Invite failed")
                    .foregroundColor(.red)
                Text(msg)
            } else {
                Text("Join organization")
                Text("You've been invited to join an organization.")
                    .padding(.bottom, 8)
                Button("Accept invite") {
                    Task { await accept() }
                }
                if isLoading {
                    Text("Loading...")
                }
            }
        }
    }

    @MainActor
    private func accept() async {
        isLoading = true
        do {
            try await OrgAPI.acceptInvite(client, token: token)
            accepted = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onAccepted()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

internal final class JoinRequestViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var org: Org?
    @SwiftCrossUI.Published var myRequest: OrgJoinRequest?
    @SwiftCrossUI.Published var isMember = false
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(slug: String) async {
        await performLoading({ isLoading = $0 }) {
            guard let fetchedOrg = try await OrgAPI.getPublic(client, slug: slug) else {
                self.errorMessage = "Organization not found"
                return
            }

            self.org = fetchedOrg
            do {
                _ = try await OrgAPI.membership(client, orgId: fetchedOrg._id)
                self.isMember = true
            } catch {
                self.isMember = false
            }
            self.myRequest = try await OrgAPI.myJoinRequest(client, orgId: fetchedOrg._id)
        }
    }

    @MainActor
    func submitRequest(message: String?) async {
        guard let org else {
            return
        }

        await perform {
            try await OrgAPI.requestJoin(client, orgId: org._id, message: message)
            self.myRequest = try await OrgAPI.myJoinRequest(client, orgId: org._id)
        }
    }

    @MainActor
    func cancelRequest() async {
        guard let request = myRequest else {
            return
        }

        await perform {
            try await OrgAPI.cancelJoinRequest(client, requestId: request._id)
            self.myRequest = nil
        }
    }
}

internal struct JoinRequestView: View {
    let slug: String
    var onJoined: () -> Void
    @State private var viewModel = JoinRequestViewModel()
    @State private var message = ""

    var body: some View {
        VStack {
            if viewModel.isLoading {
                Text("Loading...")
            } else if viewModel.isMember {
                Text("You are already a member of this organization.")
                Button("Continue") { onJoined() }
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if let org = viewModel.org {
                Text(org.name)
                    .padding(.bottom, 4)
                Text("Request to join this organization")
                    .padding(.bottom, 8)

                if let request = viewModel.myRequest {
                    Text("Your request is pending approval.")
                    if let msg = request.message, !msg.isEmpty {
                        Text("Message: \(msg)")
                    }
                    Button("Cancel request") {
                        Task { await viewModel.cancelRequest() }
                    }
                    .padding(.top, 4)
                } else {
                    TextField("Optional message to the admins...", text: $message)
                    Button("Request to Join") {
                        Task {
                            await viewModel.submitRequest(message: message.isEmpty ? nil : message)
                            message = ""
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .task {
            await viewModel.load(slug: slug)
        }
    }
}
