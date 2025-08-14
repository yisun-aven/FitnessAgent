import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false

    var body: some View {
        VStack(spacing: 16) {
            Text("FitnessAgent")
                .font(.largeTitle).bold()

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

            if let err = auth.errorMessage {
                Text(err).foregroundStyle(.red).font(.footnote)
            }

            Button(action: {
                Task {
                    if isSignup {
                        await auth.signUp(email: email, password: password)
                    } else {
                        await auth.signIn(email: email, password: password)
                    }
                }
            }) {
                Text(isSignup ? "Create account" : "Sign in")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

            Button(isSignup ? "Have an account? Sign in" : "New here? Sign up") {
                isSignup.toggle()
            }
            .font(.footnote)
            .padding(.top, 4)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
