import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var api: APIClient
    @State private var hasSelectedGoal: Bool? = nil
    @State private var needsOnboarding: Bool? = nil
    @State private var showProfile = false

    var body: some View {
        mainContent
        .preferredColorScheme(.dark)
        // Recompute state whenever auth session changes (login/logout)
        .task(id: auth.session?.user.id) {
            await refreshStateForSession()
        }
        // Also run once on initial load if already authenticated (e.g., existing session)
        .task(id: auth.session?.accessToken ?? "") {
            guard auth.isAuthenticated else { return }
            do {
                let profile = try await api.fetchMyProfile()
                needsOnboarding = (profile == nil)
                if needsOnboarding == false {
                    let goals = try await api.listGoals()
                    hasSelectedGoal = !goals.isEmpty
                } else {
                    hasSelectedGoal = false
                }
            } catch {
                needsOnboarding = true
                hasSelectedGoal = false
            }
        }
    }

    @ViewBuilder private var mainContent: some View {
        if !auth.isAuthenticated {
            LoginView()
        } else if needsOnboarding == nil || hasSelectedGoal == nil {
            loadingView
        } else if needsOnboarding == true {
            OnboardingView {
                // After onboarding completes, go to home (goals list)
                needsOnboarding = false
            }
        } else {
            MainTabView(onSignOut: signOut)
                .environmentObject(api)
                .environmentObject(auth)
        }
    }

    private var loadingView: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            ProgressView().tint(AppTheme.accent)
        }
    }

    private func signOut() {
        Task { await auth.signOut() }
    }

    private func profileSheet() -> some View {
        ProfileSheetView(
            email: auth.session?.user.email,
            userId: auth.session?.user.id.uuidString,
            onLogout: signOut
        )
    }

    private var userMenu: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label("View Profile", systemImage: "person.circle")
            }
            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .imageScale(.large)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(8)
                .pillGlass(cornerRadius: 12)
        }
    }
    
    // Refresh state when session changes
    private func refreshStateForSession() async {
        // Signed out
        guard let _ = auth.session else {
            await MainActor.run {
                hasSelectedGoal = nil
                needsOnboarding = nil
            }
            return
        }

        do {
            let profile = try await api.fetchMyProfile()
            let needs = (profile == nil)
            let hasGoals = needs ? false : ((try? await api.listGoals())?.isEmpty == false)
            await MainActor.run {
                needsOnboarding = needs
                hasSelectedGoal = hasGoals
            }
        } catch {
            // On error, be conservative: show onboarding then goal selection
            await MainActor.run {
                needsOnboarding = true
                hasSelectedGoal = false
            }
        }
    }
}

// MARK: - Main Tab View
private struct MainTabView: View {
    @EnvironmentObject private var api: APIClient
    let onSignOut: () -> Void
    var body: some View {
        TabView {
            HomeView(onSignOut: onSignOut)
                .tabItem { Label("Home", systemImage: "house.fill") }

            TasksTabView()
                .environmentObject(api)
                .tabItem { Label("Tasks", systemImage: "checklist") }

            CoachChatScreen()
                .environmentObject(api)
                .tabItem { Label("Coach", systemImage: "message.fill") }

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }

            ProfileRootView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

// MARK: - Tasks Tab (list goals -> navigate to tasks per goal)
private struct TasksTabView: View {
    @EnvironmentObject private var api: APIClient
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            ThemedBackground {
                Group {
                    if isLoading { ProgressView().tint(AppTheme.accent) }
                    else if let err = errorText { Text(err).foregroundStyle(.red) }
                    else if goals.isEmpty { Text("No goals yet").foregroundStyle(AppTheme.textSecondary) }
                    else {
                        List(goals) { g in
                            NavigationLink {
                                GoalTasksScreen(goal: g)
                                    .environmentObject(api)
                            } label: {
                                HStack { Text(g.type.replacingOccurrences(of: "_", with: " ").capitalized); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
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

private struct GoalTasksScreen: View {
    @EnvironmentObject private var api: APIClient
    let goal: Goal
    @State private var tasks: [TaskItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    var body: some View {
        ThemedBackground {
            Group {
                if isLoading { ProgressView().tint(AppTheme.accent) }
                else if let err = errorText { Text(err).foregroundStyle(.red) }
                else if tasks.isEmpty { Text("No tasks yet").foregroundStyle(AppTheme.textSecondary) }
                else { List(tasks) { TaskRow(task: $0) } }
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
                if let desc = task.description, !desc.isEmpty { Text(desc).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(task.status.capitalized).font(.caption)
        }
        .padding(8)
    }
}

// MARK: - Coach Chat Screen
private struct CoachChatScreen: View {
    @EnvironmentObject private var api: APIClient
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isSending = false
    @State private var isLoadingHistory = false
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            ThemedBackground {
                VStack(spacing: 8) {
                    ScrollViewReader { proxy in
                        ScrollView { LazyVStack(alignment: .leading, spacing: 12) {
                            if isLoadingHistory && messages.isEmpty { ProgressView().tint(AppTheme.accent) }
                            ForEach(messages) { m in
                                HStack(alignment: .bottom) {
                                    if m.role == "user" { Spacer() }
                                    Text(m.content)
                                        .padding(10)
                                        .background(m.role == "user" ? AppTheme.accent.opacity(0.2) : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    if m.role != "user" { Spacer() }
                                }
                                .id(m.id)
                            }
                        } }
                        .onChange(of: messages) { _, newValue in if let last = newValue.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
                    }
                    HStack(spacing: 8) {
                        TextField("Type a message", text: $input)
                            .textFieldStyle(.roundedBorder)
                        Button(action: { Task { await send() } }) {
                            if isSending { ProgressView().tint(.white) }
                            else { Image(systemName: "paperplane.fill") }
                        }
                        .disabled(isSending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Coach")
            .task { await loadHistory() }
            .alert("Error", isPresented: .constant(errorText != nil), actions: { Button("OK") { errorText = nil } }, message: { Text(errorText ?? "") })
        }
    }
    private func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            let resp = try await api.fetchChatHistory(limit: 200)
            var ms: [ChatMessage] = resp.messages.compactMap { m in
                let text = m.content?.values.joined(separator: "\n") ?? ""
                return text.isEmpty ? nil : ChatMessage(role: m.role, content: text)
            }
            if ms.isEmpty { ms = [ChatMessage(role: "assistant", content: "Hi! I\'m your fitness coach. How can I help today?")] }
            messages = ms
        } catch { errorText = error.localizedDescription }
    }
    private func send() async {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let msg = input
        input = ""
        messages.append(ChatMessage(role: "user", content: msg))
        isSending = true
        do {
            let resp = try await api.coachChat(message: msg)
            messages.append(ChatMessage(role: resp.role, content: resp.content))
        } catch { errorText = error.localizedDescription }
        isSending = false
    }
}

private struct ChatMessage: Identifiable, Hashable { let id = UUID(); let role: String; let content: String }

// MARK: - Friends / Profile
private struct FriendsView: View { var body: some View { ThemedBackground { Text("Friends coming soon").padding() }.navigationTitle("Friends") } }

private struct ProfileRootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    var body: some View {
        NavigationStack {
            ThemedBackground {
                ProfileSheetView(
                    email: auth.session?.user.email,
                    userId: auth.session?.user.id.uuidString,
                    onLogout: { Task { await auth.signOut() } }
                )
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(APIClient())
}