
//
//  AuthenticationService.swift
//  MyIIS
//
//  Created by Gemini on 13.10.25.
//

import Foundation
import Combine

/// Сервис для управления состоянием аутентификации в приложении.
/// Использует паттерн Singleton и ObservableObject для отслеживания изменений.
@MainActor
class AuthenticationService: ObservableObject {
    
    /// `@Published` свойство, содержащее текущего аутентифицированного пользователя.
    /// UI будет автоматически обновляться при его изменении.
    @Published var currentUser: User?
    
    /// Статический экземпляр Singleton для доступа к сервису из любой точки приложения.
    static let shared = AuthenticationService()
    
    /// Приватный инициализатор для предотвращения создания других экземпляров.
    private init() {
        // В будущем здесь можно будет реализовать логику восстановления сессии из Keychain.
    }
    
    /// Выполняет вход пользователя в систему.
    /// - Parameter user: Объект пользователя, полученный после успешной аутентификации.
    func login(user: User) {
        self.currentUser = user
        print("✅ User logged in: \(user.fullName)")
        // В реальном приложении здесь следует сохранить токен или сессию в Keychain.
    }
    
    /// Выполняет выход пользователя из системы.
    func logout() {
        self.currentUser = nil
        print("🔴 User logged out.")
        // В реальном приложении здесь следует очистить данные сессии из Keychain.
    }
}
