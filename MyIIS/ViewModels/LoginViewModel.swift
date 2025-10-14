//
//  LoginViewModel.swift
//  MyIIS
//
//  ViewModel для экрана авторизации
//  Паттерн: MVVM
//

import Foundation
import SwiftUI
import Combine

/// ViewModel для управления логикой авторизации
///
/// Отвечает за:
/// - Валидацию введенных данных
/// - Взаимодействие с API через APIService
/// - Управление состоянием UI (загрузка, ошибки)
@MainActor
class LoginViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let apiService: APIService

    // MARK: - Initialization
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Public Methods
    
    /// Выполнить авторизацию
    func login() async {
        // Валидация перед отправкой
        guard validateInput() else { return }
        
        // Начало загрузки
        isLoading = true
        errorMessage = nil
        
        do {
            // Попытка авторизации через API
            let user = try await apiService.login(
                username: username,
                password: password
            )
            
            // Успешная авторизация: передаем пользователя в сервис аутентификации
            AuthenticationService.shared.login(user: user)
            
            // ... в функции login()
            } catch let error as APIError {
                // Обработка API ошибок
                errorMessage = "Login failed for user: \(username), pass: \(password). Error: \(error.localizedDescription)"
            } catch {
                // Обработка других ошибок
                errorMessage = "Неизвестная ошибка: \(error.localizedDescription)"
            }
        
        // Конец загрузки
        isLoading = false
    }
    
    /// Очистить форму
    func clearForm() {
        username = ""
        password = ""
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Валидация введенных данных
    /// - Returns: true если данные валидны
    private func validateInput() -> Bool {
        // Проверка логина
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Введите логин"
            return false
        }
        
        // Проверка пароля
        guard !password.isEmpty else {
            errorMessage = "Введите пароль"
            return false
        }
        
        // Минимальная длина пароля
        guard password.count >= 6 else {
            errorMessage = "Пароль должен содержать минимум 6 символов"
            return false
        }
        
        return true
    }
    
    /// Обработка ошибок API
    /// - Parameter error: Ошибка от API
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .unauthorized:
            errorMessage = "Неверный логин или пароль"
        case .invalidURL:
            errorMessage = "Неверный URL запроса"
        case .networkError:
            errorMessage = "Ошибка сети. Проверьте подключение к интернету"
        case .serverError(let code):
            errorMessage = "Ошибка сервера (\(code)). Попробуйте позже"
        case .invalidResponse:
            errorMessage = "Некорректный ответ от сервера"
        case .decodingError:
            errorMessage = "Ошибка обработки данных"
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension LoginViewModel {
    /// Создать ViewModel для Preview с тестовыми данными
    static func preview() -> LoginViewModel {
        let viewModel = LoginViewModel(apiService: APIService())
        viewModel.username = "test_user"
        return viewModel
    }
    
    /// Создать ViewModel для Preview с ошибкой
    static func previewWithError() -> LoginViewModel {
        let viewModel = LoginViewModel(apiService: APIService())
        viewModel.errorMessage = "Неверный логин или пароль"
        return viewModel
    }
    
    /// Создать ViewModel для Preview в состоянии загрузки
    static func previewLoading() -> LoginViewModel {
        let viewModel = LoginViewModel(apiService: APIService())
        viewModel.isLoading = true
        return viewModel
    }
}
#endif
