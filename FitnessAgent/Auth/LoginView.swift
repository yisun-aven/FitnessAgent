import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var showPassword = false

    var body: some View {
        ThemedBackground {
            ZStack {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 40)

                        // Brand + Title
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.heart")
                                    .imageScale(.large)
                                    .foregroundStyle(AppTheme.accent)
                                Text("FitnessAgent")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            }
                            Rectangle()
                                .fill(AppTheme.accent.opacity(0.6))
                                .frame(width: 64, height: 2)
                                .cornerRadius(1)

                            Text(isSignup ? "Create your account" : "Welcome back")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        // Feedback messages
                        VStack(spacing: 10) {
                            if let info = auth.infoMessage, !info.isEmpty {
                                banner(text: info, color: .green)
                            }
                            if let err = auth.errorMessage, !err.isEmpty {
                                banner(text: err, color: .red)
                            }
                        }
                        .padding(.horizontal)

                        // Form Card
                        VStack(spacing: 14) {
                            LabeledField(systemImage: "envelope.fill") {
                                TextField("Email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.username)
                            }

                            LabeledField(systemImage: "lock.fill") {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textContentType(.password)
                            } trailing: {
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: submit) {
                                HStack {
                                    Spacer()
                                    Text(isSignup ? "Create account" : "Sign in")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .background(AppTheme.accent)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                            .opacity(auth.isLoading ? 0.85 : 1)

                            Button(action: { withAnimation { isSignup.toggle() } }) {
                                Text(isSignup ? "Have an account? Sign in" : "New here? Sign up")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .underline()
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal)

                        Spacer(minLength: 24)

                        Text("By continuing you agree to our Terms & Privacy")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.bottom, 20)
                    }
                }

                if auth.isLoading {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView().tint(AppTheme.accent)
                }
            }
        }
        .animation(.easeInOut, value: auth.isLoading)
        .onChange(of: auth.infoMessage) { _, newValue in
            // If we just created an account (and email confirmation may be required),
            // switch back to the sign-in form to guide the user.
            if newValue != nil { isSignup = false }
        }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func submit() {
        haptic()
        Task {
            if isSignup { await auth.signUp(email: email, password: password) }
            else { await auth.signIn(email: email, password: password) }
        }
    }

    private func haptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

private struct LabeledField<Content: View, Trailing: View>: View {
    let systemImage: String
    let content: () -> Content
    let trailing: () -> Trailing

    init(systemImage: String, @ViewBuilder content: @escaping () -> Content, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.systemImage = systemImage
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.textSecondary)
            content()
                .foregroundStyle(AppTheme.textPrimary)
            trailing()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension LabeledField where Trailing == EmptyView {
    init(systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(systemImage: systemImage, content: content, trailing: { EmptyView() })
    }
}

#Preview { LoginView().environmentObject(AuthViewModel()) }
