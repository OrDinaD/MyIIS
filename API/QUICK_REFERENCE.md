# 🚨 БЫСТРАЯ СПРАВКА: API Endpoints

## Что использовать ПРЯМО СЕЙЧАС ✅

```swift
// Base URL
"https://iis.bsuir.by/api/v1"

// 1️⃣ Login
POST /api/v1/auth/login
Body: {"username": "42850012", "password": "xxx"}
Response: {username, fio, email, authorities, accountType, phone, group, photoUrl, ...}
Cookie: SESSION=xxx (автоматически)

// 2️⃣ Profile
GET /api/v1/personal-information
Headers: (SESSION cookie отправляется автоматически)
Response: {id, firstName, lastName, education[], skills[], settings, ...}
```

## Что НЕ работает ❌

```swift
// ❌ Из документации SwaggerHub - НЕ ИСПОЛЬЗУЙ!
POST /api/v2/auth           // 404 Not Found
POST /api/v1/auth           // 404 Not Found  
GET /api/v1/students/me     // Не проверено
GET /api/v2/students/me     // 404 Not Found

// ❌ JWT токены НЕ ИСПОЛЬЗУЮТСЯ!
// Authorization: Bearer {token}  // НЕ РАБОТАЕТ!
```

## Файлы с деталями 📁

1. **`REAL_API_ENDPOINTS.md`** - Полная документация рабочих эндпоинтов
2. **`API_REFERENCE.swift`** - SwaggerHub документация (УСТАРЕВШАЯ! Смотри WARNING внутри)
3. **`/Tests/api_test_results.json`** - Результаты Python тестирования
4. **`/Tests/login_response.json`** - Пример ответа при логине
5. **`/Tests/IMPLEMENTATION_REPORT.md`** - Отчёт о реализации

## Быстрый тест через Terminal 🧪

```bash
# Login test
curl -X POST "https://iis.bsuir.by/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"42850012","password":"xxx"}' \
  -c cookies.txt -v

# Profile test (использует cookies из предыдущего запроса)
curl "https://iis.bsuir.by/api/v1/personal-information" \
  -b cookies.txt
```

## Swift код (работает) ✅

```swift
// APIService.swift
static let baseURL = "https://iis.bsuir.by/api/v1"

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

func login(username: String, password: String) async throws -> LoginResponse {
    let url = URL(string: "\(baseURL)/auth/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(LoginRequest(username: username, password: password))
    
    let (data, _) = try await URLSession.shared.data(for: request)
    // SESSION cookie сохраняется автоматически!
    return try JSONDecoder().decode(LoginResponse.self, from: data)
}
```

---

**Последнее обновление:** 15 января 2025  
**Статус:** ✅ Протестировано и работает в production
