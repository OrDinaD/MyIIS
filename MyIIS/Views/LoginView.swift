//
//  LoginView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct LoginView: View {
    /// ViewModel для управления логикой этого экрана
    @StateObject private var viewModel = LoginViewModel(apiService: APIService())
    
    var body: some View {
        ZStack {
            // Фоновый градиент
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Логотип
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                    .shadow(radius: 10)
                    .padding(.bottom, 16)
                
                // Форма входа
                VStack(spacing: 20) {
                    TextField("Логин (test)", text: $viewModel.username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                    
                    SecureField("Пароль (password)", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 32)
                
                // Сообщение об ошибке
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale))
                }
                
                // Кнопка входа
                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Войти")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: .blue.opacity(0.15), radius: 10, y: 5)
                )
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                
                Spacer()
            }
            .animation(.easeInOut, value: viewModel.errorMessage)
        }
    }
}

#Preview {
    LoginView()
}

#Preview("Loading") {
    let vm = LoginViewModel(apiService: APIService())
    vm.isLoading = true
    return LoginView()
}

#Preview("Error") {
    let vm = LoginViewModel(apiService: APIService())
    vm.errorMessage = "Неверный логин или пароль"
    return LoginView()
}