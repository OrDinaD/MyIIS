# Git Workflow - Руководство для MyIIS

## 🎯 Основные правила

### Когда делать коммит в текущую ветку:
- Доработка существующего экрана
- Исправление багов
- Улучшение UI/UX
- Рефакторинг кода
- Обновление документации

### Когда создавать новую ветку:
- Новый экран/View
- Новая фича
- Крупный функционал
- Экспериментальные изменения

---

## 📋 Типы коммитов

```
feat:      Новая фича
fix:       Исправление бага
style:     Изменения UI/стилей
refactor:  Рефакторинг кода
test:      Добавление тестов
docs:      Документация
chore:     Рутинные задачи
```

---

## 🔄 Workflow: Доработка существующего

### Сценарий: Улучшение LoginView

```bash
# 1. Убедись, что на правильной ветке
git branch
# * main (или develop)

# 2. Получи последние изменения
git pull

# 3. Внеси изменения в LoginView.swift

# 4. Проверь статус
git status
# Changes not staged for commit:
#   modified:   MyIIS/Views/LoginView.swift

# 5. Добавь изменения
git add MyIIS/Views/LoginView.swift
# или все изменения:
git add .

# 6. Сделай коммит
git commit -m "style: улучшена анимация кнопки Login

- Добавлена плавная анимация нажатия
- Обновлены цвета для Liquid Glass стиля
- Улучшен отклик на touch события"

# 7. Отправь на удаленный репозиторий
git push
```

### Примеры коммитов для доработки:

```bash
git commit -m "fix: исправлена ошибка валидации в LoginView"

git commit -m "style: обновлены отступы в ScheduleView согласно HIG"

git commit -m "refactor: переработан LoginViewModel с async/await"

git commit -m "test: добавлены скриншоты ProfileView"
```

---

## 🌿 Workflow: Новая фича (новая ветка)

### Сценарий: Новый экран расписания

```bash
# 1. Убедись, что на main/develop
git checkout main

# 2. Получи последние изменения
git pull

# 3. Создай новую ветку
git checkout -b feature/schedule-view
# Naming: feature/[название-фичи]

# 4. Разработай ScheduleView.swift

# 5. Протестируй через MCP iOS Simulator

# 6. Сделай коммит (или несколько)
git add .
git commit -m "feat: добавлен ScheduleView с расписанием занятий

- Реализован минималистичный дизайн в стиле Liquid Glass
- Добавлена интеграция с BSUIR API
- Создан ScheduleViewModel для управления состоянием
- Добавлены тесты API в Tests/APITests/ScheduleAPITest.swift
- Сделаны скриншоты для документации"

# 7. Отправь ветку на удаленный репозиторий
git push -u origin feature/schedule-view

# 8. Создай Pull Request на GitHub
# GitHub автоматически предложит создать PR

# 9. После ревью и одобрения - слияние в main
# Обычно делается через GitHub interface

# 10. После слияния удали локальную ветку
git checkout main
git pull
git branch -d feature/schedule-view
```

### Примеры названий веток:

```bash
feature/profile-view          # Новый экран профиля
feature/schedule-view         # Новый экран расписания
feature/notifications         # Система уведомлений
feature/dark-mode            # Поддержка темной темы
feature/api-integration      # Интеграция с API
feature/settings-screen      # Экран настроек
```

---

## 📝 Шаблоны коммитов

### Новый экран:

```bash
git commit -m "feat: добавлен [ScreenName]

- Реализован дизайн в стиле Liquid Glass согласно HIG
- Добавлен [ScreenName]ViewModel с бизнес-логикой
- Интеграция с API (если применимо)
- Добавлены тесты и скриншоты"
```

### Доработка UI:

```bash
git commit -m "style: улучшен UI в [ScreenName]

- Обновлены цвета для соответствия Liquid Glass
- Улучшены анимации переходов
- Исправлены отступы согласно HIG iOS 26"
```

### Исправление бага:

```bash
git commit -m "fix: исправлена [описание проблемы]

- Проблема: [что было не так]
- Решение: [как исправлено]
- Тестирование: [как проверено]"
```

### API интеграция:

```bash
git commit -m "feat: добавлена интеграция с [API endpoint]

- Создана модель [ModelName] согласно Swagger
- Реализован метод в APIService
- Добавлены тесты в Tests/APITests/
- Проверена работа с тестовыми credentials"
```

### Тестирование:

```bash
git commit -m "test: добавлены тесты для [Feature]

- API тесты в Tests/APITests/
- Скриншоты в Tests/Screenshots/[Feature]/
- Видео flow в Tests/Videos/[Feature]/
- Протестировано на симуляторе iPhone 17 Pro"
```

---

## 🔍 Проверка перед коммитом

### Чек-лист:

```bash
# 1. Проверь статус
git status

# 2. Посмотри diff изменений
git diff

# 3. Убедись, что нет конфиденциальных данных
git diff | grep -i "password\|token\|secret"

# 4. Проверь, что Credentials.swift не добавлен
git status | grep Credentials

# 5. Запусти проект и протестируй
# В Xcode: ⌘R

# 6. Протестируй через MCP iOS Simulator
# Сделай скриншоты

# 7. Проверь соответствие HIG
# Используй Context7

# 8. Только после всех проверок - коммит!
git commit -m "..."
```

