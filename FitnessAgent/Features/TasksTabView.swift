import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject private var api: APIClient
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ThemedBackground {
                Group {
                    if isLoading {
                        ProgressView().tint(AppTheme.accent)
                    } else if let err = errorText {
                        Text(err).foregroundStyle(.red)
                    } else if goals.isEmpty {
                        Text("No goals yet").foregroundStyle(AppTheme.textSecondary)
                    } else {
                        List(goals) { g in
                            NavigationLink {
                                GoalTasksScreen(goal: g)
                                    .environmentObject(api)
                            } label: {
                                HStack {
                                    Text(g.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .padding(.horizontal, 12)
            }
            .navigationTitle("Tasks")
            .task { await loadGoals() }
        }
    }

    private func loadGoals() async {
        isLoading = true
        defer { isLoading = false }
        do { goals = try await api.listGoals() }
        catch { errorText = error.localizedDescription }
    }
}