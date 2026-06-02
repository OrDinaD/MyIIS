//
//  AuthAPITest.swift
//  MyIIS
//
import Foundation

/// Тест для проверки API аутентификации и получения профиля
class AuthAPITest {

    private let apiService = APIService()
    private let logService = LogService.shared

    /// Тест полного цикла: логин -> получение профиля
    func testFullAuthFlow() async {
        logService.log("🧪 Starting Full Auth Flow Test")
        logService.log("=" * 60)

        guard
            let username = ProcessInfo.processInfo.environment["IIS_USERNAME"],
            let password = ProcessInfo.processInfo.environment["IIS_PASSWORD"],
            !username.isEmpty,
            !password.isEmpty
        else {
            logService.log("⚠️ Set IIS_USERNAME and IIS_PASSWORD to run Full Auth Flow Test")
            return
        }

        do {
            // Шаг 1: Логин
            logService.log("\n📝 Step 1: Login")
            logService.log("Username: \(username)")
            logService.log("Password: [REDACTED]")

            let loginResponse = try await apiService.login(username: username, password: password)
            logService.log("✅ Login successful!")
                logService.log("\n📊 User Data:")
                logService.log("Username: \(loginResponse.username)")
                logService.log("Full Name: \(loginResponse.fio)")
                logService.log("Email: \(loginResponse.email)")
                logService.log("Phone: \(loginResponse.phone)")
                logService.log("Group: \(loginResponse.group)")
                logService.log("Account Type: \(loginResponse.accountType)")
                if let photoUrl = loginResponse.photoUrl {
                    logService.log("Photo URL: \(photoUrl)")
                }
                logService.log("Is Group Head: \(loginResponse.isGroupHead ? "✓" : "✗")")

            logService.log("\n" + "=" * 60)
            logService.log("✅ Full Auth Flow Test PASSED")
            logService.log("=" * 60)

        } catch let error as APIError {
            logService.log("\n❌ API Error: \(error.localizedDescription)")
            logService.log("=" * 60)
            logService.log("❌ Full Auth Flow Test FAILED")
            logService.log("=" * 60)
        } catch {
            logService.log("\n❌ Unexpected Error: \(error.localizedDescription)")
            logService.log("=" * 60)
            logService.log("❌ Full Auth Flow Test FAILED")
            logService.log("=" * 60)
        }
    }

    /// Тест с неверными учетными данными
    func testInvalidCredentials() async {
        logService.log("\n🧪 Starting Invalid Credentials Test")
        logService.log("=" * 60)

        let username = "invalid_user"
        let password = "invalid_password"

        do {
            logService.log("📝 Attempting login with invalid credentials")
            logService.log("Username: \(username)")

            _ = try await apiService.login(username: username, password: password)

            // Если дошли сюда - тест провален
            logService.log("❌ Test FAILED: Should have thrown an error!")

        } catch let error as APIError {
            // Ожидаем ошибку 401
            logService.log("✅ Expected error received: \(error.localizedDescription)")
            logService.log("=" * 60)
            logService.log("✅ Invalid Credentials Test PASSED")
            logService.log("=" * 60)
        } catch {
            logService.log("❌ Unexpected error type: \(error)")
            logService.log("=" * 60)
            logService.log("❌ Invalid Credentials Test FAILED")
            logService.log("=" * 60)
        }
    }
}

// MARK: - Helper Extension

fileprivate extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
