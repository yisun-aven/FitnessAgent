import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var api: APIClient
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ThemedBackground {
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header

                            if isLoading {
                                ProgressView().tint(AppTheme.accent)
                            } else if goals.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(goals) { goal in
                                        NavigationLink {
                                            GoalTasksView(goal: goal)
                                                .environmentObject(api)
                                        } label: {
                                            GoalCard(goal: goal)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "bolt.heart")
                        .imageScale(.large)
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        NavigationLink {
                            GoalSelectionView(onContinue: { Task { await loadGoals() } })
                                .environmentObject(api)
                        } label: {
                            Label("New Goal", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        Button {
                            onSignOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .task { await loadGoals() }
            .alert("Error", isPresented: .constant(errorText != nil), actions: {
                Button("OK") { errorText = nil }
            }, message: { Text(errorText ?? "") })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Goals")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Rectangle()
                .fill(AppTheme.accent.opacity(0.6))
                .frame(width: 56, height: 2)
                .cornerRadius(1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No goals yet")
                .font(.title3).bold()
                .foregroundStyle(AppTheme.textPrimary)
            Text("Create your first goal to get personalized tasks.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func loadGoals() async {
        isLoading = true
        do {
            goals = try await api.listGoals()
        } catch { errorText = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Goal Card
private struct GoalCard: View {
    let goal: Goal

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                Image(systemName: iconName(for: goal.type))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: goal.type))
                    .font(.headline)
                if let target = goal.target_value {
                    Text("Target: \(target, specifier: "%.0f") • \(goal.target_date ?? "No date")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let date = goal.target_date {
                    Text("By \(date)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func title(for type: String) -> String {
        switch type.lowercased() {
        case "weight_loss": return "Weight Loss"
        case "muscle_gain": return "Muscle Gain"
        case "endurance": return "Endurance"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "weight_loss": return "scalemass"
        case "muscle_gain": return "dumbbell.fill"
        case "endurance": return "figure.run"
        default: return "target"
        }
    }
}

// MARK: - Goal Tasks View
private struct GoalTasksView: View {
    @EnvironmentObject private var api: APIClient
    let goal: Goal
    @State private var tasks: [TaskItem] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ThemedBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if isLoading {
                        ProgressView().tint(AppTheme.accent)
                    } else if tasks.isEmpty {
                        Text("No tasks yet for this goal.")
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 8)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(tasks) { task in
                                TaskRow(task: task)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .task { await loadTasks() }
        .alert("Error", isPresented: .constant(errorText != nil), actions: { Button("OK") { errorText = nil } }, message: { Text(errorText ?? "") })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cardTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Rectangle()
                .fill(AppTheme.accent.opacity(0.6))
                .frame(width: 44, height: 2)
                .cornerRadius(1)
        }
    }

    private var cardTitle: String { goal.type.replacingOccurrences(of: "_", with: " ").capitalized }

    private func loadTasks() async {
        isLoading = true
        do { tasks = try await api.listTasks(goalId: goal.id) }
        catch { errorText = error.localizedDescription }
        isLoading = false
    }
}

private struct TaskRow: View {
    let task: TaskItem
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.headline)
            if let desc = task.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 8) {
                if let due = task.due_at { Label(due, systemImage: "calendar").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(task.status.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView(onSignOut: {})
        .environmentObject(APIClient())
}
