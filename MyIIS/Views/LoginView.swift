//
//  LoginView.swift
//  MyIIS
//
//  Created by Codex on 02.02.26.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var isDebugPanelVisible = false
    @AppStorage("hasSeenLaunchReveal") private var hasSeenLaunchReveal = false

    @State private var showForm = false
    @State private var showRevealOverlay = false
    @State private var circleScale: CGFloat = 0.05
    @State private var hasTriggeredReveal = false

    private let revealDuration: TimeInterval = 1.65

    var body: some View {
        ZStack {
            VideoBackgroundView(resourceName: "LaunchBackground", resourceExtension: "mov")
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)
            .ignoresSafeArea()

            mainContent
                .opacity(showForm ? 1 : 0)
                .scaleEffect(showForm ? 1 : 0.96)
                .animation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.4), value: showForm)

            if showRevealOverlay {
                CircularRevealOverlay(scale: circleScale)
            }

#if DEBUG
            debugControls
#endif
        }
        .onAppear(perform: triggerInitialExperience)
        .animation(.easeInOut, value: viewModel.errorMessage)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 70)

            header
                .padding(.horizontal, 24)

            loginCard
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.bottom, 36)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Личный кабинет студента БГУиР")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 12)

            Text("Авторизуйтесь, чтобы продолжить")
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var loginCard: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Логин")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.8))

                TextField("Введите логин", text: $viewModel.username)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.default)
                    .textContentType(.username)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(glassFieldBackground(cornerRadius: 18))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Пароль")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.8))

                SecureField("Введите пароль", text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(glassFieldBackground(cornerRadius: 18))
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
                        Text("Войти")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: Color.buttonGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                )
                .foregroundStyle(.white)
                .liquidGlassShadow(color: .accentPurple, radius: 14)
            }
            .disabled(viewModel.isLoading)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .blur(radius: 32)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(LinearGradient.glassBorder, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 30, y: 24)
        )
    }

    private func glassFieldBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .blur(radius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

#if DEBUG
    @ViewBuilder
    private var debugControls: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { isDebugPanelVisible.toggle() }) {
                    Image(systemName: "ladybug.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentPurple)
                        .padding()
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.adaptiveShadow(opacity: 0.12), radius: 8)
                        }
                }
                .padding()
            }
            Spacer()
        }
        .sheet(isPresented: $isDebugPanelVisible) {
            DebugView()
        }
    }
#endif

    private func triggerInitialExperience() {
        guard !hasTriggeredReveal else { return }
        hasTriggeredReveal = true

        if hasSeenLaunchReveal {
            showForm = true
            showRevealOverlay = false
            circleScale = 1.8
            return
        }

        showRevealOverlay = true
        showForm = false
        circleScale = 0.08

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: revealDuration)) {
                circleScale = 1.85
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + revealDuration + 0.35) {
            withAnimation(.easeOut(duration: 0.45)) {
                showForm = true
                showRevealOverlay = false
            }
            hasSeenLaunchReveal = true
        }
    }
}

private struct CircularRevealOverlay: View {
    var scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let dimension = max(proxy.size.width, proxy.size.height)
            let circleSize = max(dimension * scale, 1)

            Color.black
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.05)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: circleSize, height: circleSize)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .opacity(scale < 1.4 ? 0.8 : 0)
                }
                .overlay {
                    Circle()
                        .frame(width: circleSize, height: circleSize)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .ignoresSafeArea()
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
