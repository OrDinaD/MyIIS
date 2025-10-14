# MVVM Pattern - Руководство для MyIIS

## 🎯 Что такое MVVM?

**MVVM** (Model-View-ViewModel) - архитектурный паттерн для разделения ответственности в приложении.

```
User → View ←→ ViewModel ←→ Model
          ↓         ↓         ↓
       UI только  Логика   Данные
```

---

## 📦 Слои MVVM

### 1. **Model** - Данные

**Что содержит:**
- Структуры данных
- Бизнес-модели
- Данные из API

**Что НЕ содержит:**
- UI логику
- Бизнес-логику
- Зависимости от View

**Пример:**
```swift
// MyIIS/Models/User.swift

struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let fullName: String
    
    // Только данные, никакой логики!
}
```

### 2. **View** - Интерфейс

**Что содержит:**
- SwiftUI Views
- UI компоненты
- Анимации
- Layout

**Что НЕ содержит:**
- Бизнес-логику
- Прямые обращения к API
- Вычисления данных

**Пример:**
```swift
// MyIIS/Views/LoginView.swift

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Только UI!
            TextField("Логин", text: $viewModel.username)
            SecureField("Пароль", text: $viewModel.password)
            
            Button("Войти") {
                Task {
                    await viewModel.login()
                }
            }
            .disabled(viewModel.isLoading)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}
```

### 3. **ViewModel** - Логика

**Что содержит:**
- Бизнес-логика
- Обработка пользовательских действий
- Валидация данных
- Взаимодействие с Services
- @Published свойства для View

**Что НЕ содержит:**
- UI код
- SwiftUI Views
- Прямую работу с UI элементами

**Пример:**
```swift
// MyIIS/ViewModels/LoginViewModel.swift

@MainActor
class LoginViewModel: ObservableObject {
    // MARK: - Published Properties (для View)
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    private let apiService: APIService
    
    // MARK: - Initialization
    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }
    
    // MARK: - Public Methods (вызываются из View)
    func login() async {
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.login(
                username: username,
                password: password
            )
            isAuthenticated = true
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods (внутренняя логика)
    private func validateInput() -> Bool {
        guard !username.isEmpty else {
            errorMessage = "Введите логин"
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "Введите пароль"
            return false
        }
        return true
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
```

---

## 🔄 Поток данных

### User Action → View → ViewModel → Service → Model

```
1. Пользователь нажимает кнопку "Войти" в View
   ↓
2. View вызывает viewModel.login()
   ↓
3. ViewModel валидирует данные
   ↓
4. ViewModel обращается к APIService
   ↓
5. APIService делает запрос к серверу
   ↓
6. Сервер возвращает данные (Model)
   ↓
7. ViewModel обрабатывает Model
   ↓
8. ViewModel обновляет @Published свойства
   ↓
9. View автоматически обновляется
```

---

## 📁 Структура файлов

```
MyIIS/
├── Models/
│   ├── User.swift              # Данные пользователя
│   ├── Schedule.swift          # Данные расписания
│   └── Group.swift             # Данные группы
│
├── Views/
│   ├── LoginView.swift         # UI экран входа
│   ├── ScheduleView.swift      # UI экран расписания
│   ├── ProfileView.swift       # UI экран профиля
│   └── Components/
│       ├── CustomButton.swift  # Переиспользуемая кнопка
│       └── LoadingView.swift   # Индикатор загрузки
│
├── ViewModels/
│   ├── LoginViewModel.swift    # Логика входа
│   ├── ScheduleViewModel.swift # Логика расписания
│   └── ProfileViewModel.swift  # Логика профиля
│
└── Services/
    ├── APIService.swift        # Работа с API
    ├── StorageService.swift    # Локальное хранилище
    └── NetworkManager.swift    # Сетевой слой
```

---

## ✅ Правила MVVM для MyIIS

### Model правила:

✅ **DO:**
- Только структуры данных
- Codable для API
- Identifiable для списков
- Computed properties для простых вычислений

❌ **DON'T:**
- Бизнес-логика
- Обращения к API
- UI код
- Ссылки на View или ViewModel

### View правила:

✅ **DO:**
- Только UI
- @StateObject для ViewModel
- Binding для двустороннего обмена
- SwiftUI компоненты
- Анимации и переходы

❌ **DON'T:**
- Бизнес-логика
- Прямые обращения к API
- Валидация данных
- Обработка ошибок (показывать - да, обрабатывать - нет)

### ViewModel правила:

✅ **DO:**
- @Published для свойств View
- ObservableObject
- @MainActor для UI операций
- Бизнес-логика
- Валидация
- Обработка ошибок
- Взаимодействие с Services

❌ **DON'T:**
- import SwiftUI (кроме @Published)
- Прямая работа с UI элементами
- Hardcoded UI константы

---

## 🎨 Примеры для разных экранов

