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
            let user = try await apiService.login(username: username, password: password)
            print("✅ Login successful!")
            print("   - User: \(user.fullName)")
            print("   - Email: \(user.email)")
            print("   - Group: \(user.academicGroup ?? "N/A")")
        } catch let error as APIError {
            print("❌ Login failed with API error: \(error.localizedDescription)")
        } catch {
            print("❌ Login failed with an unexpected error: \(error.localizedDescription)")
        }
        
        print("🏁 API login test finished.")
    }
}