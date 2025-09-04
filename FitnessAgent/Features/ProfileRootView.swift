import SwiftUI

struct ProfileRootView: View {
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