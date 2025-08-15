import SwiftUI

enum AppTheme {
    static let bgTop = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let accent = Color(red: 0.98, green: 0.80, blue: 0.28)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgTop, bgBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ThemedBackground<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            content()
        }
        .tint(AppTheme.accent)
        .foregroundStyle(AppTheme.textPrimary)
    }
}
