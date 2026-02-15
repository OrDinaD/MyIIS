# Инструкции для GitHub Copilot - Проект MyIIS

## 🎯 Общая информация о проекте

**Платформа:** iOS 26  
**Инструменты:** Xcode 26  
**Язык:** Swift  
**Симулятор для тестирования:** iPhone 17 Pro  
**UUID симулятора:** `20AA9E8D-A469-4634-96FB-C80A9F80D3BF`

---

## 🎨 Дизайн-гайдлайны и стиль

### MCP Context7 - Обязательное использование

**⚠️ ВАЖНО: В КАЖДОМ НОВОМ ЧАТЕ:**

При начале работы в новом чате **обязательно** используй MCP Context7 для получения актуальной документации:

```
Используй mcp_context7_resolve-library-id для поиска "Apple Human Interface Guidelines"
Затем используй mcp_context7_get-library-docs с полученным ID
```

### Требования к дизайну:

1. **Apple Human Interface Guidelines** - следуй последней версии HIG от Apple
2. **Стиль:** Максимальный минимализм
3. **Визуальный стиль:** Liquid Glass (глянцевые, полупрозрачные элементы)
4. **Совместимость:** iOS 26 стилистика
5. **Компоненты:** Используй нативные SwiftUI компоненты
6. **Анимации:** Плавные, естественные переходы
7. **Типографика:** Системные шрифты SF Pro
8. **Цвета:** Адаптивные цвета для Dark/Light режимов, можешь сделать акцентный цвет фиолетовый.


## 🏗️ Архитектура и паттерн проектирования

### Паттерн: MVVM (Model-View-ViewModel)

**Структура:**

```
MyIIS/
├── Models/           # Модели данных
├── Views/            # SwiftUI Views
├── ViewModels/       # Бизнес-логика
├── Services/         # API и сервисы
├── Tests/            # Тестовые файлы
└── Resources/        # Ресурсы
```

## 🌐 API Integration

Данные моего профиля: 

login = "42850012"
password = "tyhfu1-jamhup-xehGow"

## 📱 MCP iOS Simulator - Полное руководство

### UUID симулятора для проекта:

```
iPhone 17 Pro UUID: 20AA9E8D-A469-4634-96FB-C80A9F80D3BF
```

### Доступные MCP iOS Simulator инструменты:

#### 1. **Управление симулятором**

##### `mcp_ios-simulator_open_simulator`
Открывает приложение iOS Simulator.

**Использование:**
```
Открыть симулятор перед началом тестирования
```

##### `mcp_ios-simulator_get_booted_sim_id`
Получает ID текущего запущенного симулятора.

**Использование:**
```
Проверить, какой симулятор активен
```

---

#### 2. **Управление приложениями**

##### `mcp_ios-simulator_install_app`
Устанавливает .app или .ipa файл на симулятор.

**Параметры:**
- `app_path` - путь к .app bundle
- `udid` - UUID симулятора (опционально)

**Пример:**
```
Установить MyIIS.app на симулятор 20AA9E8D-A469-4634-96FB-C80A9F80D3BF
```

##### `mcp_ios-simulator_launch_app`
Запускает приложение по bundle ID.

**Параметры:**
- `bundle_id` - идентификатор приложения (например, com.mycompany.MyIIS)
- `terminate_running` - завершить, если уже запущено
- `udid` - UUID симулятора

**Пример:**
```
Запустить приложение com.mycompany.MyIIS на симуляторе
```

---

#### 3. **Скриншоты и запись**

##### `mcp_ios-simulator_screenshot`
Делает скриншот экрана симулятора.

**Параметры:**
- `output_path` - путь для сохранения (относительный или абсолютный)
- `type` - формат: png, tiff, bmp, gif, jpeg (по умолчанию png)
- `display` - internal/external
- `mask` - обработка маски для нестандартных дисплеев
- `udid` - UUID симулятора

**Пример:**
```
Сделать скриншот LoginView: "Screenshots/login_screen.png"
```

##### `mcp_ios-simulator_record_video`
Записывает видео экрана симулятора.

**Параметры:**
- `output_path` - путь для сохранения
- `codec` - h264 или hevc (по умолчанию hevc)
- `display` - internal/external
- `force` - перезаписать существующий файл
- `mask` - обработка маски

**Пример:**
```
Начать запись: "Videos/login_flow.mp4"
```

##### `mcp_ios-simulator_stop_recording`
Останавливает запись видео.

**Использование:**
```
Остановить текущую запись видео
```

---

#### 4. **UI Взаимодействие**

##### `mcp_ios-simulator_ui_view`
Получает сжатый скриншот текущего состояния UI.

**Параметры:**
- `udid` - UUID симулятора

**Использование:**
```
Получить текущее состояние экрана для анализа
```

##### `mcp_ios-simulator_ui_describe_all`
Возвращает accessibility информацию для всего экрана.

**Параметры:**
- `udid` - UUID симулятора

**Использование:**
```
Получить структуру UI с accessibility labels для автоматизации
```

##### `mcp_ios-simulator_ui_describe_point`
Получает accessibility элемент в конкретной точке.

**Параметры:**
- `x` - координата X
- `y` - координата Y
- `udid` - UUID симулятора

**Пример:**
```
Узнать, какой элемент находится по координатам (200, 400)
```

