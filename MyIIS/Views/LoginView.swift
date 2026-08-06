//
//  LoginView.swift
//  MyIIS
//
import SwiftUI

struct LoginView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = LoginViewModel()
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        .reduceMotionSensitive()
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.errorMessage)
    }

    private var backgroundView: some View {
        Color(uiColor: .systemGroupedBackground)
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
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color(uiColor: .systemBackground).opacity(0.4)
                        .ignoresSafeArea()

                    ProgressView()
                        .controlSize(.large)
                        .padding(32)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
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
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(nativeFieldBackground(cornerRadius: 14))
                    .accessibilityLabel(NSLocalizedString("login_username_label", comment: ""))
                    .accessibilityIdentifier("usernameField")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("login_password_label", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Group {
                        if isPasswordVisible {
                            TextField(
                                NSLocalizedString("login_password_placeholder", comment: ""),
                                text: $viewModel.password
                            )
                        } else {
                            SecureField(
                                NSLocalizedString("login_password_placeholder", comment: ""),
                                text: $viewModel.password
                            )
                        }
                    }
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await viewModel.login()
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("login_password_label", comment: ""))
                    .accessibilityIdentifier("passwordField")

                    Button {
                        isPasswordVisible.toggle()
                        focusedField = .password
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        isPasswordVisible
                            ? NSLocalizedString("login_password_hide", value: "Скрыть пароль", comment: "")
                            : NSLocalizedString("login_password_show", value: "Показать пароль", comment: "")
                    )
                    .accessibilityIdentifier("passwordVisibilityButton")
                }
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .padding(.vertical, 4)
                .background(nativeFieldBackground(cornerRadius: 14))
            }

            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.statusError)
                            .padding(.top, 2)

                        Text(errorMessage)
                            .font(.footnote)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.primary)

                    Link(destination: URL(string: "https://iis.bsuir.by")!) {
                        Text(NSLocalizedString("login_open_website", value: "Войти на сайт", comment: ""))
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHint(NSLocalizedString("login_open_website_hint", value: "Откроет сайт ИИС в браузере", comment: ""))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.statusError.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.statusError.opacity(0.2), lineWidth: 1)
                        }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            actionButtons
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

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.login()
                }
            } label: {
                if viewModel.isServerActive == nil {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(NSLocalizedString("login_button", comment: ""))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .disabled(viewModel.isServerActive != true)
            .accessibilityLabel(NSLocalizedString("login_button", comment: ""))
            .accessibilityIdentifier("loginButton")

            if viewModel.isServerActive == false {
                Text("Попробуйте зайти позже. Сервер БГУИР сейчас недоступен, и приложение не может ничего с этим сделать.")
                    .font(.footnote)
                    .foregroundStyle(Color.statusError)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var disclaimer: some View {
        Text(NSLocalizedString("login_disclaimer", comment: ""))
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
