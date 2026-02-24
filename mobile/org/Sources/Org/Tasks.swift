import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class TasksViewModel: Performing {
    let sub = Sub<[TaskItem]>()
    var mutationError: String?

    var tasks: [TaskItem] {
        sub.data ?? []
    }

    var isLoading: Bool {
        sub.isLoading
    }

    var errorMessage: String? {
        sub.error ?? mutationError
    }

    func start(orgID: String, projectID: String) {
        sub.bind { TaskAPI.subscribeByProject(orgId: orgID, projectId: projectID, onUpdate: $0, onError: $1) }
    }

    func stop() {
        sub.cancel()
    }

    func createTask(orgID: String, projectID: String, title: String) {
        perform { try await TaskAPI.create(orgId: orgID, projectId: projectID, title: title) }
    }

    func toggleTask(orgID: String, taskID: String) {
        perform { try await TaskAPI.toggle(orgId: orgID, id: taskID) }
    }

    func deleteTask(orgID: String, id: String) {
        perform { try await TaskAPI.rm(orgId: orgID, id: id) }
    }
}

internal struct PriorityBadge: View {
    let priority: TaskPriority
    private var priorityColor: Color {
        switch priority {
        case .high:
            .red

        case .medium:
            .orange

        case .low:
            .blue
        }
    }

    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(priorityColor.opacity(0.15))
            .foregroundStyle(priorityColor)
            .clipShape(Capsule())
    }
}

internal struct TasksView: View {
    let orgID: String
    let projectID: String
    let role: OrgRole

    @State private var viewModel = TasksViewModel()
    @State private var newTaskTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading, viewModel.tasks.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(viewModel.tasks) { task in
                    HStack {
                        Button(action: {
                            viewModel.toggleTask(orgID: orgID, taskID: task._id)
                        }) {
                            Image(systemName: task.completed == true ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.completed == true ? .green : .secondary)
                                .accessibilityHidden(true)
                        }
                        .accessibilityIdentifier("toggleTask")
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .strikethrough(task.completed == true)
                                .foregroundStyle(task.completed == true ? .secondary : .primary)
                            if let priority = task.priority {
                                PriorityBadge(priority: priority)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("New task...", text: $newTaskTitle)
                    .roundedBorderTextField()
                    .onSubmit { addTask() }
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("addTaskButton")
                .disabled(newTaskTitle.trimmed.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Tasks")
        .task {
            viewModel.start(orgID: orgID, projectID: projectID)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmed
        guard !title.isEmpty else {
            return
        }

        viewModel.createTask(orgID: orgID, projectID: projectID, title: title)
        newTaskTitle = ""
    }
}
