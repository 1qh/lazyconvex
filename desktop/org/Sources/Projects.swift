import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProjectsViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var projects = [Project]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String) async {
        await performLoading({ isLoading = $0 }) {
            let result = try await ProjectAPI.list(
                client,
                orgId: orgID
            )
            projects = result.page
        }
    }

    @MainActor
    func createProject(orgID: String, name: String, description: String) async {
        await perform {
            try await ProjectAPI.create(
                client,
                orgId: orgID,
                description: description.isEmpty ? nil : description,
                name: name
            )
            await self.load(orgID: orgID)
        }
    }

    @MainActor
    func deleteProject(orgID: String, id: String) async {
        await perform {
            try await ProjectAPI.rm(client, orgId: orgID, id: id)
            await self.load(orgID: orgID)
        }
    }
}

internal struct ProjectsView: View {
    let orgID: String
    let role: OrgRole
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
                                    Text(status.displayName)
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

internal final class TasksViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var tasks = [TaskItem]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?

    @MainActor
    func load(orgID: String, projectID: String) async {
        await performLoading({ isLoading = $0 }) {
            tasks = try await TaskAPI.byProject(client, orgId: orgID, projectId: projectID)
        }
    }

    @MainActor
    func createTask(orgID: String, projectID: String, title: String) async {
        await perform {
            try await TaskAPI.create(
                client,
                orgId: orgID,
                projectId: projectID,
                title: title
            )
            await self.load(orgID: orgID, projectID: projectID)
        }
    }

    @MainActor
    func toggleTask(orgID: String, projectID: String, taskID: String) async {
        await perform {
            try await TaskAPI.toggle(client, orgId: orgID, id: taskID)
            await self.load(orgID: orgID, projectID: projectID)
        }
    }

    @MainActor
    func deleteTask(orgID: String, projectID: String, id: String) async {
        await perform {
            try await TaskAPI.rm(client, orgId: orgID, id: id)
            await self.load(orgID: orgID, projectID: projectID)
        }
    }
}

internal struct TasksView: View {
    let orgID: String
    let projectID: String
    let role: OrgRole
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
                                Text(priority.displayName)
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
                    let title = newTaskTitle.trimmed
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
