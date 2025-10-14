# MCP iOS Simulator - Шпаргалка

## 📱 Основная информация

**UUID симулятора проекта:** `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`  
**Устройство:** iPhone 17 Pro  
**iOS:** 26.0

---

## 🚀 Быстрый старт

### Базовая последовательность тестирования:

```
1. Открыть симулятор
2. Установить приложение
3. Запустить приложение
4. Сделать скриншот начального состояния
5. Выполнить тестовые действия (tap, type, swipe)
6. Сделать скриншот результата
7. Проанализировать UI
```

---

## 🛠️ Основные команды

### Управление симулятором

| Команда | Описание |
|---------|----------|
| `open_simulator` | Открыть iOS Simulator |
| `get_booted_sim_id` | Получить ID запущенного симулятора |

### Управление приложением

| Команда | Параметры | Описание |
|---------|-----------|----------|
| `install_app` | `app_path`, `udid` | Установить .app на симулятор |
| `launch_app` | `bundle_id`, `udid` | Запустить приложение |

**Пример:**
```
install_app:
  app_path: "/путь/к/MyIIS.app"
  udid: "20AA9E8D-A469-4634-96FB-C80A9F80D3BF"

launch_app:
  bundle_id: "com.mycompany.MyIIS"
  udid: "20AA9E8D-A469-4634-96FB-C80A9F80D3BF"
```

### Скриншоты и видео

| Команда | Параметры | Описание |
|---------|-----------|----------|
| `screenshot` | `output_path`, `type`, `udid` | Сделать скриншот |
| `record_video` | `output_path`, `codec`, `udid` | Начать запись видео |
| `stop_recording` | - | Остановить запись |

**Форматы скриншотов:** png, tiff, bmp, gif, jpeg  
**Видео кодеки:** h264, hevc

**Пример:**
```
screenshot:
  output_path: "Tests/Screenshots/login_view.png"
  type: "png"
  udid: "20AA9E8D-A469-4634-96FB-C80A9F80D3BF"

record_video:
  output_path: "Tests/Videos/login_flow.mp4"
  codec: "hevc"
```

### UI Взаимодействие

| Команда | Параметры | Описание |
|---------|-----------|----------|
| `ui_view` | `udid` | Получить текущий вид UI |
| `ui_describe_all` | `udid` | Вся accessibility информация |
| `ui_describe_point` | `x`, `y`, `udid` | Элемент в точке |
| `ui_tap` | `x`, `y`, `duration`, `udid` | Нажать на экран |
| `ui_type` | `text`, `udid` | Ввести текст |
| `ui_swipe` | `x_start`, `y_start`, `x_end`, `y_end`, `udid` | Свайп |

---

## 📋 Типичные сценарии

### 1. Тест экрана авторизации

```
1. open_simulator
2. install_app (путь к MyIIS.app)
3. launch_app (bundle_id)
4. screenshot → "Tests/Screenshots/login_initial.png"
5. ui_describe_all → получить координаты полей
6. ui_tap → нажать на поле "Username"
7. ui_type → ввести "42850012"
8. ui_tap → нажать на поле "Password"
9. ui_type → ввести пароль
10. ui_tap → нажать кнопку "Login"
11. screenshot → "Tests/Screenshots/login_success.png"
12. ui_describe_all → проверить новое состояние
```

### 2. Тест с видеозаписью

```
1. open_simulator
2. install_app + launch_app
3. record_video → "Tests/Videos/full_flow.mp4"
4. Выполнить все действия (tap, type, swipe)
5. stop_recording
6. Проверить видео
```

### 3. Автоматизированное тестирование UI

```
1. ui_describe_all → получить карту UI
2. Найти элементы по accessibility labels:
   - TextField "Username" → координаты (x1, y1)
   - TextField "Password" → координаты (x2, y2)
   - Button "Login" → координаты (x3, y3)
3. ui_tap (x1, y1) → фокус на Username
4. ui_type "42850012"
5. ui_tap (x2, y2) → фокус на Password
6. ui_type "пароль"
7. ui_tap (x3, y3) → нажать Login
8. ui_describe_all → проверить результат
9. Сравнить ожидаемое/фактическое состояние
```

