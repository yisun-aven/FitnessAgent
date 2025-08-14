import Foundation
import Combine
import Supabase

final class AuthViewModel: ObservableObject {
    @Published private(set) var client: SupabaseClient?
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var cancellables = Set<AnyCancellable>()

    func configure() {
        guard client == nil else { return }
        let client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
        self.client = client

        Task {
            do {
                let current = try await client.auth.session
                await MainActor.run { self.session = current }
            } catch {}

            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run { self.session = session }
            }
        }

        // client.auth.stateChange.sink { [weak self] _, session in
        //     DispatchQueue.main.async { self?.session = session }
        // }.store(in: &cancellables)
    }

    var isAuthenticated: Bool { session != nil }
    var accessToken: String? { session?.accessToken }

    func signIn(email: String, password: String) async {
        guard let client else { return }
        await MainActor.run { isLoading = true; errorMessage = nil; infoMessage = nil }
        do { _ = try await client.auth.signIn(email: email, password: password) }
        catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("not confirmed") || msg.contains("confirm") || msg.contains("not allowed") {
                await MainActor.run {
                    errorMessage = nil
                    infoMessage = "Email not confirmed. Please check your inbox and spam for the verification email, then sign in."
                }
            } else {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
        await MainActor.run { isLoading = false }
    }

    func signUp(email: String, password: String) async {
        guard let client else { return }
        await MainActor.run { isLoading = true; errorMessage = nil; infoMessage = nil }
        do {
            let _ = try await client.auth.signUp(email: email, password: password)
            // Session may be nil if email confirmation is required. The authStateChanges stream will update session when available.
            await MainActor.run { infoMessage = "Account created. If email confirmation is required, check your inbox, then sign in." }
            // Ensure we always redirect to the login screen regardless of whether Supabase created a session.
            try? await client.auth.signOut()
        }
        catch {
            let message = error.localizedDescription.lowercased()
            // Supabase typically returns messages like "User already registered" / "already exists"
            if message.contains("already registered") || message.contains("already exists") || message.contains("duplicate") {
                await MainActor.run {
                    errorMessage = nil
                    infoMessage = "Account already exists. Please sign in."
                }
            } else {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
        await MainActor.run { isLoading = false }
    }

    func signOut() async { try? await client?.auth.signOut() }
}
