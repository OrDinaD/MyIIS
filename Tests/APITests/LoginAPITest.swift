import Foundation

// Этот файл предназначен для ручного тестирования API.
// Он не является частью основного таргета приложения или юнит-тестов.

@MainActor
class LoginAPITest {
    
    static func runTest() async {
        print("🧪 Starting API login test...")
        
        let apiService = APIService()
        
        // Используем реальные учетные данные, предоставленные пользователем
        let username = "42850012"
        let password = "Bsuirinyouv.12_"
        
        do {
            let loginResponse = try await apiService.login(username: username, password: password)
            print("✅ Login successful!")
            print("   - Username: \(loginResponse.username)")
            print("   - Full name: \(loginResponse.fio)")
            print("   - Email: \(loginResponse.email)")
            print("   - Group: \(loginResponse.group)")
        } catch let error as APIError {
            print("❌ Login failed with API error: \(error.localizedDescription)")
        } catch {
            print("❌ Login failed with an unexpected error: \(error.localizedDescription)")
        }
        
        print("🏁 API login test finished.")
    }
}