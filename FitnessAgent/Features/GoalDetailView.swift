import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject private var api: APIClient
    let goal: Goal

    @State private var tasks: [TaskItem] = []
    @State private var loading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @State private var showCoachChat = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false

    var body: some View {
        ZStack(alignment: .top) {
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

            // Floating Coach Chat button and panel (goal-scoped)
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 12) {
                        if showCoachChat {
                            GoalCoachChatPanel(goalId: goal.id, onClose: { showCoachChat = false })
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 32, height: 32, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                    if deleting { ProgressView().tint(.red) } else { Image(systemName: "trash") }
                }
                .disabled(deleting)
                .accessibilityLabel("Delete Goal")
            }
        }
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .task(id: goal.id) { await load() }
        .refreshable { await load() }
        .alert("Delete Goal?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteGoal() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the goal and its data. This action cannot be undone.")
        }
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

    private func deleteGoal() async {
        deleting = true; defer { deleting = false }
        do {
            try await api.deleteGoal(goalId: goal.id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Goal-scoped Coach Chat Panel
private struct GoalCoachChatPanel: View {
    @EnvironmentObject private var api: APIClient
    let goalId: String
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isSending = false
    @State private var isLoadingHistory = false
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
                        if isLoadingHistory && messages.isEmpty {
                            HStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                        }
                        ForEach(messages) { msg in
                            HStack {
                                if msg.role == "assistant" { Spacer(minLength: 0) }
                                Text(msg.content)
                                    .padding(12)
                                    .background(msg.role == "user" ? AppTheme.accent.opacity(0.2) : Color.white.opacity(0.06))
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                                if msg.role == "user" { Spacer(minLength: 0) }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages) { _, newValue in
                    if let last = newValue.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
        // Match surrounding layout sizing used in Home
        .frame(width: min(UIScreen.main.bounds.width - 40, 420))
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.6, 480))
        .glass(cornerRadius: 18)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .task { await loadHistory() }
        .alert("Error", isPresented: .constant(errorText != nil), actions: { Button("OK") { errorText = nil } }, message: { Text(errorText ?? "") })
    }

    private func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            let resp = try await api.fetchChatHistory(goalId: goalId, limit: 200)
            var ms: [ChatMessage] = resp.messages.compactMap { m in
                let text = m.content?["text"] ?? m.content?["content"] ?? ""
                return text.isEmpty ? nil : ChatMessage(role: m.role, content: text)
            }
            if ms.isEmpty {
                ms = [.init(role: "assistant", content: "Hi! I’m your fitness coach. How can I help today?")]
            }
            messages = ms
        } catch {
            errorText = error.localizedDescription
            if messages.isEmpty {
                messages = [.init(role: "assistant", content: "Hi! I’m your fitness coach. How can I help today?")]
            }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(.init(role: "user", content: text))
        isSending = true
        Task {
            do {
                let resp = try await api.coachChat(message: text, goalId: goalId)
                messages.append(.init(role: resp.role, content: resp.content))
            } catch {
                errorText = error.localizedDescription
            }
            isSending = false
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
