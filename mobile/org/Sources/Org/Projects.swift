import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class ProjectsViewModel: Performing {
    let sub = Sub<PaginatedResult<Project>>()
    var mutationError: String?
    var selectedIDs = Set<String>()

    var projects: [Project] {
        sub.data?.page ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start(orgID: String) {
        sub.bind { ProjectAPI.subscribeList(orgId: orgID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func createProject(orgID: String, name: String, description: String) {
        perform { try await ProjectAPI.create(orgId: orgID, description: description.isEmpty ? nil : description, name: name) }
    }

    func deleteProject(orgID: String, id: String) {
        perform { try await ProjectAPI.rm(orgId: orgID, id: id) }
    }

    func toggleSelect(id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func toggleSelectAll() {
        if selectedIDs.count == projects.count {
            selectedIDs = Set<String>()
        } else {
            var ids = Set<String>()
            for p in projects {
                ids.insert(p._id)
            }
            selectedIDs = ids
        }
    }

    func clearSelection() {
        selectedIDs = Set<String>()
    }

    func bulkDeleteProjects(orgID: String) {
        perform {
            try await ProjectAPI.bulkRm(orgId: orgID, ids: Array(self.selectedIDs))
            self.selectedIDs = Set<String>()
        }
    }
}

internal struct ProjectsView: View {
    let orgID: String

    let role: OrgRole

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
                List {
                    ForEach(viewModel.projects) { project in
                        HStack(spacing: 8) {
                            if role.isAdmin {
                                Button(action: { viewModel.toggleSelect(id: project._id) }) {
                                    Image(systemName: viewModel.selectedIDs.contains(project._id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedIDs.contains(project._id) ? .blue : .secondary)
                                        .accessibilityHidden(true)
                                }
                                .buttonStyle(.plain)
                            }
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
                                        Text(status.displayName)
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
                    }
                }
                .listStyle(.plain)
                if role.isAdmin, !viewModel.selectedIDs.isEmpty {
                    HStack {
                        Text("\(viewModel.selectedIDs.count) selected")
                            .font(.subheadline)
                        Spacer()
                        Button("Clear") { viewModel.clearSelection() }
                            .font(.subheadline)
                        Button("Delete", role: .destructive) { viewModel.bulkDeleteProjects(orgID: orgID) }
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
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
                        .disabled(newProjectName.trimmed.isEmpty)
                    }
                }
            }
        }
        .task {
            viewModel.start(orgID: orgID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
