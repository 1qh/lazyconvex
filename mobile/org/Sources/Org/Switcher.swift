import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class SwitcherViewModel {
    var orgs = [OrgWithRole]()

    var isLoading = true

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription() {
        stopSubscription()
        isLoading = true

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "org:myOrgs",
            type: [OrgWithRole].self,
            onUpdate: { [weak self] (result: [OrgWithRole]) in
                self?.orgs = result
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribeOrgsWithRole(
            to: "org:myOrgs",
            onUpdate: { result in
                self.orgs = Array(result)
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

    func createOrg(name: String, slug: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("org:create", args: [
                    "data": [
                        "name": name,
                        "slug": slug,
                    ] as [String: Any],
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

internal struct RoleBadge: View {
    let role: String

    private var badgeColor: Color {
        switch role {
        case "owner":
            .orange

        case "admin":
            .blue

        default:
            .green
        }
    }

    var body: some View {
        Text(role.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
}

internal struct SwitcherView: View {
    let onSelectOrg: (String, String, String) -> Void

    let onSignOut: () -> Void

    @State private var viewModel = SwitcherViewModel()

    @State private var showCreateSheet = false

    @State private var newOrgName = ""

    @State private var newOrgSlug = ""

    var onShowOnboarding: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.orgs.isEmpty {
                    VStack(spacing: 16) {
                        Text("No Organizations")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Create your first organization to get started.")
                            .foregroundStyle(.secondary)
                        Button("Get Started") {
                            onShowOnboarding?()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Quick Create") {
                            showCreateSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    List(viewModel.orgs) { orgWithRole in
                        Button(action: {
                            onSelectOrg(orgWithRole.org._id, orgWithRole.org.name, orgWithRole.role)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(orgWithRole.org.name)
                                        .font(.headline)
                                    Text(orgWithRole.org.slug)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                RoleBadge(role: orgWithRole.role)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 4)
                        }
                        #if !SKIP
                        .foregroundStyle(.primary)
                        #endif
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Organizations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onSignOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .accessibilityHidden(true)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("Organization Name", text: $newOrgName)
                        TextField("Slug (URL-friendly)", text: $newOrgSlug)
                    }
                    .navigationTitle("New Organization")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                viewModel.createOrg(name: newOrgName, slug: newOrgSlug)
                                newOrgName = ""
                                newOrgSlug = ""
                                showCreateSheet = false
                            }
                            .disabled(newOrgName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newOrgSlug
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty)
                        }
                    }
                }
            }
            .task {
                viewModel.startSubscription()
            }
            .onDisappear {
                viewModel.stopSubscription()
            }
        }
    }
}
