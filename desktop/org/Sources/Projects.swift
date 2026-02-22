import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProjectsViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var projects = [Project]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: PaginatedResult<Project> = try await client.query(
                "project:list",
                args: [
                    "orgId": orgID,
                    "paginationOpts": ["cursor": NSNull(), "numItems": 50] as [String: Any],
                ]
            )
            projects = result.page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createProject(orgID: String, name: String, description: String) async {
        do {
            try await client.mutation("project:create", args: [
                "orgId": orgID,
                "name": name,
                "description": description,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteProject(orgID: String, id: String) async {
        do {
            try await client.mutation("project:rm", args: [
                "orgId": orgID,
                "id": id,
            ])
            await load(orgID: orgID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct ProjectsView: View {
    let orgID: String
    let role: String
    var path: Binding<NavigationPath>
    @State private var viewModel = ProjectsViewModel()
    @State private var showCreateForm = false
    @State private var newName = ""
    @State private var newDesc = ""

    var body: some View {
        VStack {
            HStack {
                Text("Projects")
                Button("New Project") { showCreateForm = true }
            }
            .padding(.bottom, 4)

            if showCreateForm {
                VStack {
                    TextField("Project Name", text: $newName)
                    TextField("Description (optional)", text: $newDesc)
                    HStack {
                        Button("Cancel") { showCreateForm = false }
                        Button("Create") {
                            Task {
                                await viewModel.createProject(orgID: orgID, name: newName, description: newDesc)
                                newName = ""
                                newDesc = ""
                                showCreateForm = false
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.projects.isEmpty {
                Text("No projects yet")
            } else {
                ScrollView {
                    ForEach(viewModel.projects) { project in
                        HStack {
                            VStack {
                                Text(project.name)
                                if let desc = project.description, !desc.isEmpty {
                                    Text(desc)
                                }
                                if let status = project.status {
                                    Text(status.capitalized)
                                }
                            }
                            Button("Delete") {
                                Task { await viewModel.deleteProject(orgID: orgID, id: project._id) }
                            }
                            NavigationLink("Tasks", value: project._id, path: path)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await viewModel.load(orgID: orgID)
        }
    }
}

internal final class TasksViewModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var tasks = [TaskItem]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String, projectID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded: [TaskItem] = try await client.query(
                "task:byProject",
                args: ["orgId": orgID, "projectId": projectID]
            )
            tasks = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createTask(orgID: String, projectID: String, title: String) async {
        do {
            try await client.mutation("task:create", args: [
                "orgId": orgID,
                "projectId": projectID,
                "title": title,
            ])
            await load(orgID: orgID, projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func toggleTask(orgID: String, projectID: String, taskID: String) async {
        do {
            try await client.mutation("task:toggle", args: [
                "orgId": orgID,
                "id": taskID,
            ])
            await load(orgID: orgID, projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteTask(orgID: String, projectID: String, id: String) async {
        do {
            try await client.mutation("task:rm", args: [
                "orgId": orgID,
                "id": id,
            ])
            await load(orgID: orgID, projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

internal struct TasksView: View {
    let orgID: String
    let projectID: String
    let role: String
    @State private var viewModel = TasksViewModel()
    @State private var newTaskTitle = ""

    var body: some View {
        VStack {
            Text("Tasks")
                .padding(.bottom, 4)

            if viewModel.isLoading {
                Text("Loading...")
            } else if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            } else if viewModel.tasks.isEmpty {
                Text("No tasks yet")
            } else {
                ScrollView {
                    ForEach(viewModel.tasks) { task in
                        HStack {
                            Button(task.completed == true ? "[x]" : "[ ]") {
                                Task { await viewModel.toggleTask(orgID: orgID, projectID: projectID, taskID: task._id) }
                            }
                            Text(task.title)
                            if let priority = task.priority {
                                Text(priority.capitalized)
                            }
                            Button("Delete") {
                                Task { await viewModel.deleteTask(orgID: orgID, projectID: projectID, id: task._id) }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }

            HStack {
                TextField("New task...", text: $newTaskTitle)
                Button("Add") {
                    let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else {
                        return
                    }

                    Task {
                        await viewModel.createTask(orgID: orgID, projectID: projectID, title: title)
                        newTaskTitle = ""
                    }
                }
            }
            .padding(.top, 4)
        }
        .task {
            await viewModel.load(orgID: orgID, projectID: projectID)
        }
    }
}
