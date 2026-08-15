import SwiftUI
import UIKit

struct FirstLaunchView: View {
    static let completionKey = "has_completed_first_launch"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var loginViewModel = LoginViewModel()
    @State private var stage: Stage = .choices
    @State private var introPhase: IntroPhase
    @FocusState private var focusedField: LoginField?

    let showsControls: Bool
    let onContinueWithoutAccount: () -> Void

    init(
        showsControls: Bool = true,
        onContinueWithoutAccount: @escaping () -> Void
    ) {
        self.showsControls = showsControls
        self.onContinueWithoutAccount = onContinueWithoutAccount
        _introPhase = State(initialValue: showsControls ? .video : .ready)
    }

    private enum IntroPhase {
        case video
        case handoff
        case moving
        case ready
    }

    private enum Stage {
        case choices
        case login
    }

    private enum LoginField {
        case username
        case password
    }

    private static let appIconImage: UIImage? = {
        guard let url = Bundle.main.url(
            forResource: "Default-iOS-Default-1024x1024@1x",
            withExtension: "png"
        ) else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 64, 280), 340)
            let isInterfaceVisible = introPhase == .ready

            ZStack {
                interfaceContent(
                    contentWidth: contentWidth,
                    availableWidth: proxy.size.width,
                    availableHeight: proxy.size.height
                )
                .opacity(isInterfaceVisible ? 1 : 0)
                .allowsHitTesting(isInterfaceVisible)
                .accessibilityHidden(!isInterfaceVisible)

                if !isInterfaceVisible {
                    transitionIcon(in: proxy.size)
                }

                if !reduceMotion && (introPhase == .video || introPhase == .handoff) {
                    FirstLaunchVideoView(onFinished: beginVideoHandoff)
                        .ignoresSafeArea()
                        .opacity(introPhase == .video ? 1 : 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                if !isInterfaceVisible {
                    launchVideoBackdrop
                        .opacity(introPhase == .moving ? 0 : 1)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.65),
                            value: introPhase
                        )
                }
            }
            .background {
                welcomeBackground
            }
        }
        .overlay(alignment: .topLeading) {
            if stage == .login, introPhase == .ready {
                backButton
                    .padding(.top, 8)
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .task(id: introPhase) {
            await advanceIntroIfNeeded()
        }
        .onTapGesture(count: 3) {
            skipIntro()
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.12), value: stage)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: loginViewModel.errorMessage)
        .reduceMotionSensitive()
    }
}

private extension FirstLaunchView {
    @ViewBuilder
    func interfaceContent(
        contentWidth: CGFloat,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        if stage == .choices {
            VStack(spacing: 0) {
                appIcon
                    .frame(width: 164, height: 164)
                    .padding(.top, 44)

                Spacer(minLength: 72)

                if showsControls {
                    choices
                        .frame(width: contentWidth)
                }

                Spacer(minLength: 96)
            }
            .frame(width: availableWidth)
            .frame(minHeight: availableHeight)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    appIcon
                        .frame(width: 104, height: 104)
                        .padding(.top, 20)

                    loginForm
                        .frame(width: contentWidth)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
                .frame(width: availableWidth)
                .frame(minHeight: availableHeight)
            }
            .frame(width: availableWidth)
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    var launchVideoBackdrop: some View {
        Color(red: 0.53, green: 0.67, blue: 0.76)
            .ignoresSafeArea()
    }

    func transitionIcon(in size: CGSize) -> some View {
        let isMoving = introPhase == .moving
        let iconSize = isMoving ? 164 : min(size.width * 0.76, 320)
        let iconCenterY = isMoving ? 126 : size.height / 2

        return appIcon
            .frame(width: iconSize, height: iconSize)
            .position(x: size.width / 2, y: iconCenterY)
            .opacity(introPhase == .video && !reduceMotion ? 0 : 1)
            .accessibilityHidden(true)
    }

    func beginVideoHandoff() {
        guard introPhase == .video else { return }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            introPhase = .handoff
        }
    }

