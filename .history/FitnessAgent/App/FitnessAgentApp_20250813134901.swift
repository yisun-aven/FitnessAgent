import SwiftUI

@main
struct FitnessAgentApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var api = APIClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(api)
                .onAppear {
                    auth.configure()
                    api.configure(auth: auth)
                }
        }
    }
}
