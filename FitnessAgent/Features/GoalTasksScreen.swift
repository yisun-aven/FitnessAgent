import SwiftUI

struct GoalTasksScreen: View {
    @EnvironmentObject private var api: APIClient
    let goal: Goal
    @State private var tasks: [TaskItem] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ThemedBackground {
            Group {
                if isLoading {
                    ProgressView().tint(AppTheme.accent)
                } else if let err = errorText {
                    Text(err).foregroundStyle(.red)
                } else if tasks.isEmpty {
                    Text("No tasks yet").foregroundStyle(AppTheme.textSecondary)
                } else {
                    List(tasks) { TaskRow(task: $0) }
                }
            }
            .padding(.horizontal, 12)
        }
        .navigationTitle(goal.type.replacingOccurrences(of: "_", with: " ").capitalized)
        .task { await loadTasks() }
    }

    private func loadTasks() async {
        isLoading = true
        defer { isLoading = false }
        do { tasks = try await api.listGoalTasks(goalId: goal.id) }
        catch { errorText = error.localizedDescription }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.headline)
                if let desc = task.description, !desc.isEmpty {
                    Text(desc).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(task.status.capitalized).font(.caption)
        }
        .padding(8)
    }
}