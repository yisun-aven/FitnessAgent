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
    @State private var selection: Int = 0
    var body: some View {
        TabView(selection: $selection) {
            Home()
                .tag(0)
            
            TasksTabView()
                .environmentObject(api)
                .tag(1)
            
            CoachChatScreen()
                .environmentObject(api)
                .tag(2)
            
            FriendsView()
                .tag(3)
            
            ProfileRootView()
                .tag(4)
        }
        // Hide the system tab bar; show our custom one floating as an overlay
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            CustomTabBar(selection: $selection)
                .padding(.bottom, 8)
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(APIClient())
}