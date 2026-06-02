# 🔴 РЕАЛЬНЫЕ API ЭНДПОИНТЫ MyIIS (v1)

> ⚠️ **ВНИМАНИЕ**: Официальная документация SwaggerHub (v2.0.0) **НЕ СООТВЕТСТВУЕТ** реальному API!  
> Этот файл содержит **проверенные и рабочие** эндпоинты, обнаруженные при тестировании.

## 📍 Base URL

```
https://iis.bsuir.by/api/v1
```

**НЕ v2** как указано в SwaggerHub документации!

---

## 🔐 Аутентификация

### ❌ ЧТО **НЕ РАБОТАЕТ** (из документации)

```swift
// ❌ НЕПРАВИЛЬНО (из SwaggerHub)
POST /auth
Request: { "username": "string", "password": "string" }
Response: { "token": "JWT_TOKEN_STRING" }
Authorization: Bearer {JWT_TOKEN}
```

### ✅ ЧТО **РЕАЛЬНО РАБОТАЕТ**

#### POST `/api/v1/auth/login` - Вход в систему

**Request:**
```json
{
  "username": "12345678",
  "password": "your_password"
}
```

**Response (200 OK):**
```json
{
  "username": "12345678",
  "fio": "Иванов Иван Иванович",
  "email": "student@example.com",
  "authorities": [],
  "accountType": "STUDENT",
  "phone": "+375291234567",
  "group": "000000",
  "photoUrl": "https://example.com/photo.jpg",
  "isGroupHead": false,
  "canStudentNote": false,
  "hasNotConfirmedContact": false,
  "hasProfiling": false
}
```

**Response Headers:**
```
Set-Cookie: SESSION=MDc2N2ZiYzAtZWMxNS00YzkxLTgxODQtYzQ4ZmYxMGVhOTQ5; Path=/api/v1; Secure; HttpOnly; SameSite=None
```

**🔑 Тип аутентификации: COOKIE-BASED (не JWT!)**

- Cookie name: `SESSION`
- Атрибуты: `Secure`, `HttpOnly`, `SameSite=None`
- Path: `/api/v1`
- Все последующие запросы должны включать этот cookie

**Swift пример:**
```swift
struct LoginResponse: Codable {
    let username: String
    let fio: String           // ФИО в формате "Фамилия Имя Отчество"
    let email: String
    let authorities: [String]
    let accountType: String   // "STUDENT", "TEACHER", etc.
    let phone: String
    let group: String         // Номер группы, например "000000"
    let photoUrl: String?
    let isGroupHead: Bool
    let canStudentNote: Bool
    let hasNotConfirmedContact: Bool
    let hasProfiling: Bool
}

// URLSession автоматически сохраняет cookies
// Используйте .shared или кастомную конфигурацию с HTTPCookieStorage
```

**Response Codes:**
- `200 OK` - Успешная аутентификация, возвращает данные пользователя + SESSION cookie
- `401 Unauthorized` - Неверные credentials
- `404 Not Found` - Неправильный URL (например, `/auth` вместо `/auth/login`)

---

## 👤 Профиль пользователя

### GET `/api/v1/personal-information` - Дополнительная информация о пользователе

**Требуется:** SESSION cookie (автоматически отправляется после логина)

**Response (200 OK):**
```json
{
  "id": 26198,
  "firstName": "Владислав",
  "lastName": "Иванов",
  "middleName": "Валерьевич",
  "degree": null,
  "rating": 0,
  "course": 1,
  "department": null,
  "speciality": null,
  "faculty": null,
  "canStudentNote": false,
  "enablePractice": false,
  "practiceType": null,
  "kt": null,
  "re": null,
  "graduating": false,
  "summary": null,
  "photo": "https://example.com/photo.jpg",
  "birthDate": "2000-01-01",
  "sex": null,
  "hobby": null,
  "citizenship": null,
  "universityEmail": null,
  "currentPosition": null,
  "education": [
    {
      "id": 72936,
      "faculty": "КСиС",
      "course": 1,
      "speciality": "ПОИТ",
      "group": "000000"
    }
  ],
  "skills": [],
  "references": [],
  "settings": {
    "isPublicProfile": true,
    "isSearchJob": false,
    "isShowRating": false
  }
}
```

