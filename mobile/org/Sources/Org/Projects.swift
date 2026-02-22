import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ProjectsViewModel {
    var projects = [Project]()

    var isLoading = true

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription(orgID: String) {
        stopSubscription()
        isLoading = true

        let args: [String: Any] = [
            "orgId": orgID,
            "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
        ]

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "project:list",
            args: args,
            type: PaginatedResult<Project>.self,
            onUpdate: { [weak self] (result: PaginatedResult<Project>) in
                self?.projects = result.page
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribePaginatedProjects(
            to: "project:list",
            args: args,
            onUpdate: { result in
                self.projects = Array(result.page)
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

    func createProject(orgID: String, name: String, description: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("project:create", args: [
                    "orgId": orgID,
                    "name": name,
                    "description": description,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteProject(orgID: String, id: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("project:rm", args: [
                    "orgId": orgID,
                    "id": id,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

internal struct ProjectsView: View {
    let orgID: String

    let role: String

    @State private var viewModel = ProjectsViewModel()

    @State private var showCreateSheet = false

    @State private var newProjectName = ""

    @State private var newProjectDescription = ""

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.projects.isEmpty {
                ProgressView()
            } else if viewModel.projects.isEmpty {
                VStack(spacing: 12) {
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                    Button("Create Project") {
                        showCreateSheet = true
                    }
                }
            } else {
                List(viewModel.projects) { project in
                    NavigationLink(value: project._id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                            if let desc = project.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            if let status = project.status {
                                Text(status.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { projectID in
            TasksView(orgID: orgID, projectID: projectID, role: role)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    TextField("Project Name", text: $newProjectName)
                    TextField("Description (optional)", text: $newProjectDescription)
                }
                .navigationTitle("New Project")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            viewModel.createProject(orgID: orgID, name: newProjectName, description: newProjectDescription)
                            newProjectName = ""
                            newProjectDescription = ""
                            showCreateSheet = false
                        }
                        .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .task {
            viewModel.startSubscription(orgID: orgID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }
}
