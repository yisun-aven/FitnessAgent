import SwiftUI

enum AppTheme {
    static let bgTop = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let bgBottom = Color(red: 0.02, green: 0.02, blue: 0.04)
    // Emerald accent to replace prior blue-ish/amber tones for a cohesive fitness vibe
    static let accent = Color(red: 0.98, green: 0.79, blue: 0.58)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)

    // Glass morphism surfaces and borders
    static let surface = Color.white.opacity(0.1)
    static let surfaceStrong = Color.white.opacity(0.1)
    static let border = Color.white.opacity(0.1)

    // Black-dominant → Orange → Light Blue gradient for backgrounds
    static let gradientColors: [Color] = [
        Color(red: 0.1, green: 0.1, blue: 0.1),                               // weight black more heavily
        // Color(red: 0.95, green: 0.45, blue: 0.05), // orange (slightly deeper)
        // Color(red: 0.28, green: 0.72, blue: 0.94),   // light blue (softened)
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

// MARK: - Reusable Glass Helpers
extension View {
    func glass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func pillGlass(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(AppTheme.surfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
