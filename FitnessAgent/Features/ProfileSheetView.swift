import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let email: String?
    let userId: String?
    var onLogout: (() -> Void)?

    init(email: String? = nil, userId: String? = nil, onLogout: (() -> Void)? = nil) {
        self.email = email
        self.userId = userId
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(email ?? "Signed in")
                            if let userId { 
                                Text("User ID: \(userId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if onLogout != nil {
                    Section {
                        Button(role: .destructive) {
                            onLogout?()
                            dismiss()
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileSheetView(email: "user@example.com", userId: "abc123", onLogout: {})
}
