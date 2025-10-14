# 🚀 Быстрый старт с GitHub Copilot для MyIIS

## 📋 Начало работы в новом чате

Когда открываешь новый чат с GitHub Copilot, скопируй и отправь:

```
Привет! Я работаю над iOS приложением MyIIS.

Пожалуйста, используй MCP Context7 для изучения последних Apple Human Interface 
Guidelines для iOS 26.

Основная информация о проекте:
- Платформа: iOS 26
- Инструменты: Xcode 26, Swift 6.0, SwiftUI
- Паттерн: MVVM (Model-View-ViewModel)
- Стиль: Liquid Glass с максимальным минимализмом
- API: https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0
- Симулятор: iPhone 17 Pro (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)

Мне нужно [описать задачу].

Важно:
1. Следуй MVVM паттерну
2. Соблюдай Apple HIG для iOS 26
3. Используй стиль Liquid Glass
4. Если работа с API - сначала создай тест в Tests/APITests/
5. Протестируй результат через MCP iOS Simulator
6. Если новая фича - создай ветку feature/[название]
7. ⚠️ НЕ СОЗДАВАЙ .md файлы! Только .swift код! Вся документация уже есть!
```

---

## ⚠️ ВАЖНО: НЕ СОЗДАВАЙ ДОКУМЕНТАЦИЮ!

**ЗАПРЕЩЕНО:**
- ❌ Создавать `.md` файлы (README, SUMMARY, CHANGELOG)
- ❌ Писать документацию в любом виде
- ❌ Дублировать инструкции

**ВСЯ ДОКУМЕНТАЦИЯ УЖЕ В `.github/`!**

**МОЖНО:**
- ✅ Только `.swift` файлы
- ✅ Models, Views, ViewModels, Services
- ✅ Тесты в Tests/

---

## 🎯 Типичные задачи

### 1. Создать новый экран

```
Используй Context7 для изучения HIG iOS 26.

Создай новый экран [название] в стиле Liquid Glass:

1. Создай Model (если нужно) в MyIIS/Models/
2. Создай View в MyIIS/Views/
3. Создай ViewModel в MyIIS/ViewModels/
4. Следуй MVVM паттерну
5. Используй минималистичный дизайн
6. Добавь плавные анимации

⚠️ НЕ создавай README или другие .md файлы!

После создания:
- Протестируй через MCP iOS Simulator (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
- Сделай скриншоты в Tests/Screenshots/[ScreenName]/
- Создай ветку feature/[screen-name]
```

### 2. Интегрировать API

```
Мне нужно интегрировать [endpoint] из API:
https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0

Процесс:
1. Изучи документацию Swagger для этого endpoint
2. Создай модель данных согласно схеме
3. Создай тестовый файл в Tests/APITests/[Name]APITest.swift
4. Используй тестовые credentials из Config/Credentials.swift
5. Протестируй API
6. После успешного теста - интегрируй в MyIIS/Services/APIService.swift
7. Обнови ViewModel для использования API

Важно: 100% соответствие документации Swagger!

⚠️ ТОЛЬКО .swift файлы! НЕ создавай README или API_DOCS.md!
```

### 3. Улучшить существующий экран

```
Используй Context7 для изучения HIG iOS 26.

Улучши [ScreenName]:

1. Проверь соответствие Liquid Glass стилю
2. Обнови анимации для плавности
3. Проверь адаптивность для Dark/Light режимов
4. Улучши accessibility
5. Оптимизируй код в ViewModel

После доработки:
- Протестируй через MCP iOS Simulator
- Сделай скриншоты до/после
- Сделай коммит в текущей ветке: "style: улучшен [ScreenName]"
```

### 4. Протестировать экран

```
Протестируй [ScreenName] через MCP iOS Simulator:

UUID симулятора: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF

Сценарий:
1. Открой симулятор
2. Установи и запусти приложение
3. Перейди на [ScreenName]
4. Сделай скриншот начального состояния
5. Получи UI карту через ui_describe_all
6. Выполни [описание действий]
7. Сделай скриншоты результатов
8. Сохрани в Tests/Screenshots/[ScreenName]/

Проверь:
- Все элементы видны и доступны
- Анимации работают плавно
- Accessibility labels корректны
- Dark/Light режимы работают
```

---

## 📚 Быстрые ссылки

### Документация проекта:

- [Полные инструкции](.github/copilot-instructions.md)
- [MCP Context7 гайд](.github/mcp-context7-guide.md)
- [MCP Simulator шпаргалка](.github/mcp-simulator-cheatsheet.md)
- [Git Workflow](.github/git-workflow-guide.md)

### Внешние ресурсы:

