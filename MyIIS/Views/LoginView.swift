//
//  LoginView.swift
//  MyIIS
//
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        .animation(.easeInOut, value: viewModel.errorMessage)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                header
                    .padding(.horizontal, 24)

                loginCard
                    .padding(.horizontal, 20)

                disclaimer
                    .padding(.horizontal, 24)

                Spacer(minLength: 28)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("login_title", comment: ""))
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("login_subtitle", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var loginCard: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("login_username_label", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(NSLocalizedString("login_username_placeholder", comment: ""), text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.default)
                    .textContentType(.username)
                    .submitLabel(.next)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(nativeFieldBackground(cornerRadius: 14))
                    .accessibilityIdentifier("usernameField")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("login_password_label", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                SecureField(NSLocalizedString("login_password_placeholder", comment: ""), text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(nativeFieldBackground(cornerRadius: 14))
                    .accessibilityIdentifier("passwordField")
            }

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                        .font(.caption)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.statusError.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.statusError.opacity(0.35), lineWidth: 1)
                        }
                )
                .foregroundStyle(Color.statusError)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                Task {
                    await viewModel.login()
                }
            } label: {
                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(NSLocalizedString("login_button", comment: ""))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("loginButton")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.2), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        )
    }

    private var disclaimer: some View {
        Text("Неофициальный клиент личного кабинета студента БГУиР")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func nativeFieldBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 1)
            }
    }
}

#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationService.shared)
    }
}
#endif
