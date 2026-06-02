//
//  AccountSettingsModels.swift
//  MyIIS
//
import Foundation

enum AccountSettingsTab: String, CaseIterable, Identifiable, Hashable {
    case password
    case contacts
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .password:
            return NSLocalizedString("settings_tab_password", comment: "")
        case .contacts:
            return NSLocalizedString("settings_tab_contacts", comment: "")
        case .photo:
            return NSLocalizedString("settings_tab_photo", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .password:
            return "lock"
        case .contacts:
            return "phone"
        case .photo:
            return "camera"
        }
    }
}

struct PasswordAttemptsDTO: Decodable {
    let passwordAttempts: Int
    let passwordBanExpiredTime: String?
}

struct ContactSettingsDTO: Decodable {
    let contactDtoList: [ContactDTO]
    let mobilePhoneAttempts: Int
    let emailAttempts: Int
    let contactBanExpiredTime: String?
}

struct ContactDTO: Decodable, Identifiable, Equatable {
    let id: Int
    let contactValue: String
    let contactTypeId: Int
    let confirmed: Bool
    let codeExpirationTime: String?
}

struct ContactUpdateRequest: Encodable {
    let id: Int
    let contactTypeId: Int
    let contactValue: String
}

struct ContactConfirmRequest: Encodable {
    let contactId: Int
    let code: String
}

struct ChangePasswordRequest: Encodable {
    let oldPassword: String
    let newPassword: String
}

struct ChangePhotoRequest: Encodable {
    let photoBase64String: String
}

struct ContactSendConfirmResponse: Decodable {
    let codeExpirationTime: String?
}

enum ContactType: Int {
    case mobilePhone = 4
    case email = 6
}
