# ⛔️ НЕ СОЗДАВАЙ ДОКУМЕНТАЦИЮ!

## 🚨 КРИТИЧЕСКИ ВАЖНО

### GitHub Copilot часто пытается создавать .md файлы!

**ЭТО ЗАПРЕЩЕНО!**

---

## ❌ Что НЕ НУЖНО создавать:

- `README.md` в корне проекта
- `SUMMARY.md` в корне проекта  
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `API_DOCS.md`
- `SETUP.md`
- `ARCHITECTURE.md`
- `TESTING.md`
- Любые другие `.md` файлы
- Документацию в любом виде
- Описательные текстовые файлы

---

## ✅ Что НУЖНО создавать:

- **ТОЛЬКО `.swift` файлы!**
- Models в `MyIIS/Models/`
- Views в `MyIIS/Views/`
- ViewModels в `MyIIS/ViewModels/`
- Services в `MyIIS/Services/`
- Тесты в `Tests/APITests/`
- Компоненты в `MyIIS/Views/Components/`

---

## 📚 Вся документация УЖЕ СОЗДАНА!

Она находится в `.github/` папке:

1. `copilot-instructions.md` - Главный файл с инструкциями
2. `QUICK-START.md` - Быстрый старт
3. `mcp-context7-guide.md` - Context7 гайд
4. `mcp-simulator-cheatsheet.md` - Simulator шпаргалка
5. `git-workflow-guide.md` - Git workflow
6. `mvvm-pattern-guide.md` - MVVM паттерн
7. `README.md` - Навигация
8. `SUMMARY.md` - Итоговая сводка

**Этого достаточно! Больше документов НЕ НУЖНО!**

---

## 🎯 Если Copilot предлагает создать .md файл:

### Правильный ответ:

```
❌ Нет! Не создавай .md файлы!

Вся документация уже создана в .github/ папке.
Мне нужен только .swift код.

Создай вместо этого:
- Model в MyIIS/Models/
- View в MyIIS/Views/
- ViewModel в MyIIS/ViewModels/
- Service в MyIIS/Services/
```

---

## 🔥 Частые попытки AI создать документацию:

### Попытка 1: "Создам README для лучшей документации"
**Ответ:** ❌ НЕТ! README уже есть в .github/

### Попытка 2: "Добавлю CHANGELOG для отслеживания изменений"
**Ответ:** ❌ НЕТ! Используй git log

### Попытка 3: "Создам API_DOCS для документирования API"
**Ответ:** ❌ НЕТ! API документация на SwaggerHub

### Попытка 4: "Напишу CONTRIBUTING guide для разработчиков"
**Ответ:** ❌ НЕТ! Все инструкции в copilot-instructions.md

### Попытка 5: "Создам SUMMARY после завершения работы"
**Ответ:** ❌ НЕТ! SUMMARY.md уже есть!

---

## 💡 Правильный workflow:

### Задача: Создать новый экран Profile

**❌ Неправильно:**
```
1. Создаю ProfileView.swift
2. Создаю ProfileViewModel.swift
3. Создаю README.md с описанием ← СТОП! Нельзя!
4. Создаю PROFILE_SETUP.md ← СТОП! Нельзя!
```

**✅ Правильно:**
```
1. Создаю Model: MyIIS/Models/UserProfile.swift
2. Создаю View: MyIIS/Views/ProfileView.swift
3. Создаю ViewModel: MyIIS/ViewModels/ProfileViewModel.swift
4. Создаю Service метод в: MyIIS/Services/APIService.swift
5. Создаю тест: Tests/APITests/ProfileAPITest.swift
6. Делаю коммит с понятным сообщением
7. ВСЁ! Никаких .md файлов!
```

---

## 📝 В коммите можно описать изменения:

```bash
git commit -m "feat: добавлен ProfileView

- Создан UserProfile model для данных пользователя
- Реализован ProfileView в стиле Liquid Glass
- Добавлен ProfileViewModel с логикой загрузки
- Интегрирован API endpoint /user/profile
- Добавлены тесты ProfileAPITest
- Протестировано в симуляторе iPhone 17 Pro"
```

**Видишь? Все описание в commit message!**  
**Не нужно создавать отдельный .md файл!**

---

## ⚡️ Исключения (единственные места для .md):

- `.github/` - уже создана, не трогать!
- Больше нигде!

---

## 🎓 Запомни раз и навсегда:

```
MyIIS проект = только .swift файлы

Документация = только в .github/

Если хочешь что-то задокументировать:
→ Напиши в commit message
→ Добавь комментарии в код
→ НЕ создавай .md файлы!
```

---

## 🔴 Красная линия:

**Если ты видишь, что AI создает .md файл:**

1. **ОСТАНОВИ** немедленно
2. **СКАЖИ:** "Нет! Не создавай .md файлы!"
3. **ПОПРОСИ:** "Создай только .swift код"
4. **УДАЛИ** случайно созданные .md (кроме .github/)

---

**Это правило спасет проект от захламления!** 🚀

---

**P.S.** Если возникла РЕАЛЬНАЯ необходимость добавить документацию:
1. Сначала подумай: точно ли нужна?
2. Может, достаточно комментариев в коде?
3. Может, достаточно commit message?
4. Если 100% нужна - спроси у владельца проекта
5. Только после одобрения - создавай в `.github/`

**Но в 99.9% случаев - НЕ НУЖНО!** ✋
