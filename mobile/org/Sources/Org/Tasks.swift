import ConvexShared
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
internal final class TasksViewModel {
    var tasks = [TaskItem]()

    var isLoading = true

    var errorMessage: String?

    private var subscriptionID: String?

    func startSubscription(orgID: String, projectID: String) {
        stopSubscription()
        isLoading = true

        #if !SKIP
        subscriptionID = ConvexService.shared.subscribe(
            to: "task:byProject",
            args: ["orgId": orgID, "projectId": projectID],
            type: [TaskItem].self,
            onUpdate: { [weak self] (result: [TaskItem]) in
                self?.tasks = result
                self?.isLoading = false
            },
            onError: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
        #else
        subscriptionID = ConvexService.shared.subscribeTasks(
            to: "task:byProject",
            args: ["orgId": orgID, "projectId": projectID],
            onUpdate: { result in
                self.tasks = Array(result)
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

    func createTask(orgID: String, projectID: String, title: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("task:create", args: [
                    "orgId": orgID,
                    "projectId": projectID,
                    "title": title,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleTask(orgID: String, taskID: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("task:toggle", args: [
                    "orgId": orgID,
                    "id": taskID,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteTask(orgID: String, id: String) {
        Task {
            do {
                try await ConvexService.shared.mutate("task:rm", args: [
                    "orgId": orgID,
                    "id": id,
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

internal struct PriorityBadge: View {
    let priority: String

    private var priorityColor: Color {
        switch priority {
        case "high":
            .red

        case "medium":
            .orange

        default:
            .blue
        }
    }

    var body: some View {
        Text(priority.capitalized)
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
    let role: String

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
                #if !SKIP
                    .textFieldStyle(.roundedBorder)
                #endif
                    .onSubmit { addTask() }
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("addTaskButton")
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Tasks")
        .task {
            viewModel.startSubscription(orgID: orgID, projectID: projectID)
        }
        .onDisappear {
            viewModel.stopSubscription()
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }

        viewModel.createTask(orgID: orgID, projectID: projectID, title: title)
        newTaskTitle = ""
    }
}
