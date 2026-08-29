import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image("FormeraLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 54)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await submit() } }
            }

            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isSubmitting)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .toast($errorMessage)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await auth.login(email: email, password: password)
        } catch APIError.requestFailed(let error) where error.status == 401 {
            errorMessage = "Incorrect email or password."
        } catch {
            errorMessage = "Couldn't log in: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