##### `mcp_ios-simulator_ui_tap`
Эмулирует нажатие на экран.

**Параметры:**
- `x` - координата X
- `y` - координата Y
- `duration` - длительность нажатия (для long press)
- `udid` - UUID симулятора

**Пример:**
```
Нажать кнопку Login по координатам (195, 600)
```

##### `mcp_ios-simulator_ui_type`
Вводит текст в симуляторе.

**Параметры:**
- `text` - текст для ввода (только ASCII)
- `udid` - UUID симулятора

**Пример:**
```
Ввести логин: "42850012"
```

##### `mcp_ios-simulator_ui_swipe`
Эмулирует свайп.

**Параметры:**
- `x_start` - начальная X координата
- `y_start` - начальная Y координата
- `x_end` - конечная X координата
- `y_end` - конечная Y координата
- `duration` - длительность свайпа
- `delta` - размер шага (по умолчанию 1)
- `udid` - UUID симулятора

**Пример:**
```
Свайп вверх для скролла: от (195, 700) до (195, 300)
```

---

### 🎬 Workflow тестирования через MCP iOS Simulator:

#### Базовый сценарий тестирования:

```
1. mcp_ios-simulator_open_simulator
   - Открыть симулятор

2. mcp_ios-simulator_install_app
   - Установить последний билд приложения
   - app_path: "/путь/к/MyIIS.app"
   - udid: "20AA9E8D-A469-4634-96FB-C80A9F80D3BF"

3. mcp_ios-simulator_launch_app
   - Запустить приложение
   - bundle_id: "com.mycompany.MyIIS"
   - udid: "20AA9E8D-A469-4634-96FB-C80A9F80D3BF"

4. mcp_ios-simulator_ui_describe_all
   - Получить структуру UI
   - Найти координаты нужных элементов

5. mcp_ios-simulator_screenshot
   - Сделать скриншот начального состояния
   - output_path: "Tests/Screenshots/initial_state.png"

6. Выполнить тестовые действия:
   - mcp_ios-simulator_ui_tap - нажать на поля ввода
   - mcp_ios-simulator_ui_type - ввести данные
   - mcp_ios-simulator_ui_tap - нажать кнопку Login
   - mcp_ios-simulator_ui_swipe - если нужен скролл

7. mcp_ios-simulator_screenshot
   - Сделать скриншот результата
   - output_path: "Tests/Screenshots/after_login.png"

8. Анализ результата через ui_describe_all или ui_view
```

#### Сценарий с видеозаписью:

```
1. Открыть и запустить приложение (шаги 1-3 выше)

2. mcp_ios-simulator_record_video
   - Начать запись
   - output_path: "Tests/Videos/login_flow.mp4"
   - codec: "hevc"

3. Выполнить полный flow действий
   - Все необходимые tap, type, swipe

4. mcp_ios-simulator_stop_recording
   - Остановить запись

5. Проверить записанное видео
```

#### Автоматизированное UI тестирование:

```
1. ui_describe_all - получить полную карту UI
2. Найти элементы по accessibility labels
3. Получить их координаты
4. Выполнить действия программно:
   - Найти TextField с label "Username"
   - Tap по его координатам
   - Type логин
   - Найти TextField с label "Password"
   - Tap и type пароль
   - Найти Button "Login"
   - Tap по кнопке
5. ui_describe_all - проверить новое состояние
6. Сравнить ожидаемое и фактическое состояние
```

### 📝 Лучшие практики MCP iOS Simulator:

1. **Всегда указывай UUID** для надежности
2. **Делай скриншоты** до и после изменений
3. **Используй ui_describe_all** для понимания структуры UI
4. **Записывай видео** сложных flows для документации
5. **Проверяй accessibility** - это поможет в автоматизации
6. **Сохраняй артефакты** в структурированные папки:
   - `Tests/Screenshots/[feature]/[screen].png`
   - `Tests/Videos/[feature]/[flow].mp4`

---

## ⚠️ КРИТИЧЕСКИ ВАЖНО: НЕ СОЗДАВАЙ ДОКУМЕНТАЦИЮ!

**🚫 ЗАПРЕЩЕНО создавать:**
- `.md` файлы (README, SUMMARY, CHANGELOG, etc.)
- Документацию в любом виде
- Описательные файлы
- Инструкции в коде проекта

**✅ ЧТО НУЖНО создавать:**
- Только `.swift` файлы с кодом
- Models, Views, ViewModels, Services
- Тестовые файлы в Tests/

**ВСЯ ДОКУМЕНТАЦИЯ УЖЕ СОЗДАНА в `.github/`!**
Не дублируй, не создавай новую, не пиши README!

## ✅ Чек-лист перед коммитом:

- [ ] Код соответствует MVVM паттерну
- [ ] Следует HIG и Liquid Glass стилю (проверено через Context7)
- [ ] API соответствует документации на SwaggerHub
- [ ] Созданы и пройденy API тесты (если работа с API)
- [ ] Проведено тестирование через MCP iOS Simulator
- [ ] Сделаны скриншоты результата (в Tests/Screenshots/)
- [ ] Нет hardcoded credentials (проверь!)
- [ ] Код отформатирован (SwiftFormat/SwiftLint)
- [ ] Написаны понятные commit messages
- [ ] **НЕ СОЗДАНО новых .md файлов!** ⚠️

---
