import Foundation

struct PasswordExpiryResponse: Decodable {
    let error: String
}

/// Contract captured from the IIS password recovery flow on 2026-10-19.
struct PasswordRecoveryAccount: Decodable, Identifiable, Sendable {
    let id: Int
    let login: String
    let isBlocked: Bool

    private enum CodingKeys: String, CodingKey {
        case id, login, expireBanDate
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        login = try values.decode(String.self, forKey: .login)
        isBlocked = try values.contains(.expireBanDate) && !values.decodeNil(forKey: .expireBanDate)
    }
}

struct PasswordRecoveryCodeLifetime: Decodable {
    let codeLifetimeSeconds: Int
}

struct PasswordRecoveryConfirmation: Decodable, Sendable {
    let token: String
    let login: String
}

struct PasswordRecoveryContact: Encodable {
    let accountId: Int
    let contactValue: String
}

struct PasswordRecoveryCode: Encodable {
    let accountId: Int
    let confirmCode: String
    let contactValue: String
}

struct PasswordRecoveryNewPassword: Encodable {
    let login: String
    let token: String
    let newPassword: String

    private enum CodingKeys: String, CodingKey {
        case login, token, currentPassword, newPassword
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(login, forKey: .login)
        try values.encode(token, forKey: .token)
        try values.encodeNil(forKey: .currentPassword)
        try values.encode(newPassword, forKey: .newPassword)
    }
}

struct PasswordRecoveryFailure: LocalizedError {
    let key: String

    var errorDescription: String? { NSLocalizedString(key, comment: "") }
}