---

## 🚫 Что НЕ коммитить

### Добавлено в .gitignore:

- `Config/Credentials.swift` - тестовые credentials
- `xcuserdata/` - пользовательские настройки Xcode
- `.DS_Store` - системные файлы Mac
- `*.pem`, `*.p12` - сертификаты
- `.env*` - переменные окружения

### Проверка перед push:

```bash
# Убедись, что не добавлены конфиденциальные файлы
git log --name-only -1

# Если случайно добавил Credentials.swift:
git reset HEAD Config/Credentials.swift
git checkout -- Config/Credentials.swift
```

---

## 🎬 Полный workflow: От идеи до продакшена

### Новая фича с нуля:

```bash
# 1. Планирование
# - Изучи требования
# - Проверь API документацию
# - Запроси Context7 для HIG

# 2. Создание ветки
git checkout main
git pull
git checkout -b feature/my-awesome-feature

# 3. Разработка
# - Создай Model (если нужно)
# - Создай View
# - Создай ViewModel
# - Создай API Service (если нужно)

# 4. API тестирование (если применимо)
# - Создай тест в Tests/APITests/
# - Запусти тест с реальными credentials
# - Убедись, что API работает

git add Tests/APITests/MyFeatureAPITest.swift
git commit -m "test: добавлен API тест для [Feature]"

# 5. Основная реализация
git add MyIIS/Models/MyModel.swift
git add MyIIS/Views/MyView.swift
git add MyIIS/ViewModels/MyViewModel.swift
git commit -m "feat: добавлен [Feature]

- Полное описание
- MVVM архитектура
- Liquid Glass стиль"

# 6. UI тестирование
# - Открой симулятор
# - Протестируй через MCP iOS Simulator
# - Сделай скриншоты

git add Tests/Screenshots/MyFeature/
git commit -m "test: добавлены скриншоты [Feature]"

# 7. Финальная проверка
# - Запусти проект
# - Проверь все сценарии
# - Проверь на багах

# 8. Push и PR
git push -u origin feature/my-awesome-feature
# Создай PR на GitHub
# Дождись ревью
# После одобрения - merge

# 9. Очистка
git checkout main
git pull
git branch -d feature/my-awesome-feature
```

---

## 💡 Полезные команды

### Просмотр истории:

```bash
# Список последних коммитов
git log --oneline -10

# Красивый граф веток
git log --graph --oneline --all

# Изменения в конкретном коммите
git show [commit-hash]
```

### Отмена изменений:

```bash
# Отменить изменения в файле (до add)
git checkout -- MyIIS/Views/MyView.swift

# Убрать файл из staged (после add)
git reset HEAD MyIIS/Views/MyView.swift

# Изменить последний коммит
git commit --amend -m "Новое сообщение"
```

### Работа с ветками:

```bash
# Список веток
git branch

# Переключиться на ветку
git checkout [branch-name]

# Создать и переключиться
git checkout -b [new-branch]

# Удалить ветку
git branch -d [branch-name]

# Удалить удаленную ветку
git push origin --delete [branch-name]
```

### Синхронизация:

```bash
# Получить изменения (без слияния)
git fetch

# Получить и слить
git pull

# Отправить изменения
git push

# Отправить новую ветку
git push -u origin [branch-name]
```

---

## 📊 Пример реального workflow

```bash
# Утро: Начало работы над новым экраном профиля

git checkout main
git pull
git checkout -b feature/profile-screen

# Изучаю HIG через Context7
# Создаю ProfileView.swift, ProfileViewModel.swift

git add MyIIS/Views/ProfileView.swift
git add MyIIS/ViewModels/ProfileViewModel.swift
git commit -m "feat: добавлен начальный ProfileView

- Базовая структура экрана
- MVVM архитектура
- Минималистичный дизайн"

# Добавляю API интеграцию
# Сначала тест

git add Tests/APITests/ProfileAPITest.swift
git commit -m "test: добавлен тест Profile API"

# После успешного теста - интеграция

git add MyIIS/Services/APIService.swift
git commit -m "feat: добавлена интеграция Profile API

- Реализован getUserProfile метод
- Соответствие Swagger документации
- Обработка ошибок"

# Тестирую в симуляторе

# Делаю скриншоты через MCP

git add Tests/Screenshots/ProfileView/
git commit -m "test: добавлены скриншоты ProfileView"

# Финальные доработки

git add .
git commit -m "style: финальные улучшения ProfileView

- Обновлены цвета
- Улучшены анимации
- Соответствие Liquid Glass стилю"

# Отправляю на ревью

git push -u origin feature/profile-screen

# Создаю PR на GitHub
# Жду ревью и одобрения
# После merge - возвращаюсь в main

git checkout main
git pull
git branch -d feature/profile-screen
```

---

**Помни:** Качественные коммиты и правильный workflow - 
залог успешного проекта! 🚀
