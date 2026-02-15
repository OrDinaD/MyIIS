#!/usr/bin/env swift

import Foundation

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let username: String
    let fio: String
    let email: String
    let authorities: [String]
    let accountType: String
    let phone: String
    let group: String
    let photoUrl: String?
    let isGroupHead: Bool
    let canStudentNote: Bool
    let hasNotConfirmedContact: Bool
    let hasProfiling: Bool
}

func testLogin() async throws {
    let baseURL = "https://iis.bsuir.by/api/v1"
    let endpoint = URL(string: "\(baseURL)/auth/login")!
    
    let loginData = LoginRequest(
        username: "42850012",
        password: "tyhfu1-jamhup-xehGow"
    )
    
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(loginData)
    
    print("🔄 Отправка запроса на вход...")
    print("📍 URL: \(endpoint)")
    print("👤 Пользователь: \(loginData.username)")
    print("")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "Invalid response", code: -1)
    }
    
    print("📡 Статус ответа: \(httpResponse.statusCode)")
    print("")
    
    if httpResponse.statusCode == 200 {
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        print("✅ ВХОД УСПЕШЕН!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("👤 Имя: \(loginResponse.fio)")
        print("📧 Email: \(loginResponse.email)")
        print("📱 Телефон: \(loginResponse.phone)")
        print("🎓 Группа: \(loginResponse.group)")
        print("📝 Тип аккаунта: \(loginResponse.accountType)")
        print("👨‍🎓 Староста: \(loginResponse.isGroupHead ? "Да" : "Нет")")
        if let photo = loginResponse.photoUrl {
            print("📷 Фото: \(photo)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if let cookies = HTTPCookieStorage.shared.cookies(for: endpoint) {
            print("\n🍪 Полученные cookies:")
            for cookie in cookies {
                print("  • \(cookie.name): \(cookie.value)")
            }
        }
        
    } else {
        print("❌ ОШИБКА ВХОДА!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if let errorString = String(data: data, encoding: .utf8) {
            print("Ответ сервера:")
            print(errorString)
        }
    }
}

Task {
    do {
        try await testLogin()
    } catch {
        print("❌ Критическая ошибка: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()
