import SwiftUI

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            ThemedBackground { Text("Friends coming soon").padding() }
                .navigationTitle("Friends")
        }
    }
}