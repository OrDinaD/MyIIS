//
//  SettingsModels.swift
//  MyIIS
//
import Foundation

/// Основные секции настроек профиля.
enum SettingsSection: String, CaseIterable, Identifiable {
    case profile
    case security
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:
            return "Профиль"
        case .security:
            return "Безопасность"
        case .notifications:
            return "Уведомления"
        }
    }

    var systemIcon: String {
        switch self {
        case .profile:
            return "person.crop.circle"
        case .security:
            return "lock.shield"
        case .notifications:
            return "bell.badge"
        }
    }
}

/// Тип аксессуара, который отображается рядом с пунктом настроек.
enum SettingsAccessoryType {
    case toggle
    case navigation
    case button
    case destructive
}

/// Конкретные пункты настроек внутри секций.
enum SettingsItem: Hashable, Identifiable {
    case publicProfile
    case jobSearch
    case showRating
    case changePassword
    case twoFactorAuth
    case academicNotifications
    case eventNotifications
    case logout

    var id: String {
        switch self {
        case .publicProfile:
            return "publicProfile"
        case .jobSearch:
            return "jobSearch"
        case .showRating:
            return "showRating"
        case .changePassword:
            return "changePassword"
        case .twoFactorAuth:
            return "twoFactorAuth"
        case .academicNotifications:
            return "academicNotifications"
        case .eventNotifications:
            return "eventNotifications"
        case .logout:
            return "logout"
        }
    }

    var section: SettingsSection {
        switch self {
        case .publicProfile, .jobSearch, .showRating:
            return .profile
        case .changePassword, .twoFactorAuth:
            return .security
        case .academicNotifications, .eventNotifications:
            return .notifications
        case .logout:
            return .security
        }
    }

    var title: String {
        switch self {
        case .publicProfile:
            return "Публичный профиль"
        case .jobSearch:
            return "Ищу работу"
        case .showRating:
            return "Показывать рейтинг"
        case .changePassword:
            return "Изменить пароль"
        case .twoFactorAuth:
            return "Двухфакторная аутентификация"
        case .academicNotifications:
            return "Академические уведомления"
        case .eventNotifications:
            return "События и мероприятия"
        case .logout:
            return "Выйти из аккаунта"
        }
    }

    var subtitle: String? {
        switch self {
        case .publicProfile:
            return "Отображать профиль другим студентам"
        case .jobSearch:
            return "Разрешить предложения стажировок"
        case .showRating:
            return "Показывать рейтинг в профиле"
        case .changePassword:
            return "Обновите пароль, чтобы повысить безопасность"
        case .twoFactorAuth:
            return "Добавьте дополнительный уровень защиты"
        case .academicNotifications:
            return "Получать уведомления об успеваемости"
        case .eventNotifications:
            return "Напоминания о мероприятиях университета"
        case .logout:
            return nil
        }
    }

    var accessory: SettingsAccessoryType {
        switch self {
        case .publicProfile, .jobSearch, .showRating, .twoFactorAuth, .academicNotifications, .eventNotifications:
            return .toggle
        case .changePassword:
            return .navigation
        case .logout:
            return .destructive
        }
    }

    var systemIcon: String {
        switch self {
        case .publicProfile:
            return "globe"
        case .jobSearch:
            return "briefcase"
        case .showRating:
            return "star.circle"
        case .changePassword:
            return "key.horizontal"
        case .twoFactorAuth:
            return "shield.lefthalf.filled"
        case .academicNotifications:
            return "bell"
        case .eventNotifications:
            return "calendar"
        case .logout:
            return "rectangle.portrait.and.arrow.forward"
        }
    }
}

/// Настройки безопасности пользователя.
struct SecuritySettings: Equatable {
    var isTwoFactorEnabled: Bool
}

extension SecuritySettings {
    static let `default` = SecuritySettings(isTwoFactorEnabled: false)
}

/// Настройки уведомлений пользователя.
struct NotificationSettings: Equatable {
    var academicUpdates: Bool
    var eventsAndNews: Bool
}

extension NotificationSettings {
    static let `default` = NotificationSettings(academicUpdates: true, eventsAndNews: false)
}

/// Возможные ошибки работы с настройками.
enum SettingsError: LocalizedError {
    case passwordsDoNotMatch
    case weakPassword
    case invalidCurrentPassword
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .passwordsDoNotMatch:
            return "Пароли не совпадают"
        case .weakPassword:
            return "Пароль должен содержать минимум 8 символов, цифры и буквы в разных регистрах"
        case .invalidCurrentPassword:
            return "Текущий пароль указан неверно"
        case .networkUnavailable:
            return "Сервис временно недоступен. Попробуйте позже"
        }
    }
}
