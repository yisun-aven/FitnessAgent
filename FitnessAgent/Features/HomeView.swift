import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var api: APIClient
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showCoachChat = false

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
                                            GoalDetailView(goal: goal)
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
                    // Floating Coach Chat button and panel
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 12) {
                                if showCoachChat {
                                    CoachChatPanel(onClose: { showCoachChat = false })
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showCoachChat.toggle()
                                    }
                                } label: {
                                    Image(systemName: showCoachChat ? "xmark" : "message.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                        .background(AppTheme.accent.opacity(0.95))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                                }
                                .accessibilityLabel("Coach Chat")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 16)
                            .zIndex(50)
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
                    HStack(spacing: 10) {
                        NavigationLink {
                            GoalSelectionView(onContinue: { Task { await loadGoals() } })
                                .environmentObject(api)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("New Goal")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        Button {
                            onSignOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(8)
                                .pillGlass(cornerRadius: 10)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("No goals yet")
                .font(.title3).bold()
                .foregroundStyle(AppTheme.textPrimary)
            Text("Create your first goal to get personalized tasks.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glass(cornerRadius: 16)
    }

    private func loadGoals() async {
        isLoading = true
        do {
            goals = try await api.listGoals()
        } catch { errorText = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Coach Chat (Floating Panel)
private struct CoachChatPanel: View {
    @EnvironmentObject private var api: APIClient
    @State private var messages: [ChatMessage] = [
        .init(role: "assistant", content: "Hi! I’m your fitness coach. How can I help today?")
    ]
    @State private var input: String = ""
    @State private var isSending = false
    @State private var errorText: String?
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Coach")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(6)
                        .background(.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.02))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.role == "assistant" { Spacer(minLength: 0) }
                                Text(msg.content)
                                    .padding(12)
                                    .background(msg.role == "user" ? AppTheme.accent.opacity(0.25) : AppTheme.surfaceStrong)
                                    .cornerRadius(12)
                                if msg.role == "user" { Spacer(minLength: 0) }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 8) {
                TextField("Ask your coach...", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .pillGlass(cornerRadius: 10)
                Button(action: send) {
                    if isSending { ProgressView().tint(AppTheme.accent) }
                    else { Image(systemName: "paperplane.fill") }
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .pillGlass(cornerRadius: 10)
            }
            .padding(10)
            .background(Color.white.opacity(0.02))
        }
        // Match Home content's horizontal padding (.padding(.horizontal, 20))
        .frame(width: min(UIScreen.main.bounds.width - 40, 420))
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.6, 480))
        .glass(cornerRadius: 18)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .alert("Error", isPresented: .constant(errorText != nil), actions: { Button("OK") { errorText = nil } }, message: { Text(errorText ?? "") })
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(.init(role: "user", content: text))
        isSending = true

        Task {
            do {
                let resp = try await api.coachChat(message: text, goalId: nil)
                messages.append(.init(role: resp.role, content: resp.content))
            } catch {
                errorText = error.localizedDescription
            }
            isSending = false
        }
    }
}

// MARK: - Coach Chat
private struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
}

// MARK: - Goal Card
private struct GoalCard: View {
    let goal: Goal

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.surfaceStrong)
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
        .glass(cornerRadius: 16)
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
                    .pillGlass(cornerRadius: 8)
            }
        }
        .padding(14)
        .glass(cornerRadius: 14)
    }
}

#Preview {
    HomeView(onSignOut: {})
        .environmentObject(APIClient())
}