# ✅ Инструкции для GitHub Copilot - Созданы!

## ⚠️ КРИТИЧЕСКИ ВАЖНО!

### 🚫 НЕ СОЗДАВАЙ БОЛЬШЕ .md ФАЙЛОВ!

**ВСЯ НЕОБХОДИМАЯ ДОКУМЕНТАЦИЯ УЖЕ СОЗДАНА!**

Эти файлы ниже - **ЕДИНСТВЕННЫЕ** документы проекта.
**НЕ ДУБЛИРУЙ, НЕ СОЗДАВАЙ НОВЫЕ!**

При работе с проектом GitHub Copilot должен:
- ✅ Создавать ТОЛЬКО `.swift` файлы
- ✅ Работать с Models, Views, ViewModels, Services
- ❌ НЕ создавать README.md
- ❌ НЕ создавать SUMMARY.md
- ❌ НЕ создавать CHANGELOG.md
- ❌ НЕ создавать любые другие .md файлы

**Если AI предлагает создать .md файл - откажись!**
**Вся документация УЖЕ в `.github/` папке!**

---

## 📊 Что создано:

### 📂 Основные инструкции (в .github/):

1. **copilot-instructions.md** ⭐️ ГЛАВНЫЙ ФАЙЛ
   - Полные инструкции для AI
   - Все требования проекта
   - Технические детали
   - MCP инструменты
   - Git workflow

2. **QUICK-START.md** 🚀 НАЧНИ ОТСЮДА
   - Шаблоны для быстрого старта
   - Типичные задачи
   - Примеры запросов
   - Чек-листы

3. **mcp-context7-guide.md** 🎨
   - Как использовать Context7
   - Apple HIG изучение
   - Примеры запросов
   - Best practices

4. **mcp-simulator-cheatsheet.md** 📱
   - Все команды iOS Simulator
   - Сценарии тестирования
   - UI автоматизация
   - Примеры использования

5. **git-workflow-guide.md** 🔄
   - Правила ветвления
   - Типы коммитов
   - Процесс разработки
   - Примеры команд

6. **mvvm-pattern-guide.md** 🏗️
   - Подробный гайд MVVM
   - Model, View, ViewModel
   - Примеры кода
   - Best practices

7. **README.md** 📚
   - Навигация по документации
   - Краткие описания
   - Быстрые ссылки

---

## 📁 Структура проекта создана:

```
MyIIS/
├── .github/
│   ├── copilot-instructions.md        ⭐️ Главный файл
│   ├── QUICK-START.md                 🚀 Начни отсюда
│   ├── mcp-context7-guide.md          🎨 Context7
│   ├── mcp-simulator-cheatsheet.md    📱 Simulator
│   ├── git-workflow-guide.md          🔄 Git
│   ├── mvvm-pattern-guide.md          🏗️ MVVM
│   └── README.md                      📚 Навигация
│
├── MyIIS/
│   ├── Models/                        📦 Модели данных
│   ├── Views/                         🎨 SwiftUI Views
│   │   └── Components/
│   ├── ViewModels/                    🧠 Бизнес-логика
│   │   └── LoginViewModel.swift      (Пример создан)
│   ├── Services/                      🔌 API и сервисы
│   │   └── APIService.swift          (Пример создан)
│   └── Resources/                     📦 Ресурсы
│
├── Tests/
│   ├── APITests/                      🧪 API тесты
│   │   └── LoginAPITest.swift        (Пример создан)
│   ├── Screenshots/                   📸 Скриншоты
│   └── Videos/                        🎬 Видео
│
├── Config/
│   └── Credentials.swift              🔐 Тестовые credentials
│
├── .gitignore                         🚫 Защита данных
└── README.md                          📖 Главный README

```

---

## 🔐 Безопасность настроена:

✅ `.gitignore` создан
✅ `Config/Credentials.swift` в ignore
✅ Тестовые данные защищены
✅ Все секреты локальны

**⚠️ Важно:** `Config/Credentials.swift` содержит реальные учетные данные!
Не коммить в репозиторий!