### Пример: Schedule (Расписание)

#### Model:
```swift
// MyIIS/Models/Schedule.swift

struct Schedule: Codable, Identifiable {
    let id: String
    let date: Date
    let lessons: [Lesson]
}

struct Lesson: Codable, Identifiable {
    let id: String
    let name: String
    let room: String
    let startTime: String
    let endTime: String
    let teacher: String
}
```

#### ViewModel:
```swift
// MyIIS/ViewModels/ScheduleViewModel.swift

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var schedule: [Schedule] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date = Date()
    
    private let apiService: APIService
    
    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }
    
    func loadSchedule() async {
        isLoading = true
        errorMessage = nil
        
        do {
            schedule = try await apiService.getSchedule(
                for: selectedDate
            )
        } catch {
            errorMessage = "Не удалось загрузить расписание"
        }
        
        isLoading = false
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await loadSchedule()
        }
    }
}
```

#### View:
```swift
// MyIIS/Views/ScheduleView.swift

struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Дата",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.selectedDate) { newDate in
                    viewModel.selectDate(newDate)
                }
                
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error)
                } else {
                    List(viewModel.schedule) { schedule in
                        ScheduleRow(schedule: schedule)
                    }
                }
            }
            .navigationTitle("Расписание")
        }
        .task {
            await viewModel.loadSchedule()
        }
    }
}
```

---

## 🔌 Dependency Injection

### Зачем нужен?
- Легкое тестирование
- Замена реализации Services
- Изоляция компонентов

### Пример:

```swift
// Протокол для Service
protocol APIServiceProtocol {
    func login(username: String, password: String) async throws -> LoginResponse
}

// Реальная реализация
class APIService: APIServiceProtocol {
    func login(username: String, password: String) async throws -> LoginResponse {
        // Реальный запрос к API
    }
}

// Mock для тестов
class MockAPIService: APIServiceProtocol {
    func login(username: String, password: String) async throws -> LoginResponse {
        // Возвращаем тестовые данные
        return LoginResponse(token: "test_token", userId: "123")
    }
}

// ViewModel принимает любую реализацию
class LoginViewModel: ObservableObject {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
}

// Использование в тестах
let mockService = MockAPIService()
let viewModel = LoginViewModel(apiService: mockService)
```

---

## 🧪 Тестирование MVVM

### ViewModel легко тестировать:

```swift
// Tests/ViewModelTests/LoginViewModelTests.swift

@MainActor
class LoginViewModelTests: XCTestCase {
    func testSuccessfulLogin() async {
        // Arrange
        let mockService = MockAPIService()
        let viewModel = LoginViewModel(apiService: mockService)
        
        viewModel.username = "test_user"
        viewModel.password = "test_pass"
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testValidation() {
        // Arrange
        let viewModel = LoginViewModel()
        
        // Act & Assert
        viewModel.username = ""
        viewModel.password = ""
        // Валидация должна провалиться
    }
}
```

---

## 💡 Best Practices

### 1. Один ViewModel на один экран
```
LoginView → LoginViewModel
ScheduleView → ScheduleViewModel
ProfileView → ProfileViewModel
```

### 2. @Published только для View
```swift
// ✅ Good
@Published var username: String = ""  // Используется в TextField

// ❌ Bad
@Published private var apiToken: String = ""  // View не нужен
```

### 3. async/await для асинхронных операций
```swift
// ✅ Good
func loadData() async {
    do {
        let data = try await apiService.fetchData()
        self.items = data
    } catch {
        self.errorMessage = error.localizedDescription
    }
}

// ❌ Bad (старый подход с completion handlers)
func loadData(completion: @escaping (Result<[Item], Error>) -> Void) {
    apiService.fetchData { result in
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
```

### 4. @MainActor для UI операций
```swift
// ✅ Good
@MainActor
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
    // Все операции автоматически на main thread
}
```

### 5. Валидация в ViewModel
```swift
// ✅ Good - в ViewModel
private func validateInput() -> Bool {
    guard !username.isEmpty else {
        errorMessage = "Введите логин"
        return false
    }
    return true
}

// ❌ Bad - в View
if username.isEmpty {
    // Не делай так!
}
```

---

## 🎯 Checklist для MVVM

При создании новой фичи проверь:

- [ ] Model содержит только данные
- [ ] View содержит только UI
- [ ] ViewModel содержит всю логику
- [ ] View использует @StateObject для ViewModel
- [ ] ViewModel наследуется от ObservableObject
- [ ] ViewModel помечен @MainActor
- [ ] Published свойства используются для UI
- [ ] Нет прямых обращений к API из View
- [ ] Валидация происходит в ViewModel
- [ ] Ошибки обрабатываются в ViewModel
- [ ] Services внедряются через DI
- [ ] Можно легко протестировать ViewModel

---

**MVVM = чистый, тестируемый, масштабируемый код! 🚀**