### 4. Тест скролла и навигации

```
1. ui_describe_all → карта начального экрана
2. screenshot → "before_scroll.png"
3. ui_swipe:
   x_start: 195, y_start: 700
   x_end: 195, y_end: 300
   duration: "0.3"
4. screenshot → "after_scroll.png"
5. ui_describe_all → новые видимые элементы
```

---

## 📂 Структура сохранения артефактов

```
Tests/
├── Screenshots/
│   ├── LoginView/
│   │   ├── initial_state.png
│   │   ├── filled_form.png
│   │   └── success_state.png
│   ├── ScheduleView/
│   │   └── ...
│   └── ProfileView/
│       └── ...
└── Videos/
    ├── LoginFlow/
    │   └── complete_login.mp4
    ├── ScheduleFlow/
    │   └── ...
    └── ProfileFlow/
        └── ...
```

---

## 💡 Best Practices

### ✅ DO

- **Всегда указывай UUID** для надежности
- **Делай скриншоты** до и после каждого важного действия
- **Используй ui_describe_all** перед взаимодействием
- **Сохраняй артефакты** в структурированные папки
- **Записывай видео** сложных пользовательских сценариев
- **Проверяй accessibility** для автоматизации

### ❌ DON'T

- Не делай действия вслепую без ui_describe_all
- Не забывай останавливать запись видео
- Не используй хардкод координат (ищи через accessibility)
- Не пропускай скриншоты критичных состояний

---

## 🎯 Интеграция с разработкой

### Workflow для новой фичи:

```
1. Разработка View + ViewModel
2. Сборка проекта в Xcode
3. open_simulator
4. install_app (свежий билд)
5. launch_app
6. Выполнить тестовый сценарий через MCP
7. Сделать скриншоты для документации
8. Проверить UI через ui_describe_all
9. Коммит с приложенными скриншотами
```

### Коммит с результатами тестирования:

```bash
git add Tests/Screenshots/LoginView/
git commit -m "feat: добавлен LoginView с тестами

- Реализован минималистичный дизайн в стиле Liquid Glass
- Добавлены скриншоты всех состояний
- Протестировано через MCP iOS Simulator
- Проверена accessibility для автоматизации"
```

---

## 🔍 Отладка через UI описание

### Найти элемент по label:

```
1. ui_describe_all
2. Найти в выводе:
   {
     "label": "Login Button",
     "frame": { "x": 150, "y": 600, "width": 100, "height": 44 }
   }
3. Вычислить центр: x = 150 + 50 = 200, y = 600 + 22 = 622
4. ui_tap (200, 622)
```

### Проверить видимость элемента:

```
1. ui_describe_all → сохранить вывод
2. Найти нужный элемент по label
3. Если не найден → элемент не виден (скрыт или за границей)
4. Использовать ui_swipe для скролла
5. ui_describe_all → проверить снова
```

---

## 📊 Пример полного теста

```swift
// Запрос для Copilot:

"Протестируй LoginView через MCP iOS Simulator:

1. Открой симулятор (UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF)
2. Установи и запусти MyIIS
3. Сделай скриншот начального состояния → Tests/Screenshots/LoginView/initial.png
4. Получи UI карту через ui_describe_all
5. Найди поля ввода и кнопку Login
6. Введи тестовый логин: 42850012
7. Введи тестовый пароль
8. Нажми Login
9. Сделай скриншот после нажатия → Tests/Screenshots/LoginView/after_login.png
10. Проверь новое состояние UI
11. Сохрани результаты"
```

---

## 🎓 Дополнительные возможности

### Координаты экрана iPhone 17 Pro:

- **Ширина:** ~393 точки
- **Высота:** ~852 точки (без учета Dynamic Island)
- **Центр:** (196, 426)

### Типичные зоны:

- **Status Bar:** y = 0-59
- **Navigation Bar:** y = 59-103
- **Content Area:** y = 103-752
- **Tab Bar:** y = 752-852

---

**Важно:** Всегда проверяй реальные координаты через `ui_describe_all` 
перед выполнением действий! 🎯
