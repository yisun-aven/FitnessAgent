import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var hasSelectedGoal = false

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                LoginView()
            } else if !hasSelectedGoal {
                GoalSelectionView(onContinue: { hasSelectedGoal = true })
            } else {
                HomeView(onSignOut: {
                    Task { await auth.signOut() }
                })
            }
        }
        .preferredColorScheme(.dark) // black/white palette
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(APIClient())
}