---

## 📱 UUID симулятора записан:

```
iPhone 17 Pro: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF
```

Этот UUID теперь во всех инструкциях, AI будет его помнить!

---

## 🎯 Как начать работу:

### 1. В новом чате с GitHub Copilot:

Открой `.github/QUICK-START.md` и скопируй первый шаблон запроса.

### 2. Изучи основной файл:

Прочитай `.github/copilot-instructions.md` - там ВСЯ информация для AI.

### 3. Используй шпаргалки:

- Context7? → `.github/mcp-context7-guide.md`
- Simulator? → `.github/mcp-simulator-cheatsheet.md`
- Git? → `.github/git-workflow-guide.md`
- MVVM? → `.github/mvvm-pattern-guide.md`

---

## ✨ Особенности:

### MCP Context7:
- Обязательно в каждом новом чате
- Изучение Apple HIG для iOS 26
- Соответствие Liquid Glass стилю
- Актуальная документация

### MCP iOS Simulator:
- Полная автоматизация тестирования
- Скриншоты и видео
- UI взаимодействие
- Accessibility тестирование

### Git Workflow:
- Доработка → коммит в текущую ветку
- Новая фича → новая ветка `feature/название`
- Правильные commit messages
- Pull Requests для ревью

### API Integration:
- Swagger документация обязательна
- Сначала тест → потом интеграция
- 100% соответствие API схеме
- Защищенные credentials

---

## 🚀 Примеры использования:

### Создать новый экран:

```
Используй Context7 для изучения HIG iOS 26.

Создай ProfileView в стиле Liquid Glass:
1. MVVM паттерн
2. Минималистичный дизайн
3. API интеграция
4. Тестирование в симуляторе (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
5. Ветка feature/profile-view
```

### Протестировать экран:

```
Протестируй LoginView через MCP iOS Simulator:
UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF

Сценарий:
1. Открой симулятор
2. Запусти приложение
3. Сделай скриншоты
4. Протестируй UI
5. Сохрани в Tests/Screenshots/
```

### Интегрировать API:

```
Интегрируй Login API из Swagger:
https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0

1. Создай тест в Tests/APITests/LoginAPITest.swift
2. Используй Config/Credentials.swift
3. После теста → APIService.swift
4. Обнови LoginViewModel
```

---

## 📋 Checklist:

- [x] Создана структура папок (MVVM)
- [x] Написаны инструкции для Copilot
- [x] Добавлены гайды по MCP инструментам
- [x] Создан Git workflow guide
- [x] Добавлен MVVM pattern guide
- [x] UUID симулятора записан
- [x] Настроена безопасность (.gitignore)
- [x] Созданы примеры кода (ViewModel, Service, Test)
- [x] Созданы шаблоны для быстрого старта
- [x] Документация структурирована

---

## 🎓 Следующие шаги:

1. **Прочитай** `.github/copilot-instructions.md`
2. **Открой новый чат** с GitHub Copilot
3. **Используй шаблон** из `.github/QUICK-START.md`
4. **Начни разработку!** 🚀

---

## 💡 Полезные ссылки:

- Главный файл: `.github/copilot-instructions.md`
- Быстрый старт: `.github/QUICK-START.md`
- API Docs: https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0

---

## ⚡ Ключевые моменты:

✅ **Context7** - в каждом новом чате!
✅ **UUID** - `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`
✅ **MVVM** - строгое разделение слоев
✅ **Liquid Glass** - минимализм и полупрозрачность
✅ **API Test First** - сначала тест, потом код
✅ **Git Branches** - новая фича = новая ветка
✅ **Credentials** - НИКОГДА не коммитить!

---

**Готово! Теперь GitHub Copilot будет работать с полным пониманием проекта! 🎉**

---

## 📞 Если нужна помощь:

1. Проверь `.github/copilot-instructions.md` - там ВСЁ
2. Используй `.github/QUICK-START.md` для шаблонов
3. Смотри соответствующие гайды для деталей

**Удачной разработки! 🚀**