**Swift модель:**
```swift
struct PersonalInformation: Codable {
    let id: Int
    let firstName: String
    let lastName: String
    let middleName: String
    let degree: String?
    let rating: Int
    let course: Int
    let department: String?
    let speciality: String?
    let faculty: String?
    let canStudentNote: Bool
    let enablePractice: Bool
    let practiceType: String?
    let kt: String?
    let re: String?
    let graduating: Bool
    let summary: String?
    let photo: String?
    let birthDate: String  // Format: "YYYY-MM-DD"
    let sex: String?
    let hobby: String?
    let citizenship: String?
    let universityEmail: String?
    let currentPosition: String?
    let education: [Education]
    let skills: [Skill]
    let references: [Reference]
    let settings: Settings
    
    struct Education: Codable {
        let id: Int
        let faculty: String    // "КСиС", "ФРЭ", etc.
        let course: Int
        let speciality: String // "ПОИТ", "ПИ", etc.
        let group: String      // "000000", etc.
    }
    
    struct Skill: Codable {
        let id: Int
        let name: String
    }
    
    struct Reference: Codable {
        let id: Int
        let name: String
        let reference: String  // URL
    }
    
    struct Settings: Codable {
        let isPublicProfile: Bool
        let isSearchJob: Bool
        let isShowRating: Bool
    }
}
```

**Response Codes:**
- `200 OK` - Успешно получена информация
- `401 Unauthorized` - Отсутствует или истёк SESSION cookie
- `403 Forbidden` - Нет прав доступа

---

## 📊 Сравнение: Документация vs Реальность

| Параметр | SwaggerHub v2.0.0 | Реальное API v1 |
|----------|-------------------|-----------------|
| **Base URL** | `/api/v2` | `/api/v1` ✅ |
| **Login Endpoint** | `POST /auth` | `POST /auth/login` ✅ |
| **Authentication Type** | JWT Token | SESSION Cookie ✅ |
| **Login Response** | `{token: string}` | `{username, fio, email, ...}` ✅ |
| **Authorization Header** | `Bearer {token}` | Не используется ✅ |
| **Session Management** | Не описана | Cookie-based ✅ |
| **Profile Endpoint** | `GET /students/me` | `GET /personal-information` ✅ |

---

## 🧪 Проверенные эндпоинты

### ✅ Работают (протестировано)

1. **POST** `/api/v1/auth/login` - Аутентификация
   - Status: 200 OK
   - Возвращает: LoginResponse + SESSION cookie

2. **GET** `/api/v1/personal-information` - Профиль пользователя
   - Status: 200 OK (требуется SESSION cookie)
   - Возвращает: PersonalInformation

### ❌ Не работают (404 Not Found)

1. **POST** `/api/v1/auth` - Указан в документации, но не существует
2. **POST** `/api/v2/auth` - API v2 не доступен
3. **GET** `/api/v1/students/me` - Указан в документации, но не существует
4. **GET** `/api/v2/students/me` - API v2 не доступен

### ❓ Не протестированы (требуют дополнительной проверки)

Все остальные эндпоинты из SwaggerHub документации требуют проверки:
- `/students/{id}`
- `/students/me/record-book`
- `/students/me/group`
- `/students/me/settings`
- `/schedule`
- `/news/*`
- `/rating`
- и т.д.

**⚠️ ВАЖНО**: Не доверяйте документации! Всегда тестируйте эндпоинты перед использованием.

---

## 🛠️ Инструменты для тестирования

### Python тестирование

