//
//  ProfileView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        NavigationStack {
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
                
                // Проверяем, есть ли пользователь
                if let user = authService.currentUser {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Аватар
                            AsyncImage(url: user.photoUrl) {
                                $0.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                    .shadow(radius: 10)
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 120))
                                    .foregroundStyle(.gray.opacity(0.3))
                            }
                            
                            // Имя и группа
                            VStack(spacing: 4) {
                                Text(user.fullName)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                if let group = user.academicGroup {
                                    Text("Группа: \(group)")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Список с информацией
                            List {
                                Section(header: Text("Контактная информация")) {
                                    Label(user.email, systemImage: "envelope.fill")
                                }
                                
                                Section(header: Text("Действия")) {
                                    Button(role: .destructive, action: {
                                        authService.logout()
                                    }) {
                                        Label("Выйти из аккаунта", systemImage: "arrow.backward.square.fill")
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                            .frame(height: 250) // Ограничиваем высоту списка
                            .scrollDisabled(true)
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                } else {
                    // Если пользователя нет (например, после выхода)
                    VStack {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Нет данных о пользователе")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    // Создаем мок-сервис для превью
    let authService = AuthenticationService.shared
    authService.currentUser = User.mock
    
    return ProfileView()
        .environmentObject(authService)
}

#Preview("Logged Out") {
    let authService = AuthenticationService.shared
    authService.currentUser = nil // Убедимся, что для этого превью пользователя нет
    
    return ProfileView()
        .environmentObject(authService)
}