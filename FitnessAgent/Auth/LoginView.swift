import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo + Title
                VStack(spacing: 8) {
                    Image(systemName: "figure.run.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.white)
                        .shadow(radius: 8)

                    Text("FitnessAgent")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                // Messages
                if let info = auth.infoMessage, !info.isEmpty {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                if let err = auth.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                // Form
                VStack(spacing: 12) {
                    Group {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    .padding(14)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)

                    Button(action: submit) {
                        HStack {
                            Spacer()
                            Text(isSignup ? "Create account" : "Sign in")
                                .font(.headline)
                                .foregroundStyle(.black)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                    .opacity(auth.isLoading ? 0.8 : 1)

                    Button(action: { withAnimation { isSignup.toggle() } }) {
                        Text(isSignup ? "Have an account? Sign in" : "New here? Sign up")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .underline()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)

                Spacer()

                Text("By continuing you agree to our Terms & Privacy")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }

            if auth.isLoading {
                ProgressView().tint(.white)
            }
        }
        .animation(.easeInOut, value: auth.isLoading)
        .onChange(of: auth.infoMessage) { _, newValue in
            // If we just created an account (and email confirmation may be required),
            // switch back to the sign-in form to guide the user.
            if newValue != nil { isSignup = false }
        }
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

#Preview { LoginView().environmentObject(AuthViewModel()) }