    func skipIntro() {
        guard introPhase != .ready else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            introPhase = .ready
        }
    }

    func advanceIntroIfNeeded() async {
        guard showsControls else { return }

        if reduceMotion, introPhase == .video {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            introPhase = .ready
            return
        }

        switch introPhase {
        case .handoff:
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.52, bounce: 0.12)) {
                introPhase = .moving
            }
        case .moving:
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                introPhase = .ready
            }
        case .video, .ready:
            break
        }
    }

    var welcomeBackground: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.28))
                .frame(width: 360, height: 360)
                .blur(radius: 2)
                .offset(x: -190, y: -330)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.08 : 0.13))
                .frame(width: 430, height: 430)
                .blur(radius: 6)
                .offset(x: 220, y: 370)
        }
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.12, blue: 0.27),
                Color(red: 0.08, green: 0.23, blue: 0.39),
                Color(red: 0.11, green: 0.17, blue: 0.34)
            ]
        }

        return [
            Color(red: 0.86, green: 0.96, blue: 1.00),
            Color(red: 0.65, green: 0.88, blue: 0.99),
            Color(red: 0.77, green: 0.84, blue: 0.98)
        ]
    }

    private var appIcon: some View {
        Group {
            if let image = Self.appIconImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.indigo)
            }
        }
        .shadow(color: Color.indigo.opacity(0.24), radius: 24, y: 14)
        .accessibilityLabel(NSLocalizedString("first_launch_app_icon", comment: ""))
    }

    private var choices: some View {
        VStack(spacing: 14) {
            Button {
                focusedField = nil
                withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.12)) {
                    stage = .login
                }
            } label: {
                Text(NSLocalizedString("first_launch_sign_in", comment: ""))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .welcomePrimaryButtonStyle()
            .accessibilityIdentifier("firstLaunchSignInButton")

            Button(action: onContinueWithoutAccount) {
                Text(NSLocalizedString("first_launch_continue_guest", comment: ""))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .welcomeSecondaryButtonStyle()
            .accessibilityIdentifier("firstLaunchGuestButton")
        }
    }

    private var loginForm: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                loginFields

                if let errorMessage = loginViewModel.errorMessage {
                    errorBanner(errorMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                signInButton
                serverStatus
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42), lineWidth: 1)
            }
            .shadow(color: Color.indigo.opacity(0.14), radius: 24, y: 14)

            Text(NSLocalizedString("login_disclaimer", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .disabled(loginViewModel.isLoading)
        .overlay {
            if loginViewModel.isLoading {
                loadingOverlay
            }
        }
    }

    private var loginFields: some View {
        VStack(spacing: 14) {
            TextField(
                NSLocalizedString("login_username_placeholder", comment: ""),
                text: $loginViewModel.username
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.username)
            .submitLabel(.next)
            .focused($focusedField, equals: .username)
            .onSubmit {
                focusedField = .password
            }
            .welcomeTextFieldStyle()
            .accessibilityLabel(NSLocalizedString("login_username_label", comment: ""))
            .accessibilityIdentifier("usernameField")

            SecureField(
                NSLocalizedString("login_password_placeholder", comment: ""),
                text: $loginViewModel.password
            )
            .textContentType(.password)
            .submitLabel(.go)
            .focused($focusedField, equals: .password)
            .onSubmit {
                submitLogin()
            }
            .welcomeTextFieldStyle()
            .accessibilityLabel(NSLocalizedString("login_password_label", comment: ""))
            .accessibilityIdentifier("passwordField")
        }
    }

    private var signInButton: some View {
        Button(action: submitLogin) {
            HStack(spacing: 10) {
                if loginViewModel.isServerActive == nil {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(NSLocalizedString("login_button", comment: ""))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .welcomePrimaryButtonStyle()
        .disabled(loginViewModel.isServerActive != true)
        .accessibilityIdentifier("loginButton")
    }

    private var serverStatus: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: serverStatusIcon)
                    .foregroundStyle(serverStatusColor)
                    .symbolEffect(.pulse, isActive: loginViewModel.isServerActive != false)
                    .accessibilityHidden(true)

                Text(serverStatusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                if loginViewModel.isServerActive != true {
                    Button {
                        loginViewModel.checkServerStatus()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(NSLocalizedString("first_launch_server_retry", comment: ""))
                }
            }

            if loginViewModel.isServerActive == false {
                Text(NSLocalizedString("first_launch_server_unavailable_message", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onContinueWithoutAccount) {
                    Text(NSLocalizedString("first_launch_continue_guest", comment: ""))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .welcomeSecondaryButtonStyle()
                .accessibilityIdentifier("serverUnavailableGuestButton")
            }
        }
        .padding(14)
        .background(serverStatusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(serverStatusColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var serverStatusTitle: String {
        switch loginViewModel.isServerActive {
        case true:
            return NSLocalizedString("first_launch_server_available", comment: "")
        case false:
            return NSLocalizedString("first_launch_server_unavailable", comment: "")
        case nil:
            return NSLocalizedString("first_launch_server_checking", comment: "")
        }
    }

    private var serverStatusIcon: String {
        switch loginViewModel.isServerActive {
        case true:
            return "network"
        case false:
            return "xmark.circle.fill"
        case nil:
            return "network"
        }
    }

    private var serverStatusColor: Color {
        switch loginViewModel.isServerActive {
        case true:
            return .green
        case false:
            return .red
        case nil:
            return .orange
        }
    }

    private var backButton: some View {
        Button {
            focusedField = nil
            withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.1)) {
                stage = .choices
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.headline)
                .frame(width: 44, height: 44)
        }
        .welcomeSecondaryButtonStyle()
        .accessibilityLabel(NSLocalizedString("common_back", value: "Назад", comment: ""))
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.08)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            ProgressView(NSLocalizedString("login_loading", comment: ""))
                .padding(22)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func submitLogin() {
        focusedField = nil
        Task {
            await loginViewModel.login()
        }
    }
}

private extension View {
    @ViewBuilder
    func welcomePrimaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
        } else {
            buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
        }
    }

    @ViewBuilder
    func welcomeSecondaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 18))
        } else {
            buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 18))
        }
    }

    func welcomeTextFieldStyle() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(
                Color(uiColor: .secondarySystemBackground).opacity(0.84),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
            }
    }
}

#Preview("Первый запуск") {
    FirstLaunchView(onContinueWithoutAccount: {})
}

#Preview("Кадр для видео") {
    FirstLaunchView(showsControls: false, onContinueWithoutAccount: {})
}
