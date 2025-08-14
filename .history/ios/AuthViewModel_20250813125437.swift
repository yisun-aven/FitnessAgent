import Foundation
import Combine
import Supabase

final class AuthViewModel: ObservableObject {
    @Published private(set) var client: SupabaseClient?
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    func configure() {
        guard client == nil else { return }
        let client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
        self.client = client

        // Restore session if available
        Task { @MainActor in
            do {
                let session = try await client.auth.session
                self.session = session
            } catch {
                // no persisted session
            }
        }

        // Listen to auth state changes
        client.auth.stateChange.sink { [weak self] event, session in
            DispatchQueue.main.async {
                self?.session = session
            }
        }.store(in: &cancellables)
    }

    var isAuthenticated: Bool { session != nil }
    var accessToken: String? { session?.accessToken }

    func signIn(email: String, password: String) async {
        guard let client else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func signUp(email: String, password: String) async {
        guard let client else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func signOut() async {
        guard let client else { return }
        do { try await client.auth.signOut() } catch { print("signOut error: \(error)") }
    }
}
