import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class SwitcherViewModel: Performing {
    let sub = Sub<[OrgWithRole]>()
    var mutationError: String?

    var orgs: [OrgWithRole] {
        sub.data ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start() {
        sub.bind { OrgAPI.subscribeMyOrgs(onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func createOrg(name: String, slug: String) {
        perform { try await OrgAPI.create(name: name, slug: slug) }
    }
}

internal struct RoleBadge: View {
    let role: OrgRole

    private var badgeColor: Color {
        switch role {
        case .owner:
            .orange

        case .admin:
            .blue

        case .member:
            .green
        }
    }

    var body: some View {
        Text(role.rawValue.capitalized)
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
    let onSelectOrg: (String, String, OrgRole) -> Void

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
                        .primaryForeground()
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
                            .disabled(newOrgName.trimmed.isEmpty || newOrgSlug.trimmed
                                .isEmpty)
                        }
                    }
                }
            }
            .task {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }
}
