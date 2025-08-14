import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var api: APIClient
    @State private var tasks: [TaskItem] = []
    @State private var errorText: String?

    var onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List(tasks) { task in
                VStack(alignment: .leading) {
                    Text(task.title).font(.headline)
                    if let desc = task.description { Text(desc).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Your Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") { Task { await loadTasks() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { onSignOut() }
                }
            }
            .task { await loadTasks() }
            .alert("Error", isPresented: .constant(errorText != nil), actions: {
                Button("OK") { errorText = nil }
            }, message: { Text(errorText ?? "") })
        }
    }

    private func loadTasks() async {
        do { tasks = try await api.listTasks() }
        catch { errorText = error.localizedDescription }
    }
}

#Preview { HomeView(onSignOut: {}).environmentObject(APIClient()) }