- [API Swagger](https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0)
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) (используй Context7!)
- [SwiftUI Docs](https://developer.apple.com/documentation/swiftui) (используй Context7!)

---

## 🎨 Стиль Liquid Glass - Ключевые элементы

При создании UI, попроси Copilot использовать:

```
Стиль Liquid Glass:
- Полупрозрачные фоны (.ultraThinMaterial, .thinMaterial)
- Размытие (blur effects)
- Глянцевые поверхности
- Плавные градиенты
- Мягкие тени
- Округлые углы (cornerRadius)
- Плавные анимации (.spring, .easeInOut)
- Минимализм (минимум элементов)
- Много whitespace
```

---

## 🛠️ Структура проекта MVVM

```
MyIIS/
├── Models/              # Чистые данные
│   └── User.swift
├── Views/               # SwiftUI Views (только UI)
│   ├── LoginView.swift
│   └── Components/
├── ViewModels/          # Бизнес-логика (@Published)
│   └── LoginViewModel.swift
├── Services/            # API, Network, Storage
│   └── APIService.swift
└── Resources/           # Assets, Colors, Fonts

Tests/
├── APITests/            # Тесты API
├── Screenshots/         # Скриншоты для документации
└── Videos/              # Видео flows
```

---

## ⚡ Частые команды

### Тестирование в симуляторе:

```
Протестируй текущий экран в симуляторе (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
```

### Проверка соответствия HIG:

```
Используй Context7 для проверки, соответствует ли [ScreenName] HIG iOS 26
```

### API тест:

```
Создай и запусти тест для [endpoint] в Tests/APITests/
Используй credentials из Config/Credentials.swift
```

### Скриншоты:

```
Сделай скриншоты [ScreenName] через MCP Simulator в Tests/Screenshots/[ScreenName]/
```

---

## ✅ Чек-лист перед коммитом

Перед коммитом попроси Copilot проверить:

```
Проверь перед коммитом:
1. Код следует MVVM паттерну
2. Соответствие HIG iOS 26 (через Context7)
3. Стиль Liquid Glass применен корректно
4. API соответствует Swagger (если применимо)
5. Нет hardcoded credentials
6. Протестировано в симуляторе
7. Сделаны скриншоты
8. Accessibility добавлены
9. Dark/Light режимы работают
10. Анимации плавные
11. ⚠️ НЕ СОЗДАНО .md файлов! (критично!)
```

---

## 🎓 Примеры полных запросов

### Новый экран с нуля:

```
Используй Context7 для изучения HIG iOS 26.

Создай экран Расписания (ScheduleView) для iOS приложения MyIIS:

Требования:
- MVVM паттерн
- Liquid Glass стиль с максимальным минимализмом
- SwiftUI для iOS 26
- Интеграция с API (https://app.swaggerhub.com/apis-docs/N1ghtF1re/BsuirAdditionalApi/1.0.0)
- Плавные анимации
- Поддержка Dark/Light режимов

Процесс:
1. Создай модель Schedule в MyIIS/Models/Schedule.swift
2. Создай ScheduleView в MyIIS/Views/ScheduleView.swift
3. Создай ScheduleViewModel в MyIIS/ViewModels/ScheduleViewModel.swift
4. Создай API тест в Tests/APITests/ScheduleAPITest.swift
5. После теста - интегрируй в APIService
6. Протестируй в симуляторе (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
7. Сделай скриншоты
8. Создай ветку feature/schedule-view

Начни с изучения HIG через Context7!
```

### Доработка существующего:

```
Используй Context7 для изучения HIG iOS 26.

Улучши LoginView в стиле Liquid Glass:

Текущие проблемы:
- [описать проблемы]

Что нужно:
- Обновить анимации
- Улучшить валидацию
- Добавить loading состояние
- Улучшить обработку ошибок

После доработки:
- Протестируй в симуляторе (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
- Сделай скриншоты
- Коммит: "style: улучшен LoginView"
```

---

## 🎯 Помни!

1. **Context7** - обязательно в каждом новом чате
2. **UUID симулятора** - `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`
3. **API тесты** - сначала тест, потом интеграция
4. **Ветки** - новая фича = новая ветка
5. **Скриншоты** - документируй результаты
6. **HIG** - всегда соответствие стандартам Apple
7. **Liquid Glass** - минимализм и полупрозрачность
8. **MVVM** - четкое разделение слоев
9. **🚫 НЕ СОЗДАВАЙ .md ФАЙЛЫ!** - вся документация уже есть!

---

## ⚠️ КРИТИЧНО: Про документацию

**Если AI пытается создать:**
- README.md
- SUMMARY.md
- CHANGELOG.md
- API_DOCS.md
- CONTRIBUTING.md
- Любые другие .md файлы

**ОСТАНОВИСЬ И СКАЖИ:**
"❌ Нет! Вся документация уже создана в `.github/`. Создавай только `.swift` файлы с кодом!"

---

**Удачной разработки! 🚀**
