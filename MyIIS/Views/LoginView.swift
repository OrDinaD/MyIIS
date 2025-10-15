//
//  LoginView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var isDebugPanelVisible = false
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color(uiColor: .systemBackground),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main login form UI
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text("MyIIS")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("БГУИР")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
                
                // Login Form Card
                VStack(spacing: 20) {
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Логин")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        TextField("Введите логин", text: $viewModel.username)
                            .textFieldStyle(.plain)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.purple.opacity(0.3), lineWidth: 1)
                                    }
                            }
                            .autocapitalization(.none)
                            .textContentType(.username)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пароль")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        SecureField("Введите пароль", text: $viewModel.password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.purple.opacity(0.3), lineWidth: 1)
                                    }
                            }
                            .textContentType(.password)
                    }
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red.opacity(0.1))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Login Button
                    Button {
                        Task {
                            await viewModel.login()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Войти")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .animation(.easeInOut, value: viewModel.errorMessage)

#if DEBUG
            // Debugger UI
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isDebugPanelVisible.toggle() }) {
                        Image(systemName: "ladybug.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .padding()
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                    }
                    .padding()
                }
                Spacer()
            }
            
            if isDebugPanelVisible {
                DebugView()
                    .background(.ultraThickMaterial)
                    .transition(.move(edge: .bottom))
            }
#endif
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