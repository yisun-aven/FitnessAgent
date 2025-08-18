import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject private var api: APIClient
    let goal: Goal

    @State private var tasks: [TaskItem] = []
    @State private var loading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 6) {
                Text("Goal Tasks")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Rectangle()
                    .fill(AppTheme.accent.opacity(0.6))
                    .frame(width: 56, height: 2)
                    .cornerRadius(1)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 14, trailing: 20))
            
            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 14, trailing: 20))
            }

            if tasks.isEmpty && !loading && error == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No tasks yet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Create tasks for this goal to track your progress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .glass(cornerRadius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 14, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(tasks) { task in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let desc = task.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            if let due = task.due_at, !due.isEmpty {
                                Label("Due: \(due)", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                Text(task.status.capitalized)
                            }
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .pillGlass(cornerRadius: 8)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .glass(cornerRadius: 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 14, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay { if loading { ProgressView() } }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 34, height: 34, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
        }
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .task(id: goal.id) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            tasks = try await api.listGoalTasks(goalId: goal.id)
            error = nil
        } catch {
            tasks = []
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal(
            id: "demo",
            user_id: "u",
            type: "weight_loss",
            target_value: 7,
            target_date: "2025-09-17",
            status: "active",
            created_at: "2025-08-17T00:00:00Z"
        ))
        .environmentObject(APIClient())
    }
}
