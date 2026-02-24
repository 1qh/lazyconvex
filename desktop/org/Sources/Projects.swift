import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal final class ProjectsViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var projects = [Project]()
    @SwiftCrossUI.Published var isLoading = true
    @SwiftCrossUI.Published var errorMessage: String?
    @SwiftCrossUI.Published var selectedIDs = Set<String>()

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

    @MainActor
    func toggleSelect(id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    @MainActor
    func toggleSelectAll() {
        if selectedIDs.count == projects.count {
            selectedIDs.removeAll()
        } else {
            var ids = Set<String>()
            for p in projects {
                ids.insert(p._id)
            }
            selectedIDs = ids
        }
    }

    @MainActor
    func clearSelection() {
        selectedIDs.removeAll()
    }

    @MainActor
    func bulkDeleteProjects(orgID: String) async {
        await perform {
            try await ProjectAPI.bulkRm(client, orgId: orgID, ids: Array(selectedIDs))
            selectedIDs.removeAll()
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
                if role.isAdmin {
                    Button(viewModel.selectedIDs.count == viewModel.projects.count ? "Deselect All" : "Select All") {
                        viewModel.toggleSelectAll()
                    }
                    if !viewModel.selectedIDs.isEmpty {
                        Button("Delete Selected (\(viewModel.selectedIDs.count))") {
                            Task { await viewModel.bulkDeleteProjects(orgID: orgID) }
                        }
                    }
                }
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
                            if role.isAdmin {
                                Button(viewModel.selectedIDs.contains(project._id) ? "[x]" : "[ ]") {
                                    viewModel.toggleSelect(id: project._id)
                                }
                            }
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
    @SwiftCrossUI.Published var editors = [EditorEntry]()
    @SwiftCrossUI.Published var members = [OrgMemberEntry]()

    var availableMembers: [OrgMemberEntry] {
        var editorIDs = Set<String>()
        for e in editors {
            editorIDs.insert(e.userId)
        }
        var result = [OrgMemberEntry]()
        for m in members where !editorIDs.contains(m.userId) {
            result.append(m)
        }
        return result
    }

    @MainActor
    func load(orgID: String, projectID: String) async {
        await performLoading({ isLoading = $0 }) {
            tasks = try await TaskAPI.byProject(client, orgId: orgID, projectId: projectID)
            editors = try await ProjectAPI.editors(client, orgId: orgID, projectId: projectID)
            members = try await OrgAPI.members(client, orgId: orgID)
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

    @MainActor
    func addEditor(orgID: String, editorId: String, projectID: String) async {
        await perform {
            try await ProjectAPI.addEditor(client, orgId: orgID, editorId: editorId, projectId: projectID)
            await self.load(orgID: orgID, projectID: projectID)
        }
    }

    @MainActor
    func removeEditor(orgID: String, editorId: String, projectID: String) async {
        await perform {
            try await ProjectAPI.removeEditor(client, orgId: orgID, editorId: editorId, projectId: projectID)
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
            if role.isAdmin {
                Text("Editors")
                    .padding(.bottom, 4)
                if viewModel.editors.isEmpty {
                    Text("No editors")
                } else {
                    ForEach(viewModel.editors) { editor in
                        HStack {
                            Text(editor.name ?? editor.email ?? editor.userId)
                            Button("Remove") {
                                Task { await viewModel.removeEditor(orgID: orgID, editorId: editor.userId, projectID: projectID) }
                            }
                        }
                    }
                }
                Text("Add Editor")
                    .padding(.top, 4)
                ForEach(viewModel.availableMembers) { member in
                    HStack {
                        Text(member.name ?? member.email ?? member.userId)
                        Button("Add") {
                            Task { await viewModel.addEditor(orgID: orgID, editorId: member.userId, projectID: projectID) }
                        }
                    }
                }
            }

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
