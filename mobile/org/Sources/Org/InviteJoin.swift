import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class AcceptInviteViewModel: Performing {
    var accepted = false
    var isLoading = false
    var mutationError: String?

    func accept(token: String, onDone: @escaping () -> Void) {
        isLoading = true
        perform {
            try await OrgAPI.acceptInvite(token: token)
            self.accepted = true
            self.isLoading = false
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onDone()
        }
    }
}

internal struct AcceptInviteView: View {
    let token: String
    let onAccepted: () -> Void

    @State private var viewModel = AcceptInviteViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.accepted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("You're in!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Redirecting to organization...")
                    .foregroundStyle(.secondary)
            } else if let msg = viewModel.mutationError {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("Invite failed")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(msg)
                    .foregroundStyle(.secondary)
            } else {
                Text("Join organization")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("You've been invited to join an organization.")
                    .foregroundStyle(.secondary)
                Button("Accept invite") {
                    viewModel.accept(token: token, onDone: onAccepted)
                }
                .buttonStyle(.borderedProminent)
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .padding()
        .navigationTitle("Invite")
    }
}

@MainActor
@Observable
internal final class JoinRequestViewModel: Performing {
    var org: Org?
    var myRequest: OrgJoinRequest?
    var mutationError: String?
    var isMember = false
    var isLoading = true

    func load(slug: String) async {
        isLoading = true
        mutationError = nil
        do {
            guard let fetchedOrg = try await OrgAPI.getPublic(slug: slug) else {
                mutationError = "Organization not found"
                isLoading = false
                return
            }

            org = fetchedOrg
            do {
                _ = try await OrgAPI.membership(orgId: fetchedOrg._id)
                isMember = true
            } catch {
                isMember = false
            }
            myRequest = try await OrgAPI.myJoinRequest(orgId: fetchedOrg._id)
        } catch {
            mutationError = error.localizedDescription
        }
        isLoading = false
    }

    func submitRequest(orgID: String, message: String?) {
        perform {
            try await OrgAPI.requestJoin(orgId: orgID, message: message)
            self.myRequest = try await OrgAPI.myJoinRequest(orgId: orgID)
        }
    }

    func cancelRequest(requestID: String) {
        perform {
            try await OrgAPI.cancelJoinRequest(requestId: requestID)
            self.myRequest = nil
        }
    }
}

internal struct JoinRequestView: View {
    let slug: String
    let onJoined: () -> Void

    @State private var viewModel = JoinRequestViewModel()
    @State private var message = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isMember {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("You are already a member")
                        .font(.title2)
                    Button("Continue") { onJoined() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let msg = viewModel.mutationError {
                Text(msg)
                    .foregroundStyle(.red)
                    .padding()
            } else if let org = viewModel.org {
                VStack(spacing: 16) {
                    Text(org.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Request to join this organization")
                        .foregroundStyle(.secondary)

                    if let request = viewModel.myRequest {
                        VStack(spacing: 12) {
                            Text("Your request is pending approval.")
                                .foregroundStyle(.secondary)
                            if let msg = request.message, !msg.isEmpty {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Cancel request") {
                                viewModel.cancelRequest(requestID: request._id)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Form {
                            TextField("Optional message to the admins...", text: $message)
                        }
                        Button("Request to Join") {
                            viewModel.submitRequest(orgID: org._id, message: message.isEmpty ? nil : message)
                            message = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            } else {
                Text("Organization not found")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Join Organization")
        .task {
            await viewModel.load(slug: slug)
        }
    }
}
