import SwiftUI

struct CoachChatScreen: View {
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
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if isLoadingHistory && messages.isEmpty {
                                    ProgressView().tint(AppTheme.accent)
                                }
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
                            }
                        }
                        .onChange(of: messages) { _, newValue in
                            if let last = newValue.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Type a message", text: $input).textFieldStyle(.roundedBorder)
                        Button(action: { Task { await send() } }) {
                            if isSending { ProgressView().tint(.white) } else { Image(systemName: "paperplane.fill") }
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
            if ms.isEmpty { ms = [ChatMessage(role: "assistant", content: "Hi! I’m your fitness coach. How can I help today?")] }
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

// Using shared ChatMessage model defined elsewhere in the app.