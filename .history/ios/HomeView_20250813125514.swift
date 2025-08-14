import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var api: APIClient
    var onSignOut: () -> Void
    @State private var tasks: [TaskItem] = []
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            List(tasks) { task in
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.headline)
                    if let desc = task.description { Text(desc).font(.subheadline).foregroundStyle(.secondary) }
                    if let due = task.due_at { Text("Due: \(due)").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Your Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") { onSignOut() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") { Task { await load() } }
                }
            }
        }
        .task { await load() }
        .alert("Error", isPresented: .constant(errorText != nil)) {
            Button("OK") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func load() async {
        do {
            tasks = try await api.listTasks()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    HomeView(onSignOut: {})
        .environmentObject(APIClient())
}
