# MyIIS - iOS приложение для БГУИР

## 📱 О проекте

MyIIS - современное iOS приложение для студентов и преподавателей БГУИР, разработанное с использованием SwiftUI и следованием последним стандартам Apple Human Interface Guidelines.

## 🎨 Дизайн

- **Стиль:** Liquid Glass с максимальным минимализмом
- **Платформа:** iOS 26
- **Инструменты:** Xcode 26, Swift 6.0
- **UI Framework:** SwiftUI

## 🏗️ Архитектура

Проект следует паттерну **MVVM** (Model-View-ViewModel):

```
MyIIS/
├── Models/           # Модели данных
├── Views/            # SwiftUI Views
├── ViewModels/       # Бизнес-логика
├── Services/         # API и сервисы
├── Tests/            # Тестовые файлы
└── Resources/        # Ресурсы
```

## 🌐 API

API документация доступна на SwaggerHub:
https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0

## 🤖 Работа с GitHub Copilot

Полные инструкции для работы с AI ассистентом находятся в:
`.github/copilot-instructions.md`

### Ключевые моменты:

1. **MCP Context7** - используй для изучения Apple HIG в каждом новом чате
2. **API** - сначала создай тест в `Tests/APITests/`, затем интегрируй
3. **Симулятор** - UUID: `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`
4. **Git workflow:**
   - Доработка фичи → коммит в текущую ветку
   - Новая фича → отдельная ветка `feature/[название]`

## 🧪 Тестирование

### MCP iOS Simulator

Проект использует MCP iOS Simulator для автоматизированного тестирования:

- Скриншоты → `Tests/Screenshots/`
- Видео → `Tests/Videos/`
- UUID симулятора: `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`

### API Tests

Все API тесты находятся в `Tests/APITests/`

## 🔐 Безопасность

⚠️ **Конфиденциальные данные:**
- `Config/Credentials.swift` - в .gitignore
- Никогда не коммитьте реальные credentials
- API ключи хранятся только локально

## 📝 Правила коммитов

```bash
feat: новая фича
fix: исправление бага
style: изменения UI
refactor: рефакторинг
test: добавление тестов
docs: документация
```

## 🚀 Начало работы

1. Клонируй репозиторий
2. Открой `MyIIS.xcodeproj` в Xcode 26
3. Выбери симулятор iPhone 17 Pro
4. Запусти проект (⌘R)

## 📚 Документация

- [Инструкции для Copilot](.github/copilot-instructions.md)
- [API Documentation](https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0)
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)

## 👥 Авторы

Проект разработан для студентов БГУИР

---

**Версия:** 1.0  
**Последнее обновление:** 13 октября 2025