```python
import requests

# 1. Login
url = "https://iis.bsuir.by/api/v1/auth/login"
payload = {
    "username": "12345678",
    "password": "your_password"
}

session = requests.Session()
response = session.post(url, json=payload)

if response.status_code == 200:
    print("✅ Login successful")
    print(f"SESSION cookie: {session.cookies.get('SESSION')}")
    print(f"User data: {response.json()}")
    
    # 2. Get personal information
    info_url = "https://iis.bsuir.by/api/v1/personal-information"
    info_response = session.get(info_url)
    
    if info_response.status_code == 200:
        print("✅ Personal info retrieved")
        print(f"Data: {info_response.json()}")
else:
    print(f"❌ Login failed: {response.status_code}")
```

### Swift тестирование

```swift
// URLSession автоматически управляет cookies
let session = URLSession.shared

// 1. Login
var request = URLRequest(url: URL(string: "https://iis.bsuir.by/api/v1/auth/login")!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try? JSONEncoder().encode(LoginRequest(username: "12345678", password: "password"))

let (data, response) = try await session.data(for: request)
// SESSION cookie автоматически сохранён в HTTPCookieStorage

// 2. Get profile (cookie отправится автоматически)
let profileRequest = URLRequest(url: URL(string: "https://iis.bsuir.by/api/v1/personal-information")!)
let (profileData, _) = try await session.data(for: profileRequest)
```

---

## 📝 Changelog

### 2025-01-15
- ✅ Обнаружен рабочий эндпоинт `/api/v1/auth/login`
- ✅ Подтверждена cookie-based аутентификация (SESSION cookie)
- ✅ Протестирован эндпоинт `/api/v1/personal-information`
- ✅ Обновлены Swift модели под реальную структуру API
- ✅ Создана документация с реальными эндпоинтами

### Известные проблемы
- Официальная SwaggerHub документация устарела
- API v2 недоступен (все запросы возвращают 404)
- JWT аутентификация не реализована (только cookies)
- Многие эндпоинты из документации не протестированы

---

## 🎯 Рекомендации

1. **Всегда используйте `/api/v1`** вместо `/api/v2`
2. **Используйте cookie-based auth**, не пытайтесь реализовать JWT
3. **Тестируйте эндпоинты** через Python перед реализацией в Swift
4. **Сохраняйте результаты** в `.json` файлы для документации
5. **Не доверяйте SwaggerHub** документации - она неактуальна

---

## 📚 Дополнительные ресурсы

- **Результаты тестирования**: `/Tests/api_test_results.json`
- **Пример login response**: `/Tests/login_response.json`
- **Пример profile response**: `/Tests/profile_response.json`
- **Python тесты**: `/Tests/api_url_tester.py`, `/Tests/api_full_test.py`
- **Swift реализация**: `/MyIIS/Services/APIService.swift`
- **Отчёт о реализации**: `/Tests/IMPLEMENTATION_REPORT.md`

---

**Составлено на основе реального тестирования API в январе 2025 года.**

---

## 📚 СЭО (LMS Moodle) Эндпоинты

> Эти эндпоинты были извлечены из HAR файлов для взаимодействия с СЭО (LMS Moodle).

### Общие
* **GET `/`** - Главная страница СЭО
* **GET `/my/`** - Дашборд (Личный кабинет)
* **GET `/login/auth.php`** - Аутентификация в СЭО
* **GET `/course/view.php?id={id}`** - Просмотр деталей курса и его модулей

### Задания и Файлы
* **GET `/mod/assign/view.php?id={id}&action=editsubmission`** - Редактирование или просмотр отправленного задания
* **POST `/repository/draftfiles_ajax.php?action=list`** - Запрос списка файлов в черновиках (используется при загрузке)
* **POST `/repository/repository_ajax.php?action=list`** - Взаимодействие с репозиториями файлов (например, загрузка архивов, документов)

### Служебные
* **GET `/lib/ajax/service-nologin.php`** - Публичные AJAX запросы (например, загрузка шаблонов Moodle)
* **POST `/lib/ajax/service.php`** - Приватные AJAX запросы (отслеживание прогресса, сохранение состояний)

