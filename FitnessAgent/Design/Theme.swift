import SwiftUI

enum AppTheme {
    static let bgTop = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let accent = Color(red: 0.98, green: 0.80, blue: 0.28)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)

    // Black-dominant → Orange → Light Blue gradient for backgrounds
    static let gradientColors: [Color] = [
        .black,                                // dominant black (top/leading)
        .black,                                // weight black more heavily
        Color(red: 0.95, green: 0.45, blue: 0.05), // orange (slightly deeper)
        Color(red: 0.28, green: 0.72, blue: 0.94)   // light blue (softened)
    ]

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Reusable button gradient for primary actions
    static var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.00, green: 0.80, blue: 0.30), Color(red: 1.00, green: 0.55, blue: 0.35)],
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
