
//
//  User.swift
//  MyIIS
//
//  Created by Gemini on 13.10.25.
//

import Foundation

/// Модель данных пользователя
struct User: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let firstName: String
    let lastName: String
    let middleName: String
    let email: String
    let photoUrl: URL?
    let academicGroup: String?
    
    /// Полное имя для отображения
    var fullName: String {
        "\(lastName) \(firstName) \(middleName)"
    }
    
    /// Инициалы
    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

#if DEBUG
extension User {
    /// Тестовый пользователь для превью и отладки
    static let mock = User(
        id: UUID(),
        username: "testuser",
        firstName: "Иван",
        lastName: "Иванов",
        middleName: "Иванович",
        email: "ivanov.ivan@example.com",
        photoUrl: URL(string: "https://i.pravatar.cc/150"),
        academicGroup: "123456"
    )
}
#endif
