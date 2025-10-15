
//
//  User.swift
//  MyIIS
//
//  Created by Gemini on 13.10.25.
//

import Foundation

// MARK: - User Skill

struct UserSkill: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
}

// MARK: - User Reference

struct UserReference: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let reference: String
}

// MARK: - User Settings

struct UserSettings: Codable, Equatable {
    let isPublicProfile: Bool
    let isSearchJob: Bool
    let isShowRating: Bool
}

// MARK: - Education

struct Education: Codable, Equatable {
    let faculty: String
    let course: Int
    let speciality: String
    let group: String
}

// MARK: - User Model

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let firstName: String
    let lastName: String
    let middleName: String
    let birthDay: String
    let email: String?
    let phone: String?
    let photo: String?
    let summary: String?
    let rating: Int
    let education: Education
    let skills: [UserSkill]
    let references: [UserReference]
    let settings: UserSettings
    
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
    
    /// URL фотографии
    var photoURL: URL? {
        guard let photo = photo else { return nil }
        return URL(string: photo)
    }
    
    /// Отображаемый рейтинг (с учетом настроек)
    var displayRating: Int {
        settings.isShowRating ? rating : 0
    }
}

#if DEBUG
extension User {
    /// Тестовый пользователь для превью и отладки
    static let mock = User(
        id: 1,
        firstName: "Антон",
        lastName: "Парамонов",
        middleName: "Иванович",
        birthDay: "2000-01-15",
        email: "anton.paramonov@example.com",
        phone: "+375291234567",
        photo: nil,
        summary: "Студент БГУИР, увлекаюсь программированием и искусственным интеллектом",
        rating: 5,
        education: Education(
            faculty: "КСиС",
            course: 1,
            speciality: "ПОИТ",
            group: "851001"
        ),
        skills: [
            UserSkill(id: 1, name: "ИИ"),
            UserSkill(id: 2, name: "Swift"),
            UserSkill(id: 3, name: "iOS Development")
        ],
        references: [
            UserReference(id: 1, name: "vk", reference: "https://vk.com/id0"),
            UserReference(id: 2, name: "telegram", reference: "https://t.me/username")
        ],
        settings: UserSettings(
            isPublicProfile: true,
            isSearchJob: true,
            isShowRating: true
        )
    )
}
#endif
