# 📡 API Documentation

## 🎯 Какой файл открыть?

### Если нужно быстро узнать рабочие эндпоинты:
👉 **`QUICK_REFERENCE.md`** - краткая справка (30 секунд на чтение)

### Если нужна полная документация реальных эндпоинтов:
👉 **`REAL_API_ENDPOINTS.md`** - всё про работающие эндпоинты с примерами

### Если нужна официальная документация (ВНИМАНИЕ: УСТАРЕЛА!):
👉 **`API_REFERENCE.swift`** - SwaggerHub v2.0.0 (НЕ СООТВЕТСТВУЕТ реальности!)

---

## 📊 Структура папки

```
API/
├── README.md              ← Вы здесь
├── QUICK_REFERENCE.md     ← Быстрая шпаргалка (рабочие эндпоинты)
├── REAL_API_ENDPOINTS.md  ← Полная документация (реальное API v1)
└── API_REFERENCE.swift    ← SwaggerHub документация (НЕ РАБОТАЕТ! v2)
```

---

## ⚠️ ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ

**Официальная документация SwaggerHub НЕ СООТВЕТСТВУЕТ реальному API!**

### Основные отличия:

| Параметр | Документация | Реальность |
|----------|--------------|------------|
| API версия | v2 | **v1** ✅ |
| Login путь | `/auth` | **`/auth/login`** ✅ |
| Аутентификация | JWT Token | **SESSION Cookie** ✅ |
| Login response | `{token}` | **`{username, fio, ...}`** ✅ |
| Profile путь | `/students/me` | **`/personal-information`** ✅ |

### Что делать?

1. ✅ Используй **`REAL_API_ENDPOINTS.md`** для актуальной информации
2. ✅ Используй **`QUICK_REFERENCE.md`** для быстрого доступа
3. ❌ НЕ полагайся на **`API_REFERENCE.swift`** без проверки
4. 🧪 Всегда **тестируй новые эндпоинты** через Python перед использованием

---

## 🧪 Тестирование

Примеры Python скриптов для тестирования API:

```bash
# Перейти в Tests/
cd /Volumes/Data/Developer/MyIIS/Tests

# Активировать venv (если есть)
source venv/bin/activate

# Запустить тест
python api_full_test.py
```

Результаты сохраняются в:
- `Tests/api_test_results.json`
- `Tests/login_response.json`
- `Tests/profile_response.json`

---

## 📝 История изменений

### 2025-01-15
- ✅ Создана документация реальных эндпоинтов
- ✅ Добавлено предупреждение в API_REFERENCE.swift
- ✅ Создана быстрая справка QUICK_REFERENCE.md
- ✅ Протестированы: `/auth/login`, `/personal-information`

---

## 🔗 Связанные файлы

- **Swift реализация**: `/MyIIS/Services/APIService.swift`
- **Python тесты**: `/Tests/api_url_tester.py`, `/Tests/api_full_test.py`
- **Результаты тестов**: `/Tests/*.json`
- **Отчёт**: `/Tests/IMPLEMENTATION_REPORT.md`

---

## 📞 Контакты

- **GitHub API**: https://github.com/N1ghtF1re/Bsuir-Additional-Api
- **SwaggerHub**: https://app.swaggerhub.com/apis/N1ghtF1re/BsuirAdditionalApi/2.0.0
- **Email**: pankratiew@brakhmen.info

⚠️ **Примечание**: Даже официальные источники могут быть неактуальны!
