import Foundation
import Security

struct StoredCredentials: Codable {
    let username: String
    let password: String
}

enum CredentialStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error with status: \(status)"
        case .decodingFailed:
            return "Не удалось прочитать сохранённые учетные данные."
        }
    }
}

final class CredentialStore {
    static let shared = CredentialStore()

    private let service = "by.bsuir.MyIIS.auth"
    private let account = "userCredentials"

    private init() {}

    func save(_ credentials: StoredCredentials) throws {
        let encoded = try JSONEncoder().encode(credentials)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var newItem = baseQuery
        newItem[kSecValueData as String] = encoded
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newItem as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    func retrieve() throws -> StoredCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialStoreError.unexpectedStatus(status)
        }

        guard let credentials = try? JSONDecoder().decode(StoredCredentials.self, from: data) else {
            throw CredentialStoreError.decodingFailed
        }

        return credentials
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }
}
